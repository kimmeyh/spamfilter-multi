# F325: First-Run Evaluation, Sprint 83 (copy of the F152 template)

**Status**: step 1 (static pass) DONE 2026-11-04. Steps 2-3 (live runs: Windows release-equivalent build with an
empty data folder; Android clean install on the emulator, Q10 = 1) run with Harold at Manual Validation. iPhone: not
runnable this sprint (no TestFlight build); recorded as a gap.

**Build**: 0.24.0+21, branch `feature/20261031_Sprint_83`. All paths are under `mobile-app/`.

**Method**: a read-only Explore agent traced the first-run path from `main.dart` (574 s). V = VERIFIED in code by the
agent; H = HYPOTHESIS for the live run. Three V claims were re-checked by the main session (walkthrough text, the Gmail
"Recommended" label, the plain-text GitHub address): 3 of 3 match. Nothing below is a confirmed user problem until
the live run; findings become backlog cards after it (R-5), and nothing is fixed in this task.

## 1. Installation and Launch

- First screen is "Loading spam filter rules..."; on failure it shows the raw text "Error: <error>" and Retry
  (`lib/ui/widgets/rules_ready_gate.dart:56,71`). V
- No account: Account Selection; one or more: Review No Rule Items (`main_navigation_screen.dart:88-94`). Same on both
  platforms. V
- Windows: window 1280x720, minimum 800x600 (`windows/runner/main.cpp:239`, `flutter_window.cpp:71-72`). V
- Windows: Ctrl+N does nothing (`main.dart:847`); Ctrl+R / F5 call `popAndPushNamed('/')` on the home route
  (`main.dart:874`). H

## 2. First-Run Orientation

- Empty state: "Select Account", one sentence on what the app does, "Add Account", "Try Demo Mode instead"
  (`empty_state.dart:115-121`, `account_selection_screen.dart:924-940`). V
- Settings with no account gives "Please add an email account first" (`account_selection_screen.dart:626`). V
- Help has "First time? Start here" (`help_screen.dart:303`). V
- `assets/content/help/walkthrough.md` is out of date: it names Outlook.com and ProtonMail (Outlook is commented out
  in `platform_registry.dart:124-132`, ProtonMail has no entry, iCloud is missing); says "Start Scan" (the button is
  "Start Live Scan"); says to tap "+" (the button is "Add Account"); describes a "Move matched emails to folder"
  setting that does not exist; and step 8 mentions "F82 in the app code". V
- `select_account.md` says to swipe to delete; delete is an icon button (`account_selection_screen.dart:1047, 1179`). V

## 3. Completing the Primary Task

- The provider list shows an empty "Coming Soon" heading (`platform_selection_screen.dart:160-165`). V
- AOL, Yahoo, iCloud: a setup dialog with a required "I have my app password ready" checkbox; the web addresses in it
  are plain text, not links (`platform_selection_screen.dart:476-518`). V
- Gmail contradicts itself: the provider screen and dialog say Google Sign-In, no app password needed
  (`platform_selection_screen.dart:341, 500`); the next screen labels "App Password (IMAP) (Recommended)" and warns
  that Google Sign-In "may require more frequent re-authentication" (`account_setup_screen.dart:830, 852, 876`). V
- Gmail sign-in: Windows opens the browser with "Trouble signing in?"; Android uses native sign-in with a visible
  "Manual Token Entry" button (`gmail_oauth_screen.dart:507-552`). V
- After saving: "[OK] Account ... saved successfully", then Manual Scan; no automatic scan
  (`account_setup_screen.dart:711-746`). V
- Scan mode is never chosen by the user; it defaults to Read-Only (`settings_store.dart:94`). The only signs are a grey
  "Mode: Read-Only" line, "Scan complete - Read-Only" and "Deleted (not processed)" (`scan_progress_screen.dart:317,
  378-381`; `results_display_screen.dart:1518`). V
- A real account's Manual Scan also shows "Start Demo Scan (Testing)" (`scan_progress_screen.dart:468`). V
- Android: no prompt on first run; background scanning starts off (`settings_store.dart:97`), so a new account shows
  the F324 line "Background scanning is off for this account" with "Turn on", and "Turn on" does not request the
  notification permission (`account_selection_screen.dart:762-789`; the Task 4 judgment call). Only the Settings
  switch requests it (`settings_screen.dart:1531-1535, 1822-1829`). No battery-optimization request. Windows asks for
  nothing. V
- An account added but never scanned: the next launch opens Review No Rule Items, which says "All 'No rule' emails
  have been reviewed" (`no_rule_review_screen.dart:1039-1042`). Text V; how it reads to a new user H.

## 4. Feedback and Confirmation

- Results: the counts are in one filter dropdown and the explanations show only when it is opened; "These emails
  matched a delete rule" does not say nothing was changed (`results_display_screen.dart:1808-1830`). V
- During a scan: spinner, "Scanning... N emails processed", Cancel (`scan_progress_screen.dart:417-487`). V

## 5. Emotional Experience

- "[OK]" / "[FAIL]" markers in user messages (`account_setup_screen.dart:524, 713`). V
- Raw exception text reaches the user: "Error adding account: $e" (`account_selection_screen.dart:517`), "Could not
  turn on background scanning: $e" (785), "Failed to delete: $e" (850), "Demo scan failed: $e"
  (`scan_progress_screen.dart:645`), and the rules-load error. V
- "Phase 2", "Soon" and "(Testing)" labels read as an unfinished product. Labels V; effect H.

## 6. Environment Compatibility

- Below 600 px the toolbar collapses and Results uses a compact layout (`standard_app_bar_actions.dart:428-439`;
  `results_display_screen.dart:1095`). V
- The email-detail pop-up height cap (60%) cuts off rows at the default Windows window and on the unfolded Fold; see
  `SPRINT_83_PLAN.md` "Phase 5 evidence" (measured). V
- No Fold hinge or posture handling. Fold behavior and DPI other than 125% H.

## 7. Quick User Feedback Capture

- The only channel is grey, non-link text at the bottom of Help: "Report issues at
  github.com/kimmeyh/spamfilter-multi/issues." (`help_screen.dart:368-369`), and one FAQ line (`faq.md:17`). No email
  link, no in-app form. V

## Sprint 58 (F151) findings against today's code

- FIXED: F151a (empty-state orientation, Demo link), F151b (Help callout), F151d (Demo safe senders), F151e (pop-up
  width), F151h (toolbar order), F151i (Help as Markdown).
- PARTLY: F151c (the Moved chip is gone; "Deleted (not processed)" remains and the explanations moved into the
  dropdown); F151f (fixed at its three named sites; still present at the section 5 sites).
- UNCLEAR: F151g (window size and scaling; needs the live run).
- REGRESSED: walkthrough accuracy (section 2).

## What the live run checks first

1. Does a new user find the Read-Only status and understand "Deleted (not processed)" without opening the dropdown?
2. Gmail: reaction to the contradictory recommendation; Windows browser sign-in versus Android native sign-in.
3. AOL / Yahoo / iCloud app-password dialog: does the user try to click the plain-text addresses?
4. Android clean install: no prompts; tap "Turn on"; does a notification ever appear on Android 13 or later?
5. Is "Try Demo Mode instead" noticed; does the Demo button on a real account's Manual Scan confuse?
6. Relaunch after adding an account without scanning: is "All reviewed" misleading?
7. Walkthrough and "Start here": does the user trip on the outdated steps?
8. Windows: default 1280x720 at the real DPI, resize to 800x600, Ctrl+R / F5.
9. Fold folded and unfolded: Results, the pop-up and the toolbar near 600 px.
10. Can the user find any way to send feedback?
