import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/rule_quick_action_service.dart';
import 'package:my_email_spam_filter/core/services/safe_sender_suggestion_service.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

/// F270 v1 (Sprint 83, T-1): the candidate service.
///
/// All addresses use `.example` domains (no personal data).
///
/// What these tests do NOT catch: the real shape of `from_email` values in a
/// production database beyond "Name <addr>" and a bare address, the DEV count
/// (recorded in the Task 5 card, counted by a read-only script), and the
/// screen (see the widget test).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DatabaseTestHelper.initializeFfi);

  late DatabaseTestHelper h;
  late int scanId;
  late SafeSenderSuggestionService service;

  setUp(() async {
    h = DatabaseTestHelper();
    await h.setUp();
    await h.createTestAccount('acct');
    scanId = await h.createTestScanResult('acct');
    service = SafeSenderSuggestionService(databaseHelper: h.dbHelper);
  });
  tearDown(() => h.tearDown());

  var seq = 0;
  Future<void> addNoRule(String from, String? auth,
      {int times = 1, String availability = 'unknown'}) async {
    final db = await h.dbHelper.database;
    for (var i = 0; i < times; i++) {
      seq++;
      await db.insert('unmatched_emails', {
        'scan_result_id': scanId,
        'provider_identifier_type': 'uid',
        'provider_identifier_value': 'u$seq',
        'from_email': from,
        'folder_name': 'INBOX',
        'availability_status': availability,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'auth_classification': auth,
      });
    }
  }

  Future<void> addAction(String from, String type) async {
    final db = await h.dbHelper.database;
    seq++;
    await db.insert('email_actions', {
      'scan_result_id': scanId,
      'email_id': 'e$seq',
      'email_from': from,
      'email_subject': 's',
      'email_received_date': 0,
      'email_folder': 'INBOX',
      'action_type': type,
      'success': 1,
    });
  }

  Future<List<String>> found({
    Set<String> rejected = const {},
    List<String> safe = const [],
  }) async {
    final list =
        await service.findCandidates(rejected: rejected, safePatterns: safe);
    return list.map((c) => c.address).toList();
  }

  test('lists a sender with N green No Rule emails; AC-1', () async {
    await addNoRule('Shop <orders@shop.example>', 'green', times: 3);
    await addNoRule('few@few.example', 'green', times: 2);
    expect(await found(), ['orders@shop.example']);
    final c = (await service.findCandidates(
            rejected: {}, safePatterns: const []))
        .single;
    expect(c.count, 3);
  });

  test('one non-green email removes the sender (grey, yellow, red, null)',
      () async {
    for (final bad in ['grey', 'yellow', 'red', null]) {
      await addNoRule('x-${bad ?? 'null'}@bad.example', 'green', times: 3);
      await addNoRule('x-${bad ?? 'null'}@bad.example', bad);
    }
    expect(await found(), isEmpty);
  });

  test('a delete action or a deleted mailbox row removes the sender',
      () async {
    await addNoRule('act@del.example', 'green', times: 3);
    await addAction('Act <act@del.example>', 'delete');
    await addNoRule('gone@del.example', 'green', times: 3);
    await addNoRule('gone@del.example', 'green', availability: 'deleted');
    await addNoRule('kept@del.example', 'green', times: 3);
    await addAction('kept@del.example', 'none');
    expect(await found(), ['kept@del.example']);
  });

  test('an already safe sender and a rejected sender are not listed', () async {
    await addNoRule('safe@ok.example', 'green', times: 3);
    await addNoRule('no@ok.example', 'green', times: 3);
    await addNoRule('yes@ok.example', 'green', times: 3);
    final list = await found(
      rejected: {'no@ok.example'},
      safe: [RuleQuickActionService.safeSenderPatternFor('exact', 'safe@ok.example')!],
    );
    expect(list, ['yes@ok.example']);
  });

  test('recommended: Entire Domain for a company, Exact Email for a provider',
      () {
    final co = SafeSenderSuggestionService.choicesFor('a@mail.shop.example')!;
    expect(co.map((c) => c.type), ['exact', 'exactDomain', 'entireDomain']);
    expect(co.where((c) => c.recommended).single.type, 'entireDomain');
    expect(co.last.value, 'shop.example');
    final gm = SafeSenderSuggestionService.choicesFor('Bob <bob@gmail.com>')!;
    expect(gm.where((c) => c.recommended).single.type, 'exact');
    expect(gm.first.value, 'bob@gmail.com');
    // Each pattern is the one the quick action saves.
    expect(gm.first.pattern,
        RuleQuickActionService.safeSenderPatternFor('exact', 'bob@gmail.com'));
    expect(SafeSenderSuggestionService.choicesFor('no-at-sign'), isNull);
  });

  test('most emails first, then address', () async {
    await addNoRule('b@s.example', 'green', times: 3);
    await addNoRule('a@s.example', 'green', times: 3);
    await addNoRule('z@s.example', 'green', times: 5);
    expect(await found(), ['z@s.example', 'a@s.example', 'b@s.example']);
  });

  test('the reject list survives a new store instance (restart)', () async {
    await SettingsStore(h.dbHelper).rejectSafeSenderSuggestion('Nope@Ok.Example');
    final again = await SettingsStore(h.dbHelper).getRejectedSafeSenderSuggestions();
    expect(again, {'nope@ok.example'});
    await SettingsStore(h.dbHelper).rejectSafeSenderSuggestion('two@ok.example');
    expect(await SettingsStore(h.dbHelper).getRejectedSafeSenderSuggestions(),
        {'nope@ok.example', 'two@ok.example'});
  });
}
