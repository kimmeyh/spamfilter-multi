import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/providers/rule_set_provider.dart';
import 'package:spam_filter_mobile/core/services/email_scanner.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import 'package:spam_filter_mobile/adapters/storage/secure_credentials_store.dart';

void main() {
  group('AOL Folder Scanning Integration Tests', () {
    late RuleSetProvider ruleProvider;
    late EmailScanProvider scanProvider;

    setUp(() async {
      ruleProvider = RuleSetProvider();
      await ruleProvider.initialize();
      scanProvider = EmailScanProvider();
    });

    test('Verify migration ran and rules loaded from database', () async {
      // Verify rules were loaded from database after migration
      expect(ruleProvider.rules, isNotNull,
          reason: 'Rules should not be null after initialization');
      expect(ruleProvider.rules!.rules.length, greaterThan(0),
          reason: 'Should have loaded rules from YAML migration');

      print('✅ Loaded ${ruleProvider.rules!.rules.length} rules from database');
      print('   Rules: ${ruleProvider.rules!.rules.map((r) => r.name).toList()}');

      // Verify safe senders loaded
      expect(ruleProvider.safeSenders, isNotNull,
          reason: 'Safe senders should not be null after initialization');
      print(
          '✅ Loaded ${ruleProvider.safeSenders!.safeSenders.length} safe senders from database');
    });

    test('Scan AOL Bulk Mail Testing folder - rules should match',
        () async {
      // Check if credentials exist for AOL account
      final credStore = SecureCredentialsStore();
      final accountId = 'aol-kimmeyharold@aol.com';
      final credentials = await credStore.getCredentials(accountId);

      if (credentials == null) {
        print('⚠️  Skipping test - AOL credentials not found for $accountId');
        print('   This test requires AOL credentials to be saved in secure storage');
        return; // Skip test if no credentials
      }

      print('📧 Found AOL credentials for $accountId');

      // Create scanner for AOL account
      final scanner = EmailScanner(
        platformId: 'aol',
        accountId: accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
      );

      print('🔍 Starting scan of Bulk Mail Testing folder...');

      // Scan the Bulk Mail Testing folder (30 days back)
      await scanner.scanInbox(
        daysBack: 30, // Scan last 30 days
        folderNames: ['Bulk Mail Testing'], // Specific folder to test
      );

      // Verify scan completed successfully
      expect(scanProvider.isComplete, isTrue,
          reason: 'Scan should complete without errors');
      expect(scanProvider.hasError, isFalse,
          reason: 'Scan should not have errors');

      // Get results
      final noRuleCount = scanProvider.noRuleCount;
      final totalEmails = scanProvider.processedCount;
      final matchedCount = totalEmails - noRuleCount;
      final deletedCount = scanProvider.deletedCount;
      final movedCount = scanProvider.movedCount;

      print('');
      print('📊 Scan Results for Bulk Mail Testing folder:');
      print('   Total emails: $totalEmails');
      print('   Matched rules: $matchedCount');
      print('   No rule: $noRuleCount');
      print('   Would delete: $deletedCount');
      print('   Would move: $movedCount');
      print('');

      // Critical assertion: Rules should match (not all "no rule")
      expect(matchedCount, greaterThan(0),
          reason:
              'At least some emails should match rules (not all "no rule: $totalEmails")');

      // Optional: Verify that matched count is reasonable (at least 50% should match)
      final matchPercentage = totalEmails > 0 ? (matchedCount / totalEmails) : 0;
      print(
          '   Match rate: ${(matchPercentage * 100).toStringAsFixed(1)}% of emails matched rules');

      if (matchPercentage < 0.5) {
        print('   ⚠️  Warning: Less than 50% of emails matched rules');
        print('      Expected: Most emails in Bulk Mail Testing should match spam rules');
        print('      Actual: Only $matchedCount out of $totalEmails matched');
      }
    }, timeout: const Timeout(Duration(minutes: 5))); // Long timeout for network operation

    test(
        'Verify AOL adapter can connect and list folders',
        () async {
      // Check if credentials exist
      final credStore = SecureCredentialsStore();
      final accountId = 'aol-kimmeyharold@aol.com';
      final credentials = await credStore.getCredentials(accountId);

      if (credentials == null) {
        print('⚠️  Skipping test - AOL credentials not found');
        return; // Skip test if no credentials
      }

      // Create scanner
      final scanner = EmailScanner(
        platformId: 'aol',
        accountId: accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
      );

      // Attempt to scan (this will verify connection works)
      try {
        print('📡 Testing AOL adapter connectivity...');
        await scanner.scanInbox(
          daysBack: 1, // Short scan to test connectivity
          folderNames: ['INBOX'], // Just INBOX for quick test
        );

        expect(scanProvider.isComplete, isTrue,
            reason: 'AOL adapter should be able to connect');
        print('✅ AOL adapter connected successfully');
      } catch (e) {
        print('❌ AOL adapter connection failed: $e');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
