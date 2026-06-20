/// Sprint 42, F98 (ADR-0039) -- shared account-id sanitization.
///
/// Per-account background scanning derives several OS-level and filesystem
/// tokens from an accountId (Windows Task Scheduler task name, per-account log
/// filename, CSV/XLSX export filename, and -- conceptually -- the WorkManager
/// unique name). They must all sanitize the accountId identically, so the rule
/// lives here once instead of being re-implemented per call site.
///
/// The rule reproduces the pattern previously inlined in
/// background_scan_windows_worker.dart: replace `@` with `_at_` and `.` with
/// `_`. (Account ids have the form `{platform}-{email}`, e.g.
/// `gmail-user@gmail.com`.)
library;

/// Returns a filesystem/Task-Scheduler-safe token derived from [accountId].
///
/// Example: `gmail-user@gmail.com` -> `gmail-user_at_gmail_com`.
String sanitizeAccountId(String accountId) {
  return accountId.replaceAll('@', '_at_').replaceAll('.', '_');
}
