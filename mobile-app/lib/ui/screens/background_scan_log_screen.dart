import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/storage/background_scan_log_store.dart';
import '../../core/storage/database_helper.dart';
import '../widgets/app_bar_with_exit.dart';

/// Screen for viewing background scan execution history
///
/// Shows a list of past background scan runs with timestamps, status,
/// and summary statistics. Users can filter by account and date range,
/// and export individual scan results to CSV.
class BackgroundScanLogScreen extends StatefulWidget {
  const BackgroundScanLogScreen({super.key});

  @override
  State<BackgroundScanLogScreen> createState() => _BackgroundScanLogScreenState();
}

class _BackgroundScanLogScreenState extends State<BackgroundScanLogScreen> {
  final Logger _logger = Logger();
  final BackgroundScanLogStore _logStore = BackgroundScanLogStore(DatabaseHelper());

  List<BackgroundScanLogEntry> _logs = [];
  List<BackgroundScanLogEntry> _filteredLogs = [];
  bool _isLoading = true;
  String? _selectedAccountFilter;
  List<String> _availableAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = await _logStore.getAllLogs(limit: 200);
      final accounts = logs.map((l) => l.accountId).toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _logs = logs;
          _availableAccounts = accounts;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to load background scan logs', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scan logs: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    if (_selectedAccountFilter == null) {
      _filteredLogs = List.from(_logs);
    } else {
      _filteredLogs = _logs
          .where((l) => l.accountId == _selectedAccountFilter)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Background Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
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
        // Account filter
        if (_availableAccounts.length > 1) _buildAccountFilter(),
        // Summary stats
        _buildSummaryStats(),
        const Divider(),
        // Log list
        Expanded(
          child: _filteredLogs.isEmpty
              ? _buildEmptyState()
              : _buildLogList(),
        ),
      ],
    );
  }

  Widget _buildAccountFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String?>(
        value: _selectedAccountFilter,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Filter by Account',
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All Accounts'),
          ),
          ..._availableAccounts.map((account) => DropdownMenuItem<String?>(
            value: account,
            child: Text(account, overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedAccountFilter = value;
            _applyFilter();
          });
        },
      ),
    );
  }

  Widget _buildSummaryStats() {
    final total = _filteredLogs.length;
    final successful = _filteredLogs.where((l) => l.status == 'success').length;
    final failed = _filteredLogs.where((l) => l.status == 'failed').length;
    final totalProcessed = _filteredLogs.fold<int>(0, (sum, l) => sum + l.emailsProcessed);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildStatChip('Total Runs', total, Colors.blue),
          _buildStatChip('Successful', successful, Colors.green),
          _buildStatChip('Failed', failed, Colors.red),
          _buildStatChip('Emails Processed', totalProcessed, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color.shade700, fontWeight: FontWeight.w600, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            'No background scan history',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Background scans will appear here after they run.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(BackgroundScanLogEntry log) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final scheduledDate = DateTime.fromMillisecondsSinceEpoch(log.scheduledTime);
    final startDate = log.actualStartTime != null
        ? DateTime.fromMillisecondsSinceEpoch(log.actualStartTime!)
        : null;
    final endDate = log.actualEndTime != null
        ? DateTime.fromMillisecondsSinceEpoch(log.actualEndTime!)
        : null;

    // Calculate duration
    String durationStr = 'N/A';
    if (startDate != null && endDate != null) {
      final duration = endDate.difference(startDate);
      if (duration.inMinutes > 0) {
        durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';
      } else {
        durationStr = '${duration.inSeconds}s';
      }
    }

    final isSuccess = log.status == 'success';
    final isFailed = log.status == 'failed';

    return Card(
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(
          isSuccess
              ? Icons.check_circle
              : isFailed
                  ? Icons.error
                  : Icons.access_time,
          color: isSuccess
              ? Colors.green
              : isFailed
                  ? Colors.red
                  : Colors.orange,
        ),
        title: Text(
          dateFormat.format(scheduledDate),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${log.accountId} - ${log.status.toUpperCase()} - $durationStr',
          style: TextStyle(
            fontSize: 12,
            color: isSuccess ? Colors.green.shade700 : isFailed ? Colors.red.shade700 : Colors.grey.shade700,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Scheduled', dateFormat.format(scheduledDate)),
                if (startDate != null)
                  _buildDetailRow('Started', dateFormat.format(startDate)),
                if (endDate != null)
                  _buildDetailRow('Completed', dateFormat.format(endDate)),
                _buildDetailRow('Duration', durationStr),
                const Divider(),
                _buildDetailRow('Emails Processed', '${log.emailsProcessed}'),
                _buildDetailRow('Unmatched', '${log.unmatchedCount}'),
                if (log.errorMessage != null) ...[
                  const Divider(),
                  _buildDetailRow('Error', log.errorMessage!, isError: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isError ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
}
