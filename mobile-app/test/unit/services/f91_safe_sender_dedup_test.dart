/// F91 (Sprint 39) Phase 2 tests: post-safe-sender-move source-folder dedup
/// (server-acknowledged-but-not-performed-move reconciliation; confirmed
/// provider-agnostic, F146 Sprint 55).
///
/// F149 (Sprint 57) tests: pre-move target-folder duplicate check (AOL
/// Inbox/Bulk oscillation fix). The symmetric counterpart to F91 -- F91
/// cleans up the SOURCE folder after a move, F149 checks the TARGET folder
/// before one, using the same searchByMessageId capability and the same
/// fake-IMAP harness.
///
/// EmailScanner.scanInbox is orchestration-heavy (real platform adapter,
/// credentials, IMAP connection) and is exercised in Phase 5.3 manual
/// testing per the Sprint 37/38 retrospectives. These tests target the
/// F91-specific dedup surface via the `@visibleForTesting`
/// `dedupSafeSenderSourceFolder` entry point and a fake IMAP platform with
/// mocked search/move responses (no live server).
///
/// F91 covered scenarios:
///   - clean move (no source duplicate -> no dedup, count stays 0)
///   - AOL re-injection (source duplicate exists -> moved to Trash, counted)
///   - Message-ID missing (skip, no search issued)
///   - Gmail OAuth platform (skip entirely -- labels not folders)
///   - source folder == target folder (skip)
///   - multiple messages across folders (aggregate count)
///   - search/move failure degrades to a no-op (scan never breaks)
///
/// F149 covered scenarios:
///   - candidate already in target folder -> skipped, not kept
///   - candidate with no target-folder match -> kept, proceeds normally
///   - Message-ID missing -> kept (cannot check, no false block)
///   - Gmail OAuth platform (skip entirely -- returns candidates unchanged)
///   - search failure degrades to fail-open (candidate kept, not blocked)
///   - multiple candidates, mixed outcomes
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/batch_action_result.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/models/evaluation_result.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/providers/rule_set_provider.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';

/// Fake IMAP platform. Subclasses GenericIMAPAdapter so the scanner's
/// `platform is GenericIMAPAdapter` gate passes, but overrides the two
/// methods the dedup step calls so no real IMAP connection is needed.
class _FakeImapPlatform extends GenericIMAPAdapter {
  /// folder -> (messageId -> matches to return from searchByMessageId)
  final Map<String, Map<String, List<EmailMessage>>> searchResponses;

  /// Whether searchByMessageId should throw (to test failure degradation).
  final bool throwOnSearch;

  /// Records each (folder, messageId) search performed.
  final List<String> searchCalls = [];

  /// Records each batch move (targetFolder -> moved message ids).
  final List<MapEntry<String, List<String>>> moveCalls = [];

  _FakeImapPlatform({
    this.searchResponses = const {},
    this.throwOnSearch = false,
  }) : super(imapHost: 'fake.imap.test', platformId: 'aol');

  @override
  Future<List<EmailMessage>> searchByMessageId(
    String folderName,
    String messageId,
  ) async {
    searchCalls.add('$folderName|$messageId');
    if (throwOnSearch) {
      throw Exception('simulated IMAP search failure');
    }
    return searchResponses[folderName]?[messageId] ?? const [];
  }

  @override
  Future<BatchActionResult> moveToFolderBatch(
    List<EmailMessage> messages,
    String targetFolder,
  ) async {
    final ids = messages.map((m) => m.id).toList();
    moveCalls.add(MapEntry(targetFolder, ids));
    return BatchActionResult.allSuccess(ids);
  }
}

/// Minimal non-IMAP platform to exercise the Gmail-OAuth / non-IMAP skip.
/// Uses BatchOperationsMixin's default searchByMessageId (returns empty).
class _FakeGmailPlatform with BatchOperationsMixin implements SpamFilterPlatform {
  bool searchCalled = false;

  @override
  String get platformId => 'gmail';
  @override
  String get displayName => 'Gmail';
  @override
  AuthMethod get supportedAuthMethod => AuthMethod.oauth2;

  @override
  Future<List<EmailMessage>> searchByMessageId(String f, String m) async {
    searchCalled = true;
    return const [];
  }

