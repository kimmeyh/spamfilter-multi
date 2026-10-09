/// F258 (Sprint 77): BEHAVIOR gate -- every Gmail label write the adapter
/// actually sends is a valid label ID, and is a request Gmail would accept.
///
/// This is NOT a source-text scan. It drives the public write paths
/// (`deleteMessage`, `moveMessage`, `moveToFolder`, `moveToFolderBatch`,
/// `takeActionBatch`) against a fake `GmailApi` that records every
/// `addLabelIds` / `removeLabelIds` and asserts each ID is a system label or
/// a resolved custom ID (`Label_*`), never a folder NAME such as "Unwanted"
/// (the F258 defect).
///
/// Sprint 77 Phase 5.1.2 F-PRECHECK extended it in two ways:
/// - the fake REJECTS a request that adds and removes the same label, as
///   Gmail does (400 "Cannot both add and remove the same label"), so every
///   test through it also guards that invariant;
/// - single and batch delete must send the same label change (parity).
///
/// What this does NOT catch: a write path not exercised here (a new call
/// site needs its own test), and Gmail rejecting a request for any other
/// reason.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart'
    show FilterAction;
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/core/models/email_message.dart';

/// Gmail refuses a request that adds and removes the same label; so does
/// this fake, so the invariant is checked on every write.
void _rejectLikeGmail(List<String>? add, List<String>? remove) {
  final both = (add ?? const []).toSet().intersection((remove ?? const []).toSet());
  if (both.isNotEmpty) {
    throw gmail.DetailedApiRequestError(
        400, 'Cannot both add and remove the same label: $both');
  }
}

/// Fake Gmail API that records all addLabelIds/removeLabelIds calls
class FakeLabelIdGmailApi implements gmail.GmailApi {
  final List<List<String>?> allAddLabelIds = [];
  final List<List<String>?> allRemoveLabelIds = [];

  @override
  late final users = FakeLabelIdUsersResource(this);

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeLabelIdGmailApi does not implement ${invocation.memberName}');
  }
}

class FakeLabelIdUsersResource implements gmail.UsersResource {
  final FakeLabelIdGmailApi api;

  FakeLabelIdUsersResource(this.api);

  @override
  late final messages = FakeLabelIdMessagesResource(api);
  @override
  late final labels = FakeLabelIdLabelsResource(api);

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeLabelIdUsersResource does not implement ${invocation.memberName}');
  }
}

class FakeLabelIdMessagesResource implements gmail.UsersMessagesResource {
  final FakeLabelIdGmailApi api;

  FakeLabelIdMessagesResource(this.api);

  @override
  Future<gmail.Message> modify(
    gmail.ModifyMessageRequest request,
    String userId,
    String id, {
    String? $fields,
  }) async {
    _rejectLikeGmail(request.addLabelIds, request.removeLabelIds);
    api.allAddLabelIds.add(request.addLabelIds);
    api.allRemoveLabelIds.add(request.removeLabelIds);
    return gmail.Message(id: id);
  }

  @override
  Future<void> batchModify(
    gmail.BatchModifyMessagesRequest request,
    String userId, {
    String? $fields,
  }) async {
    _rejectLikeGmail(request.addLabelIds, request.removeLabelIds);
    api.allAddLabelIds.add(request.addLabelIds);
    api.allRemoveLabelIds.add(request.removeLabelIds);
  }

  @override
  Future<gmail.Message> trash(String userId, String id, {String? $fields}) async {
    api.allAddLabelIds.add(['TRASH']);
    api.allRemoveLabelIds.add(['INBOX', 'UNREAD']);
    return gmail.Message(id: id);
  }

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeLabelIdMessagesResource does not implement ${invocation.memberName}');
  }
}

class FakeLabelIdLabelsResource implements gmail.UsersLabelsResource {
  final FakeLabelIdGmailApi api;

  FakeLabelIdLabelsResource(this.api);

