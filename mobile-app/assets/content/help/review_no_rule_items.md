Collects the emails that no rule matched, from every account's most recent scan, in one list. This is where you teach the filter: each item is an email the scanner saw but had no instruction for, and each action you take here becomes a rule for future scans.

When more than one account is configured, chips above the list filter by account. "All Accounts" shows everything; each chip shows that account's item count.

**Selecting items**: click a row to select it, or use its checkbox (the checkbox always toggles just that one row). On Windows desktop, Ctrl+click on a row adds or removes that row from the selection, and Shift+click on a row selects the range from your last click. Right-click a row to open the action menu directly. On Android and iOS, long-press a row to start a selection, then tap other rows to add or remove them.

**Acting on a selection** (via the "Apply Rule" menu or right-click):

- **Add Safe Sender - Exact Email / Exact Domain / Entire Domain**: trust the sender so future scans leave their mail alone.
- **Add Block Rule - Exact Email / Exact Domain / Entire Domain**: treat matching mail as spam on future scans.
- **Remove Current Rule**: dismiss the selection as reviewed without creating any rule. The items leave the list.

Items also leave the list automatically once a rule covers them -- including rules you add elsewhere in the app. The screen re-checks this on every reload.

The reload icon re-checks the stored scan results and does not fetch new mail. Run a Manual Scan, or wait for a background scan, to bring in new items. When everything is addressed, the screen shows "No unaddressed items."
