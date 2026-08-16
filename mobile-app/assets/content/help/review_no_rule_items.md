Collects the emails that no rule matched, from every account's most recent scan, in one list. This is where you teach the filter: each item is an email the scanner saw but had no instruction for, and each action you take here becomes a rule for future scans.

When more than one account is configured, chips above the list filter by account. "All Accounts" shows everything; each chip shows that account's item count.

**Selecting items**: click a row or its checkbox to select it. On Windows desktop, Ctrl+click adds or removes individual rows, and Shift+click selects a range. Right-click a row to open the action menu directly.

**Acting on a selection** (via the "Apply Rule" menu or right-click):

- **Add Safe Sender** (Exact Email / Exact Domain / Entire Domain): trust the sender so future scans leave their mail alone.
- **Add Block Rule** (Exact Email / Exact Domain / Entire Domain): treat matching mail as spam on future scans.
- **Remove Current Rule**: dismiss the selection as reviewed without creating any rule. The items leave the list.

Items also leave the list automatically once a rule covers them -- including rules you add elsewhere in the app. The screen re-checks this on every reload.

The reload icon re-checks the stored scan results and does not fetch new mail. Run a Manual Scan, or wait for a background scan, to bring in new items. When everything is addressed, the screen shows "No unaddressed items."
