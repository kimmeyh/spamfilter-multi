import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../widgets/app_bar_with_exit.dart';
import 'results_display_screen.dart';

/// Unified scan history screen showing both manual and background scans
///
/// Replaces the separate BackgroundScanLogScreen with a consolidated view
/// that shows all scan types in a single chronological list. Users can
/// filter by scan type (manual/background/all) and tap entries to view
/// detailed results.
class ScanHistoryScreen extends StatefulWidget {
  final String? accountId;
  final String? accountEmail;
  final String? platformId;
  final String? platformDisplayName;

  const ScanHistoryScreen({
    super.key,
    this.accountId,
    this.accountEmail,
    this.platformId,
    this.platformDisplayName,
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
  int _retentionDays = SettingsStore.defaultScanHistoryRetentionDays;

  @override
  void initState() {
    super.initState();
    _scanResultStore = ScanResultStore(_dbHelper);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      _retentionDays = await _settingsStore.getScanHistoryRetentionDays();

      // Auto-purge old entries
      await _scanResultStore.purgeOldScanResults(_retentionDays);

      // Load all scan history
      final scans = await _scanResultStore.getAllScanHistory(limit: 200);

      if (mounted) {
        setState(() {
          _allScans = scans;
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
    if (_typeFilter == 'all') {
      _filteredScans = List.from(_allScans);
    } else {
      _filteredScans = _allScans
          .where((s) => s.scanType == _typeFilter)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Type filter chips
        _buildTypeFilter(),
        // Summary stats
        _buildSummaryStats(),
        const Divider(),
        // Retention info
        _buildRetentionInfo(),
        // Scan list
        Expanded(
          child: _filteredScans.isEmpty
              ? _buildEmptyState()
              : _buildScanList(),
        ),
      ],
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Manual', 'manual'),
          const SizedBox(width: 8),
          _buildFilterChip('Background', 'background'),
        ],
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

  Widget _buildSummaryStats() {
    final total = _filteredScans.length;
    final completed = _filteredScans.where((s) => s.status == 'completed').length;
    final errors = _filteredScans.where((s) => s.status == 'error').length;
    final totalProcessed = _filteredScans.fold<int>(
      0, (sum, s) => sum + s.processedCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatChip('Total', total, Colors.blue),
          _buildStatChip('Completed', completed, Colors.green),
          if (errors > 0) _buildStatChip('Errors', errors, Colors.red),
          _buildStatChip('Emails Processed', totalProcessed, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(
        color: _darkenColor(color),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildRetentionInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        'Showing history for the last $_retentionDays days',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final startDate = DateTime.fromMillisecondsSinceEpoch(scan.startedAt);
    final completedDate = scan.completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(scan.completedAt!)
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

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: (isCompleted && scan.id != null && widget.platformId != null)
            ? () => _navigateToResults(scan)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      dateFormat.format(startDate),
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
              // Details row: mode, duration, counts
              Row(
                children: [
                  Text(
                    '$modeLabel  |  $durationStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Counts row
              Wrap(
                spacing: 12,
                children: [
                  _buildCountLabel('Processed', scan.processedCount, Colors.blue),
                  if (scan.deletedCount > 0)
                    _buildCountLabel('Deleted', scan.deletedCount, Colors.red),
                  if (scan.movedCount > 0)
                    _buildCountLabel('Moved', scan.movedCount, Colors.orange),
                  if (scan.safeSenderCount > 0)
                    _buildCountLabel('Safe', scan.safeSenderCount, Colors.green),
                  if (scan.errorCount > 0)
                    _buildCountLabel('Errors', scan.errorCount, Colors.red),
                ],
              ),
              // Folders scanned
              if (scan.foldersScanned.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Folders: ${scan.foldersScanned.join(", ")}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
              // Tap hint for completed scans
              if (isCompleted && widget.platformId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tap to view details',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade400,
                    fontStyle: FontStyle.italic,
                  ),
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
      case 'readonly':
        return 'Read Only';
      case 'testLimit':
        return 'Test Limit';
      case 'testAll':
        return 'Test All';
      case 'fullScan':
        return 'Full Scan';
      default:
        return scanMode;
    }
  }

  void _navigateToResults(ScanResult scan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsDisplayScreen(
          platformId: widget.platformId ?? '',
          platformDisplayName: widget.platformDisplayName ?? '',
          accountId: scan.accountId,
          accountEmail: widget.accountEmail ?? scan.accountId,
          historicalScanId: scan.id,
        ),
      ),
    );
  }

  Color _darkenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
}
