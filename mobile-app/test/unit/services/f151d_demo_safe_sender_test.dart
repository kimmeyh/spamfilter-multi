/// F151d (Sprint 58): shouldSkipSafeSenderAlreadyInTarget's Demo Mode
/// exception. Real scans keep the pre-existing "already in target folder,
/// nothing to do" skip; Demo Mode's safe-sender-matching emails are
/// deliberately placed in the target folder by design, so they must NOT be
/// skipped there -- confirmed via a live walkthrough that this silently
/// excluded all demo safe-sender results (Harold, 2026-08-15).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';

void main() {
  // shouldSkipSafeSenderAlreadyInTarget is a pure predicate that takes its
  // own platformId parameter -- the constructor's platformId is unrelated
  // to what is under test here, so any fixed value is fine.
  final scanner = EmailScanner(
    platformId: 'aol',
    accountId: 'test-account',
    ruleSetProvider: RuleSetProvider(),
    scanProvider: EmailScanProvider(),
  );

  group('shouldSkipSafeSenderAlreadyInTarget -- F151d Demo Mode exception', () {
    test('real platform, message already in target folder -> skip (true)', () {
      final result = scanner.shouldSkipSafeSenderAlreadyInTarget(
        platformId: 'aol',
        messageFolderName: 'INBOX',
        safeSenderTarget: 'INBOX',
      );
      expect(result, isTrue);
    });

    test('real platform, message NOT in target folder -> do not skip (false)', () {
      final result = scanner.shouldSkipSafeSenderAlreadyInTarget(
        platformId: 'aol',
        messageFolderName: 'Bulk Mail',
        safeSenderTarget: 'INBOX',
      );
      expect(result, isFalse);
    });

    test('demo platform, message already in target folder -> do not skip (false)', () {
      // This is the F151d fix: the demo dataset deliberately places its
      // safe-sender-matching emails in INBOX (the target), so the real-scan
      // "nothing to do" optimization must not apply here.
      final result = scanner.shouldSkipSafeSenderAlreadyInTarget(
        platformId: 'demo',
        messageFolderName: 'INBOX',
        safeSenderTarget: 'INBOX',
      );
      expect(result, isFalse);
    });

    test('demo platform, message NOT in target folder -> do not skip (false)', () {
      final result = scanner.shouldSkipSafeSenderAlreadyInTarget(
        platformId: 'demo',
        messageFolderName: 'Promotions',
        safeSenderTarget: 'INBOX',
      );
      expect(result, isFalse);
    });

    test('folder-name comparison is case-insensitive for real platforms', () {
      final result = scanner.shouldSkipSafeSenderAlreadyInTarget(
        platformId: 'gmail',
        messageFolderName: 'inbox',
        safeSenderTarget: 'INBOX',
      );
      expect(result, isTrue);
    });
  });
}
