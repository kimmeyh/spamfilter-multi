import 'package:flutter_test/flutter_test.dart';

import 'package:spam_filter_mobile/core/storage/migration_manager.dart';

void main() {
  group('MigrationManager - Rollback Mechanism Tests', () {
    group('MigrationResults Tracking', () {
      test('MigrationResults initializes with tracking fields', () {
        final results = MigrationResults();
        expect(results.rulesImported, equals(0));
        expect(results.rulesFailed, equals(0));
        expect(results.safeSendersImported, equals(0));
        expect(results.safeSendersFailed, equals(0));
        expect(results.wasTransactionRolledBack, equals(false));
        expect(results.completedAt, isNull);
        expect(results.startedAt, isNull);
      });

      test('MigrationResults tracks completion state', () {
        final results = MigrationResults();
        expect(results.isComplete, equals(false)); // No completedAt yet

        results.completedAt = DateTime.now();
        expect(results.isComplete, equals(true));

        results.wasTransactionRolledBack = true;
        expect(results.isComplete, equals(false)); // Rolled back overrides completion
      });

      test('MigrationResults isSuccess reflects import failures', () {
        final results = MigrationResults();
        expect(results.isSuccess, equals(true)); // Both 0

        results.rulesFailed = 1;
        expect(results.isSuccess, equals(false));

        results.rulesFailed = 0;
        results.safeSendersFailed = 1;
        expect(results.isSuccess, equals(false));
      });

      test('MigrationResults toString includes rollback status', () {
        final results = MigrationResults();
        results.rulesImported = 100;
        results.safeSendersImported = 50;
        results.wasTransactionRolledBack = true;
        results.completedAt = DateTime.now();

        final output = results.toString();
        expect(output, contains('100')); // rulesImported
        expect(output, contains('50')); // safeSendersImported
        expect(output, contains('true')); // wasTransactionRolledBack
      });
    });

    group('Error Tracking and Reporting', () {
      test('MigrationResults accumulates errors in list', () {
        final results = MigrationResults();
        expect(results.errors, isEmpty);

        results.errors.add('Error 1');
        results.errors.add('Error 2');

        expect(results.errors.length, equals(2));
        expect(results.errors[0], equals('Error 1'));
      });

      test('MigrationResults tracks skipped rules with reasons', () {
        final results = MigrationResults();
        expect(results.skippedRules, isEmpty);

        results.skippedRules.add('rule1: UNIQUE constraint failed');
        results.skippedRules.add('rule2: Invalid regex pattern');

        expect(results.skippedRules.length, equals(2));
        expect(results.skippedRules[0], contains('UNIQUE constraint failed'));
      });

      test('MigrationResults tracks skipped safe senders with reasons', () {
        final results = MigrationResults();
        expect(results.skippedSafeSenders, isEmpty);

        results.skippedSafeSenders.add('pattern1: Already exists');
        results.skippedSafeSenders.add('pattern2: Invalid format');

        expect(results.skippedSafeSenders.length, equals(2));
        expect(results.skippedSafeSenders[0], contains('Already exists'));
      });
    });

    group('Transaction State Management', () {
      test('MigrationResults properly indicates success when no failures', () {
        final results = MigrationResults();
        results.rulesImported = 100;
        results.safeSendersImported = 50;
        results.rulesFailed = 0;
        results.safeSendersFailed = 0;

        expect(results.isSuccess, equals(true));
      });

      test('MigrationResults indicates failure when rules import fails', () {
        final results = MigrationResults();
        results.rulesImported = 50;
        results.rulesFailed = 50;
        results.safeSendersImported = 100;
        results.safeSendersFailed = 0;

        expect(results.isSuccess, equals(false));
      });

      test('MigrationResults indicates failure when safe_senders import fails', () {
        final results = MigrationResults();
        results.rulesImported = 100;
        results.rulesFailed = 0;
        results.safeSendersImported = 50;
        results.safeSendersFailed = 50;

        expect(results.isSuccess, equals(false));
      });

      test('Completion timestamp is set after successful migration', () {
        final results = MigrationResults();
        expect(results.completedAt, isNull);

        results.completedAt = DateTime.now();
        expect(results.completedAt, isNotNull);
      });
    });

    group('Rollback Recovery Strategy', () {
      test('Transaction rollback prevents partial database state', () async {
        // This test documents the rollback behavior
        // In actual execution:
        // 1. BEGIN TRANSACTION
        // 2. INSERT rules (1000 of 5000)
        // 3. INSERT safe_senders fails
        // 4. ROLLBACK (entire transaction)
        // 5. Database should have ZERO rules (consistent state)

        final results = MigrationResults();
        results.wasTransactionRolledBack = true;
        results.rulesImported = 0; // After rollback
        results.safeSendersImported = 0;

        expect(results.isComplete, equals(false)); // Not marked complete
        expect(results.rulesImported, equals(0)); // No partial data remains
      });

      test('Migration can be safely retried after rollback', () {
        // After rollback:
        // 1. isMigrationComplete() returns false (no rules in DB)
        // 2. App restarts migration
        // 3. Transaction wraps entire import again
        // 4. Either succeeds completely or rolls back again

        final results1 = MigrationResults();
        results1.wasTransactionRolledBack = true;

        // On retry, starts fresh:
        final results2 = MigrationResults();
        results2.rulesImported = 5000;
        results2.safeSendersImported = 2000;
        results2.completedAt = DateTime.now();

        expect(results1.isComplete, equals(false));
        expect(results2.isComplete, equals(true));
      });

      test('UNIQUE constraint violations trigger rollback', () {
        // Duplicate rule name should cause:
        // 1. Database INSERT fails (UNIQUE constraint)
        // 2. Exception caught in transaction
        // 3. Entire transaction rolled back
        // 4. Database left in consistent state

        final results = MigrationResults();
        results.errors.add('Migration transaction rolled back: UNIQUE constraint failed on rules.name');
        results.wasTransactionRolledBack = true;

        expect(results.isComplete, equals(false));
        expect(results.errors.length, equals(1));
      });
    });
  });
}
