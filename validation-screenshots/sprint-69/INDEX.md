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
| `Screenshot_20260910_183529.png` | Scan results LIST, 10 "No rule", amber "0 of 10 addressed". Rows show sender + `Bulk - subject - No rule`. | **popup font-size pair** |
| `Screenshot_20260910_183550.png` | The "No Rule" ACTION POPUP for `kkrmlexjnr@hotaucage.net`: sender, metadata line, date + domain, "No matching rule" chip, then Safe Senders / Block Rule / Block Subject actions. | **popup font-size pair** |
| `Screenshot_20260911_172153.png` | Empty state, green "All 9 addressed", orange snackbar "0 of 4 (4 failed)". | **F212** |
| `Screenshot_20260911_172156.png` | Same empty state, blue "block entire domain *.mbiniff.net -- 5 remaining". | F203 |
| `Screenshot_20260911_195842.png` | Scan History, All Accounts: Total 4450, Processed 1038, Deleted 448, No Rule 525. | context |
| `Screenshot_20260910_183521.png` | Scan History, earlier: Total 3833, No Rule 475. | context |
| `Screenshot_20260910_183628.png` | Empty state, "All 10 addressed", blue snackbar blocking a `...ties.com` domain. | F203 |
| `Screenshot_20260910_183631.png` | Same, blocking `...rtsavings.com`. | F203 |
| `Screenshot_20260910_193730.png` | Settings > General: Privacy & Logging, 90-day retention, Pin Google OAuth certificates, Danger Zone. | context |

## Why `Screenshot_20260910_200433.png` matters twice

It is the single best piece of evidence in this folder, because it shows two
defects at once and neither was staged:

- **F208**: the import failure itself, with the plugin's misleading "without the
  dot" advice that sent the first diagnosis the wrong way.
- **F209**: that same error text running underneath the system navigation bar.
  This is the concrete proof that the nav-bar overlap is not cosmetic -- the
  sentence a user needs in order to understand the failure is the sentence the
  buttons cover.

## The popup font-size pair (Harold's 2026-09-11 question)

`Screenshot_20260910_183529.png` and `Screenshot_20260910_183550.png` are a
BEFORE/AFTER pair of the SAME email -- `kkrmlexjnr@hotaucage.net` -- in the list
and then in the action popup. That makes them the direct comparison, not two
similar screens.

| | List (`183529`) | Popup (`183550`) |
|---|---|---|
| Sender address | large, dominant | about the SAME size |
| `Bulk - <subject> - No rule` | clearly readable, wraps to 3 lines | **visibly smaller and dimmer**, squeezed to 2 |
| date + domain | not shown in the row | **smallest text in the sheet** |

**Harold's observation is confirmed by the rendering.** The popup's supporting
text is smaller than the same text in the list, while the sender lines match.
The popup exists so a user can confirm they tapped the right email, so its
metadata being HARDER to read than the list's is backwards.

**Caveat recorded deliberately**: an earlier claim that the popup renders at
11sp came from grepping `fontSize` values and matching them to a code region,
NOT from measuring the screen. The RELATIONSHIP above is what these two images
prove. The exact sp values still need confirming against the widget that
actually renders the sheet before anyone quotes them.

**Unrelated, but visible in `183550`**: Android's floating system pill sits over
the `Skip` button. That is the phone's overlay rather than the app's layout, but
it lands exactly on a control, which is worth knowing when F209's nav-bar work
is validated on device.

## Still to identify

36 files, listed nowhere yet. Identify them as they become relevant rather than
opening all of them: an image is cheap to keep and expensive to describe.
