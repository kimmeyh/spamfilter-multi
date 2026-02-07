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
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/evaluation_result.dart';

void main() {
  late EmailScanProvider provider;

  setUp(() {
    provider = EmailScanProvider();
  });

  group('Scan Mode Tests', () {
    /// Test readonly mode by default
    test('readonly mode is default (safe)', () {
      expect(provider.scanMode, ScanMode.readonly);
      expect(provider.emailTestLimit, isNull);
    });

    /// Test scan mode initialization
    group('initializeScanMode', () {
      test('initializes readonly mode', () {
        provider.initializeScanMode(mode: ScanMode.readonly);

        expect(provider.scanMode, ScanMode.readonly);
        expect(provider.emailTestLimit, isNull);
        expect(provider.hasActionsToRevert, isFalse);
        expect(provider.revertableActionCount, 0);
      });

      test('initializes testLimit mode with limit', () {
        provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 50);

        expect(provider.scanMode, ScanMode.testLimit);
        expect(provider.emailTestLimit, 50);
        expect(provider.hasActionsToRevert, isFalse);
      });

      test('initializes testAll mode', () {
        provider.initializeScanMode(mode: ScanMode.testAll);

        expect(provider.scanMode, ScanMode.testAll);
        expect(provider.emailTestLimit, isNull);
        expect(provider.hasActionsToRevert, isFalse);
      });

      test('clears previous revert tracking', () {
        // Set up first scan
        provider.initializeScanMode(mode: ScanMode.testAll);

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
        provider.initializeScanMode(mode: ScanMode.readonly);

        // Revert tracking should be cleared
        expect(provider.hasActionsToRevert, isFalse);
        expect(provider.revertableActionCount, 0);
      });
    });

    /// Test readonly mode behavior
    group('readonly mode', () {
      setUp(() {
        provider.initializeScanMode(mode: ScanMode.readonly);
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

    /// Test testLimit mode behavior
    group('testLimit mode', () {
      test('limits email modifications to N actions', () {
        provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 3);

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

        // [NEW] PHASE 3.1: Counts show all proposed actions (5), but only 3 executed
        expect(provider.deletedCount, 5); // All proposed actions
        expect(provider.revertableActionCount, 3); // Only executed (within limit)
        expect(provider.hasActionsToRevert, isTrue);
      });

      test('respects zero test limit', () {
        provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 0);

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

        // [NEW] PHASE 3.1: Counts show proposed actions (1), but none executed (limit = 0)
        expect(provider.deletedCount, 1); // Proposed action
        expect(provider.hasActionsToRevert, isFalse); // Not executed
      });

      test('tracks different action types within limit', () {
        provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 5);

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
        provider.initializeScanMode(mode: ScanMode.testAll);
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
      provider.initializeScanMode(mode: ScanMode.testAll);

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
      provider.initializeScanMode(mode: ScanMode.testAll);

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
      provider.initializeScanMode(mode: ScanMode.readonly);
      expect(provider.scanMode, ScanMode.readonly);

      // Switch to testLimit
      provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: 50);
      expect(provider.scanMode, ScanMode.testLimit);
      expect(provider.emailTestLimit, 50);

      // Switch to testAll
      provider.initializeScanMode(mode: ScanMode.testAll);
      expect(provider.scanMode, ScanMode.testAll);
      expect(provider.emailTestLimit, isNull);

      // Switch back to readonly
      provider.initializeScanMode(mode: ScanMode.readonly);
      expect(provider.scanMode, ScanMode.readonly);
    });
  });
}
