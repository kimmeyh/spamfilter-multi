import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_bar_with_exit.dart';
import 'scan_progress_screen.dart';
import 'settings_screen.dart';

import '../../core/providers/email_scan_provider.dart' show EmailScanProvider, EmailActionResult, EmailActionType, ScanStatus;
import '../../core/providers/rule_set_provider.dart';
import '../../core/models/rule_set.dart' show Rule, RuleConditions, RuleActions;
import '../../core/services/email_body_parser.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../widgets/empty_state.dart';

/// Displays summary of scan results bound to EmailScanProvider.
class ResultsDisplayScreen extends StatefulWidget {
  final String platformId;
  final String platformDisplayName;
  final String accountId;
  final String accountEmail;

  const ResultsDisplayScreen({
    super.key,
    required this.platformId,
    required this.platformDisplayName,
    required this.accountId,
    required this.accountEmail,
  });

  @override
  State<ResultsDisplayScreen> createState() => _ResultsDisplayScreenState();
}

class _ResultsDisplayScreenState extends State<ResultsDisplayScreen> {
  // Filter state: null means show all, otherwise filter by this action type
  EmailActionType? _filter;

  /// Show revert confirmation dialog and execute revert
  Future<void> _confirmAndRevert(
    BuildContext context,
    EmailScanProvider scanProvider,
  ) async {
    final logger = Logger();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert Last Run?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will undo all ${scanProvider.revertableActionCount} actions from the last scan:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRevertStats(scanProvider),
            const SizedBox(height: 16),
            const Text(
              'Deleted emails will be restored to your inbox.\n'
              'Moved emails will be returned to their original folders.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Revert All Changes'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Show progress dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            title: Text('Reverting Changes'),
            content: SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }

      try {
        // Execute revert
        await scanProvider.revertLastRun();
        logger.i('✅ Successfully reverted ${scanProvider.revertableActionCount} actions');

        if (context.mounted) {
          // Close progress dialog
          Navigator.pop(context);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All changes have been reverted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        logger.e('❌ Revert failed: $e');

        if (context.mounted) {
          // Close progress dialog
          Navigator.pop(context);

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Revert failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Build stats for revert confirmation
  Widget _buildRevertStats(EmailScanProvider scanProvider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (scanProvider.deletedCount > 0)
          Chip(
            label: Text('${scanProvider.deletedCount} will be restored'),
            backgroundColor: Colors.red.shade100,
            labelStyle: TextStyle(color: Colors.red.shade900, fontSize: 12),
          ),
        if (scanProvider.movedCount > 0)
          Chip(
            label: Text('${scanProvider.movedCount} will be returned'),
            backgroundColor: Colors.orange.shade100,
            labelStyle: TextStyle(color: Colors.orange.shade900, fontSize: 12),
          ),
      ],
    );
  }

  /// Export scan results to CSV file
  Future<void> _exportResults(
    BuildContext context,
    EmailScanProvider scanProvider,
  ) async {
    final logger = Logger();

    try {
      // Generate CSV content
      final csvContent = scanProvider.exportResultsToCSV();

      // Get configured export directory from Settings, or use default
      final settingsStore = SettingsStore();
      final configuredDir = await settingsStore.getCsvExportDirectory();

      String exportPath;
      if (configuredDir != null && configuredDir.isNotEmpty) {
        // Use configured directory
        final dir = Directory(configuredDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        exportPath = configuredDir;
      } else {
        // Use default directory (downloads on mobile, documents on desktop)
        final directory = Platform.isAndroid || Platform.isIOS
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        if (directory == null) {
          throw Exception('Could not access storage directory');
        }
        exportPath = directory.path;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'scan_results_$timestamp.csv';
      // Normalize export path - remove trailing slashes to avoid double separators
      String normalizedPath = exportPath;
      while (normalizedPath.endsWith('/') || normalizedPath.endsWith('\\')) {
        normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
      }
      // Use platform-appropriate path separator
      final pathSeparator = Platform.isWindows ? '\\' : '/';
      final filePath = '$normalizedPath$pathSeparator$filename';

      // Write CSV to file
      final file = File(filePath);
      await file.writeAsString(csvContent);

      logger.i('✅ Exported scan results to: $filePath');

      if (context.mounted) {
        // Show success dialog with selectable file path for copy support
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Results exported to:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the path above to copy it.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      logger.e('❌ Export failed: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Filter results based on current filter state
  List<EmailActionResult> _getFilteredResults(List<EmailActionResult> allResults) {
    if (_filter == null) {
      return allResults; // Show all
    }

    // Special handling for "No rule" - filter by action=none AND empty matched rule
    if (_filter == EmailActionType.none) {
      return allResults.where((result) {
        final hasNoRule = (result.evaluationResult?.matchedRule ?? '').isEmpty;
        return result.action == EmailActionType.none && hasNoRule;
      }).toList();
    }

    // For other filters, filter by action type
    return allResults.where((result) => result.action == _filter).toList();
  }

  /// Toggle filter when stat chip is clicked
  void _toggleFilter(EmailActionType? filterType) {
    setState(() {
      // If clicking the same filter, clear it (show all)
      if (_filter == filterType) {
        _filter = null;
      } else {
        _filter = filterType;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();
    final summary = scanProvider.getSummary();
    final allResults = scanProvider.results;
    final filteredResults = _getFilteredResults(allResults);

    return Scaffold(
      appBar: AppBarWithExit(
        title: Text('Results - ${widget.accountEmail} - ${widget.platformDisplayName}'),
        // Add explicit back button that returns to account selection
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Account Selection',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Results to CSV',
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportResults(context, scanProvider),
          ),
          if (scanProvider.hasActionsToRevert)
            IconButton(
              tooltip: 'Revert Last Run',
              icon: const Icon(Icons.undo),
              onPressed: () => _confirmAndRevert(context, scanProvider),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(accountId: widget.accountId),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(summary, scanProvider),
            const SizedBox(height: 16),
            // Show filter status if active
            if (_filter != null) ...[
              _buildFilterStatus(filteredResults.length, allResults.length),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Trigger a rebuild to refresh the results display
                  // Results are already in scan provider, just refresh UI
                  setState(() {});
                  // Small delay to show refresh animation
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: filteredResults.isEmpty
                    ? ListView( // Wrap empty state in ListView for pull-to-refresh gesture
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            // ✨ SPRINT 12: Show "Scan Started" when scan is in progress
                            child: scanProvider.status == ScanStatus.scanning
                                ? const ScanStartedEmptyState()
                                : _filter == null
                                    ? const NoResultsEmptyState()
                                    : const NoMatchingEmailsEmptyState(),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: filteredResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) => _buildResultTile(filteredResults[index]),
                      ),
              ),
            ),
            // Action buttons at bottom
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Dismiss any showing snackbar before navigating
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      // Pop back to Account Selection Screen (past Scan Progress)
                      Navigator.popUntil(
                        context,
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Back to Accounts'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // ✨ SPRINT 12 FIX: Push replacement to Scan screen directly
                      // This avoids navigation state issues with pop() and ensures
                      // reliable navigation to the scan screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanProgressScreen(
                            platformId: widget.platformId,
                            platformDisplayName: widget.platformDisplayName,
                            accountId: widget.accountId,
                            accountEmail: widget.accountEmail,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterStatus(int filteredCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing $filteredCount of $totalCount emails • Tap chip again to clear filter',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: () => _toggleFilter(null),
            tooltip: 'Clear filter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> summary, EmailScanProvider scanProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary - ${scanProvider.getScanModeDisplayName()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatChip('Found', scanProvider.totalEmails, const Color(0xFF2196F3), Colors.white, null), // Blue - not filterable
                _buildStatChip('Processed', scanProvider.processedCount, const Color(0xFF9C27B0), Colors.white, null), // Purple - not filterable
                _buildStatChip('Deleted', scanProvider.deletedCount, const Color(0xFFF44336), Colors.white, EmailActionType.delete), // Red
                _buildStatChip('Moved', scanProvider.movedCount, const Color(0xFFFF9800), Colors.white, EmailActionType.moveToJunk), // Orange
                _buildStatChip('Safe', scanProvider.safeSendersCount, const Color(0xFF4CAF50), Colors.white, EmailActionType.safeSender), // Green
                _buildStatChip('No rule', scanProvider.noRuleCount, const Color(0xFF757575), Colors.white, EmailActionType.none), // Grey
                _buildStatChip('Errors', scanProvider.errorCount, const Color(0xFFD32F2F), Colors.white, null, showErrors: true), // Dark Red
              ],
            ),
            // Revert info (Phase 2 Sprint 3)
            if (scanProvider.hasActionsToRevert) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${scanProvider.revertableActionCount} action(s) can be undone. Use Revert button above.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color bg, Color fg, EmailActionType? filterType, {bool showErrors = false}) {
    // Determine if this chip is currently the active filter
    final isActive = _filter == filterType || (showErrors && _filter != null && value > 0);

    return GestureDetector(
      onTap: () {
        // Only allow filtering for "No rule", "Deleted", "Moved", "Safe", and "Errors"
        if (filterType != null) {
          _toggleFilter(filterType);
        } else if (showErrors) {
          // For errors, filter by showing all emails with !success flag
          // For now, we do not have a simple way to filter errors separately
          // since they could overlap with any action type
          // Skip error filtering for now
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error filtering not yet implemented'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: isActive ? bg.withValues(alpha: 0.7) : bg,
        labelStyle: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildResultTile(EmailActionResult result) {
    // Issue #47: Title shows sender email, subtitle shows folder • subject • rule
    // Decode Punycode domains for display
    final rawFrom = result.email.from;
    final decodedFrom = PatternNormalization.normalizeAndDecodeEmail(rawFrom);
    final title = decodedFrom.isNotEmpty
        ? decodedFrom
        : 'Unknown sender';
    final folder = result.email.folderName;
    // Clean subject for display (remove tabs, extra spaces, repeated punctuation)
    final rawSubject = result.email.subject;
    final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(rawSubject);
    final subject = cleanedSubject.isNotEmpty ? cleanedSubject : 'No subject';
    // Issue #51: Display matched rule name or "No rule" if empty/null
    final matchedRule = result.evaluationResult?.matchedRule ?? '';
    final rule = matchedRule.isNotEmpty ? matchedRule : 'No rule';
    final subtitle = '$folder • $subject • $rule';
    final trailing = result.success
        ? const Icon(Icons.check, color: Colors.green)
        : const Icon(Icons.error, color: Colors.red);

    return ListTile(
      leading: _actionIcon(result.action),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: () => _showEmailDetailSheet(result),
    );
  }

  /// Extract the root domain from a full domain (e.g., "subdomain.example.com" -> "example.com")
  /// For domains like "pptwvrnbdho.atlantaoffre.com", returns "atlantaoffre.com"
  String? _extractRootDomain(String? fullDomain) {
    if (fullDomain == null || fullDomain.isEmpty) return null;

    final parts = fullDomain.split('.');
    // Need at least 2 parts for a valid domain (e.g., example.com)
    if (parts.length < 2) return fullDomain;

    // For most domains, return last 2 parts (example.com)
    // For known TLDs like .co.uk, .com.au, etc., would need more logic
    // For now, use simple heuristic: last 2 parts
    return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
  }

  /// Show bottom sheet with email details and inline quick actions
  void _showEmailDetailSheet(EmailActionResult result) {
    final email = result.email;
    final bodyParser = EmailBodyParser();
    // Extract email and domain, then decode Punycode for display
    final rawSenderEmail = bodyParser.extractEmailAddress(email.from);
    final senderEmail = PatternNormalization.normalizeAndDecodeEmail(rawSenderEmail);
    final rawSenderDomain = bodyParser.extractDomainFromEmail(email.from);
    final senderDomain = rawSenderDomain != null 
        ? PatternNormalization.decodePunycodeDomain(rawSenderDomain)
        : null;
    final rootDomain = _extractRootDomain(senderDomain);
    final matchedRule = result.evaluationResult?.matchedRule ?? '';
    final hasNoRule = matchedRule.isEmpty || result.action == EmailActionType.none;
    final isDeleted = result.action == EmailActionType.delete;
    final isSafeSender = result.action == EmailActionType.safeSender;

    // Clean subject for display
    final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(email.subject);
    final displaySubject = cleanedSubject.isNotEmpty ? cleanedSubject : '(No subject)';

    // Format date/time
    final dateStr = email.receivedDate.toString().substring(0, 16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // One-line summary matching Results screen format
                Row(
                  children: [
                    _actionIcon(result.action),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        senderEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    result.success
                        ? const Icon(Icons.check, color: Colors.green, size: 18)
                        : const Icon(Icons.error, color: Colors.red, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                // Subtitle line: folder • subject • rule
                Text(
                  '${email.folderName} • $displaySubject • ${matchedRule.isNotEmpty ? matchedRule : "No rule"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Date/time
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (senderDomain != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.domain, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        senderDomain,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Action result badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getActionColor(result.action).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getActionDescription(result),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getActionColor(result.action),
                    ),
                  ),
                ),
                const Divider(height: 20),

                // === SAFE SENDER SECTION ===
                // Show for: Deleted emails, No Rule emails, or Safe Sender emails (for exception)
                if (isDeleted || hasNoRule || isSafeSender) ...[
                  Text(
                    isSafeSender ? 'Update Safe Sender' : 'Add to Safe Senders',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInlineActionButton(
                        icon: Icons.person,
                        label: 'Exact Email',
                        subtitle: senderEmail,
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _addSafeSender(senderEmail, 'exact');
                        },
                      ),
                      if (senderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain,
                          label: 'Exact Domain',
                          subtitle: '@$senderDomain',
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addSafeSender('@$senderDomain', 'exactDomain');
                          },
                        ),
                      // Always show Entire Domain option (uses root domain or full domain if no subdomain)
                      if (senderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public,
                          label: 'Entire Domain',
                          subtitle: '@*.${rootDomain ?? senderDomain}',
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addSafeSender(rootDomain ?? senderDomain, 'entireDomain');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // === BLOCK RULE SECTION ===
                // Show for: No Rule emails or Safe Sender emails (to add exception/block rule)
                if (hasNoRule || isSafeSender) ...[
                  const Text(
                    'Create Block Rule',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInlineActionButton(
                        icon: Icons.person_off,
                        label: 'Block Email',
                        subtitle: senderEmail,
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _createBlockRule('from', senderEmail);
                        },
                      ),
                      if (senderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain_disabled,
                          label: 'Block Exact Domain',
                          subtitle: '@$senderDomain',
                          color: Colors.red,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _createBlockRule('exactDomain', '@$senderDomain');
                          },
                        ),
                      // Always show Block Entire Domain option (uses root domain or full domain if no subdomain)
                      if (senderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public_off,
                          label: 'Block Entire Domain',
                          subtitle: '@*.${rootDomain ?? senderDomain}',
                          color: Colors.red,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _createBlockRule('entireDomain', rootDomain ?? senderDomain);
                          },
                        ),
                      if (cleanedSubject.isNotEmpty && cleanedSubject != '(No subject)')
                        _buildInlineActionButton(
                          icon: Icons.subject,
                          label: 'Block Subject',
                          subtitle: cleanedSubject.length > 20
                              ? '${cleanedSubject.substring(0, 20)}...'
                              : cleanedSubject,
                          color: Colors.orange,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _createBlockRule('subject', cleanedSubject);
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build an inline action button (used in popup instead of dialogs)
  Widget _buildInlineActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(EmailActionType action) {
    switch (action) {
      case EmailActionType.delete:
        return Colors.red;
      case EmailActionType.moveToJunk:
        return Colors.orange;
      case EmailActionType.safeSender:
        return Colors.green;
      case EmailActionType.markAsRead:
        return Colors.blueGrey;
      case EmailActionType.none:
        return Colors.grey;
    }
  }

  /// Add sender to safe senders list
  /// Types: 'exact' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com)
  Future<void> _addSafeSender(String value, String type) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final logger = Logger();

    try {
      // Create regex pattern based on type
      String pattern;
      String displayMessage;

      switch (type) {
        case 'exact':
          // Exact email match - escape special chars
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^$escaped\$';
          displayMessage = 'Added "$value" to Safe Senders';
          break;
        case 'exactDomain':
          // Exact domain match (e.g., @subdomain.domain.com)
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^[^@\\s]+$escaped\$';
          displayMessage = 'Added exact domain "$value" to Safe Senders';
          break;
        case 'entireDomain':
          // Entire domain pattern (e.g., @*.domain.com matches any subdomain)
          // Regex: ^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$
          final escaped = value.replaceAll('.', r'\.');
          pattern = r'^[^@\s]+@(?:[a-z0-9-]+\.)*' + escaped + r'$';
          displayMessage = 'Added entire domain "*.$value" to Safe Senders';
          break;
        default:
          logger.w('Unknown safe sender type: $type');
          return;
      }

      // Add to safe senders via provider (persists to database and YAML)
      await ruleProvider.addSafeSender(pattern);

      logger.i('✅ Added safe sender: $pattern');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      logger.e('❌ Failed to add safe sender: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add safe sender: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  /// Create a block rule (persists to database and YAML)
  /// Types: 'from' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com), 'subject'
  Future<void> _createBlockRule(String type, String value) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final logger = Logger();

    try {
      // Create rule based on type
      String pattern;
      String ruleName;
      String displayMessage;

      switch (type) {
        case 'from':
          // Block exact email - escape special chars
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '^$escaped\$';
          ruleName = 'Block_${value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          displayMessage = 'Created rule to block email "$value"';
          break;
        case 'exactDomain':
          // Block exact domain (e.g., @subdomain.domain.com)
          final escaped = value.replaceAll('.', r'\.').replaceAll('@', r'@');
          pattern = '$escaped\$';
          ruleName = 'Block_ExactDomain_${value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          displayMessage = 'Created rule to block exact domain "$value"';
          break;
        case 'entireDomain':
          // Block entire domain pattern (e.g., @*.domain.com matches any subdomain)
          // Regex: @(?:[a-z0-9-]+\.)*domain\.com$
          final escaped = value.replaceAll('.', r'\.');
          pattern = r'@(?:[a-z0-9-]+\.)*' + escaped + r'$';
          ruleName = 'Block_EntireDomain_${value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          displayMessage = 'Created rule to block entire domain "*.$value"';
          break;
        case 'subject':
          // Block subject containing text - escape special regex chars
          final escaped = value.replaceAll(RegExp(r'[.*+?^${}()|[\]\\]'), r'\$&');
          pattern = escaped;
          ruleName = 'Block_Subject_${value.substring(0, value.length.clamp(0, 20)).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          displayMessage = 'Created rule to block subject containing "$value"';
          break;
        default:
          logger.w('Unknown block rule type: $type');
          return;
      }

      // Create the rule with proper types
      final conditions = type == 'subject'
          ? RuleConditions(type: 'OR', subject: [pattern])
          : RuleConditions(type: 'OR', header: [pattern]);

      final rule = Rule(
        name: ruleName,
        enabled: true,
        isLocal: true,  // Mark as local (created in app, not from YAML)
        executionOrder: 100,  // Default execution order
        conditions: conditions,
        actions: RuleActions(delete: true),
        metadata: {
          'comment': 'Created from Results screen on ${DateTime.now().toIso8601String().substring(0, 10)}',
        },
      );

      // Add rule via provider (persists to database and YAML)
      await ruleProvider.addRule(rule);

      logger.i('✅ Created block rule: $ruleName with pattern: $pattern');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      logger.e('❌ Failed to create block rule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create rule: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  String _getActionDescription(EmailActionResult result) {
    switch (result.action) {
      case EmailActionType.delete:
        return result.success ? 'Deleted' : 'Delete failed';
      case EmailActionType.moveToJunk:
        return result.success ? 'Moved to junk' : 'Move failed';
      case EmailActionType.safeSender:
        return 'Safe sender - no action';
      case EmailActionType.markAsRead:
        return result.success ? 'Marked as read' : 'Mark as read failed';
      case EmailActionType.none:
        return 'No matching rule';
    }
  }

  Widget _actionIcon(EmailActionType action) {
    switch (action) {
      case EmailActionType.delete:
        return const Icon(Icons.delete, color: Colors.red);
      case EmailActionType.moveToJunk:
        return const Icon(Icons.archive, color: Colors.orange);
      case EmailActionType.safeSender:
        return const Icon(Icons.check_circle, color: Colors.green);
      case EmailActionType.markAsRead:
        return const Icon(Icons.mark_email_read, color: Colors.blueGrey);
      case EmailActionType.none:
        return const Icon(Icons.mail_outline, color: Colors.grey);
    }
  }
}
