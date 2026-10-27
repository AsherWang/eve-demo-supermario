#include <windows.h>

#include <cwchar>
#include <string>

namespace {

std::wstring executableDirectory() {
    std::wstring path(32768, L'\0');
    const DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (length == 0 || length >= path.size()) return {};
    path.resize(length);
    const auto separator = path.find_last_of(L"\\/");
    return separator == std::wstring::npos ? std::wstring{} : path.substr(0, separator);
}

std::wstring quoted(const std::wstring& value) {
    std::wstring result = L"\"";
    for (const wchar_t character : value) {
        result += character;
        if (character == L'"') result += L'"';
    }
    result += L'"';
    return result;
}

void showError(const std::wstring& message) {
    MessageBoxW(nullptr, message.c_str(), L"Super Mario", MB_OK | MB_ICONERROR);
}

struct GameWindow {
    DWORD processId;
    HWND handle = nullptr;
};

BOOL CALLBACK findGameWindow(HWND window, LPARAM context) {
    auto& game = *reinterpret_cast<GameWindow*>(context);
    DWORD processId = 0;
    GetWindowThreadProcessId(window, &processId);
    wchar_t className[64]{};
    if (processId == game.processId &&
        GetClassNameW(window, className, 64) && std::wcscmp(className, L"SDL_app") == 0) {
        game.handle = window;
        return FALSE;
    }
    return TRUE;
}

bool revealAfterFirstPresent(const PROCESS_INFORMATION& process, const std::wstring& logPath) {
    // The pinned SDK has no hidden-window setting. Windows honors this
    // process's SW_HIDE startup flag on SDL's first ShowWindow call, while
    // Vulkan continues rendering. Reveal only after the SDK's present marker.
    HANDLE input = CreateFileW(logPath.c_str(), GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (input == INVALID_HANDLE_VALUE) return false;
    const ULONGLONG deadline = GetTickCount64() + 30000;
    std::string pending;
    bool revealed = false;
    while (GetTickCount64() < deadline) {
        char buffer[4096];
        DWORD count = 0;
        if (!ReadFile(input, buffer, sizeof(buffer), &count, nullptr)) break;
        pending.append(buffer, count);
        if (pending.find("eve_init failed:") != std::string::npos ||
            pending.find("Run failed:") != std::string::npos ||
            pending.find("frame error:") != std::string::npos ||
            pending.find("present error:") != std::string::npos) break;
        if (pending.find("[startup] first present - window shows content") != std::string::npos) {
            GameWindow game{process.dwProcessId};
            EnumWindows(findGameWindow, reinterpret_cast<LPARAM>(&game));
            if (game.handle != nullptr) {
                // The visible window belongs to the engine child, not this
                // launcher. Apply the game's identity before revealing it.
                SetWindowTextW(game.handle, L"Super Mario Bros. World 1-1 ~ 1-4 - EVEngine");
                const HINSTANCE module = GetModuleHandleW(nullptr);
                for (const int size : {ICON_SMALL, ICON_BIG}) {
                    const int metric = size == ICON_SMALL ? SM_CXSMICON : SM_CXICON;
                    const int heightMetric = size == ICON_SMALL ? SM_CYSMICON : SM_CYICON;
                    const auto icon = static_cast<HICON>(LoadImageW(module, MAKEINTRESOURCEW(1),
                        IMAGE_ICON, GetSystemMetrics(metric), GetSystemMetrics(heightMetric), LR_SHARED));
                    if (icon != nullptr) {
                        DWORD_PTR ignored = 0;
                        SendMessageTimeoutW(game.handle, WM_SETICON, static_cast<WPARAM>(size),
                            reinterpret_cast<LPARAM>(icon), SMTO_ABORTIFHUNG, 1000, &ignored);
                    }
                }
                ShowWindow(game.handle, SW_SHOW);
                SetForegroundWindow(game.handle);
                revealed = IsWindowVisible(game.handle) != FALSE;
                break;
            }
        }
        // Keep enough tail for markers split across reads, without retaining
        // the game's full state/event trace in the launcher.
        if (pending.size() > 8192) pending.erase(0, pending.size() - 1024);
        if (WaitForSingleObject(process.hProcess, 10) != WAIT_TIMEOUT) break;
    }
    CloseHandle(input);
    return revealed;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    const std::wstring root = executableDirectory();
    if (root.empty()) {
        showError(L"Could not determine the game folder.");
        return 1;
    }

    const std::wstring host = root + L"\\runtime\\eve.exe";
    if (GetFileAttributesW(host.c_str()) == INVALID_FILE_ATTRIBUTES) {
        showError(L"runtime\\eve.exe is missing. Extract the entire release ZIP before playing.");
        return 1;
    }

    SECURITY_ATTRIBUTES security{};
    security.nLength = sizeof(security);
    security.bInheritHandle = TRUE;
    const std::wstring logPath = root + L"\\game.log";
    HANDLE log = CreateFileW(logPath.c_str(), GENERIC_WRITE,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, &security,
                             CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    HANDLE nullInput = CreateFileW(L"NUL", GENERIC_READ,
                                   FILE_SHARE_READ | FILE_SHARE_WRITE, &security,
                                   OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (log == INVALID_HANDLE_VALUE || nullInput == INVALID_HANDLE_VALUE) {
        if (log != INVALID_HANDLE_VALUE) CloseHandle(log);
        if (nullInput != INVALID_HANDLE_VALUE) CloseHandle(nullInput);
        showError(L"Could not open game.log. Check that the game folder is writable.");
        return 1;
    }

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    startup.hStdInput = nullInput;
    startup.hStdOutput = log;
    startup.hStdError = log;
    PROCESS_INFORMATION process{};
    std::wstring command = quoted(host) + L" run " + quoted(root);
    const BOOL started = CreateProcessW(
        host.c_str(), command.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
        nullptr, root.c_str(), &startup, &process);
    CloseHandle(nullInput);
    CloseHandle(log);
    if (!started) {
        showError(L"Could not start the EVEngine runtime. See runtime\\eve.exe.");
        return 1;
    }

    if (!revealAfterFirstPresent(process, logPath)) {
        // Never leave an invisible hung engine behind after a failed boot.
        if (WaitForSingleObject(process.hProcess, 0) == WAIT_TIMEOUT) {
            TerminateProcess(process.hProcess, 1);
            WaitForSingleObject(process.hProcess, 5000);
        }
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        showError(L"The game could not prepare its first frame. See game.log for details.");
        return 1;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 1;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return static_cast<int>(exitCode);
}
