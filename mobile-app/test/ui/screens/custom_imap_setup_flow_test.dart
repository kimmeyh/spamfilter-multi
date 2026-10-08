/// F192 + SEC-15 (Sprint 77): a user can reach the Custom IMAP form through the
/// REAL provider picker and use it.
///
/// Path under test (the user-reachable control): Add account picker > "Custom
/// IMAP Server" > setup box > Continue > the server form > Test Connection >
/// Save. Nothing here pumps `AccountSetupScreen` directly: every test starts at
/// `PlatformSelectionScreen`, so a tile that is filtered out, a setup box that
/// does not lead to the form, or a form that does not carry its fields all fail.
///
/// The adapter behind the 'imap' platform id is a recording subclass
/// (`PlatformRegistry.overrideFactoryForTest`), so the test asserts exactly
/// what the form handed to `loadCredentials`. Secure storage is an in-memory
/// map behind the plugin channel, so Save is asserted on the stored keys.
///
/// OS behavior assumed identical on Windows and Android (ADR-0042): none here.
/// This is shared Flutter UI; widget tests run the same code both platforms run.
///
/// What these tests do NOT catch: a real TLS handshake or server (the adapter
/// test with real sockets covers those), the on-screen keyboard, and layout on
/// a phone-sized screen.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/ui/utils/credential_labels.dart';
import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';
import 'package:my_email_spam_filter/core/security/imap_host_policy.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';
import 'package:my_email_spam_filter/ui/screens/platform_selection_screen.dart';

import '../../helpers/database_test_helper.dart';

/// Records what the form passes to the adapter; opens no socket.
class _RecordingAdapter extends GenericIMAPAdapter {
  _RecordingAdapter() : super(imapHost: '', platformId: 'imap');

  final List<Credentials> loaded = [];
  ConnectionStatus status = ConnectionStatus.success();
  Object? loadError;

  /// SEC-8b: errors thrown by successive loadCredentials calls, first first.
  /// When empty, [loadError] applies.
  final List<Object> loadErrorQueue = [];

