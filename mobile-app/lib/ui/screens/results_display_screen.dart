import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_bar_with_exit.dart';
import 'scan_progress_screen.dart';
import 'settings_screen.dart';

import '../../core/providers/email_scan_provider.dart' show EmailScanProvider, EmailActionResult, EmailActionType, ScanStatus, ScanMode;
import '../../core/providers/rule_set_provider.dart';
import '../../core/models/email_message.dart';
import '../../core/models/rule_set.dart' show Rule, RuleConditions, RuleActions;
import '../../core/services/email_body_parser.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
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

/// Special filter types beyond EmailActionType
enum SpecialFilter {
  found,      // All emails (Found)
  processed,  // All processed emails (Processed)
  error,      // Only emails with errors
}

class _ResultsDisplayScreenState extends State<ResultsDisplayScreen> {
  // Filter state: null means show all, otherwise filter by this action type or special filter
  EmailActionType? _filter;
  SpecialFilter? _specialFilter;

  // Search state (Item 8: Ctrl-F search)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // Issue 2a: Auto-focus on Ctrl+F
  String _searchQuery = '';
  bool _showSearch = false;

  // Folder filter state (Item 6: folder dropdown)
  Set<String> _selectedFolders = {};

  // Issue 3: Cache folders for performance
  List<String>? _cachedFolders;

  // [NEW] Testing feedback FB-4/FB-5: Historical scan result data
  ScanResult? _lastCompletedScan;
  bool _hasEverScanned = false;
  bool _historicalLoaded = false;
  List<EmailActionResult> _historicalResults = [];

