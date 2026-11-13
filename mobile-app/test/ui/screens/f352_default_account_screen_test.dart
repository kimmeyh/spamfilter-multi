/// F352 (Sprint 85, ADR-0052): the default account on Select Account and
/// Settings > Account, and the picker being skipped when a default is seeded.
///
/// These mount the REAL AccountSelectionScreen and SettingsScreen over fake
/// secure storage and a real test database (same harness as
/// f324_background_off_test.dart).
///
/// What these do NOT catch: the real app restart (main() builds the seeded
/// provider; Manual Validation covers it), the real OS keystore, and the
/// Android layout of the extra star button on a narrow phone (the Fold8 and
/// S24+ checks in Manual Validation cover it).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart'
    show Credentials;
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/providers/selected_account_provider.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/account_selection_screen.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

import '../../helpers/database_test_helper.dart';

const _a = 'one@icloud.com';
const _b = 'two@icloud.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final fake = <String, String>{};
  late DatabaseTestHelper testHelper;

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    fake.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      switch (call.method) {
        case 'read':
          return fake[key];
        case 'write':
          fake[key!] = call.arguments['value'] as String;
          return null;
        case 'delete':
          fake.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(fake);
      }
      return null;
    });
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    DatabaseHelper().setAppPaths(testHelper.appPaths);
    await testHelper.createTestAccount(_a, platformId: 'icloud');
    await testHelper.createTestAccount(_b, platformId: 'icloud');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await testHelper.tearDown();
  });

  Future<void> seedAccounts(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final id in [_a, _b]) {
        await SecureCredentialsStore().saveCredentials(
          id,
          Credentials(email: id, password: 'app-password'),
          platformId: 'icloud',
        );
      }
    });
  }

  Widget selectScreen(SelectedAccountProvider selected) => MaterialApp(
        builder: (context, child) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: selected),
            ChangeNotifierProvider(create: (_) => EmailScanProvider()),
            ChangeNotifierProvider(create: (_) => RuleSetProvider()),
          ],
          child: child!,
        ),
        home: const AccountSelectionScreen(),
      );

  Future<void> settle(WidgetTester tester, {int rounds = 3}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  // The tap starts real database I/O; run it on the real event loop so no
  // sqflite timer is left pending in the fake clock.
  Future<void> tapReal(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
  }

  // Unmount and let the screen's own reload timers and reads finish, so no
  // timer is pending when the test ends.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> mountSelect(
      WidgetTester tester, SelectedAccountProvider selected) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(selectScreen(selected));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final toggleA = find.byKey(const Key('default_toggle_$_a'));
  final toggleB = find.byKey(const Key('default_toggle_$_b'));
  final markA = find.byKey(const Key('default_mark_$_a'));
  final markB = find.byKey(const Key('default_mark_$_b'));

  group('Select Account control and mark (AC-1, AC-3)', () {
    testWidgets('no default: every row offers Set as default and none is '
        'marked', (tester) async {
      await seedAccounts(tester);
      await mountSelect(tester, SelectedAccountProvider());

      expect(toggleA, findsOneWidget);
      expect(toggleB, findsOneWidget);
      expect(find.byTooltip(AccountSelectionScreen.setDefaultTooltip),
          findsNWidgets(2));
      expect(markA, findsNothing);
      expect(markB, findsNothing);
      await drain(tester);
    });

    testWidgets('the control sets the default, marks that row, stores it, and '
        'does not change the session selection', (tester) async {
      await seedAccounts(tester);
      final selected = SelectedAccountProvider();
      await mountSelect(tester, selected);

      await tapReal(tester, toggleA);
      await settle(tester, rounds: 1);

      expect(markA, findsOneWidget);
      expect(find.text(AccountSelectionScreen.defaultAccountLabel),
          findsOneWidget);
      expect(markB, findsNothing);
      expect(find.byTooltip(AccountSelectionScreen.removeDefaultTooltip),
          findsOneWidget);
      final stored = await tester
          .runAsync(() => SettingsStore().getDefaultAccountId());
      expect(stored, _a);
      expect(selected.hasSelection, isFalse,
          reason: 'setting a default does not select it for this session');
      await drain(tester);
    });

    testWidgets('setting another account moves the mark; Remove default '
        'returns to no default', (tester) async {
      await seedAccounts(tester);
      await tester.runAsync(() => SettingsStore().setDefaultAccountId(_a));
      await mountSelect(tester, SelectedAccountProvider());
      expect(markA, findsOneWidget, reason: 'a stored default shows its mark');

      await tapReal(tester, toggleB);
      await settle(tester, rounds: 1);
      expect(markB, findsOneWidget);
      expect(markA, findsNothing);
      expect(await tester.runAsync(() => SettingsStore().getDefaultAccountId()),
          _b);

      await tapReal(tester, toggleB); // now "Remove default"
      await settle(tester, rounds: 1);
      expect(markB, findsNothing);
      expect(find.byTooltip(AccountSelectionScreen.setDefaultTooltip),
          findsNWidgets(2));
      expect(await tester.runAsync(() => SettingsStore().getDefaultAccountId()),
          isNull);
      await drain(tester);
    });

    testWidgets('a phone-width row with the star button does not overflow',
        (tester) async {
      await seedAccounts(tester);
      await tester.runAsync(() => SettingsStore().setDefaultAccountId(_a));
      await mountSelect(tester, SelectedAccountProvider());
      tester.view.physicalSize = const Size(360, 780);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(markA, findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'a RenderFlex overflow at 360 px wide is an exception');
      await drain(tester);
    });

    // Would NOT catch: the star button being hard to hit on a real phone (this
    // checks layout overflow only, at 360 px; Manual Validation checks touch).
  });

  group('picker skipped when a default is seeded (AC-4, AC-5)', () {
    // Opening Settings from Select Account runs the resolver
    // (_resolveAccountForScopedDestination). With two accounts it prompts
    // unless the session already holds a valid selection.
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await settle(tester, rounds: 2);
    }

    testWidgets('with a seeded default the picker is NOT shown and Settings '
        'opens', (tester) async {
      await seedAccounts(tester);
      await tester.runAsync(() => SettingsStore().setDefaultAccountId(_b));
      final selected = (await tester.runAsync(() =>
          SelectedAccountProvider.createSeeded(
            readDefault: SettingsStore().getDefaultAccountId,
            listAccounts: SecureCredentialsStore().getSavedAccounts,
            clearDefault: SettingsStore().clearDefaultAccountId,
          )))!;
      expect(selected.accountId, _b);
      await mountSelect(tester, selected);

      await openSettings(tester);

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a seeded default means no account picker');
      expect(find.byType(SettingsScreen), findsOneWidget);
      final settings =
          tester.widget<SettingsScreen>(find.byType(SettingsScreen));
      expect(settings.accountId, _b);
      await drain(tester);
    });

    testWidgets('with no default the picker IS shown (today\'s behavior)',
        (tester) async {
      await seedAccounts(tester);
      await mountSelect(tester, SelectedAccountProvider());

      await openSettings(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      await drain(tester);
    });

    testWidgets('a session pick of another account wins over the default for '
        'this session', (tester) async {
      await seedAccounts(tester);
      await tester.runAsync(() => SettingsStore().setDefaultAccountId(_a));
      final selected = (await tester.runAsync(() =>
          SelectedAccountProvider.createSeeded(
            readDefault: SettingsStore().getDefaultAccountId,
            listAccounts: SecureCredentialsStore().getSavedAccounts,
            clearDefault: SettingsStore().clearDefaultAccountId,
          )))!;
      selected.select(_b);
      await mountSelect(tester, selected);

      await openSettings(tester);

      final settings =
          tester.widget<SettingsScreen>(find.byType(SettingsScreen));
      expect(settings.accountId, _b);
      expect(await tester.runAsync(() => SettingsStore().getDefaultAccountId()),
          _a,
          reason: 'the stored default is unchanged by the session pick');
      await drain(tester);
    });

    // Would NOT catch: Manual Scan and the other readers of the selection
    // (they read the same provider; the resolver is the shared gate).
  });

  group('Settings > Account label (AC-2)', () {
    Future<void> mountSettings(WidgetTester tester, String accountId) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SelectedAccountProvider()),
              ChangeNotifierProvider(create: (_) => EmailScanProvider()),
              ChangeNotifierProvider(create: (_) => RuleSetProvider()),
            ],
            child: SettingsScreen(accountId: accountId),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await tester.pump();
      });
      await tester.tap(find.text('Account'));
      await settle(tester, rounds: 6);
    }

    final label = find.byKey(const Key('settings_default_account_label'));

    testWidgets('shows for the default account only', (tester) async {
      await seedAccounts(tester);
      await tester.runAsync(() => SettingsStore().setDefaultAccountId(_a));

      await mountSettings(tester, _a);
      expect(label, findsOneWidget);
      expect(find.text(SettingsScreen.defaultAccountLabel), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await mountSettings(tester, _b);
      expect(label, findsNothing,
          reason: 'a non-default account shows no label');
      await drain(tester);
    });

    testWidgets('shows nothing when there is no default', (tester) async {
      await seedAccounts(tester);
      await mountSettings(tester, _a);
      expect(label, findsNothing);
      await drain(tester);
    });

    // Would NOT catch: the label being read-only is by construction (it is a
    // Text with no handler); no test taps it.
  });
}
