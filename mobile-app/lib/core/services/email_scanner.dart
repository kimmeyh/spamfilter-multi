/// Email scanning service that connects IMAP adapters with rule evaluation
library;

import '../models/email_message.dart';
import '../models/evaluation_result.dart';
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

      // 6. [UPDATED] ISSUE #144: Two-phase processing - evaluate all, then batch execute
      //
      // Phase 6a: Evaluate all emails and determine actions
      // Phase 6b: Execute actions in batches using platform batch APIs
      //
      // This reduces IMAP/API calls from 3N (markAsRead + applyFlag + takeAction per email)
      // to ~3 batch operations total, significantly improving performance for large scans.

      // --- Phase 6a: Evaluate all emails ---
      final evaluatedEmails = <_EvaluatedEmail>[];
      final safeSenderFolder = await _settingsStore.getAccountSafeSenderFolder(accountId);
      final safeSenderTarget = safeSenderFolder ?? 'INBOX';

      for (final message in messages) {
        scanProvider.updateProgress(
          email: message,
          message: 'Evaluating: ${message.subject}',
        );

        final result = await evaluator.evaluate(message);
        EmailActionType action = EmailActionType.none;

        if (result.matchedRule.isNotEmpty) {
          if (result.isSafeSender) {
            action = EmailActionType.safeSender;
          } else if (result.shouldDelete) {
            action = EmailActionType.delete;
          } else if (result.shouldMove) {
            action = EmailActionType.moveToJunk;
          }
        }

        evaluatedEmails.add(_EvaluatedEmail(
          message: message,
          result: result,
          action: action,
        ));
      }

      // --- Phase 6b: Batch execute actions ---
      final bool canExecuteRules =
          scanProvider.scanMode != ScanMode.readonly &&
          scanProvider.scanMode != ScanMode.testAll;
      final bool canExecuteSafeSenders =
          scanProvider.scanMode != ScanMode.readonly &&
          scanProvider.scanMode != ScanMode.testLimit;

      // Collect emails by action type for batch processing
      final deleteEmails = <_EvaluatedEmail>[];
      final moveToJunkEmails = <_EvaluatedEmail>[];
      final safeSenderMoveEmails = <_EvaluatedEmail>[];

      for (final evaluated in evaluatedEmails) {
        switch (evaluated.action) {
          case EmailActionType.delete:
            if (canExecuteRules) deleteEmails.add(evaluated);
            break;
          case EmailActionType.moveToJunk:
            if (canExecuteRules) moveToJunkEmails.add(evaluated);
            break;
          case EmailActionType.safeSender:
            // Only add if not already in target folder
            if (canExecuteSafeSenders &&
                evaluated.message.folderName != safeSenderTarget) {
              safeSenderMoveEmails.add(evaluated);
            }
            break;
          case EmailActionType.none:
          case EmailActionType.markAsRead:
            break;
        }
      }

      // Track batch results for recording
      final batchErrors = <String, String>{}; // messageId -> error

      // Execute delete batch: markAsRead + applyFlag + takeAction
      if (deleteEmails.isNotEmpty) {
        scanProvider.updateProgress(
          email: deleteEmails.first.message,
          message: 'Batch processing ${deleteEmails.length} emails for deletion...',
        );

        final deleteMessages = deleteEmails.map((e) => e.message).toList();

        // Step 1: Batch mark as read (before move, enhancement - do not block on failure)
        try {
          final markResult = await platform.markAsReadBatch(deleteMessages);
          AppLogger.scan('Batch markAsRead: ${markResult.successCount} succeeded, ${markResult.failureCount} failed');
        } catch (e) {
          AppLogger.warning('Batch markAsRead failed entirely: $e');
        }

        // Step 2: Batch apply flags grouped by rule name
        final flagGroups = <String, List<EmailMessage>>{};
        for (final evaluated in deleteEmails) {
          if (evaluated.result.matchedRule.isNotEmpty) {
            flagGroups
                .putIfAbsent(evaluated.result.matchedRule, () => [])
                .add(evaluated.message);
          }
        }
        for (final entry in flagGroups.entries) {
          try {
            final flagResult = await platform.applyFlagBatch(entry.value, entry.key);
            AppLogger.scan('Batch applyFlag "${entry.key}": ${flagResult.successCount} succeeded, ${flagResult.failureCount} failed');
          } catch (e) {
            AppLogger.warning('Batch applyFlag "${entry.key}" failed entirely: $e');
          }
        }

        // Step 3: Batch delete (move to trash/configured folder)
        try {
          final deleteResult = await platform.takeActionBatch(
            deleteMessages,
            FilterAction.delete,
          );
          AppLogger.scan('Batch delete: ${deleteResult.successCount} succeeded, ${deleteResult.failureCount} failed');
          // Track failures
          batchErrors.addAll(deleteResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch delete failed entirely: $e');
          for (final msg in deleteMessages) {
            batchErrors[msg.id] = 'Delete failed: $e';
          }
        }
      } else if (canExecuteRules) {
        // Log readonly/testAll mode for delete-eligible emails
        final readonlyDeletes = evaluatedEmails
            .where((e) => e.action == EmailActionType.delete)
            .toList();
        if (readonlyDeletes.isNotEmpty) {
          final modeDesc = scanProvider.scanMode == ScanMode.testAll
              ? 'SAFE_SENDERS_ONLY'
              : 'READONLY';
          AppLogger.scan('[$modeDesc] Would delete ${readonlyDeletes.length} emails');
        }
      }

      // Execute moveToJunk batch
      if (moveToJunkEmails.isNotEmpty) {
        scanProvider.updateProgress(
          email: moveToJunkEmails.first.message,
          message: 'Batch moving ${moveToJunkEmails.length} emails to junk...',
        );

        try {
          final junkMessages = moveToJunkEmails.map((e) => e.message).toList();
          final junkResult = await platform.takeActionBatch(
            junkMessages,
            FilterAction.moveToJunk,
          );
          AppLogger.scan('Batch moveToJunk: ${junkResult.successCount} succeeded, ${junkResult.failureCount} failed');
          batchErrors.addAll(junkResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch moveToJunk failed entirely: $e');
          for (final evaluated in moveToJunkEmails) {
            batchErrors[evaluated.message.id] = 'Move to junk failed: $e';
          }
        }
      }

      // Execute safe sender move batch
      if (safeSenderMoveEmails.isNotEmpty) {
        scanProvider.updateProgress(
          email: safeSenderMoveEmails.first.message,
          message: 'Batch moving ${safeSenderMoveEmails.length} safe sender emails...',
        );

        try {
          final safeSenderMessages = safeSenderMoveEmails.map((e) => e.message).toList();
          final moveResult = await platform.moveToFolderBatch(
            safeSenderMessages,
            safeSenderTarget,
          );
          AppLogger.scan('Batch safe sender move to $safeSenderTarget: ${moveResult.successCount} succeeded, ${moveResult.failureCount} failed');
          batchErrors.addAll(moveResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch safe sender move failed entirely: $e');
          for (final evaluated in safeSenderMoveEmails) {
            batchErrors[evaluated.message.id] = 'Move safe sender failed: $e';
          }
        }
      }

      // Log readonly mode actions
      if (!canExecuteRules) {
        final readonlyDeletes = evaluatedEmails.where((e) => e.action == EmailActionType.delete).length;
        final readonlyJunk = evaluatedEmails.where((e) => e.action == EmailActionType.moveToJunk).length;
        if (readonlyDeletes > 0 || readonlyJunk > 0) {
          final modeDesc = scanProvider.scanMode == ScanMode.testAll
              ? 'SAFE_SENDERS_ONLY'
              : 'READONLY';
          AppLogger.scan('[$modeDesc] Would delete $readonlyDeletes, move to junk $readonlyJunk emails');
        }
      }
      if (!canExecuteSafeSenders) {
        final readonlySafe = evaluatedEmails.where((e) => e.action == EmailActionType.safeSender).length;
        if (readonlySafe > 0) {
          AppLogger.scan('[READONLY] Would move $readonlySafe safe sender emails to $safeSenderTarget');
        }
      }

      // Record all results
      for (final evaluated in evaluatedEmails) {
        final errorMsg = batchErrors[evaluated.message.id];
        scanProvider.recordResult(
          EmailActionResult(
            email: evaluated.message,
            evaluationResult: evaluated.result,
            action: evaluated.action,
            success: errorMsg == null,
            error: errorMsg,
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

/// Internal helper for holding an evaluated email with its determined action
class _EvaluatedEmail {
  final EmailMessage message;
  final EvaluationResult result;
  final EmailActionType action;

  const _EvaluatedEmail({
    required this.message,
    required this.result,
    required this.action,
  });
}
