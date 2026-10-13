# F281: Best-practice UI for "Scan every <interval>" -- Research

**Sprint**: 78 (Task 4, Issue #478)
**Date**: 2026-10-10
**Author**: Claude (Opus 5.5), research tier per `SPRINT_PLANNING.md:94-110`
**Decision**: Harold picks one alternative (plan Q-S2: asked mid-sprint while other work continues).

## 1. Bottom line

Recommended: **Alternative D, a preset drop-down with a "Custom..." entry.**
- One tap covers the common intervals.
- "Custom..." keeps any exact value from 5 minutes to 24 hours.
- An invalid value can only be entered in one small dialog, never in the settings row.
- It follows both vendors' guidance:
  - Microsoft: a drop-down for a secondary choice whose default suits most users; a numeric box for an exact known number.
  - Android: a dialog for choices, with the current value shown under the title.

Alternative A (presets only) is the cheapest. It does not meet R-2's "more than a short preset list" unless the list is
long, and a long list is what the Custom entry avoids.

## 2. Requirements every alternative meets (plan Task 4 R-2, R-3)

- Range: 5 minutes (`kMinIntervalMinutes`, `scan_interval.dart:31`) to 24 hours (was 99 hours, `:34`, `:37`).
- Default 15 minutes the first time it is shown (`settings_store.dart:79`).
- Saved on change; there is no Save button (MV-Q3).
- Shown only when a background mode is on: Windows `background_enabled`; Android `background_enabled` or
  `new_mail_trigger`. A saved value is kept while hidden (F2 = 1).
- A stored value above 24 hours becomes 24 hours (F1 = 1, through `reconcileAccountInterval`).
- One shared Flutter control on Windows and Android (ADR-0042). The Android Doze note ("expect up to about 45 minutes")
  stays below it.

**Today** (`scan_interval_control.dart`): a unit drop-down (Minutes | Hours), then a 2-digit number box (1-99). It is
saved on Done, on focus loss, or on a unit change. An entry under 5 minutes shows an inline message and is not saved.

## 3. What the vendors say

**Microsoft (Windows app design, Learn):**
- Combo box (ms.date 2025-02-26): *"Use a combo box when the selection items are of secondary importance in the flow of
  your app. If the default option is recommended for most users in most situations, showing all the items by using a
  list view might draw more attention to the options than necessary."* Also: *"Sort ... numbers in numerical order"*,
  and *"When there are fewer than five items, consider using radio buttons."*
- Slider (ms.date 2025-02-26):
  - *"Is the setting an exact, known numeric value? If so, use a numeric text box."*
  - *"Don't create a continuous slider if the range of values is large and users will most likely select one of
    several representative values from the range. Instead, use those values as the only steps allowed. For example if
    time value might be up to 1 month but users only need to pick from 1 minute, 1 hour, 1 day or 1 month, then create
    a slider with only 4 step points."*
  - *"Show tick marks and a value label when users need to know the exact value."*
- Number box (ms.date 2026-09-19): stepping (`SmallChange`), spin buttons, and validation that overwrites invalid input
  with the last valid value.

**Android (AOSP settings design guidelines, last updated 2025-02-27):**
- *"Radio buttons can either be shown in a dialog or on a separate screen."* Radio buttons are not placed in the
  settings list itself.
- *"Drop-down menus are available, but ideally you should use a dialog or radio button selection screen instead."*
  *"If needed, drop-down menus can be used in cases where the setting has simple options."*
- *"Below the title, show the status to highlight the value of the setting."* *"Numerical values like percentage and
  time can be shown on the right along with the subtext."*

**Android Compose slider (last updated 2026-10-01):** a discrete slider uses `steps`, and the thumb snaps to each step.
The page names volume and brightness as uses and does not say when a slider is a poor fit.

**Mail clients that already solve this:**
- Thunderbird puts a number box beside "Check for new messages every ... minutes", with a check box to turn checking
  off (Mozilla support).
- Windows Mail used a drop-down under "Download new content": "as items arrive", fixed intervals, or "manually". The
  Microsoft article confirms "as items arrive"; the interval list comes from a third-party guide (Dummies), so the exact
  values are unverified.

## 4. Alternatives

### Alternative A -- Preset drop-down only

```
Scan every                         [ 15 minutes        v ]
                                   +--------------------+
                                   | 5 minutes          |
                                   | 10 minutes         |
                                   | 15 minutes (suggested)
                                   | 30 minutes         |
                                   | 1 hour             |
                                   | 2 hours            |
                                   | 4 hours            |
                                   | 8 hours            |
                                   | 12 hours           |
                                   | 24 hours           |
                                   +--------------------+
```

- **Pros**:
  - No invalid input exists, so no validation message.
  - One tap.
  - Reads as a sentence.
  - Microsoft's combo-box guidance fits exactly: a secondary choice with a good default, in numeric order.
  - Smallest code and test change. A stored value not in the list shows as the nearest list value (the same
    `nearestValid` path used today).
- **Cons**:
  - No exact value outside the list, for example 7 minutes or 3 hours.
  - R-2 asks for "more than a short preset list". Ten items is borderline, and a longer list scrolls.
- **Windows / Android**: one `DropdownMenu`. On Android, the AOSP guidance prefers a dialog over a drop-down but allows
  it for simple options.
- **Effort**: 60-80m.

### Alternative B -- Discrete slider with representative steps

```
Scan every                                   30 minutes
5 min |----|----|----|--o-|----|----|----|----|----| 24 h
        10   15   20   30   45   1h   2h   4h   8h  12h
```

- **Pros**:
  - Shows the whole range at once.
  - One drag or tap; touch-friendly on the Fold.
  - Microsoft's own example is a time range with representative steps, and its guidance asks for tick marks plus a
    value label.
- **Cons**:
  - 12 steps on a phone-width track are hard to hit exactly.
  - The thumb covers the value while dragging, so the label must sit elsewhere.
  - Keyboard users on Windows need arrow keys (Flutter's `Slider` supports them), and the screen reader announces a
    position, not "30 minutes", unless `semanticFormatterCallback` is set.
  - Microsoft says to use a numeric box when the value is an exact known number, and an interval is.
- **Windows / Android**: one Flutter `Slider` with `divisions` and a label map.
- **Effort**: 80-110m.

### Alternative C -- Number box plus unit (today's control, refined)

```
Scan every   [ Minutes v ]  [ 15 ]  [-][+]
             Minimum 5 minutes; maximum 24 hours
```

- **Pros**:
  - Any exact value.
  - Already built and tested.
  - Thunderbird uses the same pattern.
  - Adding -/+ step buttons follows the Number box guidance.
- **Cons**:
  - Two controls for one value.
  - Invalid combinations are possible (2 minutes, 30 hours), so it needs an inline message and a "not saved" rule
    (today's behavior).
  - Typing opens the phone keyboard.
  - It is the control Harold asked to redesign.
- **Windows / Android**: unchanged shared widget; only the limits and visibility change.
- **Effort**: 40-60m (limits, visibility, step buttons).

### Alternative D -- Preset drop-down plus "Custom..." (recommended)

```
Scan every                         [ 15 minutes        v ]
                                   +--------------------+
                                   | 5 minutes          |
                                   | 10 minutes         |
                                   | 15 minutes         |
                                   | 30 minutes         |
                                   | 1 hour             |
                                   | 2 hours            |
                                   | 4 hours            |
                                   | 12 hours           |
                                   | 24 hours           |
                                   | Custom...          |
                                   +--------------------+

Custom... opens:
  +-------------------------------------------+
  | Scan every                                |
  |   [ 45 ]  [ Minutes v ]                   |
  |   5 minutes to 24 hours                   |
  |                      [Cancel]  [Save]     |
  +-------------------------------------------+

After saving 45 minutes the row reads:   [ 45 minutes (custom)  v ]
```

- **Pros**:
  - Common values in one tap, any exact value through Custom.
  - The settings row can never hold an invalid value; validation lives only in the dialog, which keeps Save disabled
    until the value is in range.
  - It matches Microsoft's two rules together: a drop-down for a secondary choice with a good default, and a numeric
    entry for an exact number.
  - It matches the AOSP preference for a dialog.
  - The existing number-plus-unit widget is reused inside the dialog, so its tests carry over.
- **Cons**:
  - Two paths to build and test (list and dialog).
  - The dialog has a Save button. That is an exception to MV-Q3 inside the dialog only; the row itself still saves on
    change.
- **Windows / Android**: one shared `DropdownMenu` and one shared `AlertDialog`. Both are Material widgets that render
  the same on both platforms.
- **Effort**: 90-130m.

## 5. Comparison

- **Exact values**: A no; B no; C yes; D yes.
- **Invalid entry possible in the row**: A no; B no; C yes; D no.
- **Taps for a common value**: A 2; B 1 drag; C 3+ with typing; D 2.
- **Screen-reader clarity**: A good; B needs work; C fair; D good.
- **Effort**: A 60-80m; B 80-110m; C 40-60m; D 90-130m.

## 6. Recommendation

Alternative D. The preset list is the one-tap path for nearly everyone, and Custom covers exact needs without putting
validation in the settings row. If effort must be minimal, A is the fallback, with a 12-item list:
5, 10, 15, 20, 30 and 45 minutes; 1, 2, 4, 8, 12 and 24 hours.

## Sources

- Microsoft Learn, Combo box and list box (ms.date 2025-02-26):
  https://learn.microsoft.com/en-us/windows/apps/design/controls/combo-box
- Microsoft Learn, Sliders (ms.date 2025-02-26): https://learn.microsoft.com/en-us/windows/apps/design/controls/slider
- Microsoft Learn, Number box (ms.date 2026-09-19):
  https://learn.microsoft.com/en-us/windows/apps/design/controls/number-box
- AOSP, Settings design guidelines (last updated 2025-02-27):
  https://source.android.com/docs/core/settings/settings-guidelines
- Android Developers, Slider (Compose) (last updated 2026-10-01):
  https://developer.android.com/develop/ui/compose/components/slider
- Mozilla Support, Send and receive messages in Thunderbird:
  https://support.mozilla.org/en-US/kb/sending-and-receiving-messages-thunderbird
- Microsoft Support, mail and calendar sync settings ("as items arrive"):
  https://support.office.com/en-gb/article/learn-more-9b6f053c-5a4d-4a2b-bae4-57cdaddd5cb7
- Dummies, change account settings in Mail for Windows 10 (third party; interval list unverified):
  https://www.dummies.com/article/technology/computers/basic-skills/change-account-settings-mail-windows-10-248573
- Material Design 3 component pages (m3.material.io) render client-side and could not be read in this session;
  nothing here is cited from them.
