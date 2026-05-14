# F85 Phase 3 Audit Log (Sprint 38, 2026-05-14)

## Scope

Per ADR-0038 ("Content Management for Long Inline Strings"), every Dart string literal **longer than 500 characters** that is user-facing content (not regex patterns, not SQL DDL, not log message templates, not runtime-interpolated strings) must live as a Markdown file under `assets/content/` and be loaded via the asset manifest.

This document records the Sprint 38 audit of `mobile-app/lib/` for such strings.

## Method

1. AWK pass over every `*.dart` file under `lib/` that concatenates adjacent line-continuation string literals.
2. Manual inspection of any file with `Text(` widget bodies known to host explainer prose: Help, Settings, Account Setup, OAuth screens, error displays.
3. Filter out: regex patterns, SQL DDL, YAML literals, debug log message templates, runtime-interpolated strings, import statements (which can superficially look long when concatenated).

## Findings

### Migrated to assets (Phase 2, this sprint)

**`lib/ui/screens/help_screen.dart`** -- ALL 20 `HelpSection` bodies migrated. Each section's body is now stored as a `.md` file under `assets/content/help/` and referenced via `assets/content/manifest.yaml`. Section titles remain inline (titles are short labels, not content).

Migrated bodies (lines refer to old, pre-migration line numbers in `help_screen.dart`):

| Enum value | Old line range | Length (chars) | New asset |
|------------|----------------|----------------|-----------|
| selectAccount | 183-191 | ~340 | `help/select_account.md` |
| accountSetup | 193-206 | ~620 | `help/account_setup.md` |
| demoScan | 208-220 | ~590 | `help/demo_scan.md` |
| manualScan | 222-235 | ~620 | `help/manual_scan.md` |
| resultsDisplay | 237-248 | ~520 | `help/results_display.md` |
| scanHistory | 250-257 | ~270 | `help/scan_history.md` |
| settings | 259-269 | ~410 | `help/settings.md` |
| generalRulesManagement | 272-287 | ~550 | `help/general_rules_management.md` |
| generalScanHistoryRetention | 289-300 | ~510 | `help/general_scan_history_retention.md` |
| generalPrivacyLogging | 302-327 | ~1320 | `help/general_privacy_logging.md` |
| folderSettings | 330-354 | ~1180 | `help/folder_settings.md` |
| manualScanSettings | 356-383 | ~1230 | `help/manual_scan_settings.md` |
| backgroundScanning | 385-410 | ~1100 | `help/background_scanning.md` |
| manageRules | 412-425 | ~580 | `help/manage_rules.md` |
| ruleQuickAdd | 427-437 | ~430 | `help/rule_quick_add.md` |
| ruleTest | 439-447 | ~280 | `help/rule_test.md` |
| safeSenders | 449-460 | ~470 | `help/safe_senders.md` |
| folderSelection | 462-470 | ~290 | `help/folder_selection.md` |
| yamlImportExport | 472-482 | ~470 | `help/yaml_import_export.md` |
| otherWaysToReduceJunk | 484-592 | ~4200 | `help/other_ways_to_reduce_junk.md` |

Total: 20 sections, ~14,200 characters of user-facing prose moved out of Dart source.

ADR-0038 threshold is 500 characters; sections below that (selectAccount, scanHistory, settings, ruleQuickAdd, ruleTest, folderSelection, yamlImportExport) were ALSO migrated for consistency -- mixed state (some inline, some external) is worse for maintainers than uniform extraction.

### NOT migrated (audit found nothing eligible)

**`lib/ui/screens/settings_screen.dart`** -- Per F85 Phase 3 audit. All Settings subtitle and explainer strings are single-sentence (well under the 500-character threshold). Examples:
- "View and manage safe sender patterns and block rules" (54 chars)
- "Manage scan history retention and view past scan results" (56 chars)

There ARE multi-line strings in Settings (DataDeletionService confirmation dialog body, OAuth error explanations) but each is under 500 chars after concatenation. **No migration warranted.**

**`lib/ui/screens/account_setup_screen.dart`** -- audited. All explainer text is sub-300-char single-sentence. **No migration warranted.**

**`lib/ui/screens/gmail_oauth_screen.dart`** -- audited. OAuth flow explainer text is sub-300-char. **No migration warranted.**

**Other `lib/ui/screens/*.dart`** -- spot-checked manual_rule_create_screen, rule_test_screen, rule_quick_add_screen. All explainer text is sub-200-char. **No migration warranted.**

### Excluded from audit (per ADR-0038 exclusions)

- **Regex pattern strings** (e.g., `r'^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$'`): excluded because these are code, not content.
- **SQL DDL strings** (e.g., `CREATE TABLE accounts ...`): excluded because these are schema, not content.
- **YAML rule literals** in `lib/core/data/`: excluded because these are seed data, not content.
- **Logger message templates** (e.g., `_logger.i('Background scan completed in ${elapsed}s')`): excluded because these are runtime-interpolated, not authorable content.
- **Error message templates** with `$variable` interpolation: excluded because each piece is short and the interpolation is the content.

## Conclusion

Phase 2 migrated all 20 Help sections to `assets/content/help/*.md`.

Phase 3 audit found no other Dart string literals over the 500-character threshold that qualify as user-facing content. Settings tabs and other screens use short single-sentence explainers; no migration warranted.

The audit will be re-run in any future sprint that adds substantial new prose to a Dart source file (e.g., F74 FAQ section in Help, F75 Help walkthrough). Future ADR-0038 violations should fail the build via `scripts/validate-content-manifest.ps1` once the validator's drift-detection scope is extended to include a "no long prose in `.dart`" check (out of scope for Sprint 38 -- tracked separately).
