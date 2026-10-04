#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <string>
#include <fstream>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <functional>

#include "flutter_window.h"
#include "utils.h"

// SPAMFILTER_APP_ENV is baked in at compile time by runner/CMakeLists.txt
// (F119-c: derived from the APP_ENV --dart-define first, the
// SPAMFILTER_APP_ENV environment variable second, "dev" fallback last).
// Hoisted guard: define once here so every use below (log paths, window
// title, and the --native-app-env passthrough) sees the same value. The
// "dev" fallback when the macro is undefined is INTENTIONAL per Sprint 37
// F52: a bare compile without the definition produces a usable dev binary.
#ifndef SPAMFILTER_APP_ENV
#define SPAMFILTER_APP_ENV "dev"
#endif

// F-VERSION-DERIVE (Sprint 49): the app version for log filenames, derived
// from the FLUTTER_VERSION compile definition (runner/CMakeLists.txt bakes it
// from pubspec.yaml via flutter's generated_config.cmake) -- never a
// hardcoded literal that drifts on a version bump (the F105 class: main.cpp
// shipped a stale hardcoded version once already). FLUTTER_VERSION is
// "X.Y.Z+B"; the log filenames use "X.Y.Z", so strip the build suffix.
#ifndef FLUTTER_VERSION
#define FLUTTER_VERSION "0.0.0"
#endif
static std::wstring AppVersionForLogs() {
  std::string v(FLUTTER_VERSION);
  const size_t plus = v.find('+');
  if (plus != std::string::npos) {
    v = v.substr(0, plus);
  }
  // Version strings are ASCII; widen directly.
  return std::wstring(v.begin(), v.end());
}

// Background-startup log line, written BEFORE any Dart/DB access exists.
//
// History: BUG-S37-1 (Sprint 38, Issue #256) made a --background-scan launch
// EXIT whenever the foreground UI was running, because two processes on one
// SQLite file then failed with "database is locked". F243 (Sprint 75, Harold
// 2026-10-03) removed that deferral: the database now runs in WAL mode with a
// 30 s busy_timeout (database_helper.dart), and the Sprint 74 per-account scan
// claim decides whether a background scan may run -- it skips only an account
// a live scan is using, and retries once after 2-6 minutes. This line now only
// RECORDS that the UI was open; the scan proceeds.
static void LogBackgroundStartup(const std::wstring& message) {
  wchar_t appDataPath[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appDataPath))) {
    return;
  }
  // Match Dart-side path:
  //   {AppData}\\MyEmailSpamFilter\\MyEmailSpamFilter[_Dev]\\logs\\[dev_]background_scan_v<version>.log
  // SPAMFILTER_APP_ENV is defined once at file scope (see the hoisted guard
  // near the top; sourced per ADR-0041 -- derived from the APP_ENV
  // dart-define by runner/CMakeLists.txt, env var fallback, "dev" default).
  const bool isDevEnv = (std::string(SPAMFILTER_APP_ENV) != "prod");
  std::wstring dataDir = std::wstring(appDataPath)
      + L"\\MyEmailSpamFilter\\MyEmailSpamFilter"
      + (isDevEnv ? L"_Dev" : L"")
      + L"\\logs";
  CreateDirectoryW(dataDir.c_str(), nullptr);
  std::wstring logPath = dataDir
      + (isDevEnv ? L"\\dev_background_scan_v" : L"\\background_scan_v")
      + AppVersionForLogs() + L".log";

  std::wofstream log(logPath, std::ios::app);
  if (!log.is_open()) return;
  auto now = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  std::tm tm_local;
  localtime_s(&tm_local, &t);
  std::wstringstream ts;
  ts << std::put_time(&tm_local, L"%Y-%m-%dT%H:%M:%S");
  log << L"[" << ts.str() << L"] [STARTUP] " << message << L"\n";
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::wstring cmdLine(command_line);
  bool isBackgroundScan = cmdLine.find(L"--background-scan") != std::wstring::npos;

  // Single-instance mutex per executable path (ADR-0035).
  // Production and dev builds have different paths, so they get different mutexes.
  // This prevents duplicate instances of the SAME environment while allowing
  // production and development to run simultaneously.
  //
  // F243 (Sprint 75): background-scan mode only READS this mutex, to log
  // whether the UI is open. It no longer exits when it is (that was BUG-S37-1,
  // Sprint 38) -- see LogBackgroundStartup for why that is safe now.
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  std::wstring pathStr(exePath);
  size_t pathHash = std::hash<std::wstring>{}(pathStr);
  std::wstring mutexName = L"Global\\MyEmailSpamFilter_" + std::to_wstring(pathHash);

  if (isBackgroundScan) {
    // Read-only probe, informational only (F243).
    HANDLE hExisting = OpenMutexW(SYNCHRONIZE, FALSE, mutexName.c_str());
    if (hExisting != nullptr) {
      CloseHandle(hExisting);
      LogBackgroundStartup(L"Foreground UI is running; background scan "
                           L"proceeds (F243 -- the per-account scan claim "
                           L"decides).");
    }
    // Never acquire the mutex here: the UI must still be able to open while
    // a background scan runs.
  } else {
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

  // F119-c (Sprint 49): expose the NATIVE compiled environment to the Dart
  // side so the `--print-env` probe (STORE_RELEASE_PROCESS.md Step 4.0)
  // verifies BOTH compiled sides. The Dart APP_ENV dart-define and this
  // native SPAMFILTER_APP_ENV are separate compile-time mechanisms that
  // silently diverged twice: the 0.5.5 and 0.5.6 Store MSIX shipped a
  // "[DEV]" native window title on a correctly-prod Dart build.
  command_line_arguments.push_back(
      std::string("--native-app-env=") + SPAMFILTER_APP_ENV);

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
  // SPAMFILTER_APP_ENV: defined once at file scope (hoisted guard). Sourcing
  // per ADR-0041: derived from the APP_ENV dart-define by
  // runner/CMakeLists.txt, env-var fallback, "dev" default.
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
