/// F302 (Sprint 81): an IMAP message the server sent WITHOUT a UID keeps its
/// sequence number in its own field and holds the one constant
/// `kNoValidImapUid` as its id; no UID consumer acts on it, and each skip is
/// written to the diagnostic log naming the folder.
///
/// Before F302 the id held the SEQUENCE number, which every UID consumer read
/// as a UID. A sequence number names a different message after any delete, so
/// a move, delete or presence check could act on the wrong message.
///
/// Drives the REAL adapter against a fake `ImapClient` (the F177
/// `debugSetImapClient` seam) and the REAL `EmailScanProvider` persistence.
///
/// What these tests do NOT catch (one line each):
///   - a real server that answers a UID command without a UID: the fake models
///     the answer shape (`MimeMessage.uid == null`), not a server's behavior;
///   - the scanner's oldest-no-rule cursor and the Scan Results screen cursor
///     (both call `parseImapUid`; covered by the policy gate that no consumer
///     bypasses it, not driven here);
///   - Gmail: it has no IMAP UID and never produces the constant.
library;

import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/imap_uid.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

import '../../helpers/database_test_helper.dart';

/// Scripted server: SEARCH answers [searchFound]; FETCH answers one message
/// per requested UID, with no UID for those in [noUidFor] (sequence number 7
/// instead). Records every command that could change or probe the mailbox.
class _Client extends ImapClient {
  _Client(
      {this.searchFound = const [],
      this.noUidFor = const {},
      this.storeThrows = false})
      : super(isLogEnabled: false);

  final bool storeThrows;
  final List<int> searchFound;
  final Set<int> noUidFor;
  final List<String> searches = [];
  final List<String> moves = [];
  final List<String> stores = [];
  int fetches = 0;

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async =>
      Mailbox(
          encodedName: path, encodedPath: path, pathSeparator: '/', flags: []);

  @override
  Future<SearchImapResult> uidSearchMessages({
    String searchCriteria = 'UNSEEN',
    List<ReturnOption>? returnOptions,
    Duration? responseTimeout,
  }) async {
    searches.add(searchCriteria);
    final r = SearchImapResult();
    r.matchingSequence = searchFound.isEmpty
        ? MessageSequence(isUidSequence: true)
        : MessageSequence.fromIds(searchFound, isUid: true);
    return r;
  }

  @override
  Future<FetchImapResult> uidFetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    fetches++;
    final messages = [
      for (final uid in sequence.toList())
        MimeMessage()
          ..uid = noUidFor.contains(uid) ? null : uid
          ..sequenceId = noUidFor.contains(uid) ? 7 : uid
          ..addHeader('From', 'sender$uid@example.com')
          ..addHeader('Subject', 'Message $uid'),
    ];
    return FetchImapResult(messages, null);
  }

  @override
  Future<GenericImapResult> uidMove(
    MessageSequence sequence, {
    Mailbox? targetMailbox,
    String? targetMailboxPath,
  }) async {
    moves.add('${sequence.toList().join(',')}->$targetMailboxPath');
    return GenericImapResult();
  }

  @override
  Future<StoreImapResult> uidStore(
    MessageSequence sequence,
    List<String> flags, {
    StoreAction? action,
    bool? silent,
    int? unchangedSinceModSequence,
  }) async {
    stores.add('${sequence.toList().join(',')}:${flags.join(',')}');
    if (storeThrows) throw StateError('server refused the keyword');
    return StoreImapResult();
  }
}

EmailMessage _msg(String id, {String folder = 'Bulk Mail'}) => EmailMessage(
      id: id,
      from: 'spam@example.com',
      subject: 'subject $id',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 10, 23),
      folderName: folder,
    );

