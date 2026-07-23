# ADR-0041: Environment propagation -- the APP_ENV dart-define is the single source of truth

**Status**: Accepted (Chief Architect decision 2026-07-21, option 1 of 3 surfaced in-sprint; documented 2026-07-22 per Sprint 49 retro IMP-4)
**Sprint**: 49
**Supersedes**: the Sprint 37 F52 env-var-only native sourcing (not a numbered ADR; documented in `runner/CMakeLists.txt` / `main.cpp` comments)
**Related**: ADR-0035 (production/development side-by-side)

## Context

The app's dev/prod identity is compiled into TWO independent surfaces:

1. **Dart**: `AppEnvironment` reads the `APP_ENV` dart-define (`String.fromEnvironment`) -- drives the About text, data-directory suffix, log prefixes, and scan-log filenames.
2. **Native (Windows runner)**: `SPAMFILTER_APP_ENV`, a C++ compile definition set by `runner/CMakeLists.txt` at configure time -- drives the Win32 window title and the native log paths.

The Sprint 37 F52 design sourced the native definition ONLY from an OS environment variable that `build-windows.ps1` exported. The Microsoft Store build path (`flutter pub run msix:create`) never set that variable, so CMake silently defaulted to `"dev"` -- and the **0.5.5 and 0.5.6 Store releases shipped a `[DEV]` window title on a correctly-prod Dart build** (defect F119-c, the third member of the F119 family). Two independently-compiled surfaces silently diverged, and every check that examined only one surface passed.

## Decision

**The `--dart-define=APP_ENV=<env>` flag is the single source of truth for BOTH compiled surfaces.**

- The flutter tool records the build's dart-defines in `windows/flutter/ephemeral/generated_config.cmake` (entries individually base64-encoded). `runner/CMakeLists.txt` derives `SPAMFILTER_APP_ENV` from the `APP_ENV` entry via a deterministic bounded token match (`base64("APP_ENV=prod") == "QVBQX0VOVj1wcm9k"`; dev token likewise) -- no decode step, no new tooling.
- **Precedence**: (1) the `APP_ENV` dart-define when present; (2) the `SPAMFILTER_APP_ENV` environment variable (kept as a fallback -- `build-windows.ps1` still exports it, redundantly and consistently; also covers direct-CMake edge cases); (3) `"dev"` (new-developer convenience for a bare `flutter build windows`).
- **Verification is two-sided by construction**: the native runner passes its compiled value to Dart (`--native-app-env=` entrypoint argument) and the `--print-env` probe prints both `APP_ENV` and `NATIVE_APP_ENV`. `STORE_RELEASE_PROCESS.md` Step 4.0 requires BOTH to read `prod` before any Store submission. Policy pins in `test/policy/msix_config_test.dart` fail the suite if the derivation, the passthrough, or the probe line is removed.

## Consequences

- One flag (`msix_config.windows_build_args` for Store builds; `build-windows.ps1` for local builds) drives every environment-bearing surface; the class of one-surface-silently-dev defects is structurally closed.
- Release verification proves the compiled result, not the build log (the log showed the correct command for BOTH defective releases).
- The env-var path remains functional, so Sprint 37-era workflows are unaffected.
- Anyone adding a THIRD compiled surface (e.g. a future service binary) must derive it from the same dart-define and extend the probe -- pinned by this ADR and the policy tests.
