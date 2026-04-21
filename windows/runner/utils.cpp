#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <cctype>
#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

void HandleIncomingPensineFile(const std::vector<std::string>& args) {
  constexpr size_t kMaxBytes = 10 * 1024 * 1024;  // matches Dart-side import cap
  const std::string suffix = ".pensine";

  for (const auto& arg : args) {
    if (arg.size() < suffix.size()) continue;
    bool match = true;
    for (size_t i = 0; i < suffix.size(); ++i) {
      char c = arg[arg.size() - suffix.size() + i];
      if (std::tolower(static_cast<unsigned char>(c)) != suffix[i]) {
        match = false;
        break;
      }
    }
    if (!match) continue;

    int wide_len = ::MultiByteToWideChar(CP_UTF8, 0, arg.c_str(), -1, nullptr, 0);
    if (wide_len <= 0) continue;
    std::vector<wchar_t> wide_path(wide_len);
    ::MultiByteToWideChar(CP_UTF8, 0, arg.c_str(), -1, wide_path.data(), wide_len);

    HANDLE src = ::CreateFileW(wide_path.data(), GENERIC_READ, FILE_SHARE_READ,
                               nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (src == INVALID_HANDLE_VALUE) continue;

    LARGE_INTEGER size{};
    if (!::GetFileSizeEx(src, &size) || size.QuadPart <= 0 ||
        static_cast<size_t>(size.QuadPart) > kMaxBytes) {
      ::CloseHandle(src);
      continue;
    }

    std::vector<char> buffer(static_cast<size_t>(size.QuadPart));
    DWORD read = 0;
    BOOL ok = ::ReadFile(src, buffer.data(), static_cast<DWORD>(buffer.size()),
                         &read, nullptr);
    ::CloseHandle(src);
    if (!ok || read == 0) continue;

    wchar_t temp_dir[MAX_PATH];
    DWORD temp_len = ::GetTempPathW(MAX_PATH, temp_dir);
    if (temp_len == 0 || temp_len >= MAX_PATH) continue;
    std::wstring out_path(temp_dir);
    out_path += L"pensine_incoming.pensine";

    HANDLE dst = ::CreateFileW(out_path.c_str(), GENERIC_WRITE, 0, nullptr,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (dst == INVALID_HANDLE_VALUE) continue;
    DWORD written = 0;
    ::WriteFile(dst, buffer.data(), read, &written, nullptr);
    ::CloseHandle(dst);
    return;  // first .pensine arg wins
  }
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}
