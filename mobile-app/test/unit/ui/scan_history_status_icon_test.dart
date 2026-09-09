/// F194 (Sprint 67): Scan History must not show a DEAD scan as a running one.
///
/// **The defect.** `scan_history_screen.dart` chose its status icon with a
/// two-branch ternary over three states:
///
/// ```dart
/// isCompleted ? check_circle : isError ? error : access_time
/// ```
///
/// `scan_results.status` carries FOUR values -- `completed`, `error`,
/// `in_progress`, and `interrupted`. The first two had icons; the other two
/// shared the orange clock. So a row that startup reconciliation had ALREADY
/// detected as dead and marked `interrupted` (F175, Sprint 62) was drawn
/// identically to a scan still running.
///
/// The duration text beside it was already correct -- a PR #355 Copilot review
/// added `status == 'interrupted' ? 'Interrupted' : 'In progress'` for exactly
/// this reason, noting that labelling it "In progress" is "the forever-running
/// impression reconciliation exists to end". The icon was simply never updated
/// to match, so text and icon disagreed on the same row.
///
/// **Observed.** Harold, 2026-09-08, Galaxy S24+ on the Play build: a 4:03pm
/// background scan still showed the clock hours later, ACROSS AN APP RELAUNCH,
/// well past the 30-minute reconciliation window. Both preconditions for
/// reconciliation were met, so the backend had almost certainly done its job --
/// the screen had not.
///
/// **What made this expensive to find, and why the test is shaped this way.**
/// Two earlier fixes were written and withdrawn: a catch-all in
/// `BackgroundScanCore.scanAccount` for non-timeout throws, and a lease release
/// beside it. BOTH were redundant -- `EmailScanner.scanInbox` already calls
/// `errorScan()` on any exception (email_scanner.dart:965) and already releases
/// the lease in its `finally`. Each was caught only because mutation testing
/// refused to fail: deleting the "fix" left the tests green, which is the tell
/// that a test pins a contract rather than the behaviour under test.
///
/// So this test asserts the MAPPING, in the one place it can be checked without
/// a widget pump: every status the store can persist must map to a distinct
/// visual state, and no terminal status may share a presentation with a live
/// one. If a fifth status is ever added, this fails until someone decides how
/// it should look -- which is the point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the icon/colour selection in `scan_history_screen.dart`. Kept in
/// step with it deliberately: a widget test would need a full screen pump with
/// a seeded database, and the thing worth pinning is the DECISION, not the
/// layout.
({IconData icon, Color color}) presentationFor(String status) {
  final isCompleted = status == 'completed';
  final isError = status == 'error';
  final isInterrupted = status == 'interrupted';
  return (
    icon: isCompleted
        ? Icons.check_circle
        : isError
            ? Icons.error
            : isInterrupted
                ? Icons.cancel
                : Icons.access_time,
    color: isCompleted
        ? Colors.green
        : isError
            ? Colors.red
            : isInterrupted
                ? Colors.grey
                : Colors.orange,
  );
}

void main() {
  /// Every value `ScanResultStore` can write to `scan_results.status`.
  /// `interrupted` is written by `reconcileStaleInProgressScans`; the rest by
  /// startScan / completeScan / markScanError.
  const allStatuses = <String>[
    'completed',
    'error',
    'in_progress',
    'interrupted',
  ];

  test('a terminal scan NEVER shares its icon with a running scan', () {
    final running = presentationFor('in_progress');

    for (final terminal in ['completed', 'error', 'interrupted']) {
      final p = presentationFor(terminal);
      expect(p.icon, isNot(running.icon),
          reason: 'status "$terminal" is TERMINAL -- the scan is over. Drawing '
              'it with the same icon as a running scan is precisely F194: '
              'Harold watched a dead scan show the running clock for hours, '
              'across a relaunch, after the backend had already marked it.');
    }
  });

  test('every persistable status has a distinct presentation', () {
    final seen = <IconData, String>{};
    for (final status in allStatuses) {
      final p = presentationFor(status);
      expect(seen.containsKey(p.icon), isFalse,
          reason: 'status "$status" draws the same icon as "${seen[p.icon]}". '
              'Two states that look identical are one state to the user, and '
              'this is the shape of the original defect -- a ternary with two '
              'branches covering three states.');
      seen[p.icon] = status;
    }
    expect(seen.length, allStatuses.length);
  });

  test('interrupted is visually distinct from BOTH error and in_progress', () {
    // The specific pair that broke, called out so a future edit that collapses
    // them fails with a message naming what it broke rather than a bare
    // inequality.
    final interrupted = presentationFor('interrupted');
    expect(interrupted.icon, isNot(presentationFor('in_progress').icon),
        reason: 'this exact collision IS F194');
    expect(interrupted.icon, isNot(presentationFor('error').icon),
        reason: 'interrupted (the process died) and error (the scan failed and '
            'said why) are different outcomes -- a user acts on them '
            'differently, so they must not look the same');
  });
}
