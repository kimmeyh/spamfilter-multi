import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_bar_with_exit.dart';

import '../../core/providers/email_scan_provider.dart' show EmailScanProvider, EmailActionResult, EmailActionType;
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

      // Get downloads directory (or documents on desktop)
      final directory = Platform.isAndroid || Platform.isIOS
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'scan_results_$timestamp.csv';
      final filePath = '${directory.path}/$filename';

      // Write CSV to file
      final file = File(filePath);
      await file.writeAsString(csvContent);

      logger.i('✅ Exported scan results to: $filePath');

      if (context.mounted) {
        // Show success message with file path
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Results exported to:\n$filePath'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
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
                            child: _filter == null
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
                      // Navigate back to scan screen for new scan
                      Navigator.pop(context);
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
    final title = result.email.from.isNotEmpty
        ? result.email.from
        : 'Unknown sender';
    final folder = result.email.folderName;
    final subject = result.email.subject.isNotEmpty
        ? result.email.subject
        : 'No subject';
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
    );
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
