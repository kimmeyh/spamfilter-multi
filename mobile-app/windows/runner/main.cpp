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
  log << L"[" << ts.str() << L"] [STARTUP] Background scan skipped: " << reason << L"\n";
}

// F109c (Sprint 44): record a deferral event to a machine-readable HANDOFF
// FILE so the Dart side can later insert a `status='deferred'` row into the
// `background_scan_log` table (the deferral is detected here in C++ BEFORE any
// Dart/DB access exists, so we cannot write the DB row directly). The Dart
// ingest (`BackgroundDeferralIngest`) reads + clears this file on the next
// foreground launch. One line per deferral: `<epochMillis>\t<accountId>`.
// Best-effort: any failure is silently ignored (the file log above is the
// human-readable fallback).
//
// PRIVACY (PR #266 Copilot review): the account id is email-derived (PII), so
// the handoff file is written to the app-support ROOT, NOT the `logs/` dir --
// keeping the PII out of the shareable log area that may end up in support
// bundles. It is consumed + deleted on the next foreground ingest (minimal
// retention). dev/prod split via the data-dir suffix as elsewhere.
static void RecordBackgroundScanDeferral(const std::wstring& accountId) {
  wchar_t appDataPath[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appDataPath))) {
    return;
  }
  // SPAMFILTER_APP_ENV: defined once at file scope (hoisted guard; ADR-0041).
  const bool isDevEnv = (std::string(SPAMFILTER_APP_ENV) != "prod");
  // App-support ROOT (NOT logs/) -- keeps the email-derived account id out of
  // the shareable log area (PR #266 Copilot review). Dart ingests + deletes it.
  std::wstring dataDir = std::wstring(appDataPath)
      + L"\\MyEmailSpamFilter\\MyEmailSpamFilter"
      + (isDevEnv ? L"_Dev" : L"");
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
