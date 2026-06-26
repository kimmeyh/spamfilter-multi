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

// BUG-S37-1 (Sprint 38, Issue #256): Sprint 37 Phase 5.3 surfaced
// SqfliteFfiException(sqlite_error: 5, "database is locked") when the
// foreground UI was running and a scheduled --background-scan launched
// a second process holding the same DB. Root cause: main.cpp previously
// skipped the single-instance mutex entirely for --background-scan,
// so the scheduled scan acquired its own DB connection in parallel
// with the UI's connection across processes. Fix: even in
// --background-scan mode, check whether the foreground mutex is held.
// If it is, log the skip and exit cleanly; the Task Scheduler will
// retry on the next interval.
static void LogBackgroundScanSkip(const std::wstring& reason) {
  wchar_t appDataPath[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appDataPath))) {
    return;
  }
  // Match Dart-side path:
  //   {AppData}\\MyEmailSpamFilter\\MyEmailSpamFilter[_Dev]\\logs\\[dev_]background_scan_v0.5.4.log
  // We don't know dev-vs-prod from C++ without SPAMFILTER_APP_ENV (defined below),
  // so write to a deterministic startup-skip log that both environments share.
  //
  // The "dev" fallback when the macro is undefined is INTENTIONAL per Sprint 37
  // F52 design: `flutter build windows` invoked directly (without going through
  // `scripts/build-windows.ps1`) should produce a usable dev binary for
  // new-developer convenience. Prod builds go through the documented
  // `build-windows.ps1 -Environment prod` and `docs/STORE_RELEASE_PROCESS.md`
  // paths, both of which set SPAMFILTER_APP_ENV=prod before CMake configures.
  #ifndef SPAMFILTER_APP_ENV
  #define SPAMFILTER_APP_ENV "dev"
  #endif
  const bool isDevEnv = (std::string(SPAMFILTER_APP_ENV) != "prod");
  std::wstring dataDir = std::wstring(appDataPath)
      + L"\\MyEmailSpamFilter\\MyEmailSpamFilter"
      + (isDevEnv ? L"_Dev" : L"")
      + L"\\logs";
  CreateDirectoryW(dataDir.c_str(), nullptr);
  std::wstring logPath = dataDir
      + (isDevEnv ? L"\\dev_background_scan_v0.5.4.log" : L"\\background_scan_v0.5.4.log");

  std::wofstream log(logPath, std::ios::app);
  if (!log.is_open()) return;
  auto now = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  std::tm tm_local;
  localtime_s(&tm_local, &t);
  std::wstringstream ts;
  ts << std::put_time(&tm_local, L"%Y-%m-%dT%H:%M:%S");
  log << L"[" << ts.str() << L"] [STARTUP] Background scan skipped: " << reason << L"\n";
}

// F109c (Sprint 44): record a deferral event to a machine-readable HANDOFF
// FILE so the Dart side can later insert a `status='deferred'` row into the
// `background_scan_log` table (the deferral is detected here in C++ BEFORE any
// Dart/DB access exists, so we cannot write the DB row directly). The Dart
// ingest (BackgroundDeferralStore) reads + clears this file on the next
// foreground launch. One line per deferral: `<epochMillis>\t<accountId>`.
// Best-effort: any failure is silently ignored (the file log above is the
// human-readable fallback). The handoff file shares the logs dir + dev/prod
// split with the skip log.
static void RecordBackgroundScanDeferral(const std::wstring& accountId) {
  wchar_t appDataPath[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appDataPath))) {
    return;
  }
  #ifndef SPAMFILTER_APP_ENV
  #define SPAMFILTER_APP_ENV "dev"
  #endif
  const bool isDevEnv = (std::string(SPAMFILTER_APP_ENV) != "prod");
  std::wstring dataDir = std::wstring(appDataPath)
      + L"\\MyEmailSpamFilter\\MyEmailSpamFilter"
      + (isDevEnv ? L"_Dev" : L"")
      + L"\\logs";
  CreateDirectoryW(dataDir.c_str(), nullptr);
  // Shared filename across environments (the dir already encodes dev/prod).
  std::wstring handoffPath = dataDir + L"\\background_scan_deferrals.tsv";

  std::wofstream handoff(handoffPath, std::ios::app);
  if (!handoff.is_open()) return;
  auto now = std::chrono::system_clock::now();
  long long epochMillis = std::chrono::duration_cast<std::chrono::milliseconds>(
      now.time_since_epoch()).count();
  handoff << epochMillis << L"\t" << accountId << L"\n";
}

// F109c: extract the value of `--account-id=<id>` from the command line, or an
// empty string if absent (a non-account-scoped run).
static std::wstring ExtractAccountId(const std::wstring& cmdLine) {
  const std::wstring key = L"--account-id=";
  size_t pos = cmdLine.find(key);
  if (pos == std::wstring::npos) return L"";
  size_t valStart = pos + key.length();
  size_t valEnd = cmdLine.find(L' ', valStart);
  if (valEnd == std::wstring::npos) valEnd = cmdLine.length();
  return cmdLine.substr(valStart, valEnd - valStart);
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
  // BUG-S37-1 (Sprint 38): Background-scan mode now ALSO consults this mutex
  // (read-only). If the foreground UI is running, we exit cleanly rather
  // than opening a parallel DB connection that would race with the UI.
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  std::wstring pathStr(exePath);
  size_t pathHash = std::hash<std::wstring>{}(pathStr);
  std::wstring mutexName = L"Global\\MyEmailSpamFilter_" + std::to_wstring(pathHash);

  if (isBackgroundScan) {
    // Read-only probe: try to open the mutex. If it exists, foreground UI is
    // already running -> defer this scan to the next scheduled interval.
    HANDLE hExisting = OpenMutexW(SYNCHRONIZE, FALSE, mutexName.c_str());
    if (hExisting != nullptr) {
      CloseHandle(hExisting);
      LogBackgroundScanSkip(L"Foreground UI is running (mutex held); scan deferred to next interval.");
      // F109c (Sprint 44): also record the deferral to the handoff file so the
      // Dart side can surface it (a background_scan_log 'deferred' row + the
      // Settings status line). Best-effort; never blocks the clean exit.
      RecordBackgroundScanDeferral(ExtractAccountId(cmdLine));
      return EXIT_SUCCESS;
    }
    // No foreground UI -> proceed with background scan. Do NOT acquire the
    // mutex ourselves; the scan worker may overlap with a future UI launch
    // and we want the future UI to win.
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
