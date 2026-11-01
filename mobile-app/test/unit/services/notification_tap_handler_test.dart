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

  // 7.7.1 M-5 (Harold Q4 = 2): a tap must not discard typed input.
  // What these tests do NOT catch: input held outside a text field (a
  // checkbox or a folder selection on an open screen) is still discarded;
  // the cautious check looks only for dialogs and editable text fields that
  // hold text. Whether the SnackBar is readable under a dialog's barrier is
  // checked by looking, not here.
  group('7.7.1 M-5: keeps a screen with input open', () {
    late RouteStackObserver observer;

    Future<void> pumpApp(WidgetTester tester) async {
      observer = RouteStackObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('home: No Rule review')),
      ));
    }

    Future<void> tap(WidgetTester tester) async {
      await NotificationTapHandler.handleTap(
        navigator: navKey.currentState,
        hasDesktopWindow: false,
        bringToFront: () async {},
        openRoutes: observer.routes,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
    }

    testWidgets('a screen with a text field stays open and the message shows',
        (tester) async {
      await pumpApp(tester);
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: TextField())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'typed rule');
      await tap(tester);
      expect(find.text('typed rule'), findsOneWidget);
      expect(find.text(NotificationTapHandler.keptOpenMessage), findsOneWidget);
    });

    testWidgets('an open dialog stays open', (tester) async {
      await pumpApp(tester);
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Delete rule?')),
      );
      await tester.pumpAndSettle();
      await tap(tester);
      expect(find.text('Delete rule?'), findsOneWidget);
      expect(find.text(NotificationTapHandler.keptOpenMessage), findsOneWidget);
    });

    testWidgets('a kept screen is written to the diagnostic log',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('tap_kept_');
      DiagnosticLogger.debugSetEnabled(true);
      DiagnosticLogger.debugSetDir(dir.path);
      addTearDown(() {
        DiagnosticLogger.debugSetEnabled(null);
        DiagnosticLogger.debugSetDir(null);
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException catch (_) {}
      });
      await pumpApp(tester);
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Delete rule?')),
      );
      await tester.pumpAndSettle();
      // Real async: the diagnostic log's file write never completes inside
      // the widget test's fake-async zone.
      final text = await tester.runAsync(() async {
        await NotificationTapHandler.handleTap(
          navigator: navKey.currentState,
          hasDesktopWindow: false,
          bringToFront: () async {},
          openRoutes: observer.routes,
        );
        String log() => dir
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.readAsStringSync())
            .join('\n');
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!log().contains('open screen kept') &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return log();
      });
      expect(text, contains('open screen kept (a dialog is open)'));
    });

    testWidgets('empty and read-only text fields do not block', (tester) async {
      await pumpApp(tester);
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
                body: Column(children: [
                  const TextField(), // an empty search box
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: 'a rule pattern'),
                  ),
                  const SelectableText('selectable'),
                ]),
              )));
      await tester.pumpAndSettle();
      expect(NotificationTapHandler.inputAtRisk(observer.routes), isNull);
      await tap(tester);
      await tester.pumpAndSettle();
      expect(find.text('home: No Rule review'), findsOneWidget);
    });

    testWidgets('typed text two screens deep keeps both screens', (tester) async {
      await pumpApp(tester);
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Rules'))));
      await tester.pumpAndSettle();
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: TextField())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'typed rule');
      await tap(tester);
      expect(find.text('typed rule'), findsOneWidget);
      expect(observer.routes, hasLength(3));
    });

    test('a failure while deciding is written to the diagnostic log',
        () async {
      final dir = Directory.systemTemp.createTempSync('tap_fail_');
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
        navigator: _ThrowingNavigatorState(),
        hasDesktopWindow: false,
        bringToFront: () async {},
        openRoutes: [_ThrowingRoute()],
      );
      String log() => dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!log().contains('tap failed') &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(log(), contains('tap failed'));
    });

    testWidgets('a screen without input is still closed', (tester) async {
      await pumpApp(tester);
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Scan History'))));
      await tester.pumpAndSettle();
      await tap(tester);
      await tester.pumpAndSettle();
      expect(find.text('Scan History'), findsNothing);
      expect(find.text('home: No Rule review'), findsOneWidget);
      expect(find.text(NotificationTapHandler.keptOpenMessage), findsNothing);
    });

    testWidgets('a text field on the first route does not block', (tester) async {
      observer = RouteStackObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [observer],
        home: Scaffold(
            body: TextField(controller: TextEditingController(text: 'x'))),
      ));
      expect(NotificationTapHandler.inputAtRisk(observer.routes), isNull);
    });

    testWidgets('a closed dialog no longer blocks', (tester) async {
      await pumpApp(tester);
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Delete rule?')),
      );
      await tester.pumpAndSettle();
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.routes, hasLength(1));
      expect(NotificationTapHandler.inputAtRisk(observer.routes), isNull);
    });
  });

  test('the UI registers under the same Windows app ID and GUID as the poster',
      () {
    final windows = ScanCompleteNotifier.initializationSettings.windows!;
    expect(windows.guid, ScanCompleteNotifier.windowsGuid);
    expect(windows.appUserModelId, ScanCompleteNotifier.windowsAppUserModelId);
    expect(windows.appName, ScanCompleteNotifier.windowsAppName);
  });
}

/// A route whose `isActive` throws, to drive the tap's error path.
class _ThrowingRoute extends Route<void> {
  @override
  bool get isActive => throw StateError('route torn down');
}

/// Never used as a real navigator: the route check throws first.
class _ThrowingNavigatorState extends NavigatorState {}
