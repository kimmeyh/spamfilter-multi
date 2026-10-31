// Sprint 82 MV-1: a notification tap brings the app forward on its first
// route (Review No Rule Items when accounts exist).
//
// What these tests do NOT catch: whether Windows delivers the click to this
// process at all (COM class registration, two processes registered under one
// GUID) or whether the window really comes to the front. Those are checked by
// looking, in the MV-1 rehearsal on the DEV build.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/notification_tap_handler.dart';
import 'package:my_email_spam_filter/core/services/scan_complete_notifier.dart';

void main() {
  final navKey = GlobalKey<NavigatorState>();

  Future<void> pumpWithPushedRoutes(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: const Scaffold(body: Text('home: No Rule review')),
    ));
    navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Scan History'))));
    await tester.pumpAndSettle();
    navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Results'))));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
  }

  testWidgets('desktop: brings the window forward and pops to the first route',
      (tester) async {
    await pumpWithPushedRoutes(tester);
    var raised = 0;
    await NotificationTapHandler.handleTap(
      navigator: navKey.currentState,
      hasDesktopWindow: true,
      bringToFront: () async => raised++,
    );
    await tester.pumpAndSettle();
    expect(raised, 1);
    expect(find.text('home: No Rule review'), findsOneWidget);
    expect(find.text('Results'), findsNothing);
    expect(find.text('Scan History'), findsNothing);
  });

  testWidgets('phone: no window to raise, still pops to the first route',
      (tester) async {
    await pumpWithPushedRoutes(tester);
    var raised = 0;
    await NotificationTapHandler.handleTap(
      navigator: navKey.currentState,
      hasDesktopWindow: false,
      bringToFront: () async => raised++,
    );
    await tester.pumpAndSettle();
    expect(raised, 0);
    expect(find.text('home: No Rule review'), findsOneWidget);
  });

  testWidgets('a failed raise still navigates', (tester) async {
    await pumpWithPushedRoutes(tester);
    await NotificationTapHandler.handleTap(
      navigator: navKey.currentState,
      hasDesktopWindow: true,
      bringToFront: () async => throw StateError('window_manager failed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('home: No Rule review'), findsOneWidget);
  });

  test('no navigator yet: returns without throwing', () async {
    var raised = 0;
    await NotificationTapHandler.handleTap(
      navigator: null,
      hasDesktopWindow: true,
      bringToFront: () async => raised++,
    );
    expect(raised, 1);
  });

  // 7.7.1 H-2: a failure must reach the diagnostic log, which a release
  // build keeps (the console log is dropped there).
  // What this does NOT catch: a failure of initialize() itself (the plugin
  // cannot be made to fail in a host test); it uses the same _note path.
  test('7.7.1 H-2: a failed raise and a missing navigator are written to the '
      'diagnostic log', () async {
    final dir = Directory.systemTemp.createTempSync('tap_diag_');
    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(dir.path);
    addTearDown(() {
      DiagnosticLogger.debugSetEnabled(null);
      DiagnosticLogger.debugSetDir(null);
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    await NotificationTapHandler.handleTap(
      navigator: null,
      hasDesktopWindow: true,
      bringToFront: () async => throw StateError('window_manager failed'),
    );
    String log() => dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.readAsStringSync())
        .join('\n');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!(log().contains('no navigator yet') &&
            log().contains('could not bring the window forward')) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(log(), contains('notify/tap'));
    expect(log(), contains('could not bring the window forward'));
    expect(log(), contains('no navigator yet'));
  });

  test('the UI registers under the same Windows app ID and GUID as the poster',
      () {
    final windows = ScanCompleteNotifier.initializationSettings.windows!;
    expect(windows.guid, ScanCompleteNotifier.windowsGuid);
    expect(windows.appUserModelId, ScanCompleteNotifier.windowsAppUserModelId);
    expect(windows.appName, ScanCompleteNotifier.windowsAppName);
  });
}
