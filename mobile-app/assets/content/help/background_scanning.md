Background Scanning runs the same rules engine as Manual Scan, but on a schedule -- the app wakes up the Windows Task Scheduler (or Android WorkManager) without an open window. Scan Mode, Scan Range, and Default Folders are shared with Manual Scan (see that section above).

Background Scanning is configured **per account**. The Background tab shows which account you are configuring (see the account header at the top of the tab), and each enabled account gets its own scheduled entry that runs on its own frequency. Enabling it on one account does not enable it on the others.

- Enable: per-account on/off switch. Off removes that account's scheduled task; on registers a scheduled entry for that account with the OS scheduler. Disabled by default on fresh installs.
- Test: runs the background pipeline once, immediately, so you can verify the scheduler, credentials, and rules all line up before trusting the scheduled run. Useful after an upgrade or a config change.
- Frequency: how often this account's scheduled task fires (hourly, 4-hourly, daily, etc.). Daily with Scan Range = 1 day is the most efficient continuous-monitoring setup. Different accounts can run at different frequencies.
- Debug (Export after each scan): typically off. When on, every background run writes a per-run CSV next to the scan log. Useful when diagnosing a rule that seems to misfire or building an audit trail.
