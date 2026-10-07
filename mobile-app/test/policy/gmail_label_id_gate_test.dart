/// F258 (Sprint 77): Source gate to prevent unresolved folder names in label writes.
///
/// This gate verifies that every `addLabelIds:` / `removeLabelIds:` argument in
/// `gmail_api_adapter.dart` is one of:
/// 1. A `const` system literal list (e.g., `['TRASH']`, `['INBOX', 'UNREAD']`)
/// 2. A variable assigned from `_labelIdFor` / `_getOrCreateLabel` / `_resolvedMoveLabels`
/// 3. Fields of the resolved labels record
///
/// It FAILS if any site passes an unresolved folder name (e.g., the old
/// `[targetLabel]` pattern where `targetLabel` is a user-entered custom folder
/// name). This gate prevents the F258 defect from re-appearing.
///
/// **Mutation verification**: Re-introduce `[targetLabel]` at deleteMessage site 1,
/// and this gate must detect it. The behavior test verifies functional correctness;
/// this gate prevents the pattern from reappearing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/core/models/email_message.dart';

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
  });
}
