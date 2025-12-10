import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/adapters/email_providers/generic_imap_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';

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
      
      print('✅ Connected to AOL IMAP successfully');
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
      
      print('✅ Found ${folders.length} folders:');
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
      
      print('✅ Fetched ${messages.length} messages from Inbox (last 7 days)');
      
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
      
      print('✅ Fetched ${messages.length} messages from spam folders (last 30 days)');
      
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
      
      print('✅ Email headers parsed successfully');
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
  });
}
