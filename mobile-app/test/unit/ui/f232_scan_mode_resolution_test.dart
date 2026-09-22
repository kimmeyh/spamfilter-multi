/// F232 (Sprint 72): a rule created from a HISTORICAL scan view must act on the
/// mailbox -- or say plainly that it did not.
///
/// **The defect.** `_reProcessAffectedEmails` returned early when
/// `scanProvider.scanMode == ScanMode.readOnly`, and `_scanMode` DEFAULTS to
/// `readOnly`, set only by `initializeScanMode()` whose call sites are all
/// scan-STARTING paths. Nothing set it when a saved scan was opened from Scan
/// History, so in a session where no scan had been started the mode was still
/// the default and every IMAP action was skipped -- silently, to a console log
/// nobody could read.
///
/// **How Harold found it**: blocking a domain from a saved scan deleted
/// nothing, and the next background scan then deleted exactly the count that
/// session should have. His controlled comparison is what eliminated every
/// environment-level explanation: same account, credentials, network and rules,
/// minutes apart, one path working and the other not.
///
/// **Sprint 38 patched the SYMPTOM.** It added an unconditional row-hiding loop
/// so the list looked right, reasoning the hiding "is safe regardless of
/// scanMode (no IMAP side effects)". True of the hiding -- and it made the
/// skipped deletion invisible. A test asserting only that rows hid would have
/// passed throughout. That is the gap these tests close.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the RESOLUTION
/// -- which mode governs, given what is stored -- and the source wiring. They
/// do not prove the IMAP server accepted the action, and they cannot reach
/// mechanism B (a live batch failing 9 of 9 on a healthy connection), which is
/// still undiagnosed and now instrumented rather than fixed.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';

void main() {
  group('F232: the resolution rule', () {
    test('THE BUG: the provider default is read-only', () {
      // This is the whole mechanism in one assertion. A freshly constructed
      // provider -- which is the state when the app launches and the user goes
      // straight to Scan History -- reports read-only, and the old code treated
      // that as "the user wants no action" rather than "nobody has said yet".
      final provider = EmailScanProvider();
      expect(provider.scanMode, ScanMode.readOnly,
          reason: 'if this default ever changes, the F232 mechanism changes '
              'with it and this card must be re-read');
    });

    test('a session mode set by a real scan is an explicit choice', () {
      final provider = EmailScanProvider();
      provider.initializeScanMode(mode: ScanMode.safeSendersAndRules);

      expect(provider.scanMode, ScanMode.safeSendersAndRules,
          reason: 'when a scan ran this session the user expressed an intent, '
              'and it outranks the saved default');
    });
  });

  group('F232: the production code resolves from settings, not session state',
      () {
    late String source;

    setUpAll(() {
      source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    });

    test('the silent early return is gone', () {
      expect(
          source.contains(
              "logger.i('[F38] Skipping re-process: scan mode is readOnly');"),
          isFalse,
          reason: 'THE EXACT LINE THAT CAUSED THIS. A skipped action whose only '
              'trace is a console log is how the defect survived from Sprint 38 '
              'to Sprint 71.');
    });

    test('the effective mode is resolved before deciding', () {
      expect(source.contains('_resolveEffectiveScanMode'), isTrue);
      expect(source.contains('getAccountManualScanMode'), isTrue,
          reason: 'per-ACCOUNT resolution: this screen can show All Accounts, '
              'so one session value would be wrong');
    });

    test('the MANUAL mode governs a user-initiated action', () {
      expect(source.contains('getManualScanMode()'), isTrue,
          reason: 'not the background mode -- letting a background policy '
              'govern a foreground action the user just took would be a '
              'different setting answering a question it was not asked');
      expect(source.contains('getBackgroundScanMode()'), isFalse,
          reason: 'the background mode has no business on this path');
    });

    test('a read-only account is TOLD, not silently skipped', () {
      expect(
          source.contains(
              'This account is set to read-only, so your mailbox '),
          isTrue,
          reason: 'the honest half of the fix: Windows DEV/Prod stay read-only '
              'by configuration and must now SAY so rather than fall silent');
      expect(source.contains('DiagnosticLogger.kindSkipped'), isTrue,
          reason: 'and it must reach the log as well as the screen');
    });

    test('resolution failure defaults to read-only', () {
      expect(
          source.contains('scan-mode resolution failed, defaulting to'), isTrue,
          reason: 'a resolution error must never become an unintended '
              'deletion -- fail toward doing nothing');
    });
  });
}
