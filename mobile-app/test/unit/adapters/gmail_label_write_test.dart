/// F258 (Sprint 77): Gmail moves to a custom label send the label ID, not its NAME.
///
/// **Problem**: When a rule targets a custom Gmail label (e.g., "Unwanted"),
/// the adapter sends the label NAME instead of its ID, causing "400 Invalid
/// label" failures on every move or delete to a custom folder.
///
/// **Solution**: Route every label write through the existing `_labelIdFor`
/// resolver to convert names to IDs. This prevents the defect class from
/// re-appearing at any write site.
///
/// **Tests**: These tests are written FIRST (before the fix) and verify
/// the current failure modes, then verify the fix at all five write sites.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';

/// Fake GmailApi that captures modify/batch requests for assertion
class FakeGmailApi implements gmail.GmailApi {
  final List<gmail.ModifyMessageRequest> modifyRequests = [];
  final List<gmail.BatchModifyMessagesRequest> batchRequests = [];
  int listCalls = 0;

  /// Map of label names to IDs for this fake
  final Map<String, String> labelMap;

  FakeGmailApi({required this.labelMap});

  @override
  late final users = FakeUsersResource(this);

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeGmailApi does not implement ${invocation.memberName}',
    );
  }
}

class FakeUsersResource implements gmail.UsersResource {
  final FakeGmailApi api;

  FakeUsersResource(this.api);

  @override
  late final messages = FakeMessagesResource(api);
  @override
  late final labels = FakeLabelsResource(api);

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeUsersResource does not implement ${invocation.memberName}',
    );
  }
}

class FakeMessagesResource implements gmail.UsersMessagesResource {
  final FakeGmailApi api;

  FakeMessagesResource(this.api);

  @override
  Future<gmail.Message> modify(
    gmail.ModifyMessageRequest request,
    String userId,
    String id, {
    String? $fields,
  }) async {
    api.modifyRequests.add(request);
    return gmail.Message(id: id);
  }

  @override
  Future<void> batchModify(
    gmail.BatchModifyMessagesRequest request,
    String userId, {
    String? $fields,
  }) async {
    api.batchRequests.add(request);
  }

  @override
  Future<gmail.Message> trash(String userId, String id, {String? $fields}) async {
    // For trash, we simulate adding TRASH label and removing INBOX/UNREAD
    api.modifyRequests.add(
      gmail.ModifyMessageRequest(
        addLabelIds: ['TRASH'],
        removeLabelIds: ['INBOX', 'UNREAD'],
      ),
    );
    return gmail.Message(id: id);
  }

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeMessagesResource does not implement ${invocation.memberName}',
    );
  }
}

class FakeLabelsResource implements gmail.UsersLabelsResource {
  final FakeGmailApi api;

  FakeLabelsResource(this.api);

  @override
  Future<gmail.ListLabelsResponse> list(String userId, {String? $fields}) async {
    api.listCalls++;
    final labels = api.labelMap.entries
        .map((e) => gmail.Label(name: e.key, id: e.value))
        .toList();
    return gmail.ListLabelsResponse(labels: labels);
  }

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeLabelsResource does not implement ${invocation.memberName}',
    );
  }
}

EmailMessage _testMessage({
  String id = 'test-message-1',
  String folderName = 'INBOX',
}) =>
    EmailMessage(
      id: id,
      from: 'sender@example.com',
      subject: 'Test Subject',
      body: 'Test body',
      headers: const {},
      receivedDate: DateTime(2026, 10, 6),
      folderName: folderName,
    );

