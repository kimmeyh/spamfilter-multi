# Google Play Store Asset Specification (GP-6, Sprint 65, Issue #383)

**Purpose**: the capture specification Harold works from. This document says WHAT to
capture, at WHAT dimensions, and under WHICH EXACT FILENAME -- so the policy gate in
`mobile-app/test/policy/play_listing_assets_test.dart` can verify each asset once it
exists, and so a missing asset is a visible failure rather than a silent gap discovered
at upload.

**Scope boundary (Sprint 65 plan, Task 4)**: capturing the screenshots is Harold's work.
This document, the listing copy, the cross-store comparison and the gates are the coding
deliverables. Nothing here can be produced by building the app on this machine, because a
Play screenshot must come from the real Android build on a real device or emulator (R-3).

---

## Why the Android screenshots cannot be reused from Windows

`docs/store-assets/windows/` holds seven Microsoft Store screenshots. They are the
reference for WHICH SCREENS to show -- the product story that already passed Store
review -- but they must NOT be uploaded to Play. R-3 is explicit. Three reasons:

1. They show the Windows desktop layout, which is not what an Android user will see.
   Play reviewers compare screenshots against the running app.
2. Their aspect ratios are desktop-shaped and will not satisfy Play's phone-screenshot
   dimension rules.
3. Windows screenshots carry the `[DEV]`-free desktop window chrome; Android has none.

---

## Feature graphic (MANDATORY -- Play will not publish a listing without it)

| Field | Value |
|---|---|
| Filename | `docs/store-assets/android/feature_graphic_1024x500.png` |
| Dimensions | Exactly 1024 x 500 pixels |
| Format | PNG, 24-bit (no alpha channel) |
| Content | The app icon on the left third against a solid or subtle-gradient background using the launcher background colour `#4196F3`, with the app name "MyEmailSpamFilter" and a short tagline to its right. No screenshot content, no small text -- Play renders this small in listings. |
| Text to use | "MyEmailSpamFilter" plus "Spam filtering you control" |

**No alpha**: Play rejects an alpha channel on the feature graphic the same way it does on
the listing icon. The gate checks the PNG colour type for this reason.

---

## Phone screenshots (MANDATORY -- minimum 2, maximum 8)

| Field | Value |
|---|---|
| Dimensions | Each side between 320 and 3840 pixels. A standard portrait phone capture (for example 1080 x 2340, the `pixel34_updated` AVD's resolution) is accepted -- **verified empirically 2026-09-08**: all five 1080 x 2340 captures uploaded to the Play Console without complaint. This line previously also asserted "aspect ratio between 16:9 and 9:16", which 1080 x 2340 (1:2.167) EXCEEDS by 1.22x -- so the row contradicted its own worked example. Play accepts modern tall-phone ratios; the stated bound was stale. Do not crop captures to satisfy a limit Play does not enforce. |
| Format | PNG or JPEG, 24-bit, no alpha |
| Source | The REAL Android build. The signed release APK from Sprint 64 is already installed on the `pixel34_updated` AVD. |

Capture these five screens, in this order. The order is the product story: what the app
is, that it works without an account, what it found, how you control it, and that it runs
unattended.

| # | Filename | Screen | Windows reference | Why this screen |
|---|---|---|---|---|
| 1 | `phone_01_choose_provider.png` | Provider selection on first run, showing the "Try Demo Mode" card | `01_choose_provider.png` | First thing a new user sees; shows the supported providers and that Demo Mode needs no account. |
| 2 | `phone_02_scan_results.png` | Results after a Demo Mode scan, showing deleted and safe counts | `03_scan_results.png` | The core value in one image: real filtering outcomes, not a settings screen. |
| 3 | `phone_03_review_no_rule.png` | **Results screen filtered to the "No rule" items** (the `No rule: 12` chip active), NOT the Review No Rule Items screen | `04_email_quick_actions.png` | Shows the human-in-the-loop step -- messages no rule matched, awaiting the user's decision. |

**Why slot 3 is not the Review No Rule Items screen (discovered 2026-09-08 during capture).**
That screen cannot be captured from Demo Mode: it renders "0 items / No unaddressed items"
even immediately after a demo scan reports 12 remaining. This is not a defect.
`no_rule_review_screen.dart` `_loadItems()` reads persisted scans per stored account via
`_scanResultStore.getLatestCompletedScan(accountId)`, and Demo Mode runs without a saved
account, so there is no persisted scan for it to find; the results screen counts in-memory
from the scan that just ran. The two are reading different sources, and both are correct.

The substitute tells the same story with real content: the same 12 unmatched messages, each
labelled "No rule", on a screen Demo Mode genuinely reaches. Capturing the empty state would
have shown a "nothing to do here" screen as the illustration of a feature.

If this slot is ever to show the real screen, it needs a capture from a build with a
connected account and a completed persisted scan -- which cannot use Demo Mode, and would
therefore put real sender addresses in a public listing. That is why Demo Mode is mandated
for captures in the first place. Prefer the substitute.
| 4 | `phone_04_manage_rules.png` | Manage Rules with the category filter chips visible | `05_manage_rules.png` | Shows user control over the rule set, including the Body Phrase rules added in Sprint 64. |
| 5 | `phone_05_background_scan.png` | Settings, Background tab, showing scan frequency | `06_settings_general.png` | Shows unattended operation, which is the reason to keep the app installed. |

**Use Demo Mode for every capture.** It produces a realistic populated inbox with no real
account, so no personal email address, subject line, or sender ever appears in a public
Store listing. This is a privacy requirement, not a convenience.

---

## Tablet screenshots (NOT required for this submission)

The Android manifest declares no tablet-specific support, and Play requires tablet
screenshots only when the listing claims tablet compatibility. Omitting them means the
listing is not promoted for tablets, which is correct for the current build.

If tablet support is claimed later, Play requires 7-inch and 10-inch sets, and this
document must be updated with their filenames before the gate can verify them.

---

## Where these are uploaded

Partner Center has no equivalent; this is Play Console only:
**Play Console -> Grow -> Store presence -> Main store listing**, then the Graphics
section. The listing copy in `LISTING_COPY.md` fills the text fields on the same page.

---

## Verification

`mobile-app/test/policy/play_listing_assets_test.dart` checks:

- the listing copy and this specification exist,
- the short description is within 80 characters and the full description within 4000,
  measured from the actual text rather than a stated count,
- the cross-store claim comparison exists and is non-empty,
- and, for each asset filename above, IF the file exists then its dimensions and alpha
  channel are correct.

The conditional in that last line is deliberate. The assets do not exist yet, and a gate
that fails for work Harold has not done yet is noise. But a gate that silently passes when
the assets are missing is worse -- so the test prints an explicit PENDING line naming every
missing asset. The pending state is visible, not hidden.
