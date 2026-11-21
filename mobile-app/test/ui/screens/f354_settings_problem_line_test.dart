/// Sprint 85 7.7.1 M4: a failed F354 DEV credential copy is SHOWN in
/// Settings > General, not only written to the opt-in diagnostic log.
///
/// Before: the reason went to `Logger` (writes nothing in a release build) and
/// to the diagnostic log (off by default), so DEV opened on an empty account
/// list with no explanation anywhere on screen.
///
/// Mounts the REAL SettingsScreen over a real (FFI) test database.
///
/// What this does NOT catch: that main.dart sets the reason on a real failed
/// copy (dev_credential_separation_test.dart covers run(); main.dart's wiring
/// is covered there by source order only), and the line's look on a phone
/// (Windows DEV is the only build where it can appear).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/dev_credential_separation.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import '../../helpers/database_test_helper.dart';
import '../../helpers/db_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper testHelper;

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
  });

  tearDown(() async {
    DevCredentialSeparation.lastError = null;
    await testHelper.tearDown();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await mountAndLoadDbWidget(
          tester, MaterialApp(home: SettingsScreen(key: UniqueKey())));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('a failed DEV credential copy is shown with its reason',
      (tester) async {
    DevCredentialSeparation.lastError = 'access denied (test)';
    await mount(tester);

    final line = find.byKey(const Key('f354_problem'));
    await tester.scrollUntilVisible(line, 200.0,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.descendant(
            of: line,
            matching: find.textContaining('access denied (test)')),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('no line when the copy did not fail', (tester) async {
    DevCredentialSeparation.lastError = null;
    await mount(tester);
    expect(find.byKey(const Key('f354_problem')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
