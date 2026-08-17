/// PR #335 review (Copilot, second pass): accountId must NEVER be split on a
/// guessed dash to recover an email.
///
/// The bug shape: `accountId.indexOf('-')` + "does the remainder contain '@'?"
/// splits `my-name@gmail.com` into platform `my` / email `name@gmail.com`,
/// corrupting `accounts.email` and every UI label derived from it. Two code
/// paths create the accounts row -- the shared scan path
/// (`EmailScanProvider._ensureAccountRow`) and the Windows background worker
/// (`BackgroundScanWindowsWorker._ensureAccountInDatabase`). The first fix
/// corrected only the shared path; this gate exists because the reviewer
/// caught the sibling still carrying the old heuristic.
///
/// Both writers now receive the platform explicitly and may strip ONLY the
/// known `<platformId>-` prefix.
///
/// This is a SOURCE gate: the worker's writer is a private static with no
/// injection seam, so its behavior cannot be exercised directly. Per the
/// project's "source gates prove a symbol exists, not that it works" rule,
/// the equivalent BEHAVIOR is pinned on the reachable path in
/// `test/integration/scan_result_persistence_test.dart` (dash-containing
/// plain email stays whole; a platform prefix strips exactly).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountId dash-parsing policy', () {
    /// The exact heuristic that caused the defect. Matching this pattern in
    /// an accounts-row writer means the bug class is back.
    final dashIndexHeuristic = RegExp(r"indexOf\('-'\)");

    test(
        'no accounts-row writer reintroduces indexOf dash-splitting to '
        'recover an email', () {
      final writers = <String>[
        'lib/core/providers/email_scan_provider.dart',
        'lib/core/services/background_scan_windows_worker.dart',
      ];

      for (final path in writers) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: 'policy gate must fail loudly if $path moves rather '
                'than silently passing on a missing file');

        // Scope to the EMAIL-recovery region only. A dash scan elsewhere can
        // be legitimate (the worker infers a platform prefix when the
        // credential store has none, guarded so it cannot fire on a dash
        // inside the email); what must never come back is deriving the
        // stored `email` from a guessed dash.
        final source = file.readAsStringSync();
        final emailRecovery = RegExp(
            r'String email = accountId;[\s\S]{0,600}?db\.insert');
        final region = emailRecovery.firstMatch(source);
        expect(region, isNotNull,
            reason: '$path should still contain an accounts-row insert that '
                'derives `email` from accountId -- if this moved, re-point '
                'the gate rather than deleting it');

        expect(dashIndexHeuristic.hasMatch(region!.group(0)!), isFalse,
            reason: '$path must not guess an email by splitting accountId '
                'at the first dash -- "my-name@gmail.com" becomes platform '
                '"my" / email "name@gmail.com". Strip only the known '
                '"<platformId>-" prefix (PR #335 review).');
      }
    });

    test('both writers strip exactly the known platform prefix', () {
      final expected = RegExp(r"startsWith\('\$platformId-'\)");

      for (final path in <String>[
        'lib/core/providers/email_scan_provider.dart',
        'lib/core/services/background_scan_windows_worker.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(expected.hasMatch(source), isTrue,
            reason: '$path must recover the email via the explicit '
                '"<platformId>-" prefix strip');
      }
    });
  });
}
