"""Resolve optional development tools without depending on a user's cache layout."""
import os
import shutil
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]


def tool_path(name: str) -> Path:
    if name == "eve":
        override = os.environ.get("EVE_EXE")
        local = PROJECT / ".tools/evengine/eve-sdk/win32/bin/eve.exe"
        legacy = Path.home() / ".codex/cache/evengine/v0.6.0/sdk/eve-sdk/win32/bin/eve.exe"
        executable = "eve"
    else:
        override = os.environ.get("MESEN_AGENT")
        local = PROJECT / ".tools/mesen/mesen-agent.exe"
        legacy = Path.home() / ".local/bin/mesen-agent.exe"
        executable = "mesen-agent"
    if override:
        return Path(override)
    if local.is_file():
        return local
    found = shutil.which(executable)
    return Path(found) if found else legacy
