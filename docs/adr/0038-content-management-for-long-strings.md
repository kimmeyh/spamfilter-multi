# ADR-0038: Content Management for Long Inline Strings

## Status

Accepted

## Date

2026-05-14

## Context

The app embeds substantial blocks of user-facing English prose directly as Dart string literals in `lib/ui/screens/*.dart`. Examples:

- `help_screen.dart` -- ~250-300 lines of explainer text across ~20 sections (`HelpSection` enum members), some sections concatenated across multiple line-continuation literals
- `settings_screen.dart` -- multi-paragraph descriptive subtitles on the General, Account, Manual Scan, and Background tabs
- Other screens contain shorter explainer paragraphs that may or may not cross the threshold

Each time Harold (the only authoring user) wants to refine the wording of a Help section or a Settings explainer, the flow is:

1. Open the Dart source file in an editor
2. Find the right string literal among Dart code, imports, build methods, etc.
3. Edit the prose
4. Re-run a debug build to preview the change
5. Re-run tests if any widget test asserts on the text
6. Commit the source change

This is friction-heavy for content edits that are not code changes. Authoring tools (spell-check, grammar tools, plain Markdown previewing) do not work well against Dart string literals. Anyone helping Harold edit content -- present or future -- must edit Dart code rather than a content asset.

### Driving Threshold

Any Dart string literal **longer than 500 characters** (whether one continuous string or a concatenation across adjacent line-continuation `'...' '...'` literals) is a candidate for extraction.

Threshold chosen because at that length the string is content authored for end-users, not a prompt or label, and editing it via Dart-source-edit + rebuild + commit is significantly more friction than editing a plain-text asset.

### Problems with the Current State

1. **Authoring friction**: edits require Dart-source editing tools, not content-authoring tools
2. **Diff noise**: a one-word fix in a 600-character string shows up as a single-line diff that's hard to review for content correctness
3. **No build-time validation**: an enum case can drift from its rendering branch (added a section, forgot to render it; or vice versa); the gap is only caught at runtime
4. **Test coupling**: widget tests that assert on copy text need updating in lockstep with source-string changes
5. **No path to localization**: future L10n requires extracting strings; better to design the structure now

## Decision

### Asset Format: Markdown per Section in a Directory Indexed by an Asset Manifest

Use **Markdown files, one per logical section, under `mobile-app/assets/content/`**, with a YAML asset manifest at `mobile-app/assets/content/manifest.yaml` that maps each `HelpSection` enum value (and equivalent route keys for non-Help content) to its `.md` file.

**Manifest example**:

```yaml
# manifest.yaml -- maps content keys to .md asset paths.
# Build-time validator (see "Validation" below) asserts every key
# corresponds to a file and every file is referenced by exactly one key.
help:
  scanHistory: help/scan_history.md
  manageRules: help/manage_rules.md
  manageSafeSenders: help/manage_safe_senders.md
  manualScan: help/manual_scan.md
  ...
settings:
  general: settings/general.md
  account: settings/account.md
  manualScan: settings/manual_scan.md
  background: settings/background.md
```

**Per-section file example** (`assets/content/help/scan_history.md`):

```markdown
# Scan History

The Scan History screen shows every manual scan and background scan
that has run for this account in the last N days...

## What you can do here

- Tap any row to view that scan's full Scan Results
- Filter by scan type (manual / background) or by account
- ...
```

### Why Markdown + Per-File over Alternatives

| Option | Pros | Cons | Decision |
|---|---|---|---|
| **(a) YAML keyed by enum** -- one big `help_content.yaml` | Single file, structured, easy to validate | Multi-paragraph content in YAML strings is awkward (`|`-block indentation, escaping); harder to author | Rejected |
| **(b) Markdown with H2/H3 anchors** in one big `help.md` | Readable as a standalone doc; familiar format | Requires anchor-parsing logic; one-file edits touch many sections in diff | Rejected for one-file; accepted per-file |
| **(c) JSON keyed by enum** | Matches Flutter's L10n format | Multi-paragraph content in JSON strings is awkward (newline escapes); least readable in source | Rejected |
| **(d) Per-section .md files** with manifest | Each section diff-isolated; authoring friendly (each is just a .md file); easy to render via `flutter_markdown`; manifest gives a single drift-detection point | Slightly more files in the tree; needs a manifest registry | **CHOSEN** |

### Loader Strategy: Build-Time Bake (Asset Bundle)

Files live in `pubspec.yaml` under `flutter.assets:` and are bundled into the app at build time. Loaded at runtime via `rootBundle.loadString(...)`. **Not** runtime-fetched from a server -- that would add a network dependency for content rendering and is out of scope for V1.