  @override
  void setDeletedRuleFolder(String? folderName) {}
  @override
  Future<void> loadCredentials(Credentials credentials) async {}
  @override
  Future<List<EmailMessage>> fetchMessages(
          {required int daysBack, required List<String> folderNames}) async =>
      const [];
  @override
  Future<List<EvaluationResult>> applyRules(
          {required List<EmailMessage> messages,
          required Map<String, Pattern> compiledRegex}) async =>
      const [];
  @override
  Future<void> takeAction(
      {required EmailMessage message, required FilterAction action}) async {}
  @override
  Future<void> moveToFolder(
      {required EmailMessage message, required String targetFolder}) async {}
  @override
  Future<void> markAsRead({required EmailMessage message}) async {}
  @override
  Future<void> applyFlag(
      {required EmailMessage message, required String flagName}) async {}
  @override
  Future<List<FolderInfo>> listFolders() async => const [];
  @override
  Future<ConnectionStatus> testConnection() async =>
      ConnectionStatus.success();
  @override
  Future<void> disconnect() async {}
}

EmailMessage _msg({
  required String id,
  String from = 'safe@example.com',
  String folder = 'Bulk Mail',
  String? messageId,
}) {
  return EmailMessage(
    id: id,
    from: from,
    subject: 'subject',
    body: '',
    headers: const {},
    receivedDate: DateTime(2026, 5, 25),
    folderName: folder,
    messageIdHeader: messageId,
  );
}

