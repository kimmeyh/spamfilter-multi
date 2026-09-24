/// Phase 5.1.1 review findings for F232 (Sprint 72) -- C-1, C-2, C-2b, I-1.
///
/// **Why this file exists separately.** The review named a coverage gap under
/// the repo's IMP-1 rule: `f232_scan_mode_resolution_test.dart` exercised the
/// resolution tiers and asserted nothing about the historical-LOAD path or
/// about another account's mode leaking in. Both were real defects, both were
/// green, and the tests were testing the half that worked -- the Sprint 70 F220
/// shape exactly.
///
/// **C-1 was the serious one.** The F232 fix was applied inside
/// `_reProcessAffectedEmails`, which all THREE callers share. Two are
/// user-initiated. The third runs during screen load when a saved scan is
/// opened from Scan History. Before F232 that was inert by accident -- the old
/// `scanMode == readOnly` guard always tripped there, because opening history
/// sets no session mode. Removing that accident meant merely VIEWING a saved
/// scan could delete mail on a live-configured account, with no user intent and
/// the outcome discarded.
///
/// **What these tests do NOT catch** (IMP-1): they assert the SOURCE structure
/// of the guard and the resolver. They do not drive the screen, so they cannot
/// prove no deletion occurs at runtime -- that needs the manual validation step
/// of opening a saved scan on a live account and confirming the mailbox is
/// untouched. These pin the shape; the device proves the behavior.
/// SOURCE-TEXT VERIFIED: these pin the review findings' fixes as source shapes.
/// They cannot prove a rule created from a historical scan view actually acts
/// on the mailbox. What settles that is a live account run -- mechanism B is
/// still undiagnosed for exactly this reason and is instrumented rather than
/// asserted.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source =
        File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
  });

  group('C-1: screen load must never act on the mailbox', () {
    test('THE DEFECT: the load path passes userInitiated: false', () {
      expect(source.contains('_reProcessAffectedEmails(userInitiated: false)'),
          isTrue,
          reason: 'THE ASSERTION THAT WAS MISSING. This call runs during screen '
              'load from Scan History. Without the flag, F232 turned viewing '
              'history into a deletion path on a live-configured account.');
    });

    test('the parameter defaults to true so callers must opt OUT', () {
      expect(source.contains('bool userInitiated = true,'), isTrue,
          reason: 'defaulting to false would silently disable F232 for the two '
              'callers it was built for; the dangerous path is the one that '
              'must be explicit');
    });

    test('a non-user-initiated call resolves to read-only', () {
      expect(
          source.contains('final effectiveMode = userInitiated\n'
              '        ? await _resolveEffectiveScanMode(scanProvider)\n'
              '        : ScanMode.readOnly;'),
          isTrue,
          reason: 'it must not merely skip the settings lookup -- it must land '
              'on the mode that cannot touch a mailbox');
    });

    test('the stale Sprint 38 comment was rewritten, not left behind', () {
      expect(
          source.contains('returns early when scanProvider.scanMode == readOnly, which is\n'
              '          // the default state on app launch'),
          isFalse,
          reason: 'that comment described the accident F232 removed. A comment '
              'asserting a safety mechanism that no longer exists is the '
              'Sprint 70 CRITICAL pattern.');
    });
  });

  group('C-2/C-2b: resolution must not leak across accounts or skip a tier',
      () {
    test('THE DEFECT: the session-mode shortcut is gone', () {
      expect(
          source.contains('if (scanProvider.scanMode != ScanMode.readOnly) {\n'
              '      return scanProvider.scanMode;'),
          isFalse,
          reason: 'EmailScanProvider is an app-wide SINGLETON with one '
              '_scanMode and no account identity. Scanning account A then '
              'opening results for read-only account B returned A mode for B, '
              'bypassing B deliberate configuration.');
    });

    test('it delegates to the canonical resolver', () {
      expect(
          source.contains(
              'getEffectiveScanMode(widget.accountId, isBackground: false)'),
          isTrue,
          reason: 'SettingsStore.getEffectiveScanMode already implemented this '
              'with THREE tiers; the hand-rolled copy implemented two and '
              'skipped the generic per-account override');
    });

    test('MANUAL mode, not background', () {
      expect(source.contains('isBackground: false'), isTrue,
          reason: 'a foreground action the user just took must not be governed '
              'by a background policy');
    });

    test('resolution failure still defaults to read-only', () {
      expect(source.contains("'[F38] scan-mode resolution failed, defaulting to '"),
          isTrue,
          reason: 'an error must never become an unintended deletion');
    });
  });

  group('I-1: comments must not claim mechanisms that do not exist', () {
    test('the false partitioning claim is gone', () {
      expect(source.contains('The batch is\n    // PARTITIONED below'), isFalse,
          reason: 'this screen takes a single required accountId -- it is '
              'structurally single-account, and nothing partitioned per row. '
              'A comment asserting a safety property nothing implements is '
              'worse than no comment.');
    });

    test('the single-account reality is stated instead', () {
      expect(source.contains('structurally single-account'), isTrue);
    });
  });

  group('I-2: one action, one message', () {
    test('the duplicate read-only SnackBar is gone', () {
      expect(
          source.contains("'Rule saved. This account is set to read-only, so your mailbox '"),
          isFalse,
          reason: 'the method showed its own message AND returned an outcome '
              'the caller also rendered -- and a new SnackBar REPLACES the '
              'current one, so the user saw a flash then a different sentence');
    });
  });

  group('I-3: a historical export stamps the historical date', () {
    test('the export takes a scanDate', () {
      final provider = File('lib/core/providers/email_scan_provider.dart')
          .readAsStringSync();
      expect(provider.contains('DateTime? scanDate,'), isTrue);
      expect(provider.contains('final effectiveScanDate = scanDate ?? _scanStartTime;'),
          isTrue,
          reason: 'without this, exporting a saved scan wrote Unknown -- or '
              'worse, TODAY timestamp onto rows from days ago');
    });

    test('the screen passes the loaded scan date for a historical view', () {
      expect(source.contains('_historicalScanCompletedAt'), isTrue);
      expect(
          source.contains('scanDate: widget.historicalScanId != null'), isTrue,
          reason: 'null on a live view, where the provider own _scanStartTime '
              'is the right answer');
    });
  });
}