### Validation Strategy: Build-Time Generator Script

A new `mobile-app/scripts/validate-content-manifest.ps1` script runs as a pre-commit check (and via CI when we have CI):

1. Parse `assets/content/manifest.yaml`
2. For every key, assert the referenced `.md` file exists
3. For every `.md` file under `assets/content/`, assert it is referenced by exactly one manifest key (drift detection)
4. For the `help:` keys, assert every `HelpSection` enum value (read from `lib/ui/screens/help_screen.dart`) has a corresponding manifest entry
5. Exit non-zero on any mismatch with a clear diff

This script is wired into the **end of `build-windows.ps1`** before launch so a missing asset stops the build, and it is also exposed as `mobile-app/scripts/validate-content-manifest.ps1` for standalone invocation.

### Test Strategy

- Existing widget tests that assert on Help / Settings text are updated to **load from the asset bundle** rather than hardcoding the expected string. The test setup calls `rootBundle.loadString('assets/content/<path>')` and asserts the result is non-empty and renders without exception.
- A new test asserts the manifest validation script's pure-Dart logic (matching enum keys, finding orphan files) -- runs as a unit test, not a shell-out.
- Round-trip test: render each Help section in a widget test and assert it produces non-empty rendered output (catches a missing asset that the manifest validator did not catch -- e.g., the file exists but its content is empty).

### i18n Posture (Future-Proofing, Not V1)

Asset paths use a single English-only structure for V1:

```
assets/content/help/scan_history.md
assets/content/settings/general.md
```

If/when localization becomes a sprint priority, the structure extends to:

```
assets/content/en/help/scan_history.md
assets/content/fr/help/scan_history.md
```

with a locale-prefix added to the loader. The manifest remains a single file (each entry can map either a single asset path or a per-locale map). No V1 code requires this -- but the directory structure leaves room.

### Out of Scope for V1

- Rich content: embedded images, hyperlinks that open in browser. Text-only for V1. (May be added when F75 walkthrough lands.)
- Runtime asset fetching: bundled-only for V1. Server-side content updates without rebuild is a future enhancement.
- Locale switching: structure leaves room; runtime selection is a future sprint.
- Settings translation: the keys above are pre-i18n. When L10n is added, the manifest grows; keys do not change.

## Consequences

### Positive

- Harold can edit any migrated content by opening **one `.md` file** and re-running the app -- no Dart source touched, no test updates needed (tests load from asset)
- Diffs become content-focused: a one-word wording fix shows as a small change in one `.md` file
- Build-time validation catches drift between enum and asset
- Markdown is universally authorable (any editor with .md support: VS Code, GitHub web editor, etc.)
- Room for future localization without code changes
- Test scaffolding stays simple (assets are part of the bundle; `rootBundle.loadString` works in widget tests)

### Negative

- Slight increase in number of files in the repo (~25 new `.md` files for the Sprint 38 Phase 2/3 migrations)
- One additional pre-commit / build-time check (the manifest validator)
- First-time setup requires the migration sprint (this sprint, Tasks Phase 2 + 3)
- `flutter_markdown` package becomes a dependency (small footprint; widely used)

### Neutral

- Test count stays roughly flat: existing widget tests continue to work; a few new tests cover the manifest validator. Net new tests: ~3-5.

## Implementation Phases

**Phase 1 (this ADR)**: this document.

**Phase 2 -- Help screen migration** (~2-3h): refactor `help_screen.dart` per this ADR. ~250-300 lines of body text across 20 sections migrate to `assets/content/help/*.md`. All migrated in one PR; no mixed state.

**Phase 3 -- Settings descriptions migration + codebase audit** (~2-4h): migrate the multi-paragraph explainers on the four Settings tabs to `assets/content/settings/*.md`. Audit ALL `lib/` for any other string literal >500 characters that is user-facing content (not regex patterns, not SQL DDL, not log message templates, not runtime-interpolated strings).

## References

- ADR-0001: Flutter/Dart Single Codebase
- ADR-0012: AppPaths Platform Storage Abstraction (asset bundle is platform-agnostic by default)
- ADR-0037: UI/Accessibility Standards (asset-loaded content must remain selectable per the SelectionArea standard)
- Sprint 37 Phase 5.3 round-2 testing (Harold, 2026-05-01): original "content management?" question
- Sprint 37 Phase 5.3 round-3 (Harold, 2026-05-02): scope expanded from Help-only to general content architecture
- [Flutter assets and images guide](https://docs.flutter.dev/ui/assets/assets-and-images)
- [`flutter_markdown` package](https://pub.dev/packages/flutter_markdown)
