/// Email scanning service that connects IMAP adapters with rule evaluation
library;

import '../models/email_message.dart';
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
  /// [NEW] SPRINT 4: Includes scan result persistence
  Future<void> scanInbox({
    int daysBack = 7,
    List<String> folderNames = const ['INBOX'],
    String scanType = 'manual',
  }) async {
    SpamFilterPlatform? platform;

    try {
      // [NEW] SPRINT 4: Initialize persistence stores if not already done
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

      // 2. Load credentials (skip for demo platform)
      if (platformId != 'demo') {
        final credentials = await _credStore.getCredentials(accountId);
        if (credentials == null) {
          throw Exception('No credentials found for account $accountId');
        }
        await platform.loadCredentials(credentials);
      }

      // 2.5. Configure deleted rule folder from account settings
      final deletedRuleFolder = await _settingsStore.getAccountDeletedRuleFolder(accountId);
      platform.setDeletedRuleFolder(deletedRuleFolder);

      // 3. [UPDATED] ISSUE #128: Start scan with 0 emails, will increment as found
      await scanProvider.startScan(
        totalEmails: 0,
        scanType: scanType,
        foldersScanned: folderNames,
      );

      // 4. [UPDATED] ISSUE #128: Fetch messages folder-by-folder for progress reporting
      final List<EmailMessage> messages = [];
      for (final folderName in folderNames) {
        // [NEW] ISSUE #128: Report folder being fetched
        scanProvider.setCurrentFolder(folderName);
        scanProvider.updateProgress(
          email: EmailMessage(
            id: '',
            from: '',
            subject: 'Searching folder "$folderName"...',
            body: '',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: folderName,
          ),
          message: 'Searching folder "$folderName"...',
        );

        // Fetch messages from this folder
        final folderMessages = await platform.fetchMessages(
          daysBack: daysBack,
          folderNames: [folderName],  // Fetch one folder at a time
        );

        messages.addAll(folderMessages);

        // [NEW] ISSUE #128: Increment found count and report folder completion
        if (folderMessages.isNotEmpty) {
          scanProvider.incrementFoundEmails(folderMessages.length);
          scanProvider.updateProgress(
            email: EmailMessage(
              id: '',
              from: '',
              subject: 'Found ${folderMessages.length} emails in "$folderName"',
              body: '',
              headers: {},
              receivedDate: DateTime.now(),
              folderName: folderName,
            ),
            message: 'Found ${folderMessages.length} emails in "$folderName", continuing...',
          );
        } else {
          scanProvider.updateProgress(
            email: EmailMessage(
              id: '',
              from: '',
              subject: 'No emails found in "$folderName"',
              body: '',
              headers: {},
              receivedDate: DateTime.now(),
              folderName: folderName,
            ),
            message: 'No emails found in "$folderName", continuing...',
          );
        }
      }

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

            // [NEW] F13: Move safe sender to configured folder if not already there
            final safeSenderFolder = await _settingsStore.getAccountSafeSenderFolder(accountId);
            final targetFolder = safeSenderFolder ?? 'INBOX'; // Default to INBOX

            // Only move if email is NOT already in the target folder
            if (message.folderName != targetFolder) {
              // [UPDATED] ISSUE #123+#124: Skip safe sender processing in testLimit mode (rules only)
              if (scanProvider.scanMode != ScanMode.readonly && scanProvider.scanMode != ScanMode.testLimit) {
                try {
                  AppLogger.scan('Moving safe sender email from ${message.folderName} to $targetFolder: ${message.subject}');
                  await platform.moveToFolder(
                    message: message,
                    targetFolder: targetFolder,
                  );
                } catch (e) {
                  success = false;
                  error = 'Move safe sender failed: $e';
                }
              } else {
                AppLogger.scan('[READONLY] Would move safe sender email to $targetFolder: ${message.subject}');
              }
            } else {
              AppLogger.scan('Safe sender email already in target folder ($targetFolder), no move needed: ${message.subject}');
            }
          }
          // Spam/phishing detected
          else if (result.shouldDelete) {
            action = EmailActionType.delete;

            // [UPDATED] ISSUE #123+#124: Skip rule processing in testAll mode (safe senders only)
            // Only execute action if NOT in readonly mode AND NOT in testAll mode
            if (scanProvider.scanMode != ScanMode.readonly && scanProvider.scanMode != ScanMode.testAll) {
              try {
                // Get target folder before moving
                final deletedRuleFolder = await _settingsStore.getAccountDeletedRuleFolder(accountId);
                final targetFolder = deletedRuleFolder ?? 'Trash';

                // [FIXED] ISSUE #138: Mark as read and apply flag BEFORE moving
                // IMAP message IDs are folder-specific, so we must do these operations
                // while the message is still in the original folder
                try {
                  await platform.markAsRead(message: message);
                  AppLogger.scan('Marked email as read: ${message.subject}');
                } catch (e) {
                  AppLogger.warning('Failed to mark email as read before move: $e');
                  // Continue - mark as read is enhancement, not critical
                }

                // Apply flag/label with rule name (before move)
                if (result.matchedRule.isNotEmpty) {
                  try {
                    await platform.applyFlag(
                      message: message,
                      flagName: result.matchedRule,
                    );
                    AppLogger.scan('Applied flag "${result.matchedRule}" to email: ${message.subject}');
                  } catch (e) {
                    AppLogger.warning('Failed to apply flag before move: $e');
                    // Continue - flagging is enhancement, not critical
                  }
                }

                // Now move the email (delete via platform adapter moves to trash/deleted folder)
                await platform.takeAction(
                  message: message,
                  action: FilterAction.delete,
                );
                AppLogger.scan('Moved email to $targetFolder: ${message.subject}');
              } catch (e) {
                success = false;
                error = 'Delete failed: $e';
              }
            } else {
              // Read-only or testAll (safe senders only) mode: log what would happen
              final modeDesc = scanProvider.scanMode == ScanMode.testAll ? 'SAFE_SENDERS_ONLY' : 'READONLY';
              AppLogger.scan('[$modeDesc] Would delete email: ${message.subject}');
            }
          } else if (result.shouldMove) {
            action = EmailActionType.moveToJunk;

            // [UPDATED] ISSUE #123+#124: Skip rule processing in testAll mode (safe senders only)
            // Only execute action if NOT in readonly mode AND NOT in testAll mode
            if (scanProvider.scanMode != ScanMode.readonly && scanProvider.scanMode != ScanMode.testAll) {
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
              // Read-only or testAll (safe senders only) mode: log what would happen
              final modeDesc = scanProvider.scanMode == ScanMode.testAll ? 'SAFE_SENDERS_ONLY' : 'READONLY';
              AppLogger.scan('[$modeDesc] Would move email to junk: ${message.subject}');
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

      // 7. Complete scan ([NEW] SPRINT 4: Now async to persist final state)
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
