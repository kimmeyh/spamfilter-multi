/// F239 R-3 (Sprint 75): a background scan whose Gmail sign-in cannot be
/// renewed without the user is a SKIP with the reason "Gmail needs you to
/// sign in again" -- not a failure, and not "busy".
///
/// Before: the adapter threw a plain AuthenticationException, the core
/// rethrew it, and both workers counted a failure (Android: a failed run).
/// After: the core returns a skip with `needsSignIn`, which the workers
/// already treat as "did what it should", and it does NOT take the 2-6
/// minute busy wait -- waiting cannot fix a sign-in.
///
/// The REAL BackgroundScanCore.scanAccount and EmailScanner run here; only
/// the platform is replaced, behind the 'demo' id (which skips the
/// credential load), by one that fails the way the Gmail adapter does.
///
/// What these do NOT catch: the Gmail adapter's own decision to throw (its
/// renewal paths need the Google sign-in plugin; covered by the emulator
/// spike and Manual Validation), and the scan row, which the claim created
/// before sign-in failed and the scanner closes as `error` with the same
/// reason (no `skipped` row status exists -- recorded in the card).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/util/error_messages.dart';

import '../../helpers/database_test_helper.dart';

class _NeedsSignInPlatform extends MockEmailProvider {
  @override
  void setDeletedRuleFolder(String? folderName) =>
      throw GmailSignInRequiredException();
}

class _OtherAuthFailurePlatform extends MockEmailProvider {
  @override
  void setDeletedRuleFolder(String? folderName) =>
      throw AuthenticationException('IMAP login rejected');
}

void main() {
  late DatabaseTestHelper testHelper;
  final waits = <Duration>[];

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount('acct-a');
    waits.clear();
    BackgroundScanCore.busyWait = (d) async => waits.add(d);
  });

  tearDown(() async {
    BackgroundScanCore.busyWait = (d) => Future<void>.delayed(d);
    await testHelper.tearDown();
  });

  void usePlatform(MockEmailProvider Function() factory) {
    final previous = PlatformRegistry.overrideFactoryForTest('demo', factory);
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('demo', previous));
  }

  Future<AccountScanOutcome> scan() => BackgroundScanCore.scanAccount(
        accountId: 'acct-a',
        platformId: 'demo',
        ruleSetProvider: RuleSetProvider(),
        settingsStore: SettingsStore(testHelper.dbHelper),
        scanResultStore: ScanResultStore(testHelper.dbHelper),
      );

  test('Gmail needs the user: a skip with the reason, and NO busy wait',
      () async {
    usePlatform(_NeedsSignInPlatform.new);
    final outcome = await scan();
    expect(outcome.skipped, isTrue);
    expect(outcome.needsSignIn, isTrue);
    expect(outcome.skippedReason, 'Gmail needs you to sign in again');
    expect(waits, isEmpty,
        reason: 'the busy wait is for a busy account; only the user can fix '
            'a sign-in');
  });

  test('any other sign-in failure is still a failure (rethrown)', () async {
    usePlatform(_OtherAuthFailurePlatform.new);
    await expectLater(scan(), throwsA(isA<AuthenticationException>()));
  });

  test('the scan error text names the fix', () {
    expect(ErrorMessages.humanize(GmailSignInRequiredException()),
        'Gmail needs you to sign in again.');
    expect(ErrorMessages.humanize(AuthenticationException('x')),
        startsWith('Sign-in failed'));
  });
}
