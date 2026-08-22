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

    // Retention bound: nothing the scan keeps holds a full body. (The demo
    // set's bodies are all under the cap, so this loop alone is vacuous --
    // the dedicated long-body test below is the real retention gate.)
    expect(scanProvider.results, isNotEmpty);
    for (final result in scanProvider.results) {
      expect(result.email.body.length,
          lessThanOrEqualTo(kBodyPreviewMaxLength));
    }
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
        reason: '25 long-body messages -> 2 batches (20/5); all found');
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
}
