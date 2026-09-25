/// F202 (Sprint 74): per-provider folder defaults with an overall default,
/// for all four folder settings -- resolved account -> provider -> overall.
///
/// Every provider value here is one Harold confirmed from a live account
/// (2026-09-09 and 2026-09-25); an unconfirmed value is absent and falls
/// through to the overall default.
///
/// **What these tests do NOT catch**: whether a provider's REAL server names
/// its folders the way the table says (e.g. a Yahoo account whose spam folder
/// is not "Bulk") -- the table is Harold's observation, and a wrong entry
/// would be skipped as a missing folder, not reported. And that the Gmail API
/// really scans `SPAM` -- Manual Validation on a Gmail account with no saved
/// selection.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  late DatabaseTestHelper testHelper;
  late SettingsStore store;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    store = SettingsStore(testHelper.dbHelper);
  });

  tearDown(() async => testHelper.tearDown());

  Future<String> account(String platformId, String email) async {
    final id = '$platformId-$email';
    await testHelper.createTestAccount(id, email: email, platformId: platformId);
    return id;
  }

  group('AC-1 -- provider defaults for all four settings', () {
    test('AOL: Inbox/Bulk/Bulk Mail, safe Inbox, deleted Trash', () async {
      final a = await account('aol', 'x@aol.com');
      expect(await store.getEffectiveFolders(a), ['Inbox', 'Bulk', 'Bulk Mail']);
      expect(await store.getEffectiveFolders(a, isBackground: true),
          ['Inbox', 'Bulk', 'Bulk Mail']);
      expect(await store.getEffectiveSafeSenderFolder(a), 'Inbox');
      expect(await store.getEffectiveDeletedRuleFolder(a), 'Trash');
    });

    test('AC-2 Yahoo: Inbox + Bulk, safe Inbox, deleted Trash', () async {
      final a = await account('yahoo', 'x@yahoo.com');
      expect(await store.getEffectiveFolders(a), ['Inbox', 'Bulk']);
      expect(await store.getEffectiveSafeSenderFolder(a), 'Inbox');
      expect(await store.getEffectiveDeletedRuleFolder(a), 'Trash');
    });

    test('AC-3 iCloud: deleted is "Deleted Messages", never Trash; scan '
        'folders fall through to the overall default', () async {
      final a = await account('icloud', 'x@icloud.com');
      expect(await store.getEffectiveDeletedRuleFolder(a), 'Deleted Messages');
      expect(await store.getEffectiveSafeSenderFolder(a), 'INBOX');
      await store.setManualScanFolders(['INBOX', 'Overall']);
      expect(await store.getEffectiveFolders(a), ['INBOX', 'Overall']);
    });

    test('Gmail over IMAP: [Gmail] folder names, deleted [Gmail]/Trash',
        () async {
      final a = await account('gmail-imap', 'x@gmail.com');
      expect(await store.getEffectiveFolders(a),
          ['INBOX', '[Gmail]/Spam', 'Unwanted']);
      expect(await store.getEffectiveDeletedRuleFolder(a), '[Gmail]/Trash');
    });

    test('Gmail API: LABELS (SPAM), and deleted left to the adapter -- an IMAP '
        'folder name there would make every delete fail', () async {
      final a = await account('gmail', 'x@gmail.com');
      expect(await store.getEffectiveFolders(a), ['INBOX', 'SPAM', 'Unwanted']);
      expect(await store.getEffectiveDeletedRuleFolder(a), isNull);
      expect(await store.getEffectiveSafeSenderFolder(a), 'INBOX');
    });

    test('generic IMAP: no provider values -> the overall defaults', () async {
      final a = await account('imap', 'x@example.org');
      await store.setBackgroundScanFolders(['INBOX', 'Junk']);
      expect(await store.getEffectiveFolders(a, isBackground: true),
          ['INBOX', 'Junk'],
          reason: 'the overall tier was unreachable for any real account '
              'before F202');
      expect(await store.getEffectiveSafeSenderFolder(a), 'INBOX');
      expect(await store.getEffectiveDeletedRuleFolder(a), isNull,
          reason: 'null = the adapter default (IMAP Trash)');
    });
  });

  group('AC-5 -- an account override always wins (no migration)', () {
    test('saved selections resolve exactly as before', () async {
      final a = await account('icloud', 'y@icloud.com');
      await store.setAccountManualScanFolders(a, ['Custom']);
      await store.setAccountSafeSenderFolder(a, 'Kept');
      await store.setAccountDeletedRuleFolder(a, 'Bin');
      expect(await store.getEffectiveFolders(a), ['Custom']);
      expect(await store.getEffectiveSafeSenderFolder(a), 'Kept');
      expect(await store.getEffectiveDeletedRuleFolder(a), 'Bin');
    });
  });

  group('R-5 -- the stored platform id beats the accountId heuristic', () {
    test('a bare Gmail address added over IMAP resolves as gmail-imap',
        () async {
      await testHelper.createTestAccount('z@gmail.com',
          email: 'z@gmail.com', platformId: 'gmail-imap');
      expect(await store.getEffectiveDeletedRuleFolder('z@gmail.com'),
          '[Gmail]/Trash',
          reason: 'the heuristic alone would say the Gmail API (null)');
    });
  });
}