void main() {
  late Directory diagDir;

  setUpAll(() => DatabaseTestHelper.initializeFfi());

  setUp(() {
    diagDir = Directory.systemTemp.createTempSync('f302_diag_');
    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(diagDir.path);
  });

  tearDown(() {
    DiagnosticLogger.debugSetEnabled(null);
    DiagnosticLogger.debugSetDir(null);
    try {
      diagDir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  String diag() => diagDir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.readAsStringSync())
      .join('\n');

  /// The log writes are queued behind unawaited calls; wait for [text].
  /// Up to 10 s: each write waits on the static write chain and a lock file
  /// (DiagnosticLogger.lockWait is 2 s), and a 3 s limit failed once under a
  /// loaded parallel run (Sprint 81 merge check). Returns as soon as it shows.
  Future<String> diagWith(String text) async {
    for (var i = 0; i < 200 && !diag().contains(text); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return diag();
  }

  GenericIMAPAdapter adapterFor(_Client client) => GenericIMAPAdapter(
      imapHost: 'imap.example.com', platformId: 'aol')
    ..debugSetImapClient(client);

  group('conversion (R-1, R-2, R-4)', () {
    test('a FETCH answer with no UID gives the constant id and keeps the '
        'sequence number in its own field; the skip reaches the diagnostic log',
        () async {
      final client = _Client(searchFound: [1, 2], noUidFor: {2});
      final messages = await adapterFor(client)
          .fetchMessages(daysBack: 0, folderNames: ['Bulk Mail']);

      expect(messages, hasLength(2));
      final withUid = messages.firstWhere((m) => m.id == '1');
      expect(withUid.imapSequenceNumber, 1);
      final noUid = messages.firstWhere((m) => m.id != '1');
      expect(noUid.id, kNoValidImapUid);
      expect(noUid.id, isNot('7'), reason: 'never the sequence number');
      expect(noUid.id, isNotEmpty, reason: 'never the empty string');
      expect(int.tryParse(noUid.id), isNull);
      expect(noUid.imapSequenceNumber, 7);

      final log = await diagWith('IMAP/convert');
      expect(log, contains('[IMAP/convert]'));
      expect(log, contains('folder "Bulk Mail"'));
    });

    test('copyWithTruncatedBody keeps the sequence number', () {
      final m = EmailMessage(
        id: kNoValidImapUid,
        from: 'a@b.c',
        subject: 's',
        body: 'long body text',
        headers: const {},
        receivedDate: DateTime(2026, 10, 23),
        folderName: 'INBOX',
        imapSequenceNumber: 7,
      ).copyWithTruncatedBody(4);
      expect(m.body, 'long');
      expect(m.imapSequenceNumber, 7);
    });
  });

  group('every UID consumer refuses the constant (R-3)', () {
    test('presence check: only the real UID is searched; the skip is logged '
        'with the folder', () async {
      final client = _Client(searchFound: [5]);
      final result = await adapterFor(client).checkMessagesPresent(
          folderName: 'Bulk Mail', ids: [kNoValidImapUid, '5']);

      expect(client.searches, ['UID 5']);
      expect(result, {'5': MessagePresence.present});
      final log = await diagWith('IMAP/checkMessagesPresent');
      expect(log, contains('folder "Bulk Mail"'));
    });

    test('presence check with ONLY the constant sends nothing', () async {
      final client = _Client();
      final result = await adapterFor(client).checkMessagesPresent(
          folderName: 'Bulk Mail', ids: [kNoValidImapUid]);
      expect(result, isEmpty);
      expect(client.searches, isEmpty);
    });

    test('single move, delete and mark-as-read throw and run no command',
        () async {
      final client = _Client();
      final adapter = adapterFor(client);
      final m = _msg(kNoValidImapUid);

      await expectLater(adapter.moveToFolder(message: m, targetFolder: 'Trash'),
          throwsA(isA<ActionException>()));
      await expectLater(
          adapter.takeAction(message: m, action: FilterAction.delete),
          throwsA(isA<ActionException>()));
      await expectLater(adapter.markAsRead(message: m),
          throwsA(isA<ActionException>()));
      expect(client.moves, isEmpty);
      expect(client.stores, isEmpty);
      expect(await diagWith('IMAP/takeAction'), contains('IMAP/moveToFolder'));
    });

    test('batch delete: the constant FAILS by name and is never moved; the '
        'real UID in the same batch still moves', () async {
      final client = _Client(searchFound: const []);
      final batch = await adapterFor(client).takeActionBatch(
          [_msg(kNoValidImapUid), _msg('5')], FilterAction.delete);

      expect(client.moves, ['5->Trash']);
      expect(batch.succeededIds, ['5']);
      expect(batch.failedIds.keys, [kNoValidImapUid]);
      expect(batch.failedIds[kNoValidImapUid],
          GenericIMAPAdapter.noValidUidReason);
      expect(await diagWith('IMAP/moveToFolderBatch'),
          contains('folder "Bulk Mail"'));
    });

    test('batch of ONLY no-UID messages: nothing is sent and it is not '
        'reported as moved', () async {
      final client = _Client();
      final batch = await adapterFor(client)
          .moveToFolderBatch([_msg(kNoValidImapUid)], 'Trash');
      expect(client.moves, isEmpty);
      expect(batch.succeededIds, isEmpty);
      expect(batch.failedIds.keys, [kNoValidImapUid]);
    });

    test('batch mark-as-read, flag and mark-as-spam: not stored, not reported '
        'succeeded', () async {
      final client = _Client();
      final adapter = adapterFor(client);
      final both = [_msg(kNoValidImapUid), _msg('5')];

      final read = await adapter.markAsReadBatch(both);
      expect(read.succeededIds, ['5']);
      expect(read.failedIds.keys, [kNoValidImapUid]);

      final flag = await adapter.applyFlagBatch(both, 'Rule One');
      expect(flag.succeededIds, ['5']);
      expect(flag.failedIds.keys, [kNoValidImapUid]);

      final spam = await adapter.takeActionBatch(both, FilterAction.markAsSpam);
      expect(spam.succeededIds, ['5']);
      expect(spam.failedIds.keys, [kNoValidImapUid]);

      expect(client.stores.every((s) => s.startsWith('5:')), isTrue,
          reason: 'only UID 5 was ever stored: ${client.stores}');
      expect(client.stores, hasLength(3));
    });

    test('flag batch when the server refuses keywords: the real UID is still '
        'treated as done (legacy), the no-UID message is not', () async {
      final client = _Client(storeThrows: true);
      final flag = await adapterFor(client)
          .applyFlagBatch([_msg(kNoValidImapUid), _msg('5')], 'Rule One');
      expect(flag.succeededIds, ['5']);
      expect(flag.failedIds.keys, [kNoValidImapUid]);
    });

    test('body fetch: no FETCH is sent for the constant', () async {
      final client = _Client();
      final m = _msg(kNoValidImapUid);
      final back = await adapterFor(client).fetchFullBody(m);
      expect(back, same(m));
      expect(client.fetches, 0);
      expect(await diagWith('IMAP/fetchFullBody'),
          contains('folder "Bulk Mail"'));
    });

    test('applyFlag (single) is skipped quietly for callers and logged',
        () async {
      final client = _Client();
      await adapterFor(client)
          .applyFlag(message: _msg(kNoValidImapUid), flagName: 'Rule One');
      expect(client.stores, isEmpty);
      expect(await diagWith('IMAP/applyFlag'), contains('folder "Bulk Mail"'));
    });

    test('partitionByMoveSurvival reports the constant FAILED even with no '
        'survivors; another unparseable id keeps the legacy success', () {
      final succeeded = <String>[];
      final failed = <String, String>{};
      GenericIMAPAdapter.partitionByMoveSurvival(
        messages: [_msg(kNoValidImapUid), _msg('not-a-uid'), _msg('9')],
        survivingUids: const [],
        sourceFolder: 'Bulk Mail',
        targetFolder: 'Trash',
        onSucceeded: succeeded.add,
        onFailed: (id, reason) => failed[id] = reason,
      );
      expect(failed.keys, [kNoValidImapUid]);
      expect(succeeded, ['not-a-uid', '9']);
    });
  });

  group('the shared helper', () {
    test('parseImapUid: integer ids parse, the constant and junk give null',
        () {
      expect(parseImapUid('42', folderName: 'F', context: 't'), 42);
      expect(parseImapUid(kNoValidImapUid, folderName: 'F', context: 't'),
          isNull);
      expect(parseImapUid('abc', folderName: 'F', context: 't'), isNull);
    });

    test('hasValidImapUid is false ONLY for the constant (a Gmail id is valid)',
        () {
      expect(
          hasValidImapUid(kNoValidImapUid, folderName: 'F', context: 't'),
          isFalse);
      expect(hasValidImapUid('18d4f2e8a1b2c3d4', folderName: 'F', context: 't'),
          isTrue);
      expect(hasValidImapUid('12', folderName: 'F', context: 't'), isTrue);
    });
  });

  group('persistence: the No Rule store refuses the constant (R-3)', () {
    late DatabaseTestHelper testHelper;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      await testHelper.createTestAccount('acct-a');
      // The database set-up clears the logger's cache; set the seam again.
      DiagnosticLogger.debugSetEnabled(true);
      DiagnosticLogger.debugSetDir(diagDir.path);
    });
    tearDown(() async => testHelper.tearDown());

    EmailActionResult result(EmailMessage email) => EmailActionResult(
          email: email,
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.none,
          success: true,
        );

    test('the no-UID message is kept in email_actions with its sequence '
        'number but is NOT listed as a No Rule item', () async {
      final provider = EmailScanProvider()
        ..initializeScanMode(mode: ScanMode.readOnly);
      provider.initializePersistence(
        scanResultStore: ScanResultStore(testHelper.dbHelper),
        unmatchedEmailStore: UnmatchedEmailStore(testHelper.dbHelper),
        databaseHelper: testHelper.dbHelper,
      );
      provider.setCurrentAccountId('acct-a');
      await provider.startScan(
          totalEmails: 2,
          scanType: 'manual',
          foldersScanned: ['Bulk Mail'],
          platformId: 'aol');
      provider.recordResult(result(EmailMessage(
        id: kNoValidImapUid,
        from: 'a@example.com',
        subject: 'no uid',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 10, 23),
        folderName: 'Bulk Mail',
        imapSequenceNumber: 7,
      )));
      provider.recordResult(result(_msg('5')));
      await provider.completeScan();

      final db = await testHelper.dbHelper.database;
      final actions = await db.query('email_actions', orderBy: 'id');
      expect(actions.map((r) => r['email_id']), [kNoValidImapUid, '5']);
      expect(actions.first['imap_sequence_number'], 7);
      expect(actions.last['imap_sequence_number'], isNull);

      final unmatched = await db.query('unmatched_emails');
      expect(unmatched.map((r) => r['provider_identifier_value']), ['5'],
          reason: 'one shared marker would collapse every no-UID message of '
              'a folder into one row; none is listed');
      expect(await diagWith('scan/persist-no-rule'),
          contains('folder "Bulk Mail"'));
    });
  });
}
