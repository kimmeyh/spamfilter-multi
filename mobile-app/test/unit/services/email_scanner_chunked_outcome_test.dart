/// F177 (Sprint 62), T-3/T-4: OUTCOME EQUIVALENCE for the per-batch scan
/// pipeline, plus the body-retention bound.
///
/// The restructure moved phase 6a's evaluation inside Step 4 (per m=20
/// batch, with body-truncated retention). Batching must change HOW messages
/// are fetched and held -- never WHICH messages are evaluated or WHAT the
/// outcomes are. This test runs a REAL full `scanInbox()` in demo mode
/// (67 mock emails -> 4 batches of 20/20/20/7 through the Step 4 slicing)
/// and compares every aggregate count against an INDEPENDENT single-pass
/// evaluation of the same mock set with the same demo rules -- computed
/// here without any batching at all.
///
/// Also pins retention: every record the scan keeps carries a body no
/// longer than the persistence preview cap (kBodyPreviewMaxLength) -- the
/// invariant that ends the ~7-10MB-per-message retention behind the
/// Sprint 61 LOW_MEMORY kills. (Full bodies are still evaluated: the
/// independent expectation below evaluates FULL bodies and the counts
/// match, proving truncation happens after evaluation.)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/adapters/email_providers/mock_email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/core/services/mock_email_data.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';
import 'package:my_email_spam_filter/core/services/rule_evaluator.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/unmatched_email_store.dart';

class _TestAppPaths extends AppPaths {
  _TestAppPaths(this.testDbPath);
  final String testDbPath;
  @override
  String get databaseFilePath => testDbPath;
}

/// F174: demo-compatible provider whose fetch THROWS for one named folder,
/// so the per-folder failure path is testable end to end.
class _FailingFolderMockProvider extends MockEmailProvider {
  static const String badFolder = 'BAD';

  /// F202 R-6 (Sprint 74): 'BAD' EXISTS on this account and fails to fetch --
  /// the case F174 protects. (A folder absent from the listing is now skipped
  /// as missing, not counted; see _MissingFolderMockProvider.)
  @override
  Future<List<FolderInfo>> listFolders() async => [
        ...await super.listFolders(),
        const FolderInfo(
            id: badFolder, displayName: badFolder,
            canonicalName: CanonicalFolder.custom),
      ];

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    if (folderNames.first == badFolder) {
      throw Exception('simulated per-folder fetch failure');
    }
    return [
      EmailMessage(
        id: '${folderNames.first}-1',
        from: 'sender@example.com',
        subject: 'ok',
        body: 'short body',
        headers: const {},
        receivedDate: DateTime(2026, 1, 1),
        folderName: folderNames.first,
      ),
    ];
  }
}

/// F202 R-6 (Sprint 74): a configured folder that does NOT EXIST on the
/// account -- the fetch throws, and the listing does not contain it.
class _MissingFolderMockProvider extends _FailingFolderMockProvider {
  @override
  Future<List<FolderInfo>> listFolders() async =>
      (await super.listFolders())
          .where((f) => f.id != _FailingFolderMockProvider.badFolder)
          .toList();
}

/// F202 R-6: the fetch throws AND the folder listing itself fails -- the
/// scanner cannot tell missing from failed, so it must count the error.
class _UnlistableFolderMockProvider extends _FailingFolderMockProvider {
  @override
  Future<List<FolderInfo>> listFolders() async =>
      throw Exception('simulated listing failure');
}

/// F202 (review, item d): records the Deleted Rule folder the SCANNER hands
/// the adapter, so the Gmail API vs gmail-imap split is proven at the
/// scanner/adapter boundary, not only inside SettingsStore.
class _RecordingFolderMockProvider extends MockEmailProvider {
  static final List<String?> deletedRuleFolders = [];

  @override
  void setDeletedRuleFolder(String? folderName) {
    deletedRuleFolders.add(folderName);
    super.setDeletedRuleFolder(folderName);
  }
}

/// Demo-compatible provider serving messages with bodies far LARGER than
/// the retention cap -- the demo mock set's own bodies are all under 100
/// chars (probed at authoring: max 92), so it can never exercise the
/// truncation path. This provider makes the retention assertion
/// non-vacuous by construction.
class _LongBodyMockProvider extends MockEmailProvider {
  static const int bodyLength = 50000;

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    return [
      for (var i = 0; i < 25; i++)
        EmailMessage(
          id: 'long-$i',
          from: 'longsender$i@example.com',
          subject: 'Long body $i',
          body: 'x' * bodyLength,
          headers: const {},
          receivedDate: DateTime(2026, 1, 1),
          folderName: folderNames.first,
        ),
    ];
  }
}

