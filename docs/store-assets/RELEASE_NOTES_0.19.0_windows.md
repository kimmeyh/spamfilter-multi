# Release notes -- 0.19.0 -- Microsoft Store

Re-derived 2026-10-13 (Sprint 78 cycle, Phase 8.3) from the finished CHANGELOG (STORE_RELEASE_PROCESS.md Step 1b),
replacing the provisional text written at plan approval.

**Range**: everything after 0.18.0 (live on the Store): CHANGELOG `[Unreleased]` entries dated 2026-10-10 and
2026-10-13.

**Excluded from this file**: dev-build-only features (content history, R76-4, and its 7.7.1 fix), test tooling and
policy gates (WinWright, text-contrast and cited-test gates), Android-only fixes (the Doze alarm double scan, and the
reschedule of an interval saved above 24 hours -- on Windows the interval was already reconciled at startup), and the
internal deletion-path fix (no visible change).

---

Every file the app saves for you now goes to one folder: MyEmailSpamFilter in Documents. A folder you chose in Settings is still used, and saved files are not moved. If Documents cannot be written to, the app uses its own folder instead.

Review No Rule Items now works like the Results screen: search (Ctrl+F), account, folder and sort choices, and the same email details with Safe Sender, Block Rule and Skip. The next email opens automatically, and the details name the account.

"Scan every" is now a list from 5 minutes to 24 hours, with Custom for other values. It appears only when background scanning is on.

In the email details, the subject, date and account match the sender's color. For a shared provider such as gmail.com, the domain buttons are dimmed, as Exact Email is usually the better choice; they still work.

Fixes: adding a rule from Review No Rule Items no longer blanks the list, and the list drops emails a rule made elsewhere now covers. A failed scan no longer shows "In progress". Search text and the Rule Test highlight are readable in the dark theme. The warning for a sender that failed authentication is no longer hidden behind the next email. If the rules cannot be reloaded, a message with Retry says so.
