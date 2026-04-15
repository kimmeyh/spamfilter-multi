import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../widgets/app_bar_with_exit.dart';
import 'help_screen.dart';
import 'results_display_screen.dart';

/// Unified scan history screen showing both manual and background scans
///
/// Shows all accounts in a single chronological list with account and type
/// filters. Users can filter by account and scan type, view totals with
/// tooltips, and tap entries to view detailed results.
class ScanHistoryScreen extends StatefulWidget {
  final String? accountId;
  final String? accountEmail;
  final String? platformId;
  final String? platformDisplayName;
  final String? preSelectedAccountId;

  const ScanHistoryScreen({
    super.key,
    this.accountId,
    this.accountEmail,
    this.platformId,
    this.platformDisplayName,
    this.preSelectedAccountId,
  });

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late final ScanResultStore _scanResultStore;
  final SettingsStore _settingsStore = SettingsStore();

  List<ScanResult> _allScans = [];
  List<ScanResult> _filteredScans = [];
  bool _isLoading = true;
  String _typeFilter = 'all'; // 'all', 'manual', 'background'
  String _accountFilter = 'all'; // 'all' or specific accountId
  int _retentionDays = SettingsStore.defaultScanHistoryRetentionDays;
  List<String> _distinctAccounts = []; // unique accountIds from scan data
  Map<String, String> _accountEmails = {}; // accountId -> email display

