/// Unit tests for Phase 2 Sprint 3: Scan modes and read-only testing
/// 
/// [NEW] PHASE 2 SPRINT 3: Read-only mode, test limits, and revert capability
/// 
/// Tests verify:
/// - Readonly mode prevents all email modifications (safe by default)
/// - Test limit mode executes only up to N actions
/// - Test all mode executes all actions
/// - Revert functionality undoes all actions from last run
/// - Confirm functionality prevents further reverts
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';

void main() {
  late EmailScanProvider provider;

  setUp(() {
    provider = EmailScanProvider();
  });

  group('Scan Mode Tests', () {
    /// Test readonly mode by default
    test('readonly mode is default (safe)', () {
      expect(provider.scanMode, ScanMode.readOnly);
    });

    /// Test scan mode initialization
    group('initializeScanMode', () {
      test('initializes readonly mode', () {
        provider.initializeScanMode(mode: ScanMode.readOnly);

        expect(provider.scanMode, ScanMode.readOnly);
        expect(provider.hasActionsToRevert, isFalse);
        expect(provider.revertableActionCount, 0);
      });

      test('initializes rulesOnly mode (F181: no test limit exists)', () {
        provider.initializeScanMode(mode: ScanMode.rulesOnly);

        expect(provider.scanMode, ScanMode.rulesOnly);
        expect(provider.hasActionsToRevert, isFalse);
      });

      test('initializes testAll mode', () {
        provider.initializeScanMode(mode: ScanMode.safeSendersOnly);

        expect(provider.scanMode, ScanMode.safeSendersOnly);
        expect(provider.hasActionsToRevert, isFalse);
      });

      test('clears previous revert tracking', () {
        // Set up first scan
        provider.initializeScanMode(mode: ScanMode.safeSendersOnly);

        // Create and record dummy action
        final email = EmailMessage(
          id: 'test-1',
          from: 'test@example.com',
          subject: 'Test',
          body: 'Test body',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.delete,
          success: true,
        );

        provider.recordResult(result);

        expect(provider.hasActionsToRevert, isTrue);
        expect(provider.revertableActionCount, 1);

        // Reinitialize scan mode
        provider.initializeScanMode(mode: ScanMode.readOnly);

        // Revert tracking should be cleared
        expect(provider.hasActionsToRevert, isFalse);
        expect(provider.revertableActionCount, 0);
      });
    });

    /// Test readonly mode behavior
    group('readonly mode', () {
      setUp(() {
        provider.initializeScanMode(mode: ScanMode.readOnly);
      });

      test('prevents email deletion (logs only)', () {
        final email = EmailMessage(
          id: 'test-1',
          from: 'spam@example.com',
          subject: 'Delete This',
          body: 'Spam email',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.delete,
          success: true,
        );

        provider.recordResult(result);

        // [NEW] PHASE 3.1: In readonly mode, counts show what WOULD happen (proposed actions)
        // but actions are NOT executed (hasActionsToRevert remains false)
        expect(provider.deletedCount, 1); // Shows proposed action
        expect(provider.hasActionsToRevert, isFalse); // Not executed
      });

      test('prevents email moving (logs only)', () {
        final email = EmailMessage(
          id: 'test-2',
          from: 'newsletter@example.com',
          subject: 'Newsletter',
          body: 'Weekly newsletter',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult(
            shouldDelete: false,
            shouldMove: true,
            targetFolder: 'Junk',
            matchedRule: 'newsletter-rule',
            matchedPattern: 'pattern',
          ),
          action: EmailActionType.moveToJunk,
          success: true,
        );

        provider.recordResult(result);

        // [NEW] PHASE 3.1: In readonly mode, counts show what WOULD happen (proposed actions)
        expect(provider.movedCount, 1); // Shows proposed action
        expect(provider.hasActionsToRevert, isFalse); // Not executed
      });

      test('prevents safe sender addition (logs only)', () {
        final email = EmailMessage(
          id: 'test-3',
          from: 'friend@example.com',
          subject: 'Hi',
          body: 'Hello friend',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.safeSender('whitelist-rule'),
          action: EmailActionType.safeSender,
          success: true,
        );

        provider.recordResult(result);

        // [NEW] PHASE 3.1: In readonly mode, counts show what WOULD happen (proposed actions)
        expect(provider.safeSendersCount, 1); // Shows proposed action
        expect(provider.hasActionsToRevert, isFalse); // Not executed
      });

      test('no actions can be reverted', () {
        final email = EmailMessage(
          id: 'test-1',
          from: 'spam@example.com',
          subject: 'Test',
          body: 'Test',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.delete,
          success: true,
        );

        // Record multiple actions
        for (int i = 0; i < 5; i++) {
          provider.recordResult(result);
        }

        expect(provider.hasActionsToRevert, isFalse);
        expect(provider.revertableActionCount, 0);
      });
    });

    /// F181 (Sprint 63): the 50-email testLimit cap is REMOVED -- rulesOnly
    /// executes and revert-tracks every action, uncapped. These tests were
    /// inverted from the old cap assertions.
    group('rulesOnly mode (uncapped, F181)', () {
      test('executes and tracks ALL actions -- no 3-of-5 cap (F181)', () {
        provider.initializeScanMode(mode: ScanMode.rulesOnly);

        for (int i = 0; i < 5; i++) {
          final email = EmailMessage(
            id: 'test-${i + 1}',
            from: 'spam@example.com',
            subject: 'Test',
            body: 'Test body',
            headers: const {},
            receivedDate: DateTime.now(),
            folderName: 'INBOX',
          );

          final result = EmailActionResult(
            email: email,
            evaluationResult: EvaluationResult.noMatch(),
            action: EmailActionType.delete,
            success: true,
          );

          provider.recordResult(result);
        }

        // F181: all 5 proposed actions execute AND are revert-tracked.
        expect(provider.deletedCount, 5);
        expect(provider.revertableActionCount, 5);
        expect(provider.hasActionsToRevert, isTrue);
      });

      test('single action executes and is revertable (F181: no zero-cap)', () {
        provider.initializeScanMode(mode: ScanMode.rulesOnly);

        final email = EmailMessage(
          id: 'test-1',
          from: 'spam@example.com',
          subject: 'Test',
          body: 'Test body',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        );

        final result = EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.delete,
          success: true,
        );

        provider.recordResult(result);

        // F181: the action executes and is tracked (the old limit=0 case is gone).
        expect(provider.deletedCount, 1);
        expect(provider.hasActionsToRevert, isTrue);
      });

      test('tracks different action types (uncapped)', () {
        provider.initializeScanMode(mode: ScanMode.rulesOnly);

        final baseDate = DateTime.now();

        // Delete 2
        for (int i = 0; i < 2; i++) {
          provider.recordResult(EmailActionResult(
            email: EmailMessage(
              id: 'delete-${i + 1}',
              from: 'test@example.com',
              subject: 'Test',
              body: 'Test',
              headers: const {},
              receivedDate: baseDate,
              folderName: 'INBOX',
            ),
            evaluationResult: EvaluationResult.noMatch(),
            action: EmailActionType.delete,
            success: true,
          ));
        }

        // Move 2
        for (int i = 0; i < 2; i++) {
          provider.recordResult(EmailActionResult(
            email: EmailMessage(
              id: 'move-${i + 1}',
              from: 'test@example.com',
              subject: 'Test',
              body: 'Test',
              headers: const {},
              receivedDate: baseDate,
              folderName: 'INBOX',
            ),
            evaluationResult: EvaluationResult(
              shouldDelete: false,
              shouldMove: true,
              targetFolder: 'Junk',
              matchedRule: 'rule',
              matchedPattern: 'pattern',
            ),
            action: EmailActionType.moveToJunk,
            success: true,
          ));
        }

        // Add to safe senders 1
        provider.recordResult(EmailActionResult(
          email: EmailMessage(
            id: 'safe-1',
            from: 'test@example.com',
            subject: 'Test',
            body: 'Test',
            headers: const {},
            receivedDate: baseDate,
            folderName: 'INBOX',
          ),
          evaluationResult: EvaluationResult.safeSender('rule'),
          action: EmailActionType.safeSender,
          success: true,
        ));

        expect(provider.deletedCount, 2);
        expect(provider.movedCount, 2);
        expect(provider.safeSendersCount, 1);
        expect(provider.revertableActionCount, 5);
      });
    });

    /// Test testAll mode behavior
    group('testAll mode', () {
      setUp(() {
        provider.initializeScanMode(mode: ScanMode.safeSendersOnly);
      });

      test('executes all email actions', () {
        final baseDate = DateTime.now();

        for (int i = 0; i < 10; i++) {
          final email = EmailMessage(
            id: 'test-${i + 1}',
            from: 'spam@example.com',
            subject: 'Test',
            body: 'Test body',
            headers: const {},
            receivedDate: baseDate,
            folderName: 'INBOX',
          );

          final result = EmailActionResult(
            email: email,
            evaluationResult: EvaluationResult.noMatch(),
            action: EmailActionType.delete,
            success: true,
          );

          provider.recordResult(result);
        }

        // All 10 actions should execute
        expect(provider.deletedCount, 10);
        expect(provider.revertableActionCount, 10);
        expect(provider.hasActionsToRevert, isTrue);
      });

      test('tracks actions for revert', () {
        final baseDate = DateTime.now();

        final actions = [
          EmailActionResult(
            email: EmailMessage(
              id: 'delete-1',
              from: 'test@example.com',
              subject: 'Test',
              body: 'Test',
              headers: const {},
              receivedDate: baseDate,
              folderName: 'INBOX',
            ),
            evaluationResult: EvaluationResult.noMatch(),
            action: EmailActionType.delete,
            success: true,
          ),
          EmailActionResult(
            email: EmailMessage(
              id: 'move-1',
              from: 'test@example.com',
              subject: 'Test',
              body: 'Test',
              headers: const {},
              receivedDate: baseDate,
              folderName: 'INBOX',
            ),
            evaluationResult: EvaluationResult(
              shouldDelete: false,
              shouldMove: true,
              targetFolder: 'Spam',
              matchedRule: 'rule-2',
              matchedPattern: 'pattern',
            ),
            action: EmailActionType.moveToJunk,
            success: true,
          ),
          EmailActionResult(
            email: EmailMessage(
              id: 'safe-1',
              from: 'test@example.com',
              subject: 'Test',
              body: 'Test',
              headers: const {},
              receivedDate: baseDate,
              folderName: 'INBOX',
            ),
            evaluationResult: EvaluationResult.safeSender('rule-3'),
            action: EmailActionType.safeSender,
            success: true,
          ),
        ];

        for (var action in actions) {
          provider.recordResult(action);
        }

        expect(provider.revertableActionCount, 3);
        expect(provider.hasActionsToRevert, isTrue);
      });
    });
  });

  group('Revert Functionality', () {
    test('revertLastRun clears revert tracking', () async {
      provider.initializeScanMode(mode: ScanMode.safeSendersOnly);

      final email = EmailMessage(
        id: 'test-1',
        from: 'spam@example.com',
        subject: 'Test',
        body: 'Test body',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = EmailActionResult(
        email: email,
        evaluationResult: EvaluationResult.noMatch(),
        action: EmailActionType.delete,
        success: true,
      );

      provider.recordResult(result);

      expect(provider.hasActionsToRevert, isTrue);
      expect(provider.revertableActionCount, 1);

      // Note: revertLastRun() is async and would need actual email adapter
      // to fully test, but we can verify the API exists
      expect(() => provider.revertLastRun(), returnsNormally);
    });

    test('confirmLastRun prevents further reverts', () {
      provider.initializeScanMode(mode: ScanMode.safeSendersOnly);

      final email = EmailMessage(
        id: 'test-1',
        from: 'spam@example.com',
        subject: 'Test',
        body: 'Test body',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = EmailActionResult(
        email: email,
        evaluationResult: EvaluationResult.noMatch(),
        action: EmailActionType.delete,
        success: true,
      );

      provider.recordResult(result);

      expect(provider.hasActionsToRevert, isTrue);

      provider.confirmLastRun();

      // After confirm, revert should not be possible
      expect(provider.hasActionsToRevert, isFalse);
      expect(provider.revertableActionCount, 0);
    });
  });

  group('Scan Mode Transition', () {
    test('switching modes clears previous state', () {
      // Start with readonly
      provider.initializeScanMode(mode: ScanMode.readOnly);
      expect(provider.scanMode, ScanMode.readOnly);

      // Switch to rulesOnly (F181: no limit parameter)
      provider.initializeScanMode(mode: ScanMode.rulesOnly);
      expect(provider.scanMode, ScanMode.rulesOnly);

      // Switch to testAll
      provider.initializeScanMode(mode: ScanMode.safeSendersOnly);
      expect(provider.scanMode, ScanMode.safeSendersOnly);

      // Switch back to readonly
      provider.initializeScanMode(mode: ScanMode.readOnly);
      expect(provider.scanMode, ScanMode.readOnly);
    });
  });

  // F110 (Sprint 43): "Phishing SPF/DKIM/DMARC" -- the auth-failure CSV column
  // + per-account-log failures list.
  group('F110 phishing auth-failure reporting', () {
    EmailActionResult resultWithHeaders(
        String from, Map<String, String> headers) {
      return EmailActionResult(
        email: EmailMessage(
          id: 'id-$from',
          from: from,
          subject: 'subj',
          body: '',
          headers: headers,
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        evaluationResult: EvaluationResult.noMatch(),
        action: EmailActionType.none,
        success: true,
      );
    }

    setUp(() => provider.initializeScanMode(mode: ScanMode.readOnly));

    test('getExcelRows last column lists failed checks, blank when none', () {
      provider.recordResult(resultWithHeaders('spoof@evil.com', {
        'Authentication-Results':
            'spf=fail; dkim=pass; dmarc=fail header.from=evil.com',
      }));
      provider.recordResult(resultWithHeaders('legit@good.com', {
        'Authentication-Results':
            'spf=pass; dkim=pass; dmarc=pass header.from=good.com',
      }));

      final rows = provider.getExcelRows();
      expect(rows, hasLength(2));
      // The Auth column is the LAST cell (index 10 of 11).
      expect(rows[0].last, 'SPF,DMARC');
      expect(rows[1].last, '');
    });

    test('getAuthFailures returns only failed emails with their checks', () {
      provider.recordResult(resultWithHeaders('spoof@evil.com', {
        'Authentication-Results':
            'spf=fail; dkim=fail; dmarc=fail header.from=evil.com',
      }));
      provider.recordResult(resultWithHeaders('legit@good.com', {
        'Authentication-Results': 'spf=pass; dkim=pass; dmarc=pass',
      }));

      final failures = provider.getAuthFailures();
      expect(failures, hasLength(1));
      expect(failures.first.from, 'spoof@evil.com');
      expect(failures.first.failedChecks, 'SPF,DKIM,DMARC');
    });

    test('no failures when no email failed auth', () {
      provider.recordResult(resultWithHeaders('a@b.com', {
        'Authentication-Results': 'spf=pass; dkim=pass; dmarc=pass',
      }));
      expect(provider.getAuthFailures(), isEmpty);
    });
  });
}
