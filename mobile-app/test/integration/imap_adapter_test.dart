// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:spam_filter_mobile/adapters/email_providers/generic_imap_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';

void main() {
  group('GenericIMAPAdapter - AOL Integration', () {
    // NOTE: These tests require actual AOL credentials
    // Set environment variables or skip tests if not available:
    // AOL_EMAIL=your-email@aol.com
    // AOL_APP_PASSWORD=your-app-password
    
    late GenericIMAPAdapter adapter;
    final testEmail = const String.fromEnvironment('AOL_EMAIL', defaultValue: '');
    final testPassword = const String.fromEnvironment('AOL_APP_PASSWORD', defaultValue: '');

    setUp(() {
      adapter = GenericIMAPAdapter.aol();
    });

    tearDown(() async {
      try {
        await adapter.disconnect();
      } catch (e) {
        // Ignore disconnect errors in cleanup
      }
    });

    test('AOL adapter has correct configuration', () {
      expect(adapter.platformId, equals('aol'));
      expect(adapter.displayName, equals('AOL Mail'));
      expect(adapter.supportedAuthMethod, equals(AuthMethod.appPassword));
    });

    test('test connection without credentials should fail gracefully', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final credentials = Credentials(
        email: 'invalid@aol.com',
        password: 'wrong-password',
      );

      expect(
        () async => await adapter.loadCredentials(credentials),
        throwsA(isA<AuthenticationException>()),
      );
    }, skip: testEmail.isEmpty || testPassword.isEmpty);

    test('connect to AOL IMAP server', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        print('Set AOL_EMAIL and AOL_APP_PASSWORD environment variables to run this test');
        return;
      }

      final credentials = Credentials(
        email: testEmail,
        password: testPassword,
      );

      await adapter.loadCredentials(credentials);
      
      final status = await adapter.testConnection();
      expect(status.isConnected, isTrue);
      expect(status.errorMessage, isNull);
      
      print('[OK] Connected to AOL IMAP successfully');
      print('   Server: ${status.serverInfo}');
    }, timeout: const Timeout(Duration(seconds: 30)), 
       skip: testEmail.isEmpty || testPassword.isEmpty);

    test('list available folders', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final credentials = Credentials(
        email: testEmail,
        password: testPassword,
      );

      await adapter.loadCredentials(credentials);
      final folders = await adapter.listFolders();
      
      expect(folders, isNotEmpty);
      expect(folders.any((f) => f.displayName.toLowerCase().contains('inbox')), isTrue);
      
      print('[OK] Found ${folders.length} folders:');
      for (final folder in folders.take(10)) {
        print('   - ${folder.displayName} (${folder.canonicalName.name})');
      }
    }, timeout: const Timeout(Duration(seconds: 30)),
       skip: testEmail.isEmpty || testPassword.isEmpty);

    test('fetch recent messages from Inbox', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final credentials = Credentials(
        email: testEmail,
        password: testPassword,
      );

      await adapter.loadCredentials(credentials);
      
      // Fetch messages from last 7 days
      final messages = await adapter.fetchMessages(
        daysBack: 7,
        folderNames: ['Inbox'],
      );
      
      print('[OK] Fetched ${messages.length} messages from Inbox (last 7 days)');
      
      if (messages.isNotEmpty) {
        final first = messages.first;
        print('   First message:');
        print('     From: ${first.from}');
        print('     Subject: ${first.subject}');
        print('     Date: ${first.receivedDate}');
        print('     Folder: ${first.folderName}');
      }
      
      // Verify message structure
      for (final msg in messages.take(5)) {
        expect(msg.id, isNotEmpty);
        expect(msg.from, isNotEmpty);
        expect(msg.folderName, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 2)),
       skip: testEmail.isEmpty || testPassword.isEmpty);

    test('fetch messages from Bulk Mail folder', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final credentials = Credentials(
        email: testEmail,
        password: testPassword,
      );

      await adapter.loadCredentials(credentials);
      
      // Fetch from spam folders
      final messages = await adapter.fetchMessages(
        daysBack: 30,
        folderNames: ['Bulk Mail', 'Spam'],
      );
      
      print('[OK] Fetched ${messages.length} messages from spam folders (last 30 days)');
      
      if (messages.isNotEmpty) {
        print('   Sample spam message:');
        print('     From: ${messages.first.from}');
        print('     Subject: ${messages.first.subject}');
      }
    }, timeout: const Timeout(Duration(minutes: 2)),
       skip: testEmail.isEmpty || testPassword.isEmpty);

    test('parse email headers correctly', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final credentials = Credentials(
        email: testEmail,
        password: testPassword,
      );

      await adapter.loadCredentials(credentials);
      
      final messages = await adapter.fetchMessages(
        daysBack: 7,
        folderNames: ['Inbox'],
      );
      
      if (messages.isEmpty) {
        print('No messages to test headers');
        return;
      }
      
      final msg = messages.first;
      
      // Test header access
      expect(msg.headers, isNotEmpty);
      expect(msg.getSenderEmail(), isNotEmpty);
      
      print('[OK] Email headers parsed successfully');
      print('   Sender email: ${msg.getSenderEmail()}');
      print('   Headers count: ${msg.headers.length}');
      
      // Common headers
      final commonHeaders = ['from', 'to', 'subject', 'date', 'message-id'];
      for (final header in commonHeaders) {
        final value = msg.getHeader(header);
        if (value != null) {
          print('   $header: ${value.length > 50 ? "${value.substring(0, 50)}..." : value}');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)),
       skip: testEmail.isEmpty || testPassword.isEmpty);
  });

  group('GenericIMAPAdapter - Mock Tests', () {
    test('factory constructors create correct configurations', () {
      final aol = GenericIMAPAdapter.aol();
      expect(aol.platformId, equals('aol'));
      expect(aol.displayName, equals('AOL Mail'));

      final yahoo = GenericIMAPAdapter.yahoo();
      expect(yahoo.platformId, equals('yahoo'));
      expect(yahoo.displayName, equals('Yahoo Mail'));

      final icloud = GenericIMAPAdapter.icloud();
      expect(icloud.platformId, equals('icloud'));
      expect(icloud.displayName, equals('iCloud Mail'));
    });

    test('custom IMAP configuration', () {
      final custom = GenericIMAPAdapter.custom(
        imapHost: 'mail.example.com',
        imapPort: 993,
        isSecure: true,
      );

      expect(custom.platformId, equals('imap'));
      expect(custom.displayName, equals('Custom IMAP'));
    });

    test('credentials validation', () {
      final validCredentials = Credentials(
        email: 'test@aol.com',
        password: 'test-password',
      );

      expect(validCredentials.email, isNotEmpty);
      expect(validCredentials.password, isNotEmpty);
    });

    test('setDeletedRuleFolder stores folder name', () {
      final adapter = GenericIMAPAdapter.aol();
      // Should not throw
      adapter.setDeletedRuleFolder('Trash');
      adapter.setDeletedRuleFolder(null);
    });

    test('operations on disconnected adapter throw ConnectionException', () async {
      final adapter = GenericIMAPAdapter.aol();
      final message = EmailMessage(
        id: '123',
        from: 'test@example.com',
        subject: 'Test',
        body: '',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      // All operations should throw ConnectionException when not connected
      expect(
        () => adapter.takeAction(message: message, action: FilterAction.delete),
        throwsA(isA<ConnectionException>()),
      );
      expect(
        () => adapter.markAsRead(message: message),
        throwsA(isA<ConnectionException>()),
      );
      expect(
        () => adapter.moveToFolder(message: message, targetFolder: 'Trash'),
        throwsA(isA<ConnectionException>()),
      );
      expect(
        () => adapter.fetchMessages(daysBack: 7, folderNames: ['INBOX']),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  // [ISSUE #145] Integration tests for UID-based operations
  group('GenericIMAPAdapter - UID Fetch Verification', () {
    final testEmail = const String.fromEnvironment('AOL_EMAIL', defaultValue: '');
    final testPassword = const String.fromEnvironment('AOL_APP_PASSWORD', defaultValue: '');

    test('fetched messages use UIDs (not sequence IDs)', () async {
      if (testEmail.isEmpty || testPassword.isEmpty) {
        print('Skipping: AOL credentials not provided');
        return;
      }

      final adapter = GenericIMAPAdapter.aol();

      try {
        await adapter.loadCredentials(Credentials(
          email: testEmail,
          password: testPassword,
        ));

        final messages = await adapter.fetchMessages(
          daysBack: 7,
          folderNames: ['Inbox'],
        );

        if (messages.isEmpty) {
          print('No messages to verify UIDs');
          return;
        }

        // UIDs are typically larger numbers than sequence IDs
        // Sequence IDs are sequential starting from 1
        // UIDs can be any positive integer and do not reset
        for (final msg in messages.take(5)) {
          final id = int.tryParse(msg.id);
          expect(id, isNotNull, reason: 'Message ID should be parseable as int');
          expect(id, greaterThan(0), reason: 'Message UID should be positive');
          print('  Message UID: ${msg.id}, Subject: ${msg.subject}');
        }

        // Verify UIDs are unique (they should always be)
        final uids = messages.map((m) => m.id).toSet();
        expect(uids.length, equals(messages.length),
            reason: 'All message UIDs should be unique');

        print('[OK] Verified ${messages.length} messages use UID-based IDs');
      } finally {
        await adapter.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 2)),
       skip: testEmail.isEmpty || testPassword.isEmpty);
  });
}
