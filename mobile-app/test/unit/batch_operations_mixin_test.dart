// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/batch_action_result.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/evaluation_result.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';

/// Test implementation of SpamFilterPlatform using BatchOperationsMixin
/// to verify the default single-message fallback behavior.
class TestPlatform with BatchOperationsMixin implements SpamFilterPlatform {
  final List<String> callLog = [];
  bool shouldThrowOnId = false;
  String? throwOnId;

  @override
  String get platformId => 'test';

  @override
  String get displayName => 'Test Platform';

  @override
  AuthMethod get supportedAuthMethod => AuthMethod.appPassword;

  @override
  Future<void> loadCredentials(Credentials credentials) async {}

  @override
  void setDeletedRuleFolder(String? folderName) {}

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    return [];
  }

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async {
    return [];
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    if (shouldThrowOnId && message.id == throwOnId) {
      throw Exception('Simulated failure for ${message.id}');
    }
    callLog.add('takeAction:${message.id}:${action.name}');
  }

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {
    if (shouldThrowOnId && message.id == throwOnId) {
      throw Exception('Simulated failure for ${message.id}');
    }
    callLog.add('moveToFolder:${message.id}:$targetFolder');
  }

  @override
  Future<void> markAsRead({required EmailMessage message}) async {
    if (shouldThrowOnId && message.id == throwOnId) {
      throw Exception('Simulated failure for ${message.id}');
    }
    callLog.add('markAsRead:${message.id}');
  }

  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {
    if (shouldThrowOnId && message.id == throwOnId) {
      throw Exception('Simulated failure for ${message.id}');
    }
    callLog.add('applyFlag:${message.id}:$flagName');
  }

  @override
  Future<List<FolderInfo>> listFolders() async {
    return [];
  }

  @override
  Future<ConnectionStatus> testConnection() async {
    return ConnectionStatus.success();
  }

  @override
  Future<void> disconnect() async {}
}

EmailMessage _createTestEmail(String id) {
  return EmailMessage(
    id: id,
    from: 'test@example.com',
    subject: 'Test $id',
    body: 'Body',
    headers: {},
    receivedDate: DateTime.now(),
    folderName: 'INBOX',
  );
}

void main() {
  late TestPlatform platform;
  late List<EmailMessage> testMessages;

  setUp(() {
    platform = TestPlatform();
    testMessages = [
      _createTestEmail('1'),
      _createTestEmail('2'),
      _createTestEmail('3'),
    ];
  });

  group('BatchOperationsMixin - markAsReadBatch', () {
    test('processes all messages successfully', () async {
      final result = await platform.markAsReadBatch(testMessages);

      expect(result.allSucceeded, isTrue);
      expect(result.successCount, 3);
      expect(result.failureCount, 0);
      expect(platform.callLog, [
        'markAsRead:1',
        'markAsRead:2',
        'markAsRead:3',
      ]);
    });

    test('handles individual message failure', () async {
      platform.shouldThrowOnId = true;
      platform.throwOnId = '2';

      final result = await platform.markAsReadBatch(testMessages);

      expect(result.allSucceeded, isFalse);
      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.succeededIds, contains('1'));
      expect(result.succeededIds, contains('3'));
      expect(result.failedIds.keys, contains('2'));
    });

    test('handles empty list', () async {
      final result = await platform.markAsReadBatch([]);

      expect(result.allSucceeded, isTrue);
      expect(result.totalCount, 0);
    });
  });

  group('BatchOperationsMixin - applyFlagBatch', () {
    test('processes all messages with flag name', () async {
      final result = await platform.applyFlagBatch(testMessages, 'SpamRule1');

      expect(result.allSucceeded, isTrue);
      expect(result.successCount, 3);
      expect(platform.callLog, [
        'applyFlag:1:SpamRule1',
        'applyFlag:2:SpamRule1',
        'applyFlag:3:SpamRule1',
      ]);
    });

    test('handles individual message failure', () async {
      platform.shouldThrowOnId = true;
      platform.throwOnId = '1';

      final result = await platform.applyFlagBatch(testMessages, 'TestFlag');

      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.failedIds.keys, contains('1'));
    });
  });

  group('BatchOperationsMixin - moveToFolderBatch', () {
    test('processes all messages with target folder', () async {
      final result = await platform.moveToFolderBatch(testMessages, 'Trash');

      expect(result.allSucceeded, isTrue);
      expect(result.successCount, 3);
      expect(platform.callLog, [
        'moveToFolder:1:Trash',
        'moveToFolder:2:Trash',
        'moveToFolder:3:Trash',
      ]);
    });

    test('handles individual message failure', () async {
      platform.shouldThrowOnId = true;
      platform.throwOnId = '3';

      final result = await platform.moveToFolderBatch(testMessages, 'Junk');

      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.failedIds.keys, contains('3'));
    });
  });

  group('BatchOperationsMixin - takeActionBatch', () {
    test('processes delete action for all messages', () async {
      final result = await platform.takeActionBatch(
        testMessages,
        FilterAction.delete,
      );

      expect(result.allSucceeded, isTrue);
      expect(result.successCount, 3);
      expect(platform.callLog, [
        'takeAction:1:delete',
        'takeAction:2:delete',
        'takeAction:3:delete',
      ]);
    });

    test('processes moveToJunk action for all messages', () async {
      final result = await platform.takeActionBatch(
        testMessages,
        FilterAction.moveToJunk,
      );

      expect(result.allSucceeded, isTrue);
      expect(platform.callLog, [
        'takeAction:1:moveToJunk',
        'takeAction:2:moveToJunk',
        'takeAction:3:moveToJunk',
      ]);
    });

    test('handles partial failure in batch', () async {
      platform.shouldThrowOnId = true;
      platform.throwOnId = '2';

      final result = await platform.takeActionBatch(
        testMessages,
        FilterAction.delete,
      );

      expect(result.successCount, 2);
      expect(result.failureCount, 1);
      expect(result.succeededIds, containsAll(['1', '3']));
      expect(result.failedIds.keys, contains('2'));
    });

    test('handles empty message list', () async {
      final result = await platform.takeActionBatch(
        [],
        FilterAction.delete,
      );

      expect(result.allSucceeded, isTrue);
      expect(result.totalCount, 0);
    });
  });

  group('BatchOperationsMixin - single message fallback ordering', () {
    test('processes messages in order', () async {
      final messages = [
        _createTestEmail('a'),
        _createTestEmail('b'),
        _createTestEmail('c'),
        _createTestEmail('d'),
        _createTestEmail('e'),
      ];

      await platform.markAsReadBatch(messages);

      expect(platform.callLog, [
        'markAsRead:a',
        'markAsRead:b',
        'markAsRead:c',
        'markAsRead:d',
        'markAsRead:e',
      ]);
    });

    test('continues processing after failure', () async {
      platform.shouldThrowOnId = true;
      platform.throwOnId = 'b';

      final messages = [
        _createTestEmail('a'),
        _createTestEmail('b'),
        _createTestEmail('c'),
      ];

      final result = await platform.takeActionBatch(
        messages,
        FilterAction.delete,
      );

      // Should process a, skip b (error), then continue with c
      expect(result.succeededIds, ['a', 'c']);
      expect(result.failedIds.keys, contains('b'));
      expect(platform.callLog, [
        'takeAction:a:delete',
        // b fails (not in log)
        'takeAction:c:delete',
      ]);
    });
  });
}
