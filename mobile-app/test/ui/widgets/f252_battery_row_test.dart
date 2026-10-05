/// F252 (Sprint 76): Settings > Background > "Keep background scans running".
///
/// What this does NOT catch: whether Android's App info page really offers
/// Battery > Unrestricted on a given phone, or Samsung's menu names (checked on
/// the Fold at Manual Validation); and the row's PLACEMENT in Settings, which
/// is behind `Platform.isAndroid` and is pinned by a source gate below.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/android_battery_status.dart';
import 'package:my_email_spam_filter/ui/widgets/battery_optimization_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late Object? unrestricted;

  setUp(() {
    calls = [];
    unrestricted = false;
    messenger.setMockMethodCallHandler(AndroidBatteryStatus.channel,
        (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isIgnoringBatteryOptimizations':
          return unrestricted;
        case 'openAppSettings':
          return true;
      }
      return null;
    });
  });

  tearDown(() =>
      messenger.setMockMethodCallHandler(AndroidBatteryStatus.channel, null));

  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BatteryOptimizationRow())));
    await tester.pump();
  }

  String statusText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('battery_optimization_status')))
      .data!;

  testWidgets('Optimized: says so, gives the steps, offers the button',
      (tester) async {
    await pumpRow(tester);
    expect(statusText(tester), startsWith('Battery: Optimized.'));
    expect(find.textContaining('Never sleeping apps'), findsOneWidget);
    expect(find.byKey(const Key('battery_optimization_open')), findsOneWidget);
  });

  testWidgets('Unrestricted: says so and drops the steps', (tester) async {
    unrestricted = true;
    await pumpRow(tester);
    expect(statusText(tester), startsWith('Battery: Unrestricted.'));
    expect(find.textContaining('Never sleeping apps'), findsNothing);
  });

  testWidgets('a channel failure reads as not available, not as Optimized',
      (tester) async {
    messenger.setMockMethodCallHandler(AndroidBatteryStatus.channel,
        (call) async => throw PlatformException(code: 'x'));
    await pumpRow(tester);
    expect(statusText(tester), 'Battery setting: not available.');
  });

  testWidgets('the button opens the app settings page', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byKey(const Key('battery_optimization_open')));
    await tester.pump();
    expect(calls, contains('openAppSettings'));
  });

  testWidgets('returning to the app re-reads the state the user changed',
      (tester) async {
    await pumpRow(tester);
    expect(statusText(tester), startsWith('Battery: Optimized.'));

    unrestricted = true; // the user set Unrestricted in Android settings
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(statusText(tester), startsWith('Battery: Unrestricted.'));
  });

  test('placement: Settings shows the row on Android with background on', () {
    // SOURCE-TEXT VERIFIED: the row sits behind Platform.isAndroid, which a
    // host widget test cannot reach; the gate pins the guard and the widget.
    final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
    expect(
        src.contains('if (Platform.isAndroid && _backgroundScanEnabled)\n'
            '          const BatteryOptimizationRow(),'),
        isTrue);
  });

  test('the app never declares REQUEST_IGNORE_BATTERY_OPTIMIZATIONS', () {
    // Google Play: "prohibit apps from requesting direct exemption from Power
    // Management features ... unless the core function of the app is
    // adversely affected". The user chooses Unrestricted instead.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'), isFalse);
    // The CODE reference, not the name: MainActivity's comment names the
    // intent to explain why it is not used.
    final kotlinDir = Directory('android/app/src/main/kotlin');
    for (final f in kotlinDir.listSync(recursive: true).whereType<File>()) {
      expect(
          f.readAsStringSync()
              .contains('Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
          isFalse,
          reason: '${f.path} must not request the exemption directly');
    }
  });
}
