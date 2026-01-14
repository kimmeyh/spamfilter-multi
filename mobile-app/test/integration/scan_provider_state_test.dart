// ignore_for_file: avoid_print

/// Integration tests for EmailScanProvider State Management
///
/// Tests comprehensive state management scenarios:
/// - Scan lifecycle (idle -> scanning -> completed)
/// - Multi-account folder selection isolation
/// - Progressive update throttling
/// - Scan mode behavior (readonly, testLimit, testAll, fullScan)
/// - Revert capability tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/evaluation_result.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';

void main() {
  group('EmailScanProvider - Scan Lifecycle', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Initial state should be idle', () {
      expect(provider.status, equals(ScanStatus.idle));
      expect(provider.processedCount, equals(0));
      expect(provider.totalEmails, equals(0));
      expect(provider.progress, equals(0.0));
      expect(provider.results, isEmpty);
    });

    test('startScan should transition to scanning state', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 100);

      expect(provider.status, equals(ScanStatus.scanning));
      expect(provider.totalEmails, equals(100));
      expect(provider.processedCount, equals(0));
      expect(provider.deletedCount, equals(0));
      expect(provider.movedCount, equals(0));
      expect(provider.safeSendersCount, equals(0));
      expect(provider.noRuleCount, equals(0));
      expect(provider.errorCount, equals(0));
    });

    test('recordResult should update progress', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 10);

      // Record 5 results
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'test$i@example.com');
      }

      expect(provider.processedCount, equals(5));
      expect(provider.deletedCount, equals(5));
      expect(provider.progress, equals(0.5));
    });

    test('completeScan should transition to completed state', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 5);

      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'test$i@example.com');
      }

      provider.completeScan();

      expect(provider.status, equals(ScanStatus.completed));
      expect(provider.progress, equals(1.0));
    });

    test('pauseScan and resumeScan should work correctly', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 10);

      _recordSimpleResult(provider, EmailActionType.delete, 'test@example.com');

      provider.pauseScan();
      expect(provider.status, equals(ScanStatus.paused));

      provider.resumeScan();
      expect(provider.status, equals(ScanStatus.scanning));
    });

    test('setError should transition to error state with message', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 10);

      provider.errorScan('Connection timeout');

      expect(provider.status, equals(ScanStatus.error));
      expect(provider.statusMessage, contains('Connection timeout'));
    });

    test('reset should clear all state', () {
      provider.initializeScanMode(mode: ScanMode.testAll);
      provider.startScan(totalEmails: 10);

      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'test$i@example.com');
      }

      provider.reset();

      expect(provider.status, equals(ScanStatus.idle));
      expect(provider.processedCount, equals(0));
      expect(provider.totalEmails, equals(0));
      expect(provider.results, isEmpty);
      expect(provider.deletedCount, equals(0));
    });
  });

  group('EmailScanProvider - Multi-Account Folder Selection', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Folders should be isolated per account (Issue #41)', () {
      // Set folders for account 1
      provider.setCurrentAccount('aol-user1@aol.com');
      provider.setSelectedFolders(['Inbox', 'Bulk Mail']);

      // Set folders for account 2
      provider.setCurrentAccount('gmail-user2@gmail.com');
      provider.setSelectedFolders(['INBOX', 'SPAM']);

      // Switch back to account 1 and verify folders
      provider.setCurrentAccount('aol-user1@aol.com');
      expect(provider.selectedFolders, equals(['Inbox', 'Bulk Mail']));

      // Switch to account 2 and verify folders
      provider.setCurrentAccount('gmail-user2@gmail.com');
      expect(provider.selectedFolders, equals(['INBOX', 'SPAM']));

      print('✅ Multi-account folder isolation verified');
    });

    test('Default folders should be INBOX when no selection exists', () {
      provider.setCurrentAccount('new-account@example.com');

      expect(provider.selectedFolders, equals(['INBOX']));
    });

    test('setSelectedFolders should require valid account ID', () {
      // Without account ID, folders should not be set
      provider.setSelectedFolders(['Inbox', 'Spam']);

      // Should use INBOX default since no account is set
      expect(provider.selectedFolders, equals(['INBOX']));
    });
  });

  group('EmailScanProvider - Scan Mode Behavior', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Readonly mode should log actions without executing', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 5);

      // Record results in readonly mode
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'spam$i@example.com');
      }

      // Counts should reflect proposed actions
      expect(provider.deletedCount, equals(5));

      // But no revertable actions in readonly mode
      expect(provider.hasActionsToRevert, isFalse);
      expect(provider.revertableActionCount, equals(0));

      print('✅ Readonly mode verified - counts show proposed actions, no revertable actions');
    });

    test('TestLimit mode should track revertable actions up to limit', () {
      const testLimit = 3;
      provider.initializeScanMode(mode: ScanMode.testLimit, testLimit: testLimit);
      provider.startScan(totalEmails: 10);

      // Record 5 delete actions (but only 3 should be revertable)
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'spam$i@example.com');
      }

      // All 5 should be counted
      expect(provider.deletedCount, equals(5));

      // But only 3 should be revertable (due to limit)
      expect(provider.hasActionsToRevert, isTrue);
      expect(provider.revertableActionCount, equals(testLimit));

      print('✅ TestLimit mode verified - limit of $testLimit respected');
    });

    test('TestAll mode should track all actions as revertable', () {
      provider.initializeScanMode(mode: ScanMode.testAll);
      provider.startScan(totalEmails: 10);

      // Record 10 delete actions
      for (int i = 0; i < 10; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'spam$i@example.com');
      }

      expect(provider.deletedCount, equals(10));
      expect(provider.hasActionsToRevert, isTrue);
      expect(provider.revertableActionCount, equals(10));

      print('✅ TestAll mode verified - all 10 actions revertable');
    });

    test('FullScan mode should NOT track revertable actions', () {
      provider.initializeScanMode(mode: ScanMode.fullScan);
      provider.startScan(totalEmails: 5);

      // Record 5 delete actions
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'spam$i@example.com');
      }

      expect(provider.deletedCount, equals(5));

      // FullScan mode = permanent, no revert
      expect(provider.hasActionsToRevert, isFalse);
      expect(provider.revertableActionCount, equals(0));

      print('✅ FullScan mode verified - permanent actions, no revert tracking');
    });
  });

  group('EmailScanProvider - No Rule Tracking', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('Emails with no rule match should be counted', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 10);

      // Record some matched results
      _recordSimpleResult(provider, EmailActionType.delete, 'spam@example.com');
      _recordSimpleResult(provider, EmailActionType.safeSender, 'friend@example.com');

      // Record results with no rule match (action = none)
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.none, 'unknown$i@example.com');
      }

      expect(provider.noRuleCount, equals(5));
      expect(provider.deletedCount, equals(1));
      expect(provider.safeSendersCount, equals(1));
      expect(provider.processedCount, equals(7));

      print('✅ No rule count tracking verified: ${provider.noRuleCount} emails without rules');
    });

    test('noRuleCount should reset on new scan', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 5);

      // Record some no-rule results
      for (int i = 0; i < 3; i++) {
        _recordSimpleResult(provider, EmailActionType.none, 'unknown$i@example.com');
      }

      expect(provider.noRuleCount, equals(3));

      // Start new scan - noRuleCount should reset
      provider.startScan(totalEmails: 10);

      expect(provider.noRuleCount, equals(0));

      print('✅ noRuleCount reset on new scan verified');
    });
  });

  group('EmailScanProvider - Current Folder Tracking', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('updateCurrentFolder should update currentFolder', () {
      provider.initializeScanMode(mode: ScanMode.readonly);
      provider.startScan(totalEmails: 100);

      provider.setCurrentFolder('Inbox');
      expect(provider.currentFolder, equals('Inbox'));

      provider.setCurrentFolder('Bulk Mail');
      expect(provider.currentFolder, equals('Bulk Mail'));

      provider.setCurrentFolder('Spam');
      expect(provider.currentFolder, equals('Spam'));

      print('✅ Current folder tracking verified');
    });
  });

  group('EmailScanProvider - Summary Generation', () {
    late EmailScanProvider provider;

    setUp(() {
      provider = EmailScanProvider();
    });

    test('getSummary should return correct summary map', () {
      provider.initializeScanMode(mode: ScanMode.testAll);
      provider.startScan(totalEmails: 20);

      // Add various results
      for (int i = 0; i < 5; i++) {
        _recordSimpleResult(provider, EmailActionType.delete, 'spam$i@example.com');
      }
      for (int i = 0; i < 3; i++) {
        _recordSimpleResult(provider, EmailActionType.moveToJunk, 'move$i@example.com');
      }
      for (int i = 0; i < 4; i++) {
        _recordSimpleResult(provider, EmailActionType.safeSender, 'safe$i@example.com');
      }
      for (int i = 0; i < 6; i++) {
        _recordSimpleResult(provider, EmailActionType.none, 'norule$i@example.com');
      }

      // Add an error (need to call updateProgress first to increment processedCount)
      final errorEmail = _createEmail('error@example.com', 'Error Email');
      provider.updateProgress(email: errorEmail, message: 'Processing: Error Email');
      provider.recordResult(EmailActionResult(
        email: errorEmail,
        action: EmailActionType.delete,
        success: false,
        error: 'Network error',
      ));

      provider.completeScan();

      final summary = provider.getSummary();

      expect(summary['total_emails'], equals(20));
      expect(summary['processed'], equals(19));
      // Note: deleted count includes the error result since action was EmailActionType.delete
      expect(summary['deleted'], equals(6));  // 5 successful + 1 failed
      expect(summary['moved'], equals(3));
      expect(summary['safe_senders'], equals(4));
      expect(summary['errors'], equals(1));
      expect(summary['status'], equals('ScanStatus.completed'));

      print('✅ Summary generation verified:');
      print('   $summary');
    });
  });

  group('EmailScanProvider - Provider Junk Folders Configuration', () {
    test('JUNK_FOLDERS_BY_PROVIDER should have correct folders for AOL', () {
      final aolFolders = EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER['aol'];

      expect(aolFolders, isNotNull);
      expect(aolFolders, contains('Bulk Mail'));
      expect(aolFolders, contains('Spam'));

      print('✅ AOL junk folders: $aolFolders');
    });

    test('JUNK_FOLDERS_BY_PROVIDER should have correct folders for Gmail', () {
      final gmailFolders = EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER['gmail'];

      expect(gmailFolders, isNotNull);
      expect(gmailFolders, contains('Spam'));
      expect(gmailFolders, contains('Trash'));

      print('✅ Gmail junk folders: $gmailFolders');
    });

    test('JUNK_FOLDERS_BY_PROVIDER should have correct folders for Yahoo', () {
      final yahooFolders = EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER['yahoo'];

      expect(yahooFolders, isNotNull);
      expect(yahooFolders, contains('Bulk'));
      expect(yahooFolders, contains('Spam'));

      print('✅ Yahoo junk folders: $yahooFolders');
    });

    test('JUNK_FOLDERS_BY_PROVIDER should have correct folders for Outlook', () {
      final outlookFolders = EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER['outlook'];

      expect(outlookFolders, isNotNull);
      expect(outlookFolders, contains('Junk Email'));
      expect(outlookFolders, contains('Spam'));

      print('✅ Outlook junk folders: $outlookFolders');
    });

    test('JUNK_FOLDERS_BY_PROVIDER should have correct folders for iCloud', () {
      final icloudFolders = EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER['icloud'];

      expect(icloudFolders, isNotNull);
      expect(icloudFolders, contains('Junk'));
      expect(icloudFolders, contains('Trash'));

      print('✅ iCloud junk folders: $icloudFolders');
    });
  });
}