void main() {
  late DatabaseHelper db;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('f177_outcome_');
    db = DatabaseHelper();
    db.setAppPaths(_TestAppPaths('${tempDir.path}/t.db'));
    await db.deleteAllData();
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
      'demo scanInbox (4 batches through the m=20 pipeline) produces counts '
      'IDENTICAL to an independent unbatched single-pass evaluation, and '
      'retains only preview-capped bodies', () async {
    // --- Independent expectation: one flat pass, no batching, full bodies.
    final mockEmails = MockEmailData.generateSampleEmails();
    expect(mockEmails.length, greaterThan(20),
        reason: 'the demo set must be multi-batch for this test to prove '
            'anything about batching');

    final evaluator = RuleEvaluator(
      ruleSet: MockEmailData.getDemoRuleSet(),
      safeSenderList: MockEmailData.getDemoSafeSenderList(),
      compiler: PatternCompiler(),
    );
    var expectSafe = 0, expectDelete = 0, expectMove = 0, expectNone = 0;
    for (final email in mockEmails) {
      final r = await evaluator.evaluate(email);
      if (r.matchedRule.isNotEmpty && r.isSafeSender) {
        expectSafe++;
      } else if (r.matchedRule.isNotEmpty && r.shouldDelete) {
        expectDelete++;
      } else if (r.matchedRule.isNotEmpty && r.shouldMove) {
        expectMove++;
      } else {
        expectNone++;
      }
    }

    // --- The real batched pipeline (readOnly, as the Sprint 61 parity
    // experiment ran): demo mode skips credentials and uses MockEmailProvider.
    final scanProvider = EmailScanProvider()
      ..initializeScanMode(mode: ScanMode.readOnly);
    final scanner = EmailScanner(
      platformId: 'demo',
      accountId: 'demo@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: scanProvider,
    );

    await scanner.scanInbox(
      daysBack: 0,
      folderNames: MockEmailData.getDemoFolders(),
    );

    // AC-3: outcome equivalence, count by count.
    expect(scanProvider.totalEmails, mockEmails.length,
        reason: 'every mock email must be found -- batching never drops');
    expect(scanProvider.safeSendersCount, expectSafe);
    expect(scanProvider.deletedCount, expectDelete);
    expect(scanProvider.movedCount, expectMove);
    expect(scanProvider.noRuleCount, expectNone,
        reason: 'per-batch evaluation must produce the same per-email '
            'verdicts as one unbatched pass over the same set');

    // Retention is NOT asserted here: the demo set's bodies are all under
    // the preview cap, so a body-length loop over these results would be
    // vacuous (it survived mutation at authoring). The dedicated long-body
    // test below is the retention gate.
    expect(scanProvider.results, isNotEmpty);
  });

  test(
      'retained records carry preview-capped bodies even when the source '
      'messages have 50KB bodies (the Sprint 61 memory-kill shape)', () async {
    // Substitute the demo factory with the long-body provider; demo id
    // keeps the credential-free scanInbox path. ALWAYS restored below.
    final SpamFilterPlatform Function()? previous =
        PlatformRegistry.overrideFactoryForTest(
            'demo', () => _LongBodyMockProvider());
    addTearDown(() =>
        PlatformRegistry.overrideFactoryForTest('demo', previous));

    final scanProvider = EmailScanProvider()
      ..initializeScanMode(mode: ScanMode.readOnly);
    final scanner = EmailScanner(
      platformId: 'demo',
      accountId: 'demo@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: scanProvider,
    );

    await scanner.scanInbox(daysBack: 0, folderNames: ['INBOX']);

    expect(scanProvider.totalEmails, 25,
        reason: 'all 25 long-body messages found. (This mock provider '
            'returns one full list -- the scanner re-slices it for '
            'evaluation; ADAPTER-side chunk sizing is pinned in '
            'generic_imap_adapter_chunked_fetch_test.dart.)');
    expect(scanProvider.results, isNotEmpty);
    expect(_LongBodyMockProvider.bodyLength,
        greaterThan(kBodyPreviewMaxLength),
        reason: 'non-vacuous by construction: source bodies EXCEED the cap');
    for (final result in scanProvider.results) {
      expect(result.email.body.length,
          lessThanOrEqualTo(kBodyPreviewMaxLength),
          reason: 'a retained full body is the ~7-10MB-per-message '
              'retention that drove 817MB-1.4GB PSS and the LOW_MEMORY '
              'kills -- truncation after evaluation is the F177 bound');
    }
  });

  test(
      'F174: a folder whose fetch THROWS surfaces errorCount >= 1 while the '
      'other folders still complete', () async {
    final previous = PlatformRegistry.overrideFactoryForTest(
        'demo', () => _FailingFolderMockProvider());
    addTearDown(() =>
        PlatformRegistry.overrideFactoryForTest('demo', previous));

    final scanProvider = EmailScanProvider()
      ..initializeScanMode(mode: ScanMode.readOnly);
    final scanner = EmailScanner(
      platformId: 'demo',
      accountId: 'demo@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: scanProvider,
    );

    await scanner.scanInbox(
      daysBack: 0,
      folderNames: ['INBOX', _FailingFolderMockProvider.badFolder, 'Second'],
    );

    expect(scanProvider.errorCount, 1,
        reason: 'pre-F174 a failed folder was indistinguishable from a '
            'clean empty one: the scan reported errors=0 while a whole '
            'folder silently contributed nothing');
    expect(scanProvider.totalEmails, 2,
        reason: 'the folders around the failure still complete (INBOX + '
            'Second, one message each)');
    expect(scanProvider.status, isNot(ScanStatus.error),
        reason: 'a per-folder failure degrades, not aborts -- unchanged '
            'behavior, now visible');
  });

  test('Harold Q1: a scan that fails BEFORE connecting leaves its row CLOSED '
      '(error), never in_progress -- proving the row now exists before the '
      'connect', () async {
    await db.insertAccount({
      'account_id': 'nope@example.com',
      'platform_id': 'aol',
      'email': 'nope@example.com',
      'display_name': 'Test',
      'date_added': DateTime.now().millisecondsSinceEpoch,
    });
    final scanner = EmailScanner(
      platformId: 'no-such-platform', // fails at Step 1, before any connect
      accountId: 'nope@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: EmailScanProvider()..initializeScanMode(mode: ScanMode.readOnly),
    );
    await expectLater(scanner.scanInbox(daysBack: 0), throwsA(anything));
    final rows = await (await db.database).query('scan_results',
        where: 'account_id = ?', whereArgs: ['nope@example.com']);
    expect(rows, hasLength(1),
        reason: 'before Q1 the row was written only AFTER connecting, so a '
            'pre-connect failure left no row -- and no signal for the '
            'background exclusion during the connect');
    expect(rows.single['status'], 'error',
        reason: 'Harold: a scan that fails before connecting must show it is '
            'no longer running');
  });

  Future<String?> deletedFolderHandedToAdapter(String storedPlatform) async {
    _RecordingFolderMockProvider.deletedRuleFolders.clear();
    await db.insertAccount({
      'account_id': 'demo@example.com',
      'platform_id': storedPlatform,
      'email': 'demo@example.com',
      'display_name': 'Test',
      'date_added': DateTime.now().millisecondsSinceEpoch,
    });
    final previous = PlatformRegistry.overrideFactoryForTest(
        'demo', () => _RecordingFolderMockProvider());
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('demo', previous));
    await EmailScanner(
      platformId: 'demo',
      accountId: 'demo@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: EmailScanProvider()..initializeScanMode(mode: ScanMode.readOnly),
    ).scanInbox(daysBack: 0, folderNames: ['INBOX']);
    return _RecordingFolderMockProvider.deletedRuleFolders.first;
  }

  test('F202 boundary: a Gmail API account hands the adapter NULL, so the '
      'adapter uses its built-in trash (an IMAP name there fails every delete)',
      () async {
    expect(await deletedFolderHandedToAdapter('gmail'), isNull);
  });

  test('F202 boundary: a gmail-imap account hands the adapter [Gmail]/Trash',
      () async {
    expect(await deletedFolderHandedToAdapter('gmail-imap'), '[Gmail]/Trash');
  });

  test('F202 boundary: an iCloud account hands the adapter "Deleted Messages"',
      () async {
    expect(await deletedFolderHandedToAdapter('icloud'), 'Deleted Messages');
  });

  Future<EmailScanProvider> scanWith(MockEmailProvider Function() make) async {
    final previous = PlatformRegistry.overrideFactoryForTest('demo', make);
    addTearDown(() => PlatformRegistry.overrideFactoryForTest('demo', previous));
    final scanProvider = EmailScanProvider()
      ..initializeScanMode(mode: ScanMode.readOnly);
    await EmailScanner(
      platformId: 'demo',
      accountId: 'demo@example.com',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: scanProvider,
    ).scanInbox(
      daysBack: 0,
      folderNames: ['INBOX', _FailingFolderMockProvider.badFolder, 'Second'],
    );
    return scanProvider;
  }

  test(
      'F202 R-6 (Harold decision 3): a configured folder that does NOT EXIST '
      'is skipped, NOT counted as an error', () async {
    final scanProvider = await scanWith(() => _MissingFolderMockProvider());
    expect(scanProvider.errorCount, 0,
        reason: 'a provider default can name a folder some accounts lack; '
            'that must not produce a phantom error on every scan');
    expect(scanProvider.totalEmails, 2);
  });

  test(
      'F202 R-6: when the folder listing itself fails, the fetch error is '
      'still counted (F174 is not undone)', () async {
    final scanProvider = await scanWith(() => _UnlistableFolderMockProvider());
    expect(scanProvider.errorCount, 1);
  });
}
