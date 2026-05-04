#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include <functional>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Skip single-instance check for background scan mode
  std::wstring cmdLine(command_line);
  bool isBackgroundScan = cmdLine.find(L"--background-scan") != std::wstring::npos;

  if (!isBackgroundScan) {
    // Single-instance mutex per executable path (ADR-0035)
    // Production and dev builds have different paths, so they get different mutexes.
    // This prevents duplicate instances of the SAME environment while allowing
    // production and development to run simultaneously.
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring pathStr(exePath);
    size_t pathHash = std::hash<std::wstring>{}(pathStr);
    std::wstring mutexName = L"Global\\MyEmailSpamFilter_" + std::to_wstring(pathHash);

    HANDLE hMutex = CreateMutexW(nullptr, TRUE, mutexName.c_str());
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
      // Another instance from the same path is already running
      // Find and activate the existing window
      HWND existingWindow = FindWindowW(nullptr, L"MyEmailSpamFilter");
      if (existingWindow == nullptr) {
        existingWindow = FindWindowW(nullptr, L"MyEmailSpamFilter [DEV]");
      }
      if (existingWindow != nullptr) {
        SetForegroundWindow(existingWindow);
        if (IsIconic(existingWindow)) {
          ShowWindow(existingWindow, SW_RESTORE);
        }
      }
      CloseHandle(hMutex);
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Determine window title based on APP_ENV (ADR-0035).
  //
  // Sprint 37 F52 Phase 1 (2026-04-29): SPAMFILTER_APP_ENV is baked
  // into the .exe at compile time via CMakeLists.txt, sourced from the
  // SPAMFILTER_APP_ENV environment variable seen by CMake at
  // configure time. This is the ONLY correct mechanism for the
  // Microsoft Store MSIX path -- the Store launcher does not pass
  // --dart-define on the command line, so any runtime-only check
  // would default to dev for the published prod binary. CMake-driven
  // compile-time defines are also robust for direct-launch variants
  // (Start-Process .exe).
  //
  // SPAMFILTER_APP_ENV defaults to "dev" if the env var was unset at
  // CMake configure time (CMakeLists.txt fallback).
  #ifndef SPAMFILTER_APP_ENV
  #define SPAMFILTER_APP_ENV "dev"
  #endif
  const bool isDevEnvironment = (std::string(SPAMFILTER_APP_ENV) != "prod");
  const wchar_t* windowTitle = isDevEnvironment
      ? L"MyEmailSpamFilter [DEV]"
      : L"MyEmailSpamFilter";

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(windowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
