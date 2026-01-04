/// Email scanning service that connects IMAP adapters with rule evaluation
library;

import 'package:logger/logger.dart';

import '../providers/email_scan_provider.dart';
import '../providers/rule_set_provider.dart';
import '../services/rule_evaluator.dart';
import '../services/pattern_compiler.dart';
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
  final Logger _logger = Logger();

  EmailScanner({
    required this.platformId,
    required this.accountId,
    required this.ruleSetProvider,
    required this.scanProvider,
  });

  /// Scan inbox with live IMAP connection
  Future<void> scanInbox({
    int daysBack = 7,
    List<String> folderNames = const ['INBOX'],
  }) async {
    SpamFilterPlatform? platform;

    try {
      // 1. Get platform adapter
      platform = PlatformRegistry.getPlatform(platformId);
      if (platform == null) {
        throw Exception('Platform $platformId not supported');
      }

      // 2. Load credentials (platform-aware: handles both IMAP and OAuth)
      final credentials = await _credStore.getCredentialsForPlatform(accountId);
      if (credentials == null) {
        throw Exception('No credentials found for account $accountId');
      }

      await platform.loadCredentials(credentials);

      // 3. Fetch messages
      final messages = await platform.fetchMessages(
        daysBack: daysBack,
        folderNames: folderNames,
      );

      // 4. Start scan
      scanProvider.startScan(totalEmails: messages.length);

      // 5. Get rule evaluator
      final evaluator = RuleEvaluator(
        ruleSet: ruleSetProvider.rules,
        safeSenderList: ruleSetProvider.safeSenders,
        compiler: PatternCompiler(),
      );

      // 6. Get scan mode settings
      final scanMode = scanProvider.scanMode;
      final testLimit = scanProvider.emailTestLimit;
      int actionsExecuted = 0;

      // 7. Process each email
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

            // ✅ Check scan mode before executing delete
            if (scanMode == ScanMode.readonly) {
              // Readonly mode: log only, don't execute
              _logger.i('[READONLY] Would delete: ${message.from} - ${message.subject}');
              success = true; // Mark as would-succeed
            } else if (scanMode == ScanMode.testLimit && actionsExecuted >= (testLimit ?? 0)) {
              // Test limit reached: log and skip
              _logger.i('[LIMIT REACHED] Skipping delete: ${message.from}');
              success = true;
            } else {
              // Execute action
              try {
                await platform.takeAction(
                  message: message,
                  action: FilterAction.delete,
                );
                actionsExecuted++;
              } catch (e) {
                success = false;
                error = 'Delete failed: $e';
              }
            }
          } else if (result.shouldMove) {
            action = EmailActionType.moveToJunk;

            // ✅ Check scan mode before executing move
            if (scanMode == ScanMode.readonly) {
              // Readonly mode: log only, don't execute
              _logger.i('[READONLY] Would move to junk: ${message.from} - ${message.subject}');
              success = true; // Mark as would-succeed
            } else if (scanMode == ScanMode.testLimit && actionsExecuted >= (testLimit ?? 0)) {
              // Test limit reached: log and skip
              _logger.i('[LIMIT REACHED] Skipping move: ${message.from}');
              success = true;
            } else {
              // Execute action
              try {
                await platform.takeAction(
                  message: message,
                  action: FilterAction.moveToJunk,
                );
                actionsExecuted++;
              } catch (e) {
                success = false;
                error = 'Move failed: $e';
              }
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

      // 8. Complete scan
      scanProvider.completeScan();
    } catch (e) {
      // Handle scan error
      scanProvider.errorScan('Scan failed: $e');
      rethrow;
    } finally {
      // 8. Disconnect
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (e) {
          // Log but don't throw
          print('Disconnect error: $e');
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

      // Load credentials (platform-aware: handles both IMAP and OAuth)
      final credentials = await _credStore.getCredentialsForPlatform(accountId);
      if (credentials == null) {
        throw Exception('No credentials found for account $accountId');
      }

      await platform.loadCredentials(credentials);

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
