# Copilot Code Review Instructions

Scope: flag real issues in PR diffs. Out of scope: formatting handled by `flutter analyze` and `dart format`.

## Project

Cross-platform Flutter/Dart email spam filter. Primary targets: Windows 11 (Microsoft Store) and Android. Provider-agnostic core (`lib/core/`), adapter pattern (`lib/adapters/`), Flutter UI (`lib/ui/`). IMAP + OAuth for AOL, Gmail, Yahoo. Rules and safe-senders use regex patterns in YAML and a SQLite DB.

## Flag These

### Security
- Secrets in code: `secrets.dev.json`, `google-services.json`, `client_secret_*.json`, API keys, OAuth tokens, passwords in strings or logs.
- Unredacted email addresses or tokens in log statements. Use `Redact.email()`, `Redact.accountId()`, `Redact.token()` from `lib/util/redact.dart`.
- Direct `regex.hasMatch()` on user-provided patterns without timeout protection. Prefer `PatternCompiler.safeHasMatch()` or gate with `PatternCompiler.detectReDoS()`.
- Raw SQL string concatenation. All DB operations must be parameterized.
- Missing input validation at trust boundaries (user input, external APIs, YAML imports).

### Correctness
- State bugs: `ChangeNotifier` mutations without `notifyListeners()`; historical vs. live data confusion (see `ResultsDisplayScreen` where `historicalScanId` must take precedence over live provider results).
- Async misuse: missing `await`, unhandled `Future`, `setState` after `dispose`.
- Silent failures: empty catch blocks, `catch (e) {}` without logging, fallbacks that hide errors. Log with `Logger.w()` at minimum.
- Null-safety errors the analyzer missed.

### Conventions
- Use `Logger` (package:logger) in `lib/`. `print()` only in `test/`.
- No contractions in comments or docs: "do not" not "don't", "cannot" not "can't".
- No emojis in code or logs. Use `[OK]`, `[FAIL]`, `[WARNING]`, `[PENDING]`. Customer-facing UI text is the only exception.
- PowerShell is primary shell. Flag bash-only syntax in developer scripts.
- No Linux tools (`jq`, `sed`, `awk`, `grep`, `find`, `cat`) in scripts.

### Architecture
- Core (`lib/core/`) must not import adapters (`lib/adapters/`). Adapters may import core.
- Storage goes through `AppPaths`. Flag hardcoded paths like `AppData\Roaming\...`.
- DB is sole source of truth for rules since Sprint 20. Flag dual-write patterns (YAML + DB) reintroduced.
- Platform-specific code must be guarded with `Platform.isWindows` / `isAndroid`, not assumed.

### Testing
- New code in `lib/` should have matching tests in `test/`. Flag `lib/` additions without tests.
- Prefer integration tests over mocks for DB and storage code.
- Do not lower assertions to pass tests; fix the underlying code.

### PR Hygiene
- Claude Code PRs target `develop`, never `main`. Flag PRs targeting `main` from a feature branch.
- CHANGELOG.md must be updated for user-facing changes under `## [Unreleased]`.

## Cross-Cutting Pattern Sweep

When a PR applies a pattern that should be codebase-wide (logging redaction, error handling, input validation, accessibility), check whether similar sites elsewhere in `lib/` were missed. Tag as `POTENTIAL_MISS: <file:line>`.

## De-Emphasize

- Formatting, whitespace, import ordering (handled by `dart format` + `flutter analyze`).
- Naming bikesheds when the existing name is clear.
- Doc style beyond "no contractions, no emojis".
- Refactors unrelated to the PR's purpose.
