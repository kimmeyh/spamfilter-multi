# Live UI Selector Map (verified via WinWright dump_tree, 2026-06-05)

App: MyEmailSpamFilter-Dev.exe, window title "MyEmailSpamFilter [DEV]".
Flutter MSAA bridge exposes UIA **Name** (semantic label) only; **AutomationId is always empty**.
Selectors must use `type=<Role>[name='...']` or `name*='...'`. `ww_get_snapshot` elides names -- use `ww_dump_tree includeProperties:true` to read names.

Current WinWright `run`/`heal` schema (from `heal` output):
```
{ "version":"1", "appId":"", "mode":"test", "attachTitle":"MyEmailSpamFilter",
  "runConfig": { "captureScreenshots":false, "screenshotFormat":"png",
    "screenshotOnFailureOnly":false, "continueOnFailure":false,
    "stepTimeoutMs":10000, "maxFailures":0 },
  "testCases": [ ... ] }
```
Top-level metadata MUST include `attachTitle` (or `launchPath`) or run reports 0 total / heal fatal-errors.

### CANONICAL step grammar (captured via ww_record export, 2026-06-05)
Each testCase has `id`, `title`, `steps[]`. Each step is `{ "tool": "<ww_toolname>", ...params, "testCaseId": "<id>" }`.
`tool` = the MCP tool name; params = that tool's params. `timestamp`/`testCaseId` optional.
Example step: `{ "tool": "ww_click", "selector": "type=Button[name='Back']" }`.
Useful step tools: ww_click (selector), ww_type (selector,text), ww_set_checked (selector,checked),
ww_wait (mode,selector/state/stableForMs/timeoutMs), ww_assert (selector,assertion,expected),
ww_clear (selector). Asserts are NOT auto-recorded -- hand-write them.
Assertions: exists, not_exists, is_visible, is_hidden, is_enabled, is_checked, value_equals,
value_contains, value_matches_regex, count_equals, count_greater_than, count_less_than.

## SCREEN: Account Selection (home)
- Button `Help`, Button `View Scan History`, Button `Settings`, Button `Exit Application` (top-bar icons)
- Text `Saved Accounts`, Text `Select an account to scan`
- Account row = Button `kimmeyharold@aol.com - AOL Mail - App Password\nkimmeyharold@aol.com` (contains child Button `Start Scan`, Button `Delete account`)
- Account row 2 = Button `kimmeyh@gmail.com - Gmail (IMAP) - App Password\nkimmeyh@gmail.com`
- Button `Add Account. Add New Account` (bottom)

## BEHAVIOR: Settings is account-scoped
Clicking `Settings` from home opens an in-Flutter overlay (Group `Alert`) titled "Select Account"
(NOT an OS dialog -- ww_wait mode:dialog will NOT see it). Pick an account button
(e.g. `kimmeyharold@aol.com\nAOL Mail`) to enter Settings, or `Cancel`.
Old scripts assumed Settings opened directly -- they must now handle this dialog.

## SCREEN: Settings (account-scoped)
- Button `Back`, Button `Select Account`, Button `Help`, Button `View Scan History`, Button `Exit Application`
- Tabs (Text): `General\nTab 1 of 4`, `Account\nTab 2 of 4`, `Manual Scan\nTab 3 of 4`, `Background\nTab 4 of 4`
  (NOTE tab 3 is "Manual Scan", NOT "Scan")
- General tab: Text `Rules Management`, Button `Manage Safe Senders`, Button `Manage Rules`,
  Button `Import / Export YAML`, CSV Export group + Button `Browse for folder`/`Reset to default`,
  Scan-history retention Buttons `7 days`/`14 days`/`30 days`/`90 days`/`1 year`, Button `Go to View Scan History`,
  Privacy CheckBoxes `Disable detailed auth logging...`, `Pin Google OAuth certificates...`

## SCREEN: Manage Rules
- Button `Back`, Button `Help`, Button `Test a pattern against sample emails` (= F25 Test-tool entry, top bar),
  Button `Refresh`, Button `Export NNNN shown rules as CSV`, Button `Exit Application`
- Edit `Search by domain, email, or keyword...`
- Filter chips (Button): `Header / From (NNNN)`, `Subject (NN)`, `Body (NNNN)`,
  `Entire Domain (NNNN)`, `Exact Domain (NN)`, `Exact Email (NNN)`, `Top-Level Domain (NNN)`
- Button `Add block rule` (FAB)
- Each rule row = Group `<pattern>\nHeader / From - <subtype>` containing
  Button `Header / From category, <subtype> sub-type. View rule details`  <-- click the BUTTON not the Group

## SCREEN: Rule details dialog (Group `Alert`, opens on rule-row button click)
- Metadata Texts: Status/Enabled, Category/`Header / From`, Sub-Type/`Top-Level Domain`,
  Action/Delete, Exec Order/10, Rule Name/`<name>`, Pattern/...
