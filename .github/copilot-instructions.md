# Copilot Code Review Instructions

Scope: flag real issues in PR diffs. Out of scope: formatting handled by `flutter analyze` and `dart format`.

Ignore repository root files matching `0*.md` and `0*.txt` during review. Do not include those files in findings or comments.

## Repository Layout & Project

Monorepo. The Flutter/Dart app lives under `mobile-app/` (code in `lib/`, tests in `test/`); the Flutter rules below apply only there. Sibling dirs (`docs/`, `scripts/`, `.github/`, `rules.yaml`) are not Flutter code. It is a cross-platform email spam filter -- targets Windows 11 (Microsoft Store) + Android; provider-agnostic core (`lib/core/`), adapters (`lib/adapters/`), UI (`lib/ui/`); IMAP + OAuth for AOL/Gmail/Yahoo; rules + safe-senders are regex in YAML and a SQLite DB.

## Flag These

### Security
- Secrets in code: `secrets.dev.json`, `google-services.json`, `client_secret_*.json`, API keys, OAuth tokens, passwords in strings or logs.
- Unredacted email addresses or tokens in logs. Use `Redact.email()` / `.accountId()` / `.token()` from `lib/util/redact.dart`.
- Direct `regex.hasMatch()` on user patterns without timeout. Prefer `PatternCompiler.safeHasMatch()` / `detectReDoS()`.
- Raw SQL string concatenation -- all DB ops must be parameterized.
- Missing input validation at trust boundaries (user input, external APIs, YAML imports).

### Correctness
- State bugs: `ChangeNotifier` mutations without `notifyListeners()`; historical-vs-live data confusion (`ResultsDisplayScreen`: `historicalScanId` must take precedence over live provider results).
- Async misuse: missing `await`, unhandled `Future`, `setState` after `dispose`.
- Silent failures: empty/log-less catch blocks, fallbacks that hide errors. Log with `Logger.w()` at minimum.
- Null-safety errors the analyzer missed.

### Conventions
- Use `Logger` (package:logger) in `mobile-app/lib/`. `print()` only in `mobile-app/test/`.
- No contractions in comments or docs. Use "do not" and "cannot".
- No emojis in code or logs. Use `[OK]`, `[FAIL]`, `[WARNING]`, `[PENDING]`. Customer-facing UI text is the only exception.
- PowerShell is the primary shell for developer scripts. Flag bash-only syntax.
- No UNIX/GNU CLI tools (`jq`, `sed`, `awk`, `grep`) in scripts; use PowerShell cmdlets. `cat`/`find`/`ls` are PS aliases -- flag only with UNIX-style args.

### Architecture
- Core (`mobile-app/lib/core/`) must not import adapters (`mobile-app/lib/adapters/`). Adapters may import core.
- Storage goes through `AppPaths`. Flag hardcoded paths like `AppData\Roaming\...`.
- DB is sole source of truth for rules since Sprint 20. Flag dual-write patterns (YAML + DB) reintroduced.
- Platform-specific code must be guarded with `Platform.isWindows` / `isAndroid`, not assumed.

### Testing
- New `lib/` code should have matching `test/` tests -- flag additions without tests.
- Prefer integration tests over mocks for DB/storage code. Do not lower assertions to pass tests; fix the code.

### PR Hygiene
- PRs target `develop`, never `main` -- flag a feature branch targeting `main`.
- CHANGELOG.md updated for user-facing changes under `## [Unreleased]`.

## Cross-Cutting Pattern Sweep

When a PR applies a pattern that should be codebase-wide (redaction, error handling, validation, accessibility) OR edits one of a known twin pair (a Dart gate + its PS1 CLI mirror; the manual + background scan paths; two call sites of one helper; a settings-display path vs the production scan path), check whether the sibling site was missed. Tag as `POTENTIAL_MISS: <file:line>`.

## Settled Decisions (do not re-flag; these are by-design)

- Body/message content is intentionally NOT persisted to `unmatched_emails` (SEC-14). Do not flag "the email body is dropped".
- `test/policy/version_consistency_test.dart` and `check-version-consistency.ps1` intentionally contain stale-version FIXTURE literals (e.g. `0.5.3`) for their self-tests; they are excluded from the sweep. Do not flag these as version drift.
- Scan-log filenames intentionally embed the app version (`live_scan_v0.5.x.log`); the version-consistency gate keeps them in sync. Do not flag the embedded version.
- Windows-desktop-only gating (`if (Platform.isWindows)`) on Review/No-Rule entry points and some scan UI is intentional (Android UX differs), not a platform-coverage gap.

## De-Emphasize

Formatting/whitespace/import order (handled by `dart format` + `flutter analyze`); naming bikesheds when the name is clear; doc style beyond "no contractions, no emojis"; refactors unrelated to the PR's purpose.
