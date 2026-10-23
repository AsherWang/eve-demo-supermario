#include <windows.h>

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
    MessageBoxW(nullptr, message.c_str(), L"Super Mario 1-1", MB_OK | MB_ICONERROR);
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
    startup.dwFlags = STARTF_USESTDHANDLES;
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

    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 1;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return static_cast<int>(exitCode);
}
