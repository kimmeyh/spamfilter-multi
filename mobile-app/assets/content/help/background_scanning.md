Background Scanning runs the same rules engine as Manual Scan, but on a schedule -- the app wakes up the Windows Task Scheduler (or Android WorkManager) without an open window. Scan Mode, Scan Range, and Default Folders are shared with Manual Scan (see that section above).

- Enable: master on/off switch. Off removes the scheduled task; on registers it with the OS scheduler. Disabled by default on fresh installs.
- Test: runs the background pipeline once, immediately, so you can verify the scheduler, credentials, and rules all line up before trusting the scheduled run. Useful after an upgrade or a config change.
- Frequency: how often the scheduled task fires (hourly, 4-hourly, daily, etc.). Daily with Scan Range = 1 day is the most efficient continuous-monitoring setup.
- Debug (Export after each scan): typically off. When on, every background run writes a per-run CSV next to the scan log. Useful when diagnosing a rule that seems to misfire or building an audit trail.