/// Helper function to record a simple result
///
/// Mirrors the actual workflow: updateProgress() then recordResult()
void _recordSimpleResult(
  EmailScanProvider provider,
  EmailActionType action,
  String from, {
  String folderName = 'Inbox',
}) {
  final email = _createEmail(from, 'Test Subject', folderName: folderName);

  // First update progress (like the real scanner does)
  provider.updateProgress(email: email, message: 'Processing: Test Subject');

  EvaluationResult? evalResult;
  if (action != EmailActionType.none) {
    evalResult = EvaluationResult(
      shouldDelete: action == EmailActionType.delete,
      shouldMove: action == EmailActionType.moveToJunk,
      matchedRule: 'TestRule',
      matchedPattern: 'test-pattern',
    );
  }

  // Then record the result
  provider.recordResult(EmailActionResult(
    email: email,
    evaluationResult: evalResult,
    action: action,
    success: true,
  ));
}

/// Counter used to generate deterministic unique email IDs for tests.
int _emailIdCounter = 0;

/// Helper function to create an email message
EmailMessage _createEmail(String from, String subject, {String folderName = 'Inbox'}) {
  final id = 'test-email-${_emailIdCounter++}';
  return EmailMessage(
    id: id,
    from: from,
    subject: subject,
    body: 'Test body content',
    headers: {'from': from},
    receivedDate: DateTime.now(),
    folderName: folderName,
  );
}