  @override
  Future<gmail.ListLabelsResponse> list(String userId, {String? $fields}) async {
    return gmail.ListLabelsResponse(
      labels: [
        gmail.Label(name: 'Unwanted', id: 'Label_7'),
        gmail.Label(name: 'Archive', id: 'Label_10'),
      ],
    );
  }

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeLabelIdLabelsResource does not implement ${invocation.memberName}');
  }
}

/// Valid label IDs (system or resolved from API)
bool _isValidLabelId(String id) {
  return const {
    'INBOX',
    'SPAM',
    'TRASH',
    'SENT',
    'DRAFT',
    'STARRED',
    'IMPORTANT',
    'UNREAD',
    'CHAT',
  }.contains(id) ||
      id.startsWith('CATEGORY_') ||
      id.startsWith('Label_');
}

void main() {
  group('F258 Policy Gate: Gmail label writes use only resolved IDs', () {
    late GmailApiAdapter adapter;
    late FakeLabelIdGmailApi fakeApi;

    setUp(() {
      adapter = GmailApiAdapter();
      fakeApi = FakeLabelIdGmailApi();
      adapter.debugSetGmailApi(fakeApi);
    });

    test('deleteMessage with custom label sends only resolved IDs', () async {
      adapter.setDeletedRuleFolder('Unwanted');
      final message = EmailMessage(
        id: 'test-1',
        from: 'sender@example.com',
        subject: 'Test',
        body: 'Body',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      await adapter.deleteMessage(message);

      // All addLabelIds must be valid (resolved or system)
      for (final addIds in fakeApi.allAddLabelIds) {
        if (addIds != null) {
          for (final id in addIds) {
            expect(_isValidLabelId(id), true,
                reason: 'addLabelIds must contain resolved IDs or system labels, not names like "Unwanted"');
          }
        }
      }
    });

    test('moveMessage with custom label sends only resolved IDs', () async {
      final message = EmailMessage(
        id: 'test-2',
        from: 'sender@example.com',
        subject: 'Test',
        body: 'Body',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      await adapter.moveMessage(message, 'Archive');

      for (final addIds in fakeApi.allAddLabelIds) {
        if (addIds != null) {
          for (final id in addIds) {
            expect(_isValidLabelId(id), true,
                reason: 'moveMessage must send resolved label IDs, not names');
          }
        }
      }
    });

    test('moveToFolder with custom labels sends only resolved IDs', () async {
      final message = EmailMessage(
        id: 'test-3',
        from: 'sender@example.com',
        subject: 'Test',
        body: 'Body',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'Unwanted',
      );

      await adapter.moveToFolder(message: message, targetFolder: 'Archive');

      for (final addIds in fakeApi.allAddLabelIds) {
        if (addIds != null) {
          for (final id in addIds) {
            expect(_isValidLabelId(id), true,
                reason: 'moveToFolder must send resolved label IDs');
          }
        }
      }
      for (final removeIds in fakeApi.allRemoveLabelIds) {
        if (removeIds != null) {
          for (final id in removeIds) {
            expect(_isValidLabelId(id), true,
                reason: 'removeLabel IDs must also be resolved or system');
          }
        }
      }
    });

    test('moveToFolderBatch with custom labels sends only resolved IDs', () async {
      final messages = [
        EmailMessage(
          id: 'test-4a',
          from: 'sender@example.com',
          subject: 'Test',
          body: 'Body',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'INBOX',
        ),
        EmailMessage(
          id: 'test-4b',
          from: 'sender@example.com',
          subject: 'Test',
          body: 'Body',
          headers: const {},
          receivedDate: DateTime.now(),
          folderName: 'Unwanted',
        ),
      ];

      await adapter.moveToFolderBatch(messages, 'Archive');

      for (final addIds in fakeApi.allAddLabelIds) {
        if (addIds != null) {
          for (final id in addIds) {
            expect(_isValidLabelId(id), true,
                reason: 'batch operations must send resolved IDs');
          }
        }
      }
    });

    // F-PRECHECK (Sprint 77 Phase 5.1.2, MEDIUM): scanning the custom Deleted
    // Rule label itself, a block rule moves a message from "Unwanted" to
    // "Unwanted". The source ID was put in `remove` while the same ID was in
    // `add`, Gmail refused it, and the whole source group failed.
    // What this does NOT catch: Gmail refusing the request for another reason.
    EmailMessage msgIn(String folder, String id) => EmailMessage(
          id: id,
          from: 'sender@example.com',
          subject: 'Test',
          body: 'Body',
          headers: const {},
          receivedDate: DateTime(2026, 10, 7),
          folderName: folder,
        );

    test('source == target custom label: never adds and removes the same label '
        '(single, batch and delete paths)', () async {
      await adapter.moveToFolder(
          message: msgIn('Unwanted', 's1'), targetFolder: 'Unwanted');
      final batch = await adapter.moveToFolderBatch(
          [msgIn('Unwanted', 's2'), msgIn('Unwanted', 's3')], 'Unwanted');
      expect(batch.failedIds, isEmpty, reason: '${batch.failedIds}');
      expect(batch.successCount, 2);
      adapter.setDeletedRuleFolder('Unwanted');
      await adapter.deleteMessage(msgIn('Unwanted', 's4'));
      final del = await adapter.takeActionBatch(
          [msgIn('Unwanted', 's5')], FilterAction.delete);
      expect(del.failedIds, isEmpty, reason: '${del.failedIds}');
      for (final add in fakeApi.allAddLabelIds) {
        expect(add, ['Label_7']);
      }
    });

    test('the pure step drops the target from remove, whatever produced it', () {
      final r = GmailApiAdapter.withResolvedIds(
        base: (add: const ['Label_7'], remove: const ['INBOX', 'UNREAD', 'Label_7']),
        targetId: 'Label_7',
        sourceId: 'Label_7',
      );
      expect(r.add, ['Label_7']);
      expect(r.remove, unorderedEquals(['INBOX', 'UNREAD']));
      final moved = GmailApiAdapter.withResolvedIds(
        base: (add: const ['Label_10'], remove: const ['INBOX', 'UNREAD']),
        targetId: 'Label_10',
        sourceId: 'Label_7',
      );
      expect(moved.remove, unorderedEquals(['INBOX', 'UNREAD', 'Label_7']),
          reason: 'Q17: a different custom source is still removed');
    });

    // F-PRECHECK (Sprint 77 Phase 5.1.2, LOW): the single delete removed only
    // INBOX and UNREAD, so a "deleted" Spam message kept SPAM and stayed in
    // Spam, while the batch delete removed it. One shared helper; this pins
    // the parity.
    // What this does NOT catch: the TRASH default (Gmail's own trash() call,
    // not a label change, on the single path).
    for (final source in ['SPAM', 'INBOX', 'Archive']) {
      test('delete to a custom folder: single and batch send the same label '
          'change for a message in $source', () async {
        adapter.setDeletedRuleFolder('Unwanted');
        await adapter.deleteMessage(msgIn(source, 'p1'));
        final single = (
          add: fakeApi.allAddLabelIds.last!.toSet(),
          remove: fakeApi.allRemoveLabelIds.last!.toSet(),
        );
        final result =
            await adapter.takeActionBatch([msgIn(source, 'p2')], FilterAction.delete);
        expect(result.failedIds, isEmpty);
        final batch = (
          add: fakeApi.allAddLabelIds.last!.toSet(),
          remove: fakeApi.allRemoveLabelIds.last!.toSet(),
        );
        expect(single.add, equals(batch.add));
        expect(single.remove, equals(batch.remove));
        if (source == 'SPAM') {
          expect(single.remove, contains('SPAM'),
              reason: 'a deleted Spam message must leave Spam');
        }
        if (source == 'Archive') {
          expect(single.remove, contains('Label_10'),
              reason: 'Q17: the custom source label is removed');
        }
      });
    }
  });
}
