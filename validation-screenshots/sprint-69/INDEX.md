# Sprint 69 validation screenshots -- what each one shows

Pulled from the Galaxy S24+ over MTP on 2026-09-11, 47 files covering the 0.15.0
closed-test period (2026-09-08 to 2026-09-11). Original phone filenames and
timestamps preserved, so this index is the only place the CONTENT is recorded.

Not in git (see `../README.md`). This index IS tracked, because a description
outlives an image.

## Identified so far

| File | Shows | Card |
|---|---|---|
| `Screenshot_20260911_172148.png` | Scan Results, AOL, Bulk/Bulk Mail/Inbox, background scan completed 17:20. Green "All 9 'No rule' emails addressed." above "No Matching Emails", with a blue "Created rule to block entire domain '*.boitously.com' -- 6 'No rule' remaining". | **F212**, **F203** |
| `Screenshot_20260910_200433.png` | Import/Export YAML with the red `PlatformException(FilePicker, Unsupported filter...)`. The message is CUT OFF MID-SENTENCE by the navigation buttons. | **F208**, **F209** |
| `Screenshot_20260910_194616.png` | Settings > Background tab, kimmeyh@gmail.com: background scanning ON, 1 hour, Read-Only Mode OFF. | context |

## Why `Screenshot_20260910_200433.png` matters twice

It is the single best piece of evidence in this folder, because it shows two
defects at once and neither was staged:

- **F208**: the import failure itself, with the plugin's misleading "without the
  dot" advice that sent the first diagnosis the wrong way.
- **F209**: that same error text running underneath the system navigation bar.
  This is the concrete proof that the nav-bar overlap is not cosmetic -- the
  sentence a user needs in order to understand the failure is the sentence the
  buttons cover.

## Still to identify

44 files. The No Rule action popup and the scan-results list rows are the two
screens needed to settle the popup font-size question Harold raised on
2026-09-11 (popup metadata reads at 11sp against the list's 12/14sp).
