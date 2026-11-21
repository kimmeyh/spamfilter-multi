// Sprint 85 Phase 5.2: the one way a test reads the diagnostic log folder.
//
// The writer keeps a transient `<log>.lock` file next to the log while it
// appends, and deletes it after. A test that lists the folder and reads every
// file can list the lock, then fail with PathNotFoundException when the writer
// deletes it before the read (seen in f259_gmail_label_cursor_test once
// DiagnosticLogger.debugReset kept each test's writes in its own folder).
// This reads only `.log` files and skips one that disappears between the
// listing and the read. Gate: test/policy/diagnostic_logger_reset_test.dart.
//
// What this does NOT catch: a line still queued in the writer when the test
// reads. Tests that log fire-and-forget still poll (or await the call).
import 'dart:io';

/// The text of every `.log` file under [dir], joined by newlines. Returns ''
/// when [dir] does not exist.
String readDiagnosticLog(Directory dir) {
  if (!dir.existsSync()) return '';
  final parts = <String>[];
  for (final f in dir.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.log')) continue;
    try {
      parts.add(f.readAsStringSync());
    } on FileSystemException {
      // Removed between the listing and the read (rotation); skip it.
    }
  }
  return parts.join('\n');
}