- Footer Buttons: `Close`, **`Edit`** (=F35), **`Test`** (=F25 open-in-test-tool), `Disable`, `Delete`

## SCREEN: F35 Rule Edit (header Group `Edit Rule`, opens from details `Edit`)
- Button `Go back to previous screen` (top-left back)
- Group `Rule (read-only ID)` (rule name is read-only PK -- preserved on save)
- CheckBox `Enabled\nRule is active`
- Edit `Execution Order`
- Action RadioButtons: `Delete\nMove email to Trash`, `Move to Folder\nMove email to a specific IMAP folder`
- Pattern section (Group `Pattern\nPreview\nType: Direct Regex`): Button `Guided (plaintext)`,
  Button `Direct regex`, Edit `Regex pattern`
- Button `Save Changes` (inside Group `Save rule edits`) -- **OFFSCREEN below fold** -> use ww_invoke

## SCREEN: F25 Test Rule Pattern (header Group `Test Rule Pattern`)
Reached via Manage Rules top-bar Button `Test a pattern against sample emails`,
OR rule-details dialog Button `Test` (opens same tool pre-filled).
- Button `Back`, Button `Help`
- Text `Match against: ` + field Buttons `From`, `Subject`, `Body`, `Header`
- CheckBox (UNNAMED -- target by role+position) + Text `Treat input as plain text (auto-generate regex)` (F25 plaintext->regex toggle)
- Edit `Regex pattern`, Button `Test`
- Result Text `Enter a pattern and press Test to see which of 67 sample emails match.`
- Text `Using demo emails. Run a real scan to test against your inbox.` (F25 demo-data prepopulate)

## SCREEN: Settings > Manual Scan tab (Text `Manual Scan\nTab 3 of 4`)
- Text `Account Settings - kimmeyharold@aol.com`, Text `Scan Mode`
- CheckBoxes: `Read-Only Mode\nNO changes to emails, but rules can be added/changed`,
  `Process Safe Senders\nMove safe sender emails to configured folder`,
  `Process all other Rules\nDelete/move emails, mark as read, add tags for matched rules`
- Text `Scan Range`; CheckBox `Scan all emails\nNo date filter - scans entire mailbox`; Slider `7 days`
- Text `Default Folders` + note "Default folders are account-specific. Select an account first,
  then configure in Account Details > Folders." (F37 tree is on the Account tab, NOT here)
- NOTE: toggling these CheckBoxes WRITES to settings (state-restore risk). Verify-only; do not toggle.

## SCREEN: Settings > Account tab (Text `Account\nTab 2 of 4`) = F37 Folder Settings home
- Text `Account Settings - kimmeyharold@aol.com`, Text `Folder Settings`,
  Text `Configure where emails are moved based on rules and safe senders`
- Button `Safe Sender Folder\nInbox` (opens F37 Safe Sender folder picker)
- Button `Deleted Rule Folder\nTrash` (opens F37 Deleted-Rule folder picker)

## SCREEN: F37 Folder picker (header Group `Select Safe Sender Folder` / `Select Deleted Rule Folder`)
- Button `Back`, Button `Help`, Button `Settings`
- Provider header: Text `AOL`, Text `kimmeyharold@aol.com`
- Edit `Search folders...`
- Text `Select one folder (42 available)`
- Provider-default-first flat list (F37 Part B), each a RadioButton inside a Group:
  `Inbox\nPrimary inbox`, `Trash\nDeleted items`, `Trash2\nDeleted items`,
  `Archive\nArchived messages`, `Bulk\nSpam/Junk folder`, `Bulk Mail\nSpam/Junk folder`,
  then alphabetical: `Bulk Mail Test1\n0 messages`, `Bulk Mail Testing\n0 messages`,
  `Church\n0 messages`, `Church/BibleStudy\n0 messages` (note `/` per-provider separator), ...
- Footer: Text `1 of 42 folders selected`, Text **`Changes saved automatically`**
- *** STATE-RESTORE CRITICAL ***: selection auto-saves. Verify selectors/structure only;
  do NOT click any RadioButton (would persist a folder change to the dev DB).
  Exit via `Back`. F37 coverage script must assert structure (search box, provider header,
  default-first order, separator) WITHOUT changing the selection.

## TODO still to map directly (lower priority -- old scripts have partial selectors):
- Scan History screen (`View Scan History`)
- Manage Safe Senders + create flow (parallels Manage Rules; FAB `Add safe sender`)
- Text-selection surfaces

## State-restore summary for script authors
Safe verify-only paths: navigation, tab switches, opening dialogs + Cancel/Close/Back,
opening F25 Test tool (Test button computes, does not persist), opening F35 Edit + Back (no Save).
DANGER (writes persist): F37 folder RadioButtons (auto-save), Manual-Scan CheckBoxes,
any `Save Changes`/`Save Rule`/`Delete`/`Disable`/`Start Scan`/`Delete account`.
Create-rule/safe-sender scripts that DO save must delete what they created in a teardown testCase.
