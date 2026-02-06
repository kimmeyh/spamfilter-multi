import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';

void main() {
  late EmailScanProvider scanProvider;

  setUp(() {
    scanProvider = EmailScanProvider();
  });

  group('EmailScanProvider', () {
    test('initializes with idle status', () {
      expect(scanProvider.status, equals(ScanStatus.idle));
      expect(scanProvider.processedCount, equals(0));
      expect(scanProvider.totalEmails, equals(0));
      expect(scanProvider.progress, equals(0.0));
      expect(scanProvider.deletedCount, equals(0));
      expect(scanProvider.movedCount, equals(0));
    });

    test('starts scan correctly', () {
      // Arrange
      const totalEmails = 100;

      // Act
      scanProvider.startScan(totalEmails: totalEmails);

      // Assert
      expect(scanProvider.status, equals(ScanStatus.scanning));
      expect(scanProvider.totalEmails, equals(totalEmails));
      expect(scanProvider.processedCount, equals(0));
      expect(scanProvider.progress, equals(0.0));
    });

    test('updates progress correctly', () {
      // Arrange
      scanProvider.startScan(totalEmails: 100);
      final email = EmailMessage(
        id: '1',
        from: 'test@example.com',
        subject: 'Test',
        body: 'Test body',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      // Act
      scanProvider.updateProgress(email: email);

      // Assert
      expect(scanProvider.processedCount, equals(1));
      expect(scanProvider.currentEmail, equals(email));
      expect(scanProvider.progress, equals(0.01));
    });

    test('records result and updates counts', () {
      // Arrange
      scanProvider.initializeScanMode(mode: ScanMode.testAll); // Enable actual execution
      scanProvider.startScan(totalEmails: 100);
      final email = EmailMessage(
        id: '1',
        from: 'spam@example.com',
        subject: 'Spam',
        body: 'Spam body',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final result = EmailActionResult(
        email: email,
        action: EmailActionType.delete,
        success: true,
      );

      // Act
      scanProvider.recordResult(result);

      // Assert
      expect(scanProvider.deletedCount, equals(1));
      expect(scanProvider.results.length, equals(1));
    });

    test('pauses and resumes scan', () {
      // Arrange
      scanProvider.startScan(totalEmails: 100);

      // Act
      scanProvider.pauseScan();

      // Assert
      expect(scanProvider.status, equals(ScanStatus.paused));

      // Resume
      scanProvider.resumeScan();
      expect(scanProvider.status, equals(ScanStatus.scanning));
    });

    test('completes scan successfully', () {
      // Arrange
      scanProvider.initializeScanMode(mode: ScanMode.testAll); // Enable actual execution
      scanProvider.startScan(totalEmails: 100);
      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'spam@example.com',
          subject: 'Spam',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      // Act
      scanProvider.completeScan();

      // Assert
      expect(scanProvider.status, equals(ScanStatus.completed));
      expect(scanProvider.currentEmail, isNull);
      expect(scanProvider.statusMessage, isNotEmpty);
    });

    test('handles scan error', () {
      // Arrange
      scanProvider.startScan(totalEmails: 100);
      const errorMessage = 'Connection timeout';

      // Act
      scanProvider.errorScan(errorMessage);

      // Assert
      expect(scanProvider.status, equals(ScanStatus.error));
      expect(scanProvider.statusMessage, contains(errorMessage));
      expect(scanProvider.currentEmail, isNull);
    });

    test('resets scan state', () {
      // Arrange
      scanProvider.initializeScanMode(mode: ScanMode.testAll); // Enable actual execution
      scanProvider.startScan(totalEmails: 100);
      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'test@example.com',
          subject: 'Test',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      // Act
      scanProvider.reset();

      // Assert
      expect(scanProvider.status, equals(ScanStatus.idle));
      expect(scanProvider.processedCount, equals(0));
      expect(scanProvider.totalEmails, equals(0));
      expect(scanProvider.deletedCount, equals(0));
      expect(scanProvider.results, isEmpty);
    });

    test('generates summary correctly', () {
      // Arrange
      scanProvider.initializeScanMode(mode: ScanMode.testAll); // Enable actual execution
      scanProvider.startScan(totalEmails: 100);
      for (int i = 0; i < 50; i++) {
        scanProvider.recordResult(EmailActionResult(
          email: EmailMessage(
            id: '$i',
            from: 'spam$i@example.com',
            subject: 'Spam',
            body: '',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: 'INBOX',
          ),
          action: EmailActionType.delete,
          success: true,
        ));
      }
      scanProvider.completeScan();

      // Act
      final summary = scanProvider.getSummary();

      // Assert
      expect(summary['total_emails'], equals(100));
      expect(summary['deleted'], equals(50));
      expect(summary['status'], contains('completed'));
    });

    test('categorizes results by action type', () {
      // Arrange
      scanProvider.initializeScanMode(mode: ScanMode.testAll); // Enable actual execution
      scanProvider.startScan(totalEmails: 100);

      // Act
      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'spam@example.com',
          subject: 'Spam',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.delete,
        success: true,
      ));

      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '2',
          from: 'bulk@example.com',
          subject: 'Bulk',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.moveToJunk,
        success: true,
      ));

      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '3',
          from: 'friend@example.com',
          subject: 'Hi',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.safeSender,
        success: true,
      ));

      // Assert
      expect(scanProvider.deletedCount, equals(1));
      expect(scanProvider.movedCount, equals(1));
      expect(scanProvider.safeSendersCount, equals(1));
    });

    test('tracks errors in results', () {
      // Arrange
      scanProvider.startScan(totalEmails: 100);

      // Act
      scanProvider.recordResult(EmailActionResult(
        email: EmailMessage(
          id: '1',
          from: 'test@example.com',
          subject: 'Test',
          body: '',
          headers: {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        action: EmailActionType.delete,
        success: false,
        error: 'Permission denied',
      ));

      // Assert
      expect(scanProvider.errorCount, equals(1));
      expect(scanProvider.results.first.error, equals('Permission denied'));
    });
  });

  // ✨ ISSUE #41: Per-account folder selection tests
  group('EmailScanProvider - Per-Account Folders (Issue #41)', () {
    test('stores folders per account', () {
      // Arrange
      const account1 = 'gmail-user1@gmail.com';
      const account2 = 'aol-user2@aol.com';
      
      // Act
      scanProvider.setCurrentAccount(account1);
      scanProvider.setSelectedFolders(['INBOX', 'SPAM', 'CATEGORY_PROMOTIONS'], accountId: account1);
      
      scanProvider.setCurrentAccount(account2);
      scanProvider.setSelectedFolders(['INBOX', 'Bulk Mail'], accountId: account2);
      
      // Assert - each account has its own folders
      expect(scanProvider.getSelectedFoldersForAccount(account1), 
          equals(['INBOX', 'SPAM', 'CATEGORY_PROMOTIONS']));
      expect(scanProvider.getSelectedFoldersForAccount(account2), 
          equals(['INBOX', 'Bulk Mail']));
    });

    test('returns INBOX as default for unknown account', () {
      expect(scanProvider.getSelectedFoldersForAccount('unknown-account'), 
          equals(['INBOX']));
    });

    test('selectedFolders getter uses current account', () {
      // Arrange
      const account1 = 'gmail-user@gmail.com';
      scanProvider.setCurrentAccount(account1);
      scanProvider.setSelectedFolders(['SPAM', 'Trash'], accountId: account1);
      
      // Assert
      expect(scanProvider.selectedFolders, equals(['SPAM', 'Trash']));
    });

    test('selectedFolders returns INBOX when no current account', () {
      // No account set
      expect(scanProvider.selectedFolders, equals(['INBOX']));
    });

    test('switching accounts changes selectedFolders', () {
      // Arrange
      const gmailAccount = 'gmail-user@gmail.com';
      const aolAccount = 'aol-user@aol.com';
      
      scanProvider.setCurrentAccount(gmailAccount);
      scanProvider.setSelectedFolders(['SPAM', 'CATEGORY_SOCIAL'], accountId: gmailAccount);
      
      scanProvider.setCurrentAccount(aolAccount);
      scanProvider.setSelectedFolders(['Bulk Mail'], accountId: aolAccount);
      
      // Act & Assert - switch to Gmail
      scanProvider.setCurrentAccount(gmailAccount);
      expect(scanProvider.selectedFolders, equals(['SPAM', 'CATEGORY_SOCIAL']));
      
      // Act & Assert - switch to AOL
      scanProvider.setCurrentAccount(aolAccount);
      expect(scanProvider.selectedFolders, equals(['Bulk Mail']));
    });

    test('clearSelectedFoldersForAccount removes folders for specific account only', () {
      // Arrange
      const account1 = 'gmail-user@gmail.com';
      const account2 = 'aol-user@aol.com';
      
      scanProvider.setCurrentAccount(account1);
      scanProvider.setSelectedFolders(['SPAM'], accountId: account1);
      scanProvider.setCurrentAccount(account2);
      scanProvider.setSelectedFolders(['Bulk Mail'], accountId: account2);
      
      // Act
      scanProvider.clearSelectedFoldersForAccount(account1);
      
      // Assert - account1 cleared, account2 retained
      expect(scanProvider.getSelectedFoldersForAccount(account1), equals(['INBOX']));
      expect(scanProvider.getSelectedFoldersForAccount(account2), equals(['Bulk Mail']));
    });

    test('empty folder list defaults to INBOX', () {
      // Arrange
      const account = 'test-account';
      scanProvider.setCurrentAccount(account);
      
      // Act
      scanProvider.setSelectedFolders([], accountId: account);
      
      // Assert
      expect(scanProvider.getSelectedFoldersForAccount(account), equals(['INBOX']));
    });
  });
}