  @override
  void initState() {
    super.initState();
    // Item 4: Set Processed filter on by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _specialFilter = SpecialFilter.processed;
      });
    });
    // Load last completed scan for historical display
    _loadLastCompletedScan();
  }

  /// Load the most recent completed scan and its email actions from database
  Future<void> _loadLastCompletedScan() async {
    try {
      final dbHelper = DatabaseHelper();
      final scanResultStore = ScanResultStore(dbHelper);
      final lastScan = await scanResultStore.getLatestCompletedScan(widget.accountId);

      List<EmailActionResult> historicalResults = [];
      if (lastScan != null && lastScan.id != null) {
        // Load individual email actions for this scan
        final actionMaps = await dbHelper.queryEmailActions(
          scanResultId: lastScan.id,
        );
        historicalResults = actionMaps.map((map) {
          final email = EmailMessage(
            id: map['email_id'] as String? ?? '',
            from: map['email_from'] as String? ?? '',
            subject: map['email_subject'] as String? ?? '',
            body: '',
            headers: {},
            receivedDate: DateTime.fromMillisecondsSinceEpoch(
              (map['email_received_date'] as int?) ?? 0,
            ),
            folderName: map['email_folder'] as String? ?? '',
          );
          final actionStr = map['action_type'] as String? ?? 'none';
          final action = EmailActionType.values.firstWhere(
            (e) => e.name == actionStr,
            orElse: () => EmailActionType.none,
          );
          return EmailActionResult(
            email: email,
            action: action,
            success: (map['success'] as int?) == 1,
            error: map['error_message'] as String?,
          );
        }).toList();
      }

      if (mounted) {
        setState(() {
          _lastCompletedScan = lastScan;
          _hasEverScanned = lastScan != null;
          _historicalResults = historicalResults;
          _historicalLoaded = true;
        });
      }
    } catch (e) {
      // If loading fails, continue with empty state
      if (mounted) {
        setState(() {
          _historicalLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Issue 2a: Dispose focus node
    super.dispose();
  }

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
        logger.i('[OK] Successfully reverted ${scanProvider.revertableActionCount} actions');

        if (context.mounted) {
          // Close progress dialog
          Navigator.pop(context);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('[OK] All changes have been reverted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        logger.e('[FAIL] Revert failed: $e');

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

      logger.i('[OK] Exported scan results to: $filePath');

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
      logger.e('[FAIL] Export failed: $e');

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

  /// Filter results based on current filter state, search query, and folder filter
  List<EmailActionResult> _getFilteredResults(List<EmailActionResult> allResults) {
    var results = allResults;
    
    // Apply special filter first (Found, Processed, Error)
    if (_specialFilter != null) {
      switch (_specialFilter!) {
        case SpecialFilter.found:
          // Show all emails (no filtering)
          break;
        case SpecialFilter.processed:
          // Show only successfully processed emails
          results = results.where((result) => result.success).toList();
          break;
        case SpecialFilter.error:
          // Show only emails with errors
          results = results.where((result) => !result.success).toList();
          break;
      }
    }
    
    // Apply action type filter
    if (_filter != null) {
      // Special handling for "No rule" - filter by action=none AND empty matched rule
      if (_filter == EmailActionType.none) {
        results = results.where((result) {
          final hasNoRule = (result.evaluationResult?.matchedRule ?? '').isEmpty;
          return result.action == EmailActionType.none && hasNoRule;
        }).toList();
      } else {
        // For other filters, filter by action type
        results = results.where((result) => result.action == _filter).toList();
      }
    }
    
    // Apply search filter (Item 8: Ctrl-F search)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((result) {
        final from = result.email.from.toLowerCase();
        final subject = result.email.subject.toLowerCase();
        final folder = result.email.folderName.toLowerCase();
        final rule = (result.evaluationResult?.matchedRule ?? '').toLowerCase();
        return from.contains(query) || 
               subject.contains(query) || 
               folder.contains(query) ||
               rule.contains(query);
      }).toList();
    }
    
    // Apply folder filter (Item 6: folder dropdown)
    if (_selectedFolders.isNotEmpty) {
      results = results.where((result) {
        return _selectedFolders.contains(result.email.folderName);
      }).toList();
    }
    
    // Item 5: Sort by folder → domain.tld → email
    results.sort((a, b) {
      // First sort by folder
      final folderCompare = a.email.folderName.compareTo(b.email.folderName);
      if (folderCompare != 0) return folderCompare;
      
      // Then sort by domain
      final bodyParser = EmailBodyParser();
      final domainA = bodyParser.extractDomainFromEmail(a.email.from) ?? '';
      final domainB = bodyParser.extractDomainFromEmail(b.email.from) ?? '';
      final domainCompare = domainA.compareTo(domainB);
      if (domainCompare != 0) return domainCompare;
      
      // Finally sort by email
      final emailA = bodyParser.extractEmailAddress(a.email.from);
      final emailB = bodyParser.extractEmailAddress(b.email.from);
      return emailA.compareTo(emailB);
    });
    
    return results;
  }

  /// Toggle filter when stat chip is clicked
  void _toggleFilter(EmailActionType? filterType) {
    setState(() {
      // If clicking the same filter, clear it (show all)
      if (_filter == filterType) {
        _filter = null;
      } else {
        _filter = filterType;
        _specialFilter = null; // Clear special filter when action filter is set
      }
    });
  }
  
  /// Toggle special filter (Found, Processed, Error)
  void _toggleSpecialFilter(SpecialFilter filterType) {
    setState(() {
      // If clicking the same filter, clear it (show all)
      if (_specialFilter == filterType) {
        _specialFilter = null;
      } else {
        _specialFilter = filterType;
        _filter = null; // Clear action filter when special filter is set
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();
    final summary = scanProvider.getSummary();
    final liveResults = scanProvider.results;

    // Use historical results from database when no live results available
    final allResults = liveResults.isNotEmpty ? liveResults : _historicalResults;
    final filteredResults = _getFilteredResults(allResults);

    // Issue 3: Cache folders list for performance (only extract once per results set)
    if (_cachedFolders == null || _cachedFolders!.length != allResults.map((r) => r.email.folderName).toSet().length) {
      _cachedFolders = allResults.map((r) => r.email.folderName).toSet().toList()..sort();
    }

    // Issue 2: Wrap with Focus to detect Ctrl+F keyboard shortcut
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Detect Ctrl+F (or Cmd+F on macOS)
        if (event is KeyDownEvent) {
          final isCtrlPressed = event.logicalKey == LogicalKeyboardKey.controlLeft ||
                                  event.logicalKey == LogicalKeyboardKey.controlRight ||
                                  event.logicalKey == LogicalKeyboardKey.metaLeft ||
                                  event.logicalKey == LogicalKeyboardKey.metaRight;
          final isFPressed = event.logicalKey == LogicalKeyboardKey.keyF;

          // Check if Ctrl/Cmd + F is pressed
          if ((HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) && isFPressed) {
            setState(() {
              _showSearch = true;
            });
            // Issue 2a: Auto-focus the search field after opening
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      appBar: AppBarWithExit(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // Issue 2a: Connect focus node
                autofocus: true,
                style: const TextStyle(color: Colors.black), // Issue 2b: Black text
                decoration: const InputDecoration(
                  hintText: 'Search emails...',
                  hintStyle: TextStyle(color: Colors.black54), // Issue 2b: Dark gray hint
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text('Results - ${widget.accountEmail} - ${widget.platformDisplayName}'),
        // Add explicit back button that returns to account selection
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close Search',
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Scan Progress',
                onPressed: () {
                  // Dismiss any showing snackbar before navigating
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  // Push replacement to Scan Progress screen (same as Scan Again button)
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
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              tooltip: 'Search (Ctrl+F)',
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
            ),
            IconButton(
              tooltip: 'Export Results to CSV',
              icon: const Icon(Icons.file_download),
              onPressed: () => _exportResults(context, scanProvider),
            ),
            // [REMOVED] ISSUE #123+#124: Revert button removed - no longer needed
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(summary, scanProvider, allResults),
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
                            // [UPDATED] Testing feedback FB-5: Only show "No Results Yet"
                            // if no scan has EVER been run for this account
                            child: scanProvider.status == ScanStatus.scanning
                                ? const ScanStartedEmptyState()
                                : scanProvider.status == ScanStatus.completed && _filter == null
                                    ? const ScanCompleteNoEmailsEmptyState()
                                    : _filter != null
                                        ? const NoMatchingEmailsEmptyState()
                                        : (_historicalLoaded && !_hasEverScanned)
                                            ? const NoResultsEmptyState()
                                            : const ScanCompleteNoEmailsEmptyState(),
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
                      // [NEW] SPRINT 12 FIX: Push replacement to Scan screen directly
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
    ),
    ); // Close Focus widget for Issue 2: Ctrl+F shortcut
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

  Widget _buildSummary(Map<String, dynamic> summary, EmailScanProvider scanProvider, List<EmailActionResult> allResults) {
    // [UPDATED] ISSUE #123+#124: Show context based on scan mode
    final scanMode = scanProvider.scanMode;
    final isReadOnly = scanMode == ScanMode.readonly;
    final isSafeSendersOnly = scanMode == ScanMode.testAll;
    final isRulesOnly = scanMode == ScanMode.testLimit;

    // [NEW] Testing feedback FB-4: Determine if showing live or historical results
    final hasLiveResults = allResults.isNotEmpty || scanProvider.status == ScanStatus.scanning;
    final showingHistorical = !hasLiveResults && _lastCompletedScan != null;

    // Build scan type and time info
    String? scanTypeLabel;
    String? scanTimeLabel;
    if (hasLiveResults) {
      scanTypeLabel = 'Live Scan';
    } else if (showingHistorical && _lastCompletedScan != null) {
      scanTypeLabel = _lastCompletedScan!.scanType == 'background' ? 'Background Scan' : 'Live Scan';
      if (_lastCompletedScan!.completedAt != null) {
        final completedDate = DateTime.fromMillisecondsSinceEpoch(_lastCompletedScan!.completedAt!);
        scanTimeLabel = 'Completed: ${completedDate.toString().substring(0, 16)}';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasLiveResults
                ? 'Summary - ${scanProvider.getScanModeDisplayName()}'
                : showingHistorical
                  ? 'Last Scan Results'
                  : 'Summary',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (scanTypeLabel != null || scanTimeLabel != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  if (scanTypeLabel != null)
                    Text(
                      scanTypeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (scanTimeLabel != null)
                    Text(
                      scanTimeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // [UPDATED] Testing feedback FB-4: Show historical counts when no live data
            if (showingHistorical && _lastCompletedScan != null)
              _buildHistoricalStats(_lastCompletedScan!)
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Item 3: Make Found/Processed/Moved/Error filterable
                  _buildSpecialStatChip('Found', scanProvider.totalEmails, const Color(0xFF2196F3), Colors.white, SpecialFilter.found),
                  _buildSpecialStatChip('Processed', scanProvider.processedCount, const Color(0xFF9C27B0), Colors.white, SpecialFilter.processed),
                  // [UPDATED] ISSUE #123+#124: Show "(not processed)" for rule actions in safe-senders-only mode
                  _buildStatChipWithMode(
                    isSafeSendersOnly || isReadOnly ? 'Deleted (not processed)' : 'Deleted',
                    scanProvider.deletedCount,
                    isSafeSendersOnly || isReadOnly ? const Color(0xFFEF9A9A) : const Color(0xFFF44336),
                    isSafeSendersOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.delete,
                  ),
                  _buildStatChipWithMode(
                    isSafeSendersOnly || isReadOnly ? 'Moved (not processed)' : 'Moved',
                    scanProvider.movedCount,
                    isSafeSendersOnly || isReadOnly ? const Color(0xFFFFCC80) : const Color(0xFFFF9800),
                    isSafeSendersOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.moveToJunk,
                  ),
                  // [UPDATED] ISSUE #123+#124: Show "(not processed)" for safe senders in rules-only mode
                  _buildStatChipWithMode(
                    isRulesOnly || isReadOnly ? 'Safe (not processed)' : 'Safe',
                    scanProvider.safeSendersCount,
                    isRulesOnly || isReadOnly ? const Color(0xFFA5D6A7) : const Color(0xFF4CAF50),
                    isRulesOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.safeSender,
                  ),
                  _buildStatChip('No rule', scanProvider.noRuleCount, const Color(0xFF757575), Colors.white, EmailActionType.none),
                  _buildSpecialStatChip('Errors', scanProvider.errorCount, const Color(0xFFD32F2F), Colors.white, SpecialFilter.error),
                  // Item 6: Add Folders multi-select filter
                  _buildFolderFilterChip(allResults),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Build stat chips from historical scan result (non-interactive, display only)
  Widget _buildHistoricalStats(ScanResult scan) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Chip(
          label: Text('Found: ${scan.totalEmails}'),
          backgroundColor: const Color(0xFF2196F3),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('Processed: ${scan.processedCount}'),
          backgroundColor: const Color(0xFF9C27B0),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('Deleted: ${scan.deletedCount}'),
          backgroundColor: const Color(0xFFF44336),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('Moved: ${scan.movedCount}'),
          backgroundColor: const Color(0xFFFF9800),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('Safe: ${scan.safeSenderCount}'),
          backgroundColor: const Color(0xFF4CAF50),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('No rule: ${scan.noRuleCount}'),
          backgroundColor: const Color(0xFF757575),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        Chip(
          label: Text('Errors: ${scan.errorCount}'),
          backgroundColor: const Color(0xFFD32F2F),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ],
    );
  }

  /// Build stat chip with mode-aware styling
  Widget _buildStatChipWithMode(String label, int value, Color bg, Color fg, EmailActionType? filterType) {
    final isActive = _filter == filterType;

    return GestureDetector(
      onTap: () {
        if (filterType != null) {
          _toggleFilter(filterType);
        }
      },
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: isActive ? bg.withValues(alpha: 0.7) : bg,
        labelStyle: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
          fontSize: label.contains('not processed') ? 11 : 14,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color bg, Color fg, EmailActionType? filterType, {bool showErrors = false}) {
    // Determine if this chip is currently the active filter
    final isActive = _filter == filterType;

    return GestureDetector(
      onTap: () {
        if (filterType != null) {
          _toggleFilter(filterType);
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
  
  /// Build stat chip for special filters (Found, Processed, Error)
  Widget _buildSpecialStatChip(String label, int value, Color bg, Color fg, SpecialFilter filterType) {
    final isActive = _specialFilter == filterType;

    return GestureDetector(
      onTap: () {
        _toggleSpecialFilter(filterType);
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
  
  /// Build folder filter dropdown chip (Item 6)
  Widget _buildFolderFilterChip(List<EmailActionResult> allResults) {
    // Issue 3: Use cached folders for performance
    final folders = _cachedFolders ?? [];
    final isActive = _selectedFolders.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        // Show folder selection dialog
        final selected = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => _buildFolderSelectionDialog(folders),
        );
        
        if (selected != null) {
          setState(() {
            _selectedFolders = selected;
          });
        }
      },
      child: Chip(
        label: Text(_selectedFolders.isEmpty 
            ? 'Folders: All' 
            : 'Folders: ${_selectedFolders.length}'),
        avatar: const Icon(Icons.folder, size: 18),
        backgroundColor: isActive ? Colors.indigo.withValues(alpha: 0.7) : Colors.indigo,
        labelStyle: TextStyle(
          color: Colors.white,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
  
  /// Build folder selection dialog
  Widget _buildFolderSelectionDialog(List<String> folders) {
    final tempSelected = Set<String>.from(_selectedFolders);
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Select Folders'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                CheckboxListTile(
                  title: const Text('All Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: tempSelected.isEmpty,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        tempSelected.clear();
                      }
                    });
                  },
                ),
                const Divider(),
                ...folders.map((folder) {
                  return CheckboxListTile(
                    title: Text(folder),
                    value: tempSelected.contains(folder),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelected.add(folder);
                        } else {
                          tempSelected.remove(folder);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempSelected),
              child: const Text('Apply'),
            ),
          ],
        );
      },
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

    // Issue 6: Wrap with Container to capture position for popup
    final tileKey = GlobalKey();

    return Container(
      key: tileKey,
      child: ListTile(
        leading: _actionIcon(result.action),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: () => _showEmailDetailSheet(result, itemKey: tileKey),
      ),
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

  /// Show positioned popup with email details and inline quick actions
  /// Issue 6: CSS-like positioning - show popup below/above email item
  void _showEmailDetailSheet(EmailActionResult result, {GlobalKey? itemKey}) {
    final email = result.email;
    final bodyParser = EmailBodyParser();
    // Extract raw email and domain (Punycode format) - used for block rule creation
    final rawSenderEmail = bodyParser.extractEmailAddress(email.from);
    final rawSenderDomain = bodyParser.extractDomainFromEmail(email.from);
    // Normalized email (plus-sign stripped) - used for safe sender pattern creation
    // This matches how SafeSenderList.findMatch() normalizes emails during evaluation
    final normalizedSenderEmail = PatternNormalization.normalizeFromHeader(email.from);
    // Decode for display only
    final displaySenderEmail = PatternNormalization.normalizeAndDecodeEmail(rawSenderEmail);
    final displaySenderDomain = rawSenderDomain != null
        ? PatternNormalization.decodePunycodeDomain(rawSenderDomain)
        : null;
    // Extract root domain from RAW domain (for rule creation)
    final rawRootDomain = _extractRootDomain(rawSenderDomain);
    // Decode root domain for display
    final displayRootDomain = rawRootDomain != null
        ? PatternNormalization.decodePunycodeDomain(rawRootDomain)
        : null;
    final matchedRule = result.evaluationResult?.matchedRule ?? '';
    final hasNoRule = matchedRule.isEmpty || result.action == EmailActionType.none;
    final isDeleted = result.action == EmailActionType.delete;
    final isSafeSender = result.action == EmailActionType.safeSender;

    // Clean subject for display
    final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(email.subject);
    final displaySubject = cleanedSubject.isNotEmpty ? cleanedSubject : '(No subject)';

    // Format date/time
    final dateStr = email.receivedDate.toString().substring(0, 16);

    // Issue 6: Calculate position for CSS-like popup positioning
    Offset? itemPosition;
    Size? itemSize;
    if (itemKey != null) {
      final RenderBox? renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        itemPosition = renderBox.localToGlobal(Offset.zero);
        itemSize = renderBox.size;
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        // Get screen dimensions
        final screenSize = MediaQuery.of(context).size;
        final screenHeight = screenSize.height;
        final popupHeight = screenHeight * 0.6; // Approximate popup height

        // Calculate position
        double? top;
        double? bottom;

        if (itemPosition != null && itemSize != null) {
          final itemBottom = itemPosition.dy + itemSize.height;
          final spaceBelow = screenHeight - itemBottom;
          final spaceAbove = itemPosition.dy;

          if (spaceBelow >= popupHeight) {
            // Show below email
            top = itemBottom + 8; // 8px gap
          } else if (spaceAbove >= popupHeight) {
            // Show above email
            bottom = screenHeight - itemPosition.dy + 8; // 8px gap
          } else {
            // Not enough room above or below - align with first email
            top = itemPosition.dy;
          }
        }

        return Stack(
          children: [
            Positioned(
              top: top,
              bottom: bottom,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
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
                        displaySenderEmail,
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
                    if (displaySenderDomain != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.domain, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        displaySenderDomain,
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
                // Issue 5: Always show Safe Sender options for all emails
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
                        subtitle: displaySenderEmail,
                        color: Colors.green,
                        isMatched: isSafeSender && result.evaluationResult?.matchedPatternType == 'exact_email',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          // Use normalized email (plus-signs stripped) to match SafeSenderList evaluation
                          _addSafeSender(normalizedSenderEmail, 'exact');
                        },
                      ),
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain,
                          label: 'Exact Domain',
                          subtitle: '@$displaySenderDomain',
                          color: Colors.green,
                          isMatched: isSafeSender && result.evaluationResult?.matchedPatternType == 'exact_domain',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _addSafeSender('@$rawSenderDomain', 'exactDomain');
                          },
                        ),
                      // Always show Entire Domain option (uses root domain or full domain if no subdomain)
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public,
                          label: 'Entire Domain',
                          subtitle: '@*.${displayRootDomain ?? displaySenderDomain}',
                          color: Colors.green,
                          isMatched: isSafeSender && result.evaluationResult?.matchedPatternType == 'entire_domain',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _addSafeSender(rawRootDomain ?? rawSenderDomain, 'entireDomain');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                // === BLOCK RULE SECTION ===
                // Issue 5: Always show Block Rule options for all emails
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
                        subtitle: displaySenderEmail,
                        color: Colors.red,
                        isMatched: isDeleted && result.evaluationResult?.matchedPatternType == 'exact_email',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _createBlockRule('from', rawSenderEmail);
                        },
                      ),
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain_disabled,
                          label: 'Block Exact Domain',
                          subtitle: '@$displaySenderDomain',
                          color: Colors.red,
                          isMatched: isDeleted && result.evaluationResult?.matchedPatternType == 'exact_domain',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _createBlockRule('exactDomain', '@$rawSenderDomain');
                          },
                        ),
                      // Always show Block Entire Domain option (uses root domain or full domain if no subdomain)
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public_off,
                          label: 'Block Entire Domain',
                          subtitle: '@*.${displayRootDomain ?? displaySenderDomain}',
                          color: Colors.red,
                          isMatched: isDeleted && result.evaluationResult?.matchedPatternType == 'entire_domain',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _createBlockRule('entireDomain', rawRootDomain ?? rawSenderDomain);
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
                          isMatched: isDeleted && result.evaluationResult?.matchedPatternType == 'subject',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _createBlockRule('subject', cleanedSubject);
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isMatched = false, // Item 2: Visual indicator for current rule match
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isMatched ? color : color.withValues(alpha: 0.3),
            width: isMatched ? 2 : 1, // Thicker border for matched rule
          ),
          borderRadius: BorderRadius.circular(8),
          color: isMatched 
              ? color.withValues(alpha: 0.15) // Darker shade for matched
              : color.withValues(alpha: 0.05),
        ),
        child: Stack(
          children: [
            Column(
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
          // Item 2: Green checkmark in top-right corner for matched rule
          if (isMatched)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
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

      logger.i('[OK] Added safe sender: $pattern');

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
      logger.e('[FAIL] Failed to add safe sender: $e');
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

      logger.i('[OK] Created block rule: $ruleName with pattern: $pattern');

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
      logger.e('[FAIL] Failed to create block rule: $e');
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
