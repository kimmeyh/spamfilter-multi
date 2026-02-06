/// Email scanning service that connects IMAP adapters with rule evaluation
library;

import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../services/rule_evaluator.dart';
import '../services/pattern_compiler.dart';
import '../storage/database_helper.dart';
import '../storage/scan_result_store.dart';
import '../storage/settings_store.dart';
import '../storage/unmatched_email_store.dart';
import '../utils/app_logger.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../adapters/storage/secure_credentials_store.dart';

/// Service to orchestrate email scanning with live IMAP connection
class EmailScanner {
  final String platformId;
  final String accountId;
  final RuleSetProvider ruleSetProvider;
  final EmailScanProvider scanProvider;
  final SecureCredentialsStore _credStore = SecureCredentialsStore();
  final SettingsStore _settingsStore = SettingsStore();

  EmailScanner({
    required this.platformId,
    required this.accountId,
    required this.ruleSetProvider,
    required this.scanProvider,
  });

  /// Scan inbox with live IMAP connection
  /// ✨ SPRINT 4: Includes scan result persistence
  Future<void> scanInbox({
    int daysBack = 7,
    List<String> folderNames = const ['INBOX'],
    String scanType = 'manual',
  }) async {
    SpamFilterPlatform? platform;

    try {
      // ✨ SPRINT 4: Initialize persistence stores if not already done
      final dbHelper = DatabaseHelper();
      scanProvider.initializePersistence(
        scanResultStore: ScanResultStore(dbHelper),
        unmatchedEmailStore: UnmatchedEmailStore(dbHelper),
      );
      scanProvider.setCurrentAccountId(accountId);

      // 1. Get platform adapter
      platform = PlatformRegistry.getPlatform(platformId);
      if (platform == null) {
        throw Exception('Platform $platformId not supported');
      }

      // 2. Load credentials
      final credentials = await _credStore.getCredentials(accountId);
      if (credentials == null) {
        throw Exception('No credentials found for account $accountId');
      }

      await platform.loadCredentials(credentials);

      // 2.5. Configure deleted rule folder from account settings
      final deletedRuleFolder = await _settingsStore.getAccountDeletedRuleFolder(accountId);
      platform.setDeletedRuleFolder(deletedRuleFolder);

      // 3. Fetch messages
      final messages = await platform.fetchMessages(
        daysBack: daysBack,
        folderNames: folderNames,
      );

      // 4. Start scan (✨ SPRINT 4: Now async to enable persistence)
      await scanProvider.startScan(
        totalEmails: messages.length,
        scanType: scanType,
        foldersScanned: folderNames,
      );

      // 5. Get rule evaluator
      // DIAGNOSTIC: Log rule and safe sender counts for troubleshooting
      AppLogger.scan('=== SCAN DIAGNOSTICS ===');
      AppLogger.rules('Rules loaded: ${ruleSetProvider.rules.rules.length}');
      AppLogger.rules('Safe senders loaded: ${ruleSetProvider.safeSenders.safeSenders.length}');
      AppLogger.debug('RuleSetProvider state: isLoading=${ruleSetProvider.isLoading}, isError=${ruleSetProvider.isError}, error=${ruleSetProvider.error}');
      if (ruleSetProvider.rules.rules.isNotEmpty) {
        AppLogger.rules('First rule: ${ruleSetProvider.rules.rules[0].name} (enabled=${ruleSetProvider.rules.rules[0].enabled})');
      }
      AppLogger.scan('=======================');

      final evaluator = RuleEvaluator(
        ruleSet: ruleSetProvider.rules,
        safeSenderList: ruleSetProvider.safeSenders,
        compiler: PatternCompiler(),
      );

      // 6. Process each email
      for (final message in messages) {
        // Update progress
        scanProvider.updateProgress(
          email: message,
          message: 'Processing: ${message.subject}',
        );

        // Evaluate email
        final result = await evaluator.evaluate(message);

        // Determine action
        EmailActionType action = EmailActionType.none;
        bool success = true;
        String? error;

        // Check if matched a rule (empty string means no match)
        if (result.matchedRule.isNotEmpty) {
          // Check if safe sender
          if (result.isSafeSender) {
            action = EmailActionType.safeSender;
          }
          // Spam/phishing detected
          else if (result.shouldDelete) {
            action = EmailActionType.delete;

            // ✨ FIX ISSUE #9: Only execute action if NOT in readonly mode
            if (scanProvider.scanMode != ScanMode.readonly) {
              try {
                // Delete via platform adapter
                await platform.takeAction(
                  message: message,
                  action: FilterAction.delete,
                );
              } catch (e) {
                success = false;
                error = 'Delete failed: $e';
              }
            } else {
              // Read-only mode: log what would happen
              AppLogger.scan('[READONLY] Would delete email: ${message.subject}');
            }
          } else if (result.shouldMove) {
            action = EmailActionType.moveToJunk;

            // ✨ FIX ISSUE #9: Only execute action if NOT in readonly mode
            if (scanProvider.scanMode != ScanMode.readonly) {
              try {
                // Move to junk folder
                await platform.takeAction(
                  message: message,
                  action: FilterAction.moveToJunk,
                );
              } catch (e) {
                success = false;
                error = 'Move failed: $e';
              }
            } else {
              // Read-only mode: log what would happen
              AppLogger.scan('[READONLY] Would move email to junk: ${message.subject}');
            }
          }
        }

        // Record result
        scanProvider.recordResult(
          EmailActionResult(
            email: message,
            evaluationResult: result,
            action: action,
            success: success,
            error: error,
          ),
        );
      }

      // 7. Complete scan (✨ SPRINT 4: Now async to persist final state)
      await scanProvider.completeScan();
    } catch (e) {
      // Handle scan error
      await scanProvider.errorScan('Scan failed: $e');
      rethrow;
    } finally {
      // 8. Disconnect
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (e) {
          // Log but do not throw
          AppLogger.warning('Disconnect error: $e');
        }
      }
    }
  }

  /// Scan specific folders
  Future<void> scanFolders({
    required List<String> folderNames,
    int daysBack = 7,
  }) async {
    return scanInbox(daysBack: daysBack, folderNames: folderNames);
  }

  /// Scan all folders except trash
  Future<void> scanAllFolders({int daysBack = 7}) async {
    SpamFilterPlatform? platform;

    try {
      // Get platform adapter
      platform = PlatformRegistry.getPlatform(platformId);
      if (platform == null) {
        throw Exception('Platform $platformId not supported');
      }

      // Load credentials
      final credentials = await _credStore.getCredentials(accountId);
      if (credentials == null) {
        throw Exception('No credentials found for account $accountId');
      }

      await platform.loadCredentials(credentials);

      // Configure deleted rule folder from account settings
      final deletedRuleFolder = await _settingsStore.getAccountDeletedRuleFolder(accountId);
      platform.setDeletedRuleFolder(deletedRuleFolder);

      // List all folders
      final folders = await platform.listFolders();

      // Filter out trash/deleted folders
      final scanFolders = folders
          .where((f) =>
              f.canonicalName != CanonicalFolder.trash &&
              f.isWritable)
          .map((f) => f.id)
          .toList();

      // Disconnect before starting scan (scan will reconnect)
      await platform.disconnect();

      // Scan filtered folders
      return scanInbox(daysBack: daysBack, folderNames: scanFolders);
    } catch (e) {
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (_) {}
      }
      rethrow;
    }
  }
}