  /// SEC-8b: what the Save certificate check returns or throws.
  final List<Credentials> probed = [];
  Object? probeError;
  ServerCertificateInfo? probeResult;

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    loaded.add(credentials);
    if (loadErrorQueue.isNotEmpty) throw loadErrorQueue.removeAt(0);
    if (loadError != null) throw loadError!;
  }

  @override
  Future<ServerCertificateInfo> probeServerCertificate(
      Credentials credentials) async {
    probed.add(credentials);
    if (probeError != null) throw probeError!;
    if (probeResult != null) return probeResult!;
    throw const SocketException('offline in this test');
  }

  @override
  Future<ConnectionStatus> testConnection() async => status;

  @override
  Future<void> disconnect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final stored = <String, String>{};
  late _RecordingAdapter adapter;
  late SpamFilterPlatform Function()? previousFactory;
  late DatabaseTestHelper db;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    stored.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return stored[args['key']];
        case 'write':
          stored[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          stored.remove(args['key']);
          return null;
        case 'readAll':
          return Map<String, String>.from(stored);
      }
      return null;
    });
    adapter = _RecordingAdapter();
    previousFactory = PlatformRegistry.overrideFactoryForTest('imap', () => adapter);
    db = DatabaseTestHelper();
    await db.setUp();
  });

  tearDown(() async {
    PlatformRegistry.overrideFactoryForTest('imap', previousFactory);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.tearDown();
  });

  Future<void> openCustomImapForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmailScanProvider()),
        ChangeNotifierProvider(create: (_) => RuleSetProvider()),
      ],
      child: const MaterialApp(home: PlatformSelectionScreen()),
    ));
    await tester.pump();

    // 1. The tile is in the picker.
    expect(find.text('Custom IMAP Server'), findsOneWidget);
    await tester.tap(find.text('Custom IMAP Server'));
    await tester.pumpAndSettle();

    // 2. The setup box describes THIS provider, not an app-password flow.
    expect(find.text('Custom IMAP Server Setup'), findsOneWidget);
    expect(find.textContaining('generate an app password'), findsNothing);
    expect(find.textContaining('find these details from your email provider'),
        findsOneWidget);
    await tester.tap(find.text('I have my server details and password ready'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 3. The server form is on screen.
    expect(find.byKey(const Key('custom_imap_host')), findsOneWidget);
    expect(find.byKey(const Key('custom_imap_port')), findsOneWidget);
    expect(find.byKey(const Key('custom_imap_encryption')), findsOneWidget);
    expect(find.byKey(const Key('custom_imap_username')), findsOneWidget);
  }

  Future<void> fill(WidgetTester tester, {
    String host = 'imap.example.com',
    String email = 'person@example.com',
    String password = 'a-long-enough-password',
  }) async {
    await tester.enterText(find.byKey(const Key('custom_imap_host')), host);
    await tester.enterText(find.widgetWithText(TextField, 'Email Address'), email);
    // By the hidden-text setting, not the label: the label follows the server
    // name (MV-Q8, "App Password" for imap.mail.yahoo.com).
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        password);
    await tester.pump();
  }

  Future<void> tapTest(WidgetTester tester) async {
    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();
  }

  /// Taps Save and lets the real async work finish. `pumpAndSettle` cannot be
  /// used here: while Save runs, its button shows a spinner that never settles.
  /// A save that goes through writes the keys, then opens the Manual Scan
  /// screen (a different feature); the tree is replaced afterwards so nothing
  /// from that screen outlives the test.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save Credentials & Continue'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> endTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
  }

  testWidgets('the form starts on SSL/TLS with port 993 and a Password label',
      (tester) async {
    await openCustomImapForm(tester);

    expect(find.text('SSL/TLS'), findsOneWidget);
    expect(find.text('STARTTLS'), findsOneWidget);
    expect(find.text('Plain'), findsNothing,
        reason: 'there is no plaintext choice');
    expect(find.text('None'), findsNothing);
    final port = tester.widget<TextField>(find.byKey(const Key('custom_imap_port')));
    expect(port.controller!.text, '993');
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'App Password'), findsNothing);
  });

  // MV-Q8 (Harold, 2026-10-07, option 1): the label follows the server name
  // as it is typed; an unknown server shows the hint. What this does NOT
  // catch: the account LIST label (auth_method_label_test.dart source gate).
  testWidgets('the password label follows the server name (MV-Q8)',
      (tester) async {
    await openCustomImapForm(tester);
    final host = find.byKey(const Key('custom_imap_host'));

    await tester.enterText(host, 'imap.mail.yahoo.com');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'App Password'), findsOneWidget);
    expect(find.text(kCustomImapPasswordHint), findsNothing);

    await tester.enterText(host, 'mail.example.com');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'App Password'), findsNothing);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.text(kCustomImapPasswordHint), findsOneWidget);
  });

  testWidgets('choosing STARTTLS moves the port to 143 unless the user typed one',
      (tester) async {
    await openCustomImapForm(tester);

    await tester.tap(find.text('STARTTLS'));
    await tester.pump();
    var port = tester.widget<TextField>(find.byKey(const Key('custom_imap_port')));
    expect(port.controller!.text, '143');

    await tester.enterText(find.byKey(const Key('custom_imap_port')), '1143');
    await tester.tap(find.text('SSL/TLS'));
    await tester.pump();
    port = tester.widget<TextField>(find.byKey(const Key('custom_imap_port')));
    expect(port.controller!.text, '1143', reason: 'a typed port is kept');
  });

  testWidgets('a blank server name blocks Test Connection and Save, no adapter call',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester, host: '');

    await tapTest(tester);
    expect(find.text(ImapHostPolicy.emptyMessage), findsOneWidget);
    expect(adapter.loaded, isEmpty);

    await tapSave(tester);
    expect(adapter.loaded, isEmpty);
    expect(stored, isEmpty, reason: 'nothing saved without a server');
  });

  testWidgets('a malformed server name (with a port) is refused with a field message',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester, host: 'imap.example.com:993');

    await tapTest(tester);
    expect(find.text(ImapHostPolicy.malformedMessage), findsOneWidget);
    expect(adapter.loaded, isEmpty);
  });

  testWidgets('a bad port is refused with a field message', (tester) async {
    await openCustomImapForm(tester);
    await fill(tester);
    await tester.enterText(find.byKey(const Key('custom_imap_port')), '99999');

    await tapTest(tester);
    expect(find.text('Enter a port number from 1 to 65535.'), findsOneWidget);
    expect(adapter.loaded, isEmpty);
  });

  testWidgets('Test Connection hands the adapter exactly the form values',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester);
    await tester.tap(find.text('STARTTLS'));
    await tester.pump();

    await tapTest(tester);

    expect(adapter.loaded, hasLength(1));
    final creds = adapter.loaded.single;
    expect(creds.email, 'person@example.com');
    expect(creds.password, 'a-long-enough-password');
    final settings = CustomImapSettings.tryFromParams(creds.additionalParams)!;
    expect(settings.host, 'imap.example.com');
    expect(settings.port, 143);
    expect(settings.encryption, ImapEncryption.startTls);
    expect(settings.username, 'person@example.com',
        reason: 'the Username field follows the email address by default');
    expect(find.text('[OK] Connection successful!'), findsOneWidget);
  });

  testWidgets('an edited Username is sent instead of the email address',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester);
    await tester.enterText(find.byKey(const Key('custom_imap_username')), 'jdoe');
    // Changing the email afterwards must NOT overwrite the typed username.
    await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'), 'other@example.com');
    await tester.pump();

    await tapTest(tester);

    final settings =
        CustomImapSettings.tryFromParams(adapter.loaded.single.additionalParams)!;
    expect(settings.username, 'jdoe');
  });

  testWidgets('a failed connection shows a plain sentence, not an exception name',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester);
    adapter.loadError = UserFacingConnectionException(
      'STARTTLS upgrade failed: x',
      'The server did not accept a secure (STARTTLS) connection, so the app '
          'did not send your password.',
    );

    await tapTest(tester);

    expect(find.textContaining('did not send your password'), findsWidgets);
    expect(find.textContaining('ConnectionException'), findsNothing);
  });

  group('local or private server address (SEC-15, Sprint 77 Q2)', () {
    testWidgets('warns ONCE, allows continuing, and does not ask again',
        (tester) async {
      await openCustomImapForm(tester);
      await fill(tester, host: '192.168.1.10');

      // First attempt: the warning appears. Cancel stops everything.
      await tapTest(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(adapter.loaded, isEmpty, reason: 'declining must not connect');

      // Second attempt: Continue goes ahead.
      await tapTest(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(adapter.loaded, hasLength(1));

      // Third attempt AND Save: already accepted, no second warning.
      await tapTest(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsNothing);
      expect(adapter.loaded, hasLength(2));
      await tapSave(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsNothing);
      expect(stored['credentials_person@example.com_imapHost'], '192.168.1.10');
      await endTest(tester);
    });

    testWidgets('the warning also guards Save when Test Connection was skipped',
        (tester) async {
      await openCustomImapForm(tester);
      await fill(tester, host: 'localhost');

      await tapSave(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(stored, isEmpty, reason: 'declining must not save');
    });

    testWidgets('a public server name shows no warning', (tester) async {
      await openCustomImapForm(tester);
      await fill(tester, host: 'imap.mail.yahoo.com');

      await tapTest(tester);
      expect(find.text(ImapHostPolicy.localNetworkWarning), findsNothing);
      expect(adapter.loaded, hasLength(1));
    });
  });

  testWidgets('Save stores host, port, encryption and username beside the credentials',
      (tester) async {
    await openCustomImapForm(tester);
    await fill(tester);
    await tester.tap(find.text('STARTTLS'));
    await tester.pump();

    await tapSave(tester);

    const prefix = 'credentials_person@example.com_';
    expect(stored['${prefix}imapHost'], 'imap.example.com');
    expect(stored['${prefix}imapPort'], '143');
    expect(stored['${prefix}imapEncryption'], 'startTls');
    expect(stored['${prefix}imapUsername'], 'person@example.com');
    expect(stored['${prefix}platformId'], 'imap');
    await endTest(tester);
  });

  group('"Trust this server?" (SEC-8b, Sprint 77 Q4)', () {
    const fp = 'ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34ab12cd34';
    const otherFp =
        '0000000000000000000000000000000000000000000000000000000000000001';
    final cert = ServerCertificateInfo(
      sha256Hex: fp,
      subject: '/CN=mail.home.test',
      issuer: '/CN=mail.home.test',
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2036, 1, 1),
    );
    ServerCertificateNotTrustedException untrusted(
            {CertificateTrustProblem problem = CertificateTrustProblem.notTrusted}) =>
        ServerCertificateNotTrustedException(
            host: 'imap.example.com', port: 993, certificate: cert, problem: problem);

    String? trustedIn(Credentials c) =>
        c.additionalParams?[CustomImapSettings.keyTrustedCertSha256];

    testWidgets('Test Connection: the dialog shows fingerprint, subject, issuer '
        'and validity; Do Not Trust stops, Trust retries with that fingerprint',
        (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.loadErrorQueue.add(untrusted());

      await tapTest(tester);
      expect(find.text('Trust this server?'), findsOneWidget);
      expect(find.text(cert.displayFingerprint), findsOneWidget);
      expect(find.text('Issued to: /CN=mail.home.test'), findsOneWidget);
      expect(find.text('Issued by: /CN=mail.home.test (self-signed)'),
          findsOneWidget);
      expect(find.textContaining('Valid: 2026-01-01 to 2036-01-01'),
          findsOneWidget);
      await tester.tap(find.text('Do Not Trust'));
      await tester.pumpAndSettle();
      expect(adapter.loaded, hasLength(1), reason: 'declining must not retry');
      expect(trustedIn(adapter.loaded.single), isNull);

      adapter.loadErrorQueue.add(untrusted());
      await tapTest(tester);
      await tester.tap(find.text('Trust'));
      await tester.pumpAndSettle();
      expect(adapter.loaded, hasLength(3));
      expect(trustedIn(adapter.loaded[1]), isNull);
      expect(trustedIn(adapter.loaded[2]), fp,
          reason: 'the retry may accept ONLY the certificate the user saw');
      expect(find.text('[OK] Connection successful!'), findsOneWidget);
    });

    testWidgets('a changed certificate says so in the dialog', (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.loadErrorQueue
          .add(untrusted(problem: CertificateTrustProblem.changed));
      await tapTest(tester);
      expect(find.textContaining('is different from the one you trusted'),
          findsOneWidget);
      await tester.tap(find.text('Do Not Trust'));
      await tester.pumpAndSettle();
    });

    testWidgets('trust given to one server is not carried to another host',
        (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.loadErrorQueue.add(untrusted());
      await tapTest(tester);
      await tester.tap(find.text('Trust'));
      await tester.pumpAndSettle();
      expect(trustedIn(adapter.loaded.last), fp);

      await tester.enterText(
          find.byKey(const Key('custom_imap_host')), 'imap.other.test');
      await tester.pump();
      await tapTest(tester);
      expect(trustedIn(adapter.loaded.last), isNull);
    });

    testWidgets('Save: an untrusted certificate asks first; Trust stores its '
        'fingerprint with the account', (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.probeError = untrusted();

      await tester.tap(find.text('Save Credentials & Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.text('Trust this server?'), findsOneWidget);
      expect(stored, isEmpty, reason: 'nothing is saved before the answer');
      await tester.tap(find.text('Trust'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(adapter.probed, hasLength(1));
      expect(stored['credentials_person@example.com_imapTrustedCertSha256'], fp);
      await endTest(tester);
    });

    testWidgets('Save: Do Not Trust saves nothing', (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.probeError = untrusted();

      await tester.tap(find.text('Save Credentials & Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.tap(find.text('Do Not Trust'));
      await tester.pumpAndSettle();

      expect(stored, isEmpty);
      expect(find.textContaining('Not saved'), findsOneWidget);
    });

    // F-PRECHECK (Sprint 77 Phase 5.1.2): a catch-all used to save the
    // account after ANY failed check, so a server that refused STARTTLS was
    // saved as "Account saved" and every scan then failed. Only an unreachable
    // server may save (Save never required a connection).
    // What these do NOT catch: which exception a REAL socket raises for a
    // given server problem (the connector tests with real sockets cover that).
    for (final blocked in <(String, Object)>[
      (
        'STARTTLS refused',
        UserFacingConnectionException(
          'STARTTLS upgrade failed: NO',
          'The server did not accept a secure (STARTTLS) connection, so the '
              'app did not send your password.',
        )
      ),
      // What the real probe throws for a handshake failure (the adapter's
      // one mapping, proven against a real socket in
      // imap_certificate_trust_test.dart).
      (
        'TLS handshake failure',
        UserFacingConnectionException(
          'TLS certificate validation failed: bad record',
          'The server certificate could not be verified, so the app did not '
              'connect or send your password.',
        )
      ),
      ('a raw handshake exception', const HandshakeException('bad record')),
      ('an unexpected error', StateError('broken exchange')),
    ]) {
      testWidgets('Save: ${blocked.$1} blocks Save with the named reason',
          (tester) async {
        await openCustomImapForm(tester);
        await fill(tester);
        adapter.probeError = blocked.$2;

        await tapSave(tester);

        expect(stored, isEmpty, reason: '${blocked.$1} must not be saved');
        expect(find.textContaining('[FAIL] Not saved'), findsOneWidget);
        expect(find.textContaining('saved successfully'), findsNothing);
        if (blocked.$2 is UserFacingConnectionException) {
          // The named reason itself is on screen, not a generic sentence.
          expect(
              find.textContaining(
                  (blocked.$2 as UserFacingConnectionException).userMessage),
              findsOneWidget);
        }
        await endTest(tester);
      });
    }

    for (final offline in <(String, Object)>[
      ('no network', const SocketException('unreachable')),
      ('a timeout', TimeoutException('no answer')),
    ]) {
      testWidgets('Save: ${offline.$1} saves and says the certificate was not '
          'checked', (tester) async {
        await openCustomImapForm(tester);
        await fill(tester);
        adapter.probeError = offline.$2;

        await tapSave(tester);

        expect(stored['credentials_person@example.com_imapHost'],
            'imap.example.com');
        expect(stored['credentials_person@example.com_imapTrustedCertSha256'],
            isNull);
        // The SnackBar is shown on every Scaffold registered with the
        // messenger during the screen change, so it can appear more than once.
        expect(find.text(AccountSetupScreen.savedUncheckedMessage, skipOffstage: false),
            findsWidgets);
        await endTest(tester);
      });
    }

    testWidgets('Save: a certificate the device trusts is recorded without a '
        'question', (tester) async {
      await openCustomImapForm(tester);
      await fill(tester);
      adapter.probeResult = ServerCertificateInfo(
        sha256Hex: otherFp,
        subject: '/CN=imap.example.com',
        issuer: '/CN=Some Public CA',
        validFrom: DateTime(2026),
        validTo: DateTime(2027),
      );

      await tapSave(tester);

      expect(find.text('Trust this server?'), findsNothing);
      expect(stored['credentials_person@example.com_imapTrustedCertSha256'],
          otherFp);
      await endTest(tester);
    });
  });
}
