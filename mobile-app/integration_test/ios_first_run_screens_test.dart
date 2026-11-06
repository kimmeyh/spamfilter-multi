// Sprint 84, F345 (R-3) -- first-run screens captured as PNG files on the iOS
// Simulator, one set per device size (iPhone, iPad).
//
// This is NOT one of the nine regression files. It exists so the `ios-simulator`
// job in .github/workflows/ios.yml can hand Harold the first-run screens before
// a real iPhone exists (they feed Sprint 84 Task 4 R-4). It skips itself unless
// the job passes the output folder, so `scripts/run-integration-tests.ps1` on
// Windows runs it as a skipped test.
//
// Run (the job does this):
//   flutter test integration_test/ios_first_run_screens_test.dart -d <udid> \
//     --dart-define=SCREENSHOT_DIR=<folder> --dart-define=SCREENSHOT_LABEL=iphone
//
// The Simulator runs the app as a process on the Mac, so a Dart File write to an
// absolute Mac path reaches the Mac disk (UNVERIFIED until the first CI run; the
// job also takes a whole-screen `xcrun simctl io screenshot` as a fallback).
//
// WHAT THIS DOES NOT CATCH: it proves each screen builds and paints on an iOS
// device size. It asserts nothing about the screen text. A screen that painted
// wrong content would still produce a PNG; a person has to look at the image.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/account_setup_screen.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';
import 'package:my_email_spam_filter/ui/screens/platform_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';
import 'package:my_email_spam_filter/ui/theme/app_theme.dart';

import 'helpers/app_harness.dart';

const String _dir = String.fromEnvironment('SCREENSHOT_DIR');
const String _label = String.fromEnvironment('SCREENSHOT_LABEL', defaultValue: 'device');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F345 first-run screens ($_label)', () {
    HarnessSession? session;

    tearDown(() async {
      await session?.dispose();
    });

    Future<void> shoot(
      WidgetTester tester,
      String name,
      Widget screen,
    ) async {
      session = await bootDbOnly(tester);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => RuleSetProvider()),
              ChangeNotifierProvider(create: (_) => EmailScanProvider()),
              ChangeNotifierProvider(create: (_) => SelectedAccountProvider()),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: screen,
            ),
          ),
        ),
      );
      // AccountSelectionScreen waits 500 ms before it reads the saved accounts.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      final path = '$_dir/$_label-$name.png';
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
      // A silent miss would leave the artifact empty and the job green.
      expect(File(path).existsSync(), isTrue, reason: 'screenshot not written: $path');
      expect(File(path).lengthSync(), greaterThan(1000));
    }

    final skipReason = _dir.isEmpty ? 'SCREENSHOT_DIR not set (iOS Simulator job only)' : null;

    testWidgets('empty state (no accounts)', (tester) async {
      await shoot(tester, '1-empty-state', const AccountSelectionScreen());
    }, skip: skipReason != null);

    testWidgets('Add Account (choose provider)', (tester) async {
      await shoot(tester, '2-add-account', const PlatformSelectionScreen());
    }, skip: skipReason != null);

    testWidgets('Add Account (AOL form)', (tester) async {
      await shoot(
        tester,
        '3-add-account-aol-form',
        const AccountSetupScreen(platformId: 'aol', platformDisplayName: 'AOL'),
      );
    }, skip: skipReason != null);

    testWidgets('Settings', (tester) async {
      await shoot(tester, '4-settings', const SettingsScreen(accountId: 'test-account'));
    }, skip: skipReason != null);

    testWidgets('Help', (tester) async {
      await shoot(tester, '5-help', const HelpScreen());
    }, skip: skipReason != null);
  });
}
