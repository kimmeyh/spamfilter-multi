// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/batch_action_result.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';

void main() {
  group('BatchActionResult', () {
    test('constructor creates result with succeeded and failed IDs', () {
      final result = BatchActionResult(
        succeededIds: ['1', '2', '3'],
        failedIds: {'4': 'error1', '5': 'error2'},
      );

      expect(result.succeededIds, ['1', '2', '3']);
      expect(result.failedIds, {'4': 'error1', '5': 'error2'});
      expect(result.successCount, 3);
      expect(result.failureCount, 2);
      expect(result.totalCount, 5);
      expect(result.allSucceeded, isFalse);
    });

    test('allSuccess factory creates result with no failures', () {
      final result = BatchActionResult.allSuccess(['1', '2', '3']);

      expect(result.succeededIds, ['1', '2', '3']);
      expect(result.failedIds, isEmpty);
      expect(result.successCount, 3);
      expect(result.failureCount, 0);
      expect(result.totalCount, 3);
      expect(result.allSucceeded, isTrue);
    });

    test('allFailed factory creates result with all failures', () {
      final result = BatchActionResult.allFailed(
        ['1', '2', '3'],
        'Connection error',
      );

      expect(result.succeededIds, isEmpty);
      expect(result.failedIds, {
        '1': 'Connection error',
        '2': 'Connection error',
        '3': 'Connection error',
      });
      expect(result.successCount, 0);
      expect(result.failureCount, 3);
      expect(result.totalCount, 3);
      expect(result.allSucceeded, isFalse);
    });

    test('empty batch result', () {
      const result = BatchActionResult(succeededIds: [], failedIds: {});

      expect(result.successCount, 0);
      expect(result.failureCount, 0);
      expect(result.totalCount, 0);
      expect(result.allSucceeded, isTrue);
    });

    test('toString provides readable summary', () {
      final result = BatchActionResult(
        succeededIds: ['1', '2'],
        failedIds: {'3': 'error'},
      );

      expect(result.toString(), contains('succeeded: 2'));
      expect(result.toString(), contains('failed: 1'));
    });
  });

  group('PendingAction', () {
    test('creates pending action with all fields', () {
      final message = EmailMessage(
        id: '1',
        from: 'test@example.com',
        subject: 'Test',
        body: 'Body',
        headers: {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final action = PendingAction(
        message: message,
        matchedRule: 'SpamRule1',
        actionType: BatchActionType.delete,
      );

      expect(action.message.id, '1');
      expect(action.matchedRule, 'SpamRule1');
      expect(action.actionType, BatchActionType.delete);
    });
  });

  group('BatchActionType', () {
    test('has expected values', () {
      expect(BatchActionType.values, contains(BatchActionType.delete));
      expect(BatchActionType.values, contains(BatchActionType.moveToJunk));
      expect(BatchActionType.values, contains(BatchActionType.safeSenderMove));
      expect(BatchActionType.values.length, 3);
    });
  });
}
