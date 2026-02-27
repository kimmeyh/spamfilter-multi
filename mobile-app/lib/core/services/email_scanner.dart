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
      AppLogger.scan('========== SCAN START ==========');
      AppLogger.scan('platformId=$platformId, accountId=$accountId');
      AppLogger.scan('daysBack=$daysBack, folders=$folderNames, scanType=$scanType');

      // [NEW] SPRINT 4: Initialize persistence stores if not already done
      final dbHelper = DatabaseHelper();
      scanProvider.initializePersistence(
        scanResultStore: ScanResultStore(dbHelper),
        unmatchedEmailStore: UnmatchedEmailStore(dbHelper),
        databaseHelper: dbHelper,
      );
      scanProvider.setCurrentAccountId(accountId);

      // 1. Get platform adapter
      platform = PlatformRegistry.getPlatform(platformId);
      if (platform == null) {
        throw Exception('Platform $platformId not supported');
      }
      AppLogger.scan('Step 1: Platform adapter loaded: ${platform.runtimeType}');

      // 2. Load credentials (skip for demo platform)
      if (platformId != 'demo') {
        final credentials = await _credStore.getCredentials(accountId);
        if (credentials == null) {
          throw Exception('No credentials found for account $accountId');
        }
        AppLogger.scan('Step 2: Credentials loaded for ${credentials.email}');
        await platform.loadCredentials(credentials);
        AppLogger.scan('Step 2: IMAP connected and authenticated');
      }

      // 2.5. Configure deleted rule folder from account settings
      final deletedRuleFolder = await _settingsStore.getAccountDeletedRuleFolder(accountId);
      platform.setDeletedRuleFolder(deletedRuleFolder);

      // 3. [UPDATED] ISSUE #128: Start scan with 0 emails, will increment as found
      AppLogger.scan('Step 3: Calling scanProvider.startScan(totalEmails: 0, scanType: $scanType)');
      AppLogger.scan('Step 3: scanProvider.status BEFORE startScan: ${scanProvider.status}');
      await scanProvider.startScan(
        totalEmails: 0,
        scanType: scanType,
        foldersScanned: folderNames,
      );
      AppLogger.scan('Step 3: scanProvider.status AFTER startScan: ${scanProvider.status}');

      // 4. [UPDATED] ISSUE #128: Fetch messages folder-by-folder for progress reporting
      final List<EmailMessage> messages = [];
      AppLogger.scan('Step 4: Starting folder-by-folder fetch. Total folders: ${folderNames.length}');
      for (final folderName in folderNames) {
        AppLogger.scan('Step 4: Fetching folder "$folderName" (daysBack=$daysBack)...');
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
        try {
          final folderMessages = await platform.fetchMessages(
            daysBack: daysBack,
            folderNames: [folderName],  // Fetch one folder at a time
          );
          AppLogger.scan('Step 4: Folder "$folderName" returned ${folderMessages.length} messages');

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
            AppLogger.scan('Step 4: WARNING - Folder "$folderName" returned 0 messages');
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
        } catch (e, st) {
          AppLogger.error('Step 4: EXCEPTION fetching folder "$folderName"', error: e, stackTrace: st);
          // Continue with other folders even if one fails
        }
      }
      AppLogger.scan('Step 4: COMPLETE - Total messages across all folders: ${messages.length}');

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
      // Normalize INBOX to uppercase for RFC 3501 compliance (INBOX is case-insensitive
      // per spec, but some IMAP servers may not handle mixed-case correctly)
      final rawTarget = safeSenderFolder ?? 'INBOX';
      final safeSenderTarget = rawTarget.toLowerCase() == 'inbox' ? 'INBOX' : rawTarget;
      AppLogger.scan('Safe sender target folder: "$safeSenderTarget" (raw: "$rawTarget")');

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

        final evaluated = _EvaluatedEmail(
          message: message,
          result: result,
          action: action,
        );
        evaluatedEmails.add(evaluated);

        // Record no-rule-match results immediately (no batch processing needed)
        if (action == EmailActionType.none) {
          scanProvider.recordResult(
            EmailActionResult(
              email: message,
              evaluationResult: result,
              action: action,
              success: true,
            ),
          );
        }
      }

      // Summary of evaluation results
      final noneCount = evaluatedEmails.where((e) => e.action == EmailActionType.none).length;
      final deleteCount = evaluatedEmails.where((e) => e.action == EmailActionType.delete).length;
      final moveCount = evaluatedEmails.where((e) => e.action == EmailActionType.moveToJunk).length;
      final safeCount = evaluatedEmails.where((e) => e.action == EmailActionType.safeSender).length;
      AppLogger.scan('Step 6a COMPLETE: Evaluated ${evaluatedEmails.length} emails: none=$noneCount, delete=$deleteCount, moveToJunk=$moveCount, safeSender=$safeCount');
      AppLogger.scan('Step 6a: scanProvider counts after eval: processed=${scanProvider.processedCount}, noRule=${scanProvider.noRuleCount}, deleted=${scanProvider.deletedCount}, moved=${scanProvider.movedCount}, safe=${scanProvider.safeSendersCount}');

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

      AppLogger.scan('Step 6b: Batch execution starting. canExecuteRules=$canExecuteRules, canExecuteSafeSenders=$canExecuteSafeSenders');
      AppLogger.scan('Step 6b: Batch sizes: delete=${deleteEmails.length}, moveToJunk=${moveToJunkEmails.length}, safeSender=${safeSenderMoveEmails.length}');

      // --- Priority 1: Safe sender moves (rescue good emails first) ---
      AppLogger.scan('Step 6b-1: Safe sender move batch: ${safeSenderMoveEmails.length} emails to move (canExecuteSafeSenders=$canExecuteSafeSenders, target="$safeSenderTarget")');
      if (safeSenderMoveEmails.isNotEmpty) {
        for (final evaluated in safeSenderMoveEmails) {
          AppLogger.scan('  Safe sender to move: id=${evaluated.message.id}, from="${evaluated.message.from}", folder="${evaluated.message.folderName}"');
        }

        scanProvider.updateProgress(
          email: EmailMessage(
            id: '',
            from: '',
            subject: 'Batch moving ${safeSenderMoveEmails.length} safe sender emails...',
            body: '',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: '',
          ),
          message: 'Batch moving ${safeSenderMoveEmails.length} safe sender emails...',
        );

        try {
          final safeSenderMessages = safeSenderMoveEmails.map((e) => e.message).toList();
          final moveResult = await platform.moveToFolderBatch(
            safeSenderMessages,
            safeSenderTarget,
          );
          AppLogger.scan('Step 6b-1: Safe sender move to "$safeSenderTarget": ${moveResult.successCount} succeeded, ${moveResult.failureCount} failed');
          if (moveResult.failedIds.isNotEmpty) {
            AppLogger.warning('Safe sender move failures: ${moveResult.failedIds}');
          }
          batchErrors.addAll(moveResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch safe sender move failed entirely: $e');
          for (final evaluated in safeSenderMoveEmails) {
            batchErrors[evaluated.message.id] = 'Move safe sender failed: $e';
          }
        }

        // Record safe sender move results after batch completes
        for (final evaluated in safeSenderMoveEmails) {
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
      } else {
        // Log why safe sender batch is empty and record results
        final safeSenderEvaluated = evaluatedEmails.where((e) => e.action == EmailActionType.safeSender).toList();
        if (safeSenderEvaluated.isNotEmpty) {
          AppLogger.scan('Safe sender emails found but not added to batch:');
          for (final e in safeSenderEvaluated) {
            final inTarget = e.message.folderName == safeSenderTarget;
            AppLogger.scan('  id=${e.message.id}, folder="${e.message.folderName}", alreadyInTarget=$inTarget, canExecute=$canExecuteSafeSenders');
          }
          // Record safe sender results (already in target or cannot execute)
          for (final evaluated in safeSenderEvaluated) {
            scanProvider.recordResult(
              EmailActionResult(
                email: evaluated.message,
                evaluationResult: evaluated.result,
                action: evaluated.action,
                success: true,
              ),
            );
          }
        }
      }

      // --- Priority 2: Delete batch (mark as read + delete) ---
      if (deleteEmails.isNotEmpty) {
        scanProvider.updateProgress(
          email: EmailMessage(
            id: '',
            from: '',
            subject: 'Batch processing ${deleteEmails.length} emails for deletion...',
            body: '',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: '',
          ),
          message: 'Batch processing ${deleteEmails.length} emails for deletion...',
        );

        final deleteMessages = deleteEmails.map((e) => e.message).toList();

        // Step 2a: Batch mark as read (enhancement - do not block on failure)
        AppLogger.scan('Step 6b-2a: Starting markAsReadBatch for ${deleteMessages.length} messages...');
        try {
          final markResult = await platform.markAsReadBatch(deleteMessages);
          AppLogger.scan('Step 6b-2a: markAsReadBatch DONE: ${markResult.successCount} succeeded, ${markResult.failureCount} failed');
        } catch (e) {
          AppLogger.warning('Step 6b-2a: markAsReadBatch FAILED: $e');
        }

        // Step 2b: Batch delete (move to trash/configured folder)
        AppLogger.scan('Step 6b-2b: Starting takeActionBatch (delete) for ${deleteMessages.length} messages...');
        try {
          final deleteResult = await platform.takeActionBatch(
            deleteMessages,
            FilterAction.delete,
          );
          AppLogger.scan('Step 6b-2b: takeActionBatch (delete) DONE: ${deleteResult.successCount} succeeded, ${deleteResult.failureCount} failed');
          batchErrors.addAll(deleteResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch delete failed entirely: $e');
          for (final msg in deleteMessages) {
            batchErrors[msg.id] = 'Delete failed: $e';
          }
        }

        // Record delete results after batch completes
        for (final evaluated in deleteEmails) {
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
      } else {
        // Readonly/testAll mode: record delete-eligible emails without execution
        final readonlyDeletes = evaluatedEmails
            .where((e) => e.action == EmailActionType.delete)
            .toList();
        if (readonlyDeletes.isNotEmpty) {
          final modeDesc = scanProvider.scanMode == ScanMode.testAll
              ? 'SAFE_SENDERS_ONLY'
              : 'READONLY';
          AppLogger.scan('[$modeDesc] Would delete ${readonlyDeletes.length} emails');
          for (final evaluated in readonlyDeletes) {
            scanProvider.recordResult(
              EmailActionResult(
                email: evaluated.message,
                evaluationResult: evaluated.result,
                action: evaluated.action,
                success: true,
              ),
            );
          }
        }
      }

      // --- Priority 3: Move to junk batch ---
      if (moveToJunkEmails.isNotEmpty) {
        scanProvider.updateProgress(
          email: EmailMessage(
            id: '',
            from: '',
            subject: 'Batch moving ${moveToJunkEmails.length} emails to junk...',
            body: '',
            headers: {},
            receivedDate: DateTime.now(),
            folderName: '',
          ),
          message: 'Batch moving ${moveToJunkEmails.length} emails to junk...',
        );

        AppLogger.scan('Step 6b-3: Starting takeActionBatch (moveToJunk) for ${moveToJunkEmails.length} messages...');
        try {
          final junkMessages = moveToJunkEmails.map((e) => e.message).toList();
          final junkResult = await platform.takeActionBatch(
            junkMessages,
            FilterAction.moveToJunk,
          );
          AppLogger.scan('Step 6b-3: takeActionBatch (moveToJunk) DONE: ${junkResult.successCount} succeeded, ${junkResult.failureCount} failed');
          batchErrors.addAll(junkResult.failedIds);
        } catch (e) {
          AppLogger.warning('Batch moveToJunk failed entirely: $e');
          for (final evaluated in moveToJunkEmails) {
            batchErrors[evaluated.message.id] = 'Move to junk failed: $e';
          }
        }

        // Record moveToJunk results after batch completes
        for (final evaluated in moveToJunkEmails) {
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
      }

      // Record readonly mode results for moveToJunk emails
      if (!canExecuteRules) {
        final readonlyJunkEmails = evaluatedEmails.where((e) => e.action == EmailActionType.moveToJunk).toList();
        if (readonlyJunkEmails.isNotEmpty) {
          final modeDesc = scanProvider.scanMode == ScanMode.testAll
              ? 'SAFE_SENDERS_ONLY'
              : 'READONLY';
          AppLogger.scan('[$modeDesc] Would move to junk ${readonlyJunkEmails.length} emails');
          for (final evaluated in readonlyJunkEmails) {
            scanProvider.recordResult(
              EmailActionResult(
                email: evaluated.message,
                evaluationResult: evaluated.result,
                action: evaluated.action,
                success: true,
              ),
            );
          }
        }
      }

      // --- Priority 4: Apply flags/categories (SKIPPED) ---
      // Flag operations tag emails with the rule name that matched them via IMAP
      // custom keywords (UID STORE +keyword). This is a cosmetic enhancement only.
      // Currently disabled because:
      // 1. AOL IMAP does not support custom keywords (returns BAD [CLIENTBUG])
      // 2. Each unique rule name requires a separate IMAP round-trip
      // 3. With 300+ emails matching 200+ rules, this creates a massive bottleneck
      // TODO: Re-enable when a provider supports custom keywords, or implement
      //       as a post-scan background operation with its own IMAP connection.
      if (canExecuteRules) {
        final allActionEmails = [...deleteEmails, ...moveToJunkEmails];
        final flagGroups = <String, List<EmailMessage>>{};
        for (final evaluated in allActionEmails) {
          if (evaluated.result.matchedRule.isNotEmpty) {
            flagGroups
                .putIfAbsent(evaluated.result.matchedRule, () => [])
                .add(evaluated.message);
          }
        }
        if (flagGroups.isNotEmpty) {
          AppLogger.scan('Step 6b-4: Skipping applyFlagBatch for ${flagGroups.length} rule groups (disabled for performance)');
        }
      }

      // 7. Complete scan ([NEW] SPRINT 4: Now async to persist final state)
      AppLogger.scan('Step 7: Completing scan. Final counts: found=${scanProvider.totalEmails}, processed=${scanProvider.processedCount}, deleted=${scanProvider.deletedCount}, moved=${scanProvider.movedCount}, safe=${scanProvider.safeSendersCount}, noRule=${scanProvider.noRuleCount}, errors=${scanProvider.errorCount}');
      await scanProvider.completeScan();
      AppLogger.scan('========== SCAN COMPLETE ==========');
    } catch (e, st) {
      // Handle scan error
      AppLogger.error('SCAN FAILED with exception', error: e, stackTrace: st);
      await scanProvider.errorScan('Scan failed: $e');
      rethrow;
    } finally {
      // 8. Disconnect
      if (platform != null) {
        try {
          await platform.disconnect();
          AppLogger.scan('Step 8: Disconnected from IMAP');
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