  @override
  void initState() {
    super.initState();
    _scanResultStore = ScanResultStore(_dbHelper);
    // Pre-select account filter if navigating from Settings
    if (widget.preSelectedAccountId != null) {
      _accountFilter = widget.preSelectedAccountId!;
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      _retentionDays = await _settingsStore.getScanHistoryRetentionDays();

      // Auto-purge old entries
      await _scanResultStore.purgeOldScanResults(_retentionDays);

      // Load configured accounts from credentials store
      final credStore = SecureCredentialsStore();
      final configuredAccounts = await credStore.getSavedAccounts();

      // Always load all scans across all accounts
      final scans = await _scanResultStore.getAllScanHistory(limit: 500);

      // Use configured accounts as the canonical list (not scan data)
      final sortedAccounts = List<String>.from(configuredAccounts)..sort();

      // Build email display map from accountId
      // accountId format is "{platform}-{email}"
      final emailMap = <String, String>{};
      for (final accountId in sortedAccounts) {
        final dashIndex = accountId.indexOf('-');
        if (dashIndex > 0 && dashIndex < accountId.length - 1) {
          emailMap[accountId] = accountId.substring(dashIndex + 1);
        } else {
          emailMap[accountId] = accountId;
        }
      }

      if (mounted) {
        setState(() {
          _allScans = scans;
          _distinctAccounts = sortedAccounts;
          _accountEmails = emailMap;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to load scan history', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scan history: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    var scans = List<ScanResult>.from(_allScans);

    // Apply account filter
    if (_accountFilter != 'all') {
      scans = scans.where((s) => s.accountId == _accountFilter).toList();
    }

    // Apply type filter
    if (_typeFilter != 'all') {
      scans = scans.where((s) => s.scanType == _typeFilter).toList();
    }

    _filteredScans = scans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: Text('Scan History ($_retentionDays days)'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(context, HelpSection.scanHistory),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Account filter chips (show when multiple configured accounts)
        if (_distinctAccounts.length > 1) _buildAccountFilter(),
        // Type filter chips
        _buildTypeFilter(),
        // Summary totals
        _buildTotals(),
        const Divider(),
        // Scan list
        Expanded(
          child: _filteredScans.isEmpty
              ? _buildEmptyState()
              : _buildScanList(),
        ),
      ],
    );
  }

  Widget _buildAccountFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
            _buildAccountChip('All Accounts', 'all'),
            const SizedBox(width: 8),
            ..._distinctAccounts.map((accountId) {
              final email = _accountEmails[accountId] ?? accountId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildAccountChip(email, accountId),
              );
            }),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAccountChip(String label, String value) {
    final isSelected = _accountFilter == value;
    return FilterChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _accountFilter = value;
          _applyFilter();
        });
      },
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Manual', 'manual'),
            const SizedBox(width: 8),
            _buildFilterChip('Background', 'background'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _typeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _typeFilter = value;
          _applyFilter();
        });
      },
    );
  }

  Widget _buildTotals() {
    final totalEmails = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.totalEmails,
    );
    final totalProcessed = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.processedCount,
    );
    final totalDeleted = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.deletedCount,
    );
    final totalMoved = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.movedCount,
    );
    final totalSafe = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.safeSenderCount,
    );
    final totalNoRule = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.noRuleCount,
    );
    final totalErrors = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.errorCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
        children: [
          _buildTotalChip('Total', totalEmails, Colors.blue,
              'Total unique emails found'),
          _buildTotalChip('Processed', totalProcessed, Colors.purple,
              'Total emails processed'),
          _buildTotalChip('Deleted', totalDeleted, Colors.red,
              'Total unique emails deleted'),
          _buildTotalChip('Moved', totalMoved, Colors.orange,
              'Total unique emails moved'),
          _buildTotalChip('Safe', totalSafe, Colors.green,
              'Total unique emails marked safe (not including Safe Folder)'),
          _buildTotalChip('No Rule', totalNoRule, Colors.grey,
              'Total unique emails currently with no rules assigned'),
          _buildTotalChip('Errors', totalErrors, Colors.red.shade300,
              'Total unique emails not processed due to errors'),
        ],
      ),
      ),
    );
  }

  Widget _buildTotalChip(String label, int value, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: color.withOpacity(0.15),
        labelStyle: TextStyle(
          color: _darkenColor(color),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No scan history',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed scans will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildScanList() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredScans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final scan = _filteredScans[index];
        return _buildScanCard(scan);
      },
    );
  }

  Widget _buildScanCard(ScanResult scan) {
    final startDate = DateTime.fromMillisecondsSinceEpoch(scan.startedAt).toLocal();
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final tzName = _abbreviateTimeZone(startDate.timeZoneName);
    final completedDate = scan.completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(scan.completedAt!).toLocal()
        : null;

    // Calculate duration
    String durationStr = 'In progress';
    if (completedDate != null) {
      final duration = completedDate.difference(startDate);
      if (duration.inMinutes > 0) {
        durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';
      } else {
        durationStr = '${duration.inSeconds}s';
      }
    }

    final isCompleted = scan.status == 'completed';
    final isError = scan.status == 'error';
    final isManual = scan.scanType == 'manual';

    // Build subtitle with scan type badge and mode
    final modeLabel = _scanModeLabel(scan.scanMode);

    final accountEmail = _accountEmails[scan.accountId] ?? scan.accountId;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: (isCompleted && scan.id != null)
            ? () => _navigateToResults(scan)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account row (when showing all accounts)
              if (_distinctAccounts.length > 1) ...[
                Text(
                  accountEmail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              // Top row: date, type badge, status icon
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isManual
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.teal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isManual ? 'Manual' : 'Background',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isManual ? Colors.blue.shade700 : Colors.teal.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${dateFormat.format(startDate)} $tzName',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isError
                            ? Icons.error
                            : Icons.access_time,
                    color: isCompleted
                        ? Colors.green
                        : isError
                            ? Colors.red
                            : Colors.orange,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Details row: duration | scan mode | Folders: list
              Text(
                [
                  durationStr,
                  modeLabel,
                  if (scan.foldersScanned.isNotEmpty)
                    'Folders: ${scan.foldersScanned.join(", ")}',
                ].join('  |  '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              // Counts row - always show all metrics
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  _buildCountLabel('Found', scan.totalEmails, Colors.indigo),
                  _buildCountLabel('Processed', scan.processedCount, Colors.blue),
                  _buildCountLabel('Deleted', scan.deletedCount, Colors.red),
                  _buildCountLabel('Moved', scan.movedCount, Colors.orange),
                  _buildCountLabel('Safe', scan.safeSenderCount, Colors.green),
                  _buildCountLabel('No Rule', scan.noRuleCount, Colors.grey),
                  _buildCountLabel('Errors', scan.errorCount, Colors.red),
                ],
              ),
              // Error message
              if (isError && scan.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  scan.errorMessage!,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountLabel(String label, int count, Color color) {
    return Text(
      '$label: $count',
      style: TextStyle(
        fontSize: 12,
        color: _darkenColor(color),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _scanModeLabel(String scanMode) {
    switch (scanMode) {
      // Current names
      case 'readOnly':
        return 'Read-Only';
      case 'rulesOnly':
        return 'Process Rules Only';
      case 'safeSendersOnly':
        return 'Process Safe Senders Only';
      case 'safeSendersAndRules':
        return 'Process Safe Senders + Rules';
      // Legacy names (backwards compatibility with existing scan records)
      case 'readonly':
        return 'Read-Only';
      case 'testLimit':
        return 'Process Rules Only';
      case 'testAll':
        return 'Process Safe Senders Only';
      case 'fullScan':
        return 'Process Safe Senders + Rules';
      default:
        return scanMode;
    }
  }

  void _navigateToResults(ScanResult scan) {
    // Extract platform and email from accountId format: "{platform}-{email}"
    final dashIndex = scan.accountId.indexOf('-');
    final platformId = dashIndex > 0
        ? scan.accountId.substring(0, dashIndex)
        : '';
    final email = _accountEmails[scan.accountId] ?? scan.accountId;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsDisplayScreen(
          platformId: platformId,
          platformDisplayName: _platformDisplayName(platformId),
          accountId: scan.accountId,
          accountEmail: email,
          historicalScanId: scan.id,
        ),
      ),
    );
  }

  String _platformDisplayName(String platformId) {
    switch (platformId) {
      case 'aol':
        return 'AOL';
      case 'gmail':
        return 'Gmail';
      case 'gmail_oauth':
        return 'Gmail (OAuth)';
      case 'yahoo':
        return 'Yahoo';
      case 'outlook':
        return 'Outlook.com';
      case 'protonmail':
        return 'ProtonMail';
      default:
        return platformId;
    }
  }

  /// Convert full timezone name to abbreviation.
  /// Windows returns full names like "Eastern Standard Time" instead of "EST".
  String _abbreviateTimeZone(String tzName) {
    // If already short (3-5 chars), it is likely an abbreviation
    if (tzName.length <= 5) return tzName;

    // Build abbreviation from first letter of each word
    final words = tzName.split(' ');
    if (words.length >= 2) {
      return words.map((w) => w.isNotEmpty ? w[0] : '').join();
    }
    return tzName;
  }

  Color _darkenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
}
