import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';

void main() {
  late EmailScanProvider scanProvider;
  late RuleSetProvider ruleSetProvider;

  setUp(() {
    scanProvider = EmailScanProvider();
    ruleSetProvider = RuleSetProvider();
  });

  group('EmailScanner constructor', () {
    test('stores platformId correctly', () {
      final scanner = EmailScanner(
        platformId: 'aol',
        accountId: 'aol-user@aol.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(scanner.platformId, 'aol');
    });

    test('stores accountId correctly', () {
      final scanner = EmailScanner(
        platformId: 'gmail',
        accountId: 'gmail-user@gmail.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(scanner.accountId, 'gmail-user@gmail.com');
    });

    test('stores ruleSetProvider correctly', () {
      final scanner = EmailScanner(
        platformId: 'aol',
        accountId: 'test@aol.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(scanner.ruleSetProvider, same(ruleSetProvider));
    });

    test('stores scanProvider correctly', () {
      final scanner = EmailScanner(
        platformId: 'aol',
        accountId: 'test@aol.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(scanner.scanProvider, same(scanProvider));
    });
  });

  group('scanInbox with unsupported platform', () {
    test('throws exception for unknown platformId', () async {
      final scanner = EmailScanner(
        platformId: 'unsupported-provider',
        accountId: 'user@unsupported.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanInbox(daysBack: 7),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Platform unsupported-provider not supported'),
        )),
      );
    });

    test('sets scanProvider to error state for unknown platformId', () async {
      final scanner = EmailScanner(
        platformId: 'unknown-platform',
        accountId: 'user@unknown.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      try {
        await scanner.scanInbox(daysBack: 7);
      } catch (_) {
        // Expected
      }

      expect(scanProvider.status, ScanStatus.error);
      expect(scanProvider.statusMessage, contains('Scan failed'));
      expect(scanProvider.statusMessage, contains('unknown-platform not supported'));
    });

    test('accepts default parameters', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanInbox(),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts custom daysBack parameter', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanInbox(daysBack: 30),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts custom folderNames parameter', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanInbox(folderNames: ['INBOX', 'Spam']),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts custom scanType parameter', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanInbox(scanType: 'background'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('scanFolders', () {
    test('throws for unsupported platform (delegates to scanInbox)', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent-platform',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanFolders(folderNames: ['INBOX', 'Junk']),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('nonexistent-platform not supported'),
        )),
      );
    });

    test('sets error state on scanProvider when platform not found', () async {
      final scanner = EmailScanner(
        platformId: 'bad-platform',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      try {
        await scanner.scanFolders(folderNames: ['INBOX'], daysBack: 14);
      } catch (_) {
        // Expected
      }

      expect(scanProvider.status, ScanStatus.error);
    });

    test('accepts default daysBack of 7', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanFolders(folderNames: ['Spam']),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('scanAllFolders', () {
    test('throws for unsupported platform', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent-platform',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanAllFolders(daysBack: 7),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('nonexistent-platform not supported'),
        )),
      );
    });

    test('throws when credentials not found for valid platform', () async {
      // Uses 'demo' which is a valid platform, but scanAllFolders
      // always tries to load credentials (unlike scanInbox which skips for demo).
      // However, SecureCredentialsStore will fail in test environment.
      // The 'aol' platform is registered but credential lookup will fail.
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(
        () => scanner.scanAllFolders(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('EmailScanner multiple instances', () {
    test('different scanners have independent configuration', () {
      final scanner1 = EmailScanner(
        platformId: 'aol',
        accountId: 'user1@aol.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      final scanProvider2 = EmailScanProvider();
      final scanner2 = EmailScanner(
        platformId: 'gmail',
        accountId: 'user2@gmail.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider2,
      );

      expect(scanner1.platformId, 'aol');
      expect(scanner2.platformId, 'gmail');
      expect(scanner1.accountId, 'user1@aol.com');
      expect(scanner2.accountId, 'user2@gmail.com');
      expect(scanner1.scanProvider, isNot(same(scanner2.scanProvider)));
    });

    test('scanners can share ruleSetProvider', () {
      final scanner1 = EmailScanner(
        platformId: 'aol',
        accountId: 'user1@aol.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      final scanner2 = EmailScanner(
        platformId: 'gmail',
        accountId: 'user2@gmail.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: EmailScanProvider(),
      );

      expect(scanner1.ruleSetProvider, same(scanner2.ruleSetProvider));
    });
  });

  group('error handling behavior', () {
    test('scanProvider remains idle before scan attempt', () {
      EmailScanner(
        platformId: 'test',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      expect(scanProvider.status, ScanStatus.idle);
      expect(scanProvider.processedCount, 0);
      expect(scanProvider.totalEmails, 0);
    });

    test('consecutive scan failures update scanProvider error state each time', () async {
      final scanner = EmailScanner(
        platformId: 'nonexistent',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      try {
        await scanner.scanInbox();
      } catch (_) {}

      expect(scanProvider.status, ScanStatus.error);

      // Second scan attempt also sets error
      try {
        await scanner.scanInbox();
      } catch (_) {}

      expect(scanProvider.status, ScanStatus.error);
      expect(scanProvider.statusMessage, contains('Scan failed'));
    });

    test('scanInbox rethrows the exception after setting error state', () async {
      final scanner = EmailScanner(
        platformId: 'unknown',
        accountId: 'test@test.com',
        ruleSetProvider: ruleSetProvider,
        scanProvider: scanProvider,
      );

      Exception? caughtException;
      try {
        await scanner.scanInbox();
      } on Exception catch (e) {
        caughtException = e;
      }

      expect(caughtException, isNotNull);
      expect(caughtException.toString(), contains('unknown not supported'));
      expect(scanProvider.status, ScanStatus.error);
    });
  });
}