void main() {
  group('F258: Gmail custom label writes use label ID not name', () {
    late GmailApiAdapter adapter;
    late FakeGmailApi fakeApi;

    setUp(() {
      adapter = GmailApiAdapter();
      // Set a custom deleted rule folder so deleteMessage tests it
      adapter.setDeletedRuleFolder('Unwanted');

      fakeApi = FakeGmailApi(
        labelMap: {
          'Unwanted': 'Label_7',
          'Archive': 'Label_10',
          'Work': 'Label_15',
        },
      );
      adapter.debugSetGmailApi(fakeApi);
    });

    group('T-1 AC-1: deleteMessage resolves custom target label ID', () {
      test('deleteMessage sends label ID (not name) for custom folder', () async {
        final message = _testMessage();

        await adapter.deleteMessage(message);

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('Label_7'),
            reason: 'should send the resolved label ID, not the name "Unwanted"');
        expect(request.addLabelIds, isNot(contains('Unwanted')),
            reason: 'should NOT send the label name');
      });

      test('deleteMessage with TRASH (default) uses built-in trash API', () async {
        adapter.setDeletedRuleFolder(null); // Reset to default TRASH
        final message = _testMessage();

        await adapter.deleteMessage(message);

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('TRASH'),
            reason: 'default delete should use TRASH system label');
      });
    });

    group('T-1 AC-2: moveMessage resolves custom target label ID', () {
      test('moveMessage sends label ID (not name) for custom folder', () async {
        final message = _testMessage();

        await adapter.moveMessage(message, 'Unwanted');

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('Label_7'),
            reason: 'should send the resolved label ID, not the name');
        expect(request.addLabelIds, isNot(contains('Unwanted')));
      });

      test('moveMessage handles system labels without API call', () async {
        final message = _testMessage();

        await adapter.moveMessage(message, 'SPAM');

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('SPAM'));
      });
    });

    group('T-1 AC-3: moveToFolder resolves custom target and source labels', () {
      test('moveToFolder sends custom target label ID', () async {
        final message = _testMessage(folderName: 'INBOX');

        await adapter.moveToFolder(message: message, targetFolder: 'Unwanted');

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('Label_7'),
            reason: 'custom target should resolve to its ID');
      });

      test('moveToFolder removes custom source label when target is different',
          () async {
        final message = _testMessage(folderName: 'Unwanted');

        await adapter.moveToFolder(message: message, targetFolder: 'Archive');

        expect(fakeApi.modifyRequests, isNotEmpty);
        final request = fakeApi.modifyRequests.last;
        // Should add Archive ID and remove Unwanted ID
        expect(request.addLabelIds, contains('Label_10'),
            reason: 'target label ID should be added');
        expect(request.removeLabelIds, contains('Label_7'),
            reason: 'source custom label ID should be removed (Q17)');
      });
    });

    group('T-1 AC-4: moveToFolderBatch resolves labels for custom folders', () {
      test('moveToFolderBatch sends custom target label ID', () async {
        final messages = [
          _testMessage(id: '1'),
          _testMessage(id: '2'),
        ];

        final result = await adapter.moveToFolderBatch(messages, 'Unwanted');

        expect(result.successCount, 2);
        expect(fakeApi.batchRequests, isNotEmpty);
        final request = fakeApi.batchRequests.last;
        expect(request.addLabelIds, contains('Label_7'));
        expect(request.addLabelIds, isNot(contains('Unwanted')));
      });
    });

    group('T-1 AC-5: unknown custom label handling', () {
      test('unknown target label fails with named error', () async {
        fakeApi.labelMap.clear();
        fakeApi.labelMap['Archive'] = 'Label_10';
        // "Unwanted" is not in the map

        final message = _testMessage();

        expect(
          () => adapter.moveMessage(message, 'Unwanted'),
          throwsA(isA<GmailLabelNotFoundException>().having(
            (e) => e.labelName,
            'labelName',
            equals('Unwanted'),
          )),
          reason: 'should throw with the exact label name',
        );
      });

      test('label list is fetched only once per connection', () async {
        final message = _testMessage();

        // Make multiple writes
        await adapter.moveMessage(message, 'Unwanted');
        await adapter.moveMessage(message, 'Archive');
        await adapter.moveMessage(message, 'Work');

        expect(fakeApi.modifyRequests.length, 3,
            reason: 'all three moves should succeed');
        expect(fakeApi.listCalls, 1,
            reason: 'labels.list is fetched once and cached for the connection');
      });

      // Lead review (Sprint 77): the batch path must report an unknown label
      // per message and keep going -- an escaping throw would discard the
      // results of every source group already moved.
      // What this does NOT catch: a labels.list NETWORK failure (same catch,
      // different exception) -- covered by the same branch, not exercised here.
      test('batch move to an unknown label fails each message with the named error, no throw',
          () async {
        fakeApi.labelMap.remove('Unwanted');
        final messages = [
          _testMessage(id: 'a', folderName: 'INBOX'),
          _testMessage(id: 'b', folderName: 'SPAM'),
        ];

        final result = await adapter.moveToFolderBatch(messages, 'Unwanted');

        expect(result.successCount, 0);
        expect(result.failedIds.keys, containsAll(['a', 'b']));
        expect(result.failedIds['a'], contains("Gmail label 'Unwanted' was not found"));
        expect(fakeApi.batchRequests, isEmpty, reason: 'nothing is sent for an unknown label');
      });

      test('Q17: an unresolvable custom SOURCE label stays and the move still succeeds',
          () async {
        final message = _testMessage(folderName: 'Gone'); // not in labelMap

        await adapter.moveToFolder(message: message, targetFolder: 'Archive');

        final request = fakeApi.modifyRequests.last;
        expect(request.addLabelIds, contains('Label_10'));
        expect(request.removeLabelIds, isNot(contains('Gone')),
            reason: 'a source name is never sent as an ID');
      });
    });

    group('T-1 AC-6: policy gate prevents unresolved names', () {
      // This group validates that the source gate test works.
      // The actual gate test lives in test/policy/gmail_label_id_gate_test.dart
      test('all modifyMessageRequest.addLabelIds are resolved IDs or system labels',
          () async {
        // Make one call to populate the requests
        final message = _testMessage();
        await adapter.moveMessage(message, 'Unwanted');

        // This is more of a documentation test; the real gate is the source check
        expect(fakeApi.modifyRequests, isNotEmpty);
        for (final req in fakeApi.modifyRequests) {
          if (req.addLabelIds != null) {
            for (final id in req.addLabelIds!) {
              expect(
                _isValidLabelId(id),
                true,
                reason: '$id should be a system label or a resolved ID (Label_*)',
              );
            }
          }
        }
      });
    });
  });
}

/// Helper: check if a string is a valid label ID (system or custom)
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