void main() {
  late EmailScanner scanner;
  late EmailScanProvider scanProvider;

  setUp(() {
    scanProvider = EmailScanProvider();
    scanner = EmailScanner(
      platformId: 'aol',
      accountId: 'test-account',
      ruleSetProvider: RuleSetProvider(),
      scanProvider: scanProvider,
    );
  });

  group('F91 Phase 2 -- post-safe-sender-move dedup', () {
    test('clean move (no source duplicate) does not dedup', () async {
      final platform = _FakeImapPlatform(searchResponses: const {});
      final moved = [_msg(id: '10', messageId: '<a@aol.com>')];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      // A search is issued, but it returns no match, so nothing is moved.
      expect(platform.searchCalls, ['Bulk Mail|<a@aol.com>']);
      expect(platform.moveCalls, isEmpty);
      expect(scanProvider.safeSenderDedupCount, 0);
    });

    test('AOL re-injection: source duplicate is moved to Trash and counted',
        () async {
      // AOL re-injected a copy with a NEW UID (99) but the SAME Message-ID.
      final reinjected = _msg(id: '99', messageId: '<a@aol.com>');
      final platform = _FakeImapPlatform(searchResponses: {
        'Bulk Mail': {
          '<a@aol.com>': [reinjected],
        },
      });
      final moved = [_msg(id: '10', messageId: '<a@aol.com>')];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      expect(platform.searchCalls, ['Bulk Mail|<a@aol.com>']);
      expect(platform.moveCalls.length, 1);
      expect(platform.moveCalls.first.key, 'Trash');
      expect(platform.moveCalls.first.value, ['99']);
      expect(scanProvider.safeSenderDedupCount, 1);
    });

    test('Message-ID missing -> skipped, no search issued', () async {
      final platform = _FakeImapPlatform();
      final moved = [_msg(id: '10', messageId: null)];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      expect(platform.searchCalls, isEmpty);
      expect(platform.moveCalls, isEmpty);
      expect(scanProvider.safeSenderDedupCount, 0);
    });

    test('Gmail OAuth (non-IMAP) platform is skipped entirely', () async {
      final platform = _FakeGmailPlatform();
      final moved = [_msg(id: '10', messageId: '<a@gmail.com>')];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      // The IMAP-only gate short-circuits before any search.
      expect(platform.searchCalled, isFalse);
      expect(scanProvider.safeSenderDedupCount, 0);
    });

    test('source folder == target folder -> skipped', () async {
      final platform = _FakeImapPlatform();
      // Message was "moved" within INBOX (source == target).
      final moved = [_msg(id: '10', folder: 'INBOX', messageId: '<a@aol.com>')];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      expect(platform.searchCalls, isEmpty);
      expect(platform.moveCalls, isEmpty);
      expect(scanProvider.safeSenderDedupCount, 0);
    });

    test('aggregates dedup count across multiple messages and folders',
        () async {
      final platform = _FakeImapPlatform(searchResponses: {
        'Bulk Mail': {
          '<a@aol.com>': [_msg(id: '201', messageId: '<a@aol.com>')],
          '<b@aol.com>': [_msg(id: '202', messageId: '<b@aol.com>')],
        },
        'Spam': {
          '<c@aol.com>': [_msg(id: '203', folder: 'Spam', messageId: '<c@aol.com>')],
        },
      });
      final moved = [
        _msg(id: '1', folder: 'Bulk Mail', messageId: '<a@aol.com>'),
        _msg(id: '2', folder: 'Bulk Mail', messageId: '<b@aol.com>'),
        _msg(id: '3', folder: 'Spam', messageId: '<c@aol.com>'),
        _msg(id: '4', folder: 'Bulk Mail', messageId: '<clean@aol.com>'), // no dup
      ];

      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      expect(platform.searchCalls.length, 4);
      expect(scanProvider.safeSenderDedupCount, 3);
      expect(platform.moveCalls.length, 3);
    });

    test('search failure degrades to a no-op (scan never breaks)', () async {
      final platform = _FakeImapPlatform(throwOnSearch: true);
      final moved = [_msg(id: '10', messageId: '<a@aol.com>')];

      // Should not throw.
      await scanner.dedupSafeSenderSourceFolder(
        platform: platform,
        movedMessages: moved,
        safeSenderTarget: 'INBOX',
        deletedRuleFolder: 'Trash',
        isLiveScan: false,
      );

      expect(platform.moveCalls, isEmpty);
      expect(scanProvider.safeSenderDedupCount, 0);
    });
  });

  group('F149 -- pre-move target-folder duplicate check', () {
    test('candidate already in target folder is skipped, not kept', () async {
      // A message with this Message-ID is already sitting in INBOX (e.g.
      // the original promotion from a prior scan cycle, or AOL has not
      // finished demoting it yet).
      final existingInInbox = _msg(id: '50', folder: 'INBOX', messageId: '<a@aol.com>');
      final platform = _FakeImapPlatform(searchResponses: {
        'INBOX': {
          '<a@aol.com>': [existingInInbox],
        },
      });
      final candidate = _msg(id: '10', folder: 'Bulk Mail', messageId: '<a@aol.com>');

      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [candidate],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      expect(platform.searchCalls, ['INBOX|<a@aol.com>']);
      expect(kept, isEmpty);
    });

    test('candidate with no target-folder match is kept', () async {
      final platform = _FakeImapPlatform(searchResponses: const {});
      final candidate = _msg(id: '10', folder: 'Bulk Mail', messageId: '<a@aol.com>');

      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [candidate],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      expect(platform.searchCalls, ['INBOX|<a@aol.com>']);
      expect(kept, [candidate]);
    });

    test('Message-ID missing -> kept, no search issued (cannot check)', () async {
      final platform = _FakeImapPlatform();
      final candidate = _msg(id: '10', folder: 'Bulk Mail', messageId: null);

      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [candidate],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      expect(platform.searchCalls, isEmpty);
      expect(kept, [candidate]);
    });

    test('Gmail OAuth (non-IMAP) platform returns candidates unchanged', () async {
      final platform = _FakeGmailPlatform();
      final candidate = _msg(id: '10', folder: 'Bulk Mail', messageId: '<a@gmail.com>');

      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [candidate],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      // The IMAP-only gate short-circuits before any search.
      expect(platform.searchCalled, isFalse);
      expect(kept, [candidate]);
    });

    test('search failure fails OPEN -- candidate is kept, not blocked', () async {
      final platform = _FakeImapPlatform(throwOnSearch: true);
      final candidate = _msg(id: '10', folder: 'Bulk Mail', messageId: '<a@aol.com>');

      // Should not throw, and must not strand a genuine safe-sender
      // candidate outside Inbox because of a transient IMAP error.
      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [candidate],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      expect(kept, [candidate]);
    });

    test('mixed outcomes: some kept, some skipped, across multiple candidates',
        () async {
      final platform = _FakeImapPlatform(searchResponses: {
        'INBOX': {
          '<already-there@aol.com>': [
            _msg(id: '99', folder: 'INBOX', messageId: '<already-there@aol.com>'),
          ],
          // no entry for '<clean@aol.com>' -> empty match -> kept
        },
      });
      final alreadyThere =
          _msg(id: '1', folder: 'Bulk Mail', messageId: '<already-there@aol.com>');
      final clean = _msg(id: '2', folder: 'Bulk Mail', messageId: '<clean@aol.com>');
      final noMessageId = _msg(id: '3', folder: 'Bulk Mail', messageId: null);

      final kept = await scanner.filterAlreadyInTargetFolder(
        platform: platform,
        candidates: [alreadyThere, clean, noMessageId],
        safeSenderTarget: 'INBOX',
        isLiveScan: false,
      );

      expect(kept, containsAll([clean, noMessageId]));
      expect(kept.contains(alreadyThere), isFalse);
      expect(kept.length, 2);
    });
  });
}
