/// F214 (Sprint 75): the Scan Range slider lines up with the controls above it.
///
/// Before: the slider sat in a Row between Text('1') and Text('90'), so its
/// track started one label-width to the right of the "Scan all emails" tile.
/// After: the slider spans the card like the tile above it; the current value
/// is still shown below it ("N days") and in the drag label.
///
/// Both Scan Range cards (Manual Scan and Background tabs) come from the one
/// `_buildScanRangeSelector`, so the Manual Scan tab covers both.
///
/// What this does NOT catch: the visual look of the track ends (Material
/// adds its own track padding inside the Slider), which Manual Validation
/// checks on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fakeSecureStorage = <String, String>{};

  setUp(() {
    fakeSecureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return fakeSecureStorage[key];
        case 'write':
          fakeSecureStorage[key!] = call.arguments['value'] as String;
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('the slider starts at the same left edge as the Scan all '
      'emails tile, with no 1 / 90 labels beside it', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // One saved account: the scoped tab auto-resolves (see
    // settings_null_account_test) and renders its real controls.
    fakeSecureStorage['saved_accounts'] = 'gmail-a@example.com';

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.tap(find.text('Manual Scan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget,
        reason: 'the Manual Scan tab must render its Scan Range slider -- '
            'without it every other check here passes vacuously');
    final tile = find.widgetWithText(CheckboxListTile, 'Scan all emails');
    expect(tile, findsOneWidget);

    expect(tester.getTopLeft(slider).dx, tester.getTopLeft(tile).dx,
        reason: 'the slider must start where the tile above it starts');
    expect(tester.getSize(slider).width, tester.getSize(tile).width,
        reason: 'and span the same width');

    final row = find.ancestor(of: slider, matching: find.byType(Row));
    for (final label in const ['1', '90']) {
      expect(
          find.descendant(of: row, matching: find.text(label)), findsNothing,
          reason: 'no "$label" flank label beside the slider');
    }
  });
}
