# Copilot Code Review Instructions

Scope: flag real issues in PR diffs. Out of scope: formatting handled by `flutter analyze` and `dart format`.

## Repository Layout

This repository is a monorepo. The Flutter/Dart app lives under `mobile-app/` (code in `mobile-app/lib/`, tests in `mobile-app/test/`). Sibling top-level directories (`docs/`, `scripts/`, `.github/`, `rules.yaml`) are not Flutter code. Flutter-specific rules below apply only to files under `mobile-app/`.

## Project

Cross-platform Flutter/Dart email spam filter. Primary targets: Windows 11 (Microsoft Store) and Android. Provider-agnostic core (`mobile-app/lib/core/`), adapter pattern (`mobile-app/lib/adapters/`), Flutter UI (`mobile-app/lib/ui/`). IMAP + OAuth for AOL, Gmail, Yahoo. Rules and safe-senders use regex patterns in YAML and a SQLite DB.

## Flag These

### Security
- Secrets in code: `secrets.dev.json`, `google-services.json`, `client_secret_*.json`, API keys, OAuth tokens, passwords in strings or logs.
- Unredacted email addresses or tokens in log statements. Use `Redact.email()`, `Redact.accountId()`, `Redact.token()` from `mobile-app/lib/util/redact.dart`.
- Direct `regex.hasMatch()` on user-provided patterns without timeout protection. Prefer `PatternCompiler.safeHasMatch()` or gate with `PatternCompiler.detectReDoS()`.
- Raw SQL string concatenation. All DB operations must be parameterized.
- Missing input validation at trust boundaries (user input, external APIs, YAML imports).

### Correctness
- State bugs: `ChangeNotifier` mutations without `notifyListeners()`; historical vs. live data confusion (see `ResultsDisplayScreen` where `historicalScanId` must take precedence over live provider results).
- Async misuse: missing `await`, unhandled `Future`, `setState` after `dispose`.
- Silent failures: empty catch blocks, `catch (e) {}` without logging, fallbacks that hide errors. Log with `Logger.w()` at minimum.
- Null-safety errors the analyzer missed.

### Conventions
- Use `Logger` (package:logger) in `mobile-app/lib/`. `print()` only in `mobile-app/test/`.
- No contractions in comments or docs. Use "do not" and "cannot".
- No emojis in code or logs. Use `[OK]`, `[FAIL]`, `[WARNING]`, `[PENDING]`. Customer-facing UI text is the only exception.
- PowerShell is the primary shell for developer scripts. Flag bash-only syntax.
- No UNIX/GNU-style CLI tools (`jq`, `sed`, `awk`, `grep`) in scripts. Use PowerShell cmdlets or Flutter tooling. Note: `cat`, `find`, `ls` are also PowerShell aliases on Windows, so flag only when used with UNIX-style arguments.

### Architecture
- Core (`mobile-app/lib/core/`) must not import adapters (`mobile-app/lib/adapters/`). Adapters may import core.
- Storage goes through `AppPaths`. Flag hardcoded paths like `AppData\Roaming\...`.
- DB is sole source of truth for rules since Sprint 20. Flag dual-write patterns (YAML + DB) reintroduced.
- Platform-specific code must be guarded with `Platform.isWindows` / `isAndroid`, not assumed.

### Testing
- New code in `mobile-app/lib/` should have matching tests in `mobile-app/test/`. Flag `mobile-app/lib/` additions without tests.
- Prefer integration tests over mocks for DB and storage code.
- Do not lower assertions to pass tests; fix the underlying code.

### PR Hygiene
- Claude Code PRs target `develop`, never `main`. Flag PRs targeting `main` from a feature branch.
- CHANGELOG.md must be updated for user-facing changes under `## [Unreleased]`.

## Cross-Cutting Pattern Sweep

When a PR applies a pattern that should be codebase-wide (logging redaction, error handling, input validation, accessibility), check whether similar sites elsewhere in `mobile-app/lib/` were missed. Tag as `POTENTIAL_MISS: <file:line>`.

## De-Emphasize

- Formatting, whitespace, import ordering (handled by `dart format` + `flutter analyze`).
- Naming bikesheds when the existing name is clear.
- Doc style beyond "no contractions, no emojis".
- Refactors unrelated to the PR's purpose.
