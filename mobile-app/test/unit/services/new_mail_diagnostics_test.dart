// Sprint 80 Task 17 (#505): the Android start-up diagnostic line for the
// new-mail trigger (R-2) and how the main screen was started (R-4).
//
// What these tests do NOT catch: whether Android binds the listener, delivers
// notifications, or reports the launch referrer on a real phone (the emulator
// rehearsal and the next Fold log pull cover that), and whether main.dart
// calls the logger (a source gate below pins the call only).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/new_mail_trigger.dart';

const _kotlinDir = 'android/app/src/main/kotlin/com/myemailspamfilter';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatDiagnostics', () {
    test('names every part, with times and the ignored app', () {
      final at = DateTime(2026, 10, 21, 23, 5).millisecondsSinceEpoch;
      final line = NewMailTrigger.formatDiagnostics({
        'accessGranted': true,
        'enabled': true,
        'componentState': 0,
        'connectedMs': at,
        'disconnectedMs': 0,
        'lastIgnored': '$at|com.aol.mobile.aolapp|switch off',
        'installedMailApps': ['com.aol.mobile.aolapp', 'com.google.android.gm'],
        'launch': 'action=android.intent.action.MAIN referrer=null taskRoot=true restored=false',
      });
      expect(line, contains('access=on flag=on component=default'));
      expect(line, contains('listenerConnected=2026-10-21T23:05:00.000'));
      expect(line, contains('listenerDisconnected=never'));
      expect(line,
          contains('lastIgnored=2026-10-21T23:05:00.000 com.aol.mobile.aolapp (switch off)'));
      expect(line, contains('mailApps=com.aol.mobile.aolapp,com.google.android.gm'));
      expect(line, contains('launch: action=android.intent.action.MAIN'));
    });

    test('a listener never bound and no mail app read as such', () {
      final line = NewMailTrigger.formatDiagnostics({
        'accessGranted': false,
        'enabled': false,
        'componentState': 2,
        'connectedMs': 0,
        'disconnectedMs': 0,
        'lastIgnored': null,
        'installedMailApps': <String>[],
        'launch': null,
      });
      expect(line, contains('access=off flag=off component=disabled'));
      expect(line, contains('listenerConnected=never'));
      expect(line, contains('lastIgnored=none'));
      expect(line, contains('mailApps=none'));
      expect(line, contains('launch: unknown'));
    });

    test('an unreadable snapshot says so instead of guessing', () {
      expect(NewMailTrigger.formatDiagnostics(null), 'diagnostics unavailable');
      expect(NewMailTrigger.formatDiagnostics({}),
          contains('access=unknown flag=unknown'));
    });

    // Sprint 81 F303 T-2 (AC-2). What this does NOT catch: whether the native
    // side really sends "error: ..." for a failing read on a phone (the Kotlin
    // JVM test covers the map, the Fold log covers the device).
    test('a field the phone could not read shows its error text', () {
      final line = NewMailTrigger.formatDiagnostics({
        'accessGranted': 'error: SecurityException: denied',
        'enabled': true,
        'componentState': 1,
        'connectedMs': 0,
        'disconnectedMs': 0,
        'lastIgnored': 'error: IllegalStateException: bad prefs',
        'installedMailApps': 'error: RuntimeException: pm died',
        'launch': 'action=MAIN',
      });
      expect(line, contains('access=error: SecurityException: denied'));
      expect(line, contains('flag=on component=enabled'));
      expect(line, contains('lastIgnored=error: IllegalStateException: bad prefs'));
      expect(line, contains('mailApps=error: RuntimeException: pm died'));
      expect(line, contains('launch: action=MAIN'));
      expect(line, contains('fieldErrors=3 ['));
      expect(line, contains('accessGranted: error: SecurityException: denied'));
      // A clean snapshot adds no error section.
      expect(NewMailTrigger.formatDiagnostics({'enabled': true}),
          isNot(contains('fieldErrors')));
    });

    test('a malformed ignored record is not invented', () {
      expect(NewMailTrigger.parseLastIgnored('nonsense'), isNull);
      expect(NewMailTrigger.parseLastIgnored('x|a|b'), isNull);
    });
  });

  test('diagnostics() reads the native channel and returns null on failure',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, (call) async {
      if (call.method == 'diagnostics') return {'accessGranted': true};
      throw PlatformException(code: 'x');
    });
    expect((await NewMailTrigger.diagnostics())!['accessGranted'], isTrue);
    expect(NewMailTrigger.lastDiagnosticsError, isNull);
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, (call) async {
      throw PlatformException(code: 'x', message: 'SecurityException: denied');
    });
    expect(await NewMailTrigger.diagnostics(), isNull);
    // PR #490 7.7.1: the cause is kept and reaches the line.
    expect(NewMailTrigger.lastDiagnosticsError, contains('SecurityException'));
    expect(
        NewMailTrigger.formatDiagnostics(null,
            error: NewMailTrigger.lastDiagnosticsError),
        startsWith('diagnostics unavailable -- PlatformException'));
    messenger.setMockMethodCallHandler(NewMailTrigger.channel, null);
  });

  group('source gates (SOURCE-TEXT VERIFIED: native code has no host runtime)', () {
    final policy = File('$_kotlinDir/MailNotificationPolicy.kt').readAsStringSync();
    final listener = File('$_kotlinDir/MailNotificationListener.kt').readAsStringSync();
    final activity = File('$_kotlinDir/MainActivity.kt').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('every accepted mail app is declared in <queries>, and only those', () {
      final block = RegExp(r'MAIL_APPS: Map<String, Set<String>\?> = mapOf\(([\s\S]*?)\n\s*\)')
          .firstMatch(policy)!
          .group(1)!;
      final mailApps =
          RegExp(r'"([a-z0-9_.]+)" to').allMatches(block).map((m) => m.group(1)).toSet();
      final queried = RegExp(r'<package android:name="([a-z0-9_.]+)"/>')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toSet();
      expect(mailApps, hasLength(5));
      expect(queried, mailApps,
          reason: 'Android 11+ hides an undeclared app: it would read as absent');
    });

    test('the listener records an ignored mail-app notification and its binds', () {
      expect(listener, contains('putString(KEY_LAST_IGNORED, "\$now|\$pkg|\$reason")'));
      expect(listener, contains('override fun onListenerConnected()'));
      expect(listener, contains('stamp(KEY_CONNECTED_MS)'));
      expect(listener, contains('override fun onListenerDisconnected()'));
    });

    test('the channel answers "diagnostics" and the activity captures its launch', () {
      expect(activity, contains('"diagnostics" ->'));
      expect(activity, contains('"launch" to { launchInfo }'));
      expect(activity, contains('DiagnosticsSnapshot.collect('),
          reason: 'F303: each field is read in its own guard');
      expect(activity, contains('override fun onCreate(savedInstanceState: Bundle?)'));
      final create = activity.indexOf('override fun onCreate');
      expect(activity.indexOf('launchInfo = try', create),
          lessThan(activity.indexOf('super.onCreate(savedInstanceState)', create)),
          reason: 'captured before the engine starts main()');
    });

    test('main.dart logs the snapshot at foreground start', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains("context: 'new-mail-diagnostics'"));
      expect(main, contains('NewMailTrigger.formatDiagnostics(await NewMailTrigger.diagnostics(),'));
      expect(main, contains('error: NewMailTrigger.lastDiagnosticsError'),
          reason: 'PR #490 7.7.1: the cause of a failed read reaches the log');
    });
  });
}
