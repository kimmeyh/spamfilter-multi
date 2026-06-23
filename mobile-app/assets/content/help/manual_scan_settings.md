The Manual Scan tab sets defaults for manual (on-demand) scans. Per-account overrides apply when present; the app-wide values shown here are the fallback. Background scans use the same inputs (see Background Scanning).

- General: top-of-tab controls including scan-history retention days (duplicated here and on General for convenience).
- Scan Mode: read-only (dry run), rules-only, safe-senders-only, or test-all. Read-only never modifies email; the others mutate mail per matched actions.
- Scan Range: how many days back to read from each folder. 1-3 days is typical for daily use; 7-30 days for occasional cleanup.
- Default Folders: which folders to scan by default (INBOX almost always, spam folders optional). The folder picker reads the account's IMAP namespace.
- Confirmation: whether to show a "proceed?" dialog before destructive scans. Off = faster loop, on = safer when testing rules.
- Export Settings: where CSV exports are saved when you tap the Download icon on a Results screen. Leaving the path blank uses the OS Downloads folder.
