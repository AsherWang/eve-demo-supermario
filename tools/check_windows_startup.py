"""Check the packaged launcher's first-present visibility and startup failure path."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes as wt
import json
from pathlib import Path
import subprocess
import time


class ProcessEntry(ctypes.Structure):
    _fields_ = [
        ('dwSize', wt.DWORD), ('cntUsage', wt.DWORD), ('pid', wt.DWORD),
        ('heap', ctypes.c_size_t), ('module', wt.DWORD), ('threads', wt.DWORD),
        ('parent', wt.DWORD), ('priority', wt.LONG), ('flags', wt.DWORD),
        ('exe', wt.WCHAR * 260),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--expect-failure', action='store_true')
    parser.add_argument('--expected-error', help='Failure text that must appear in game.log')
    args = parser.parse_args()
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    user = ctypes.WinDLL('user32', use_last_error=True)
    kernel.CreateToolhelp32Snapshot.argtypes = [wt.DWORD, wt.DWORD]
    kernel.CreateToolhelp32Snapshot.restype = wt.HANDLE
    kernel.Process32FirstW.argtypes = [wt.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel.Process32NextW.argtypes = [wt.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel.CloseHandle.argtypes = [wt.HANDLE]
    kernel.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
    kernel.OpenProcess.restype = wt.HANDLE
    kernel.TerminateProcess.argtypes = [wt.HANDLE, wt.UINT]
    callback_type = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wt.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
    user.GetClassNameW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]
    user.IsWindowVisible.argtypes = [wt.HWND]
    user.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]

    def descendants(parent: int) -> set[int]:
        snapshot = kernel.CreateToolhelp32Snapshot(2, 0)
        if snapshot == wt.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        parents = {}
        try:
            entry = ProcessEntry()
            entry.dwSize = ctypes.sizeof(entry)
            valid = kernel.Process32FirstW(snapshot, ctypes.byref(entry))
            while valid:
                parents[entry.pid] = entry.parent
                valid = kernel.Process32NextW(snapshot, ctypes.byref(entry))
        finally:
            kernel.CloseHandle(snapshot)
        result = {parent}
        while True:
            added = {pid for pid, owner in parents.items() if owner in result} - result
            if not added:
                return result
            result.update(added)

    package = args.package.resolve()
    log = package / 'game.log'
    old_log = (log.stat().st_mtime_ns, log.stat().st_size) if log.exists() else None
    process = subprocess.Popen([str(package / 'SuperMario.exe')], cwd=package)
    begin = time.monotonic()
    result = {'passed': False, 'visible_before_present': False,
              'first_present_ms': None, 'visible_ms': None, 'error_dialog': False}
    seen_fresh_log = False
    game_window = None
    try:
        while time.monotonic() - begin < 35:
            owned = descendants(process.pid)
            if log.exists():
                signature = (log.stat().st_mtime_ns, log.stat().st_size)
                seen_fresh_log |= signature != old_log
            text = log.read_text(encoding='utf-8', errors='replace') if seen_fresh_log else ''
            ready = '[startup] first present - window shows content' in text
            if ready and result['first_present_ms'] is None:
                result['first_present_ms'] = round((time.monotonic() - begin) * 1000)
            windows = []

            @callback_type
            def visit(window, _):
                owner = wt.DWORD()
                user.GetWindowThreadProcessId(window, ctypes.byref(owner))
                if owner.value in owned and user.IsWindowVisible(window):
                    name = ctypes.create_unicode_buffer(64)
                    user.GetClassNameW(window, name, len(name))
                    windows.append((window, owner.value, name.value))
                return True

            user.EnumWindows(visit, 0)
            for window, owner, name in windows:
                if name == 'SDL_app':
                    game_window = window
                    # Re-read after enumeration to avoid racing the log write.
                    current = log.read_text(encoding='utf-8', errors='replace')
                    result['visible_before_present'] |= (
                        '[startup] first present - window shows content' not in current
                    )
                    if result['visible_ms'] is None:
                        result['visible_ms'] = round((time.monotonic() - begin) * 1000)
                elif name == '#32770' and owner == process.pid:
                    result['error_dialog'] = True
                    user.PostMessageW(window, 0x0010, 0, 0)  # Close only this test's dialog.
            if args.expect_failure and result['error_dialog'] and process.poll() is not None:
                result['passed'] = (process.returncode != 0 and result['visible_ms'] is None
                                    and owned == {process.pid}
                                    and (not args.expected_error or args.expected_error in text))
                break
            if not args.expect_failure and result['visible_ms'] is not None:
                result['passed'] = ready and not result['visible_before_present'] and not result['error_dialog']
                break
            if process.poll() is not None:
                break
            time.sleep(.01)
        if result['passed'] and not args.expect_failure and game_window is not None:
            # The pinned SDK ignores quit during its first 45 frames. Test
            # normal close after that guard, not immediately at first present.
            time.sleep(1)
            user.PostMessageW(game_window, 0x0112, 0xF060, 0)  # Native title-bar SC_CLOSE.
            try:
                process.wait(timeout=5)
                result['close_exit_code'] = process.returncode
                result['passed'] = process.returncode == 0
            except subprocess.TimeoutExpired:
                result['passed'] = False
                result['close_exit_code'] = 'timeout'
    finally:
        # Terminate only descendants of this test's launcher, never other games.
        for pid in descendants(process.pid) - {process.pid}:
            handle = kernel.OpenProcess(1, False, pid)
            if handle:
                kernel.TerminateProcess(handle, 1)
                kernel.CloseHandle(handle)
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=10)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
