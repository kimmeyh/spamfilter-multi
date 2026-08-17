import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../core/providers/selected_account_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/standard_app_bar_actions.dart';
import 'help_screen.dart';
import 'no_rule_review_screen.dart';
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

  /// F87 (Sprint 38): resolve a non-null accountId for the Settings push.
  /// SettingsScreen requires a non-null accountId, but ScanHistoryScreen
  /// may be opened in "all accounts" mode (widget.accountId == null,
  /// _accountFilter == 'all'). Resolution order: (1) widget.accountId,
  /// (2) current account filter if specific, (3) first known account,
  /// (4) null -> disable the Settings IconButton.
  /// F135 (Sprint 52): resolution order for the account-scoped Settings
  /// destination. The SESSION SELECTION is consulted after this screen's own
  /// context but before falling back to "first account in the list", so a user
  /// who already chose an account gets THAT account's settings rather than an
  /// arbitrary one.
  ///
  /// Scan History is itself cross-account (it shows every account's scans), so
  /// it never PROMPTS -- it only resolves. The picker belongs to the account
  /// selection screen; this screen just needs a sensible account for the
  /// Settings icon, and returning null correctly disables that icon.
  String? _resolveAccountIdForSettings() {
    // 1. Explicit context wins: this screen was opened FOR an account.
    if (widget.accountId != null) return widget.accountId;
    // 2. The user has filtered to one account -- that is their current intent.
    if (_accountFilter != 'all') return _accountFilter;
    // 3. The session selection (F135) -- honoured only if that account still
    //    appears here, so a deleted or unrelated account cannot leak through.
    //    Read defensively: the selection is an OPTIONAL input (the fallbacks
    //    below cover its absence), so a widget-test harness that has not
    //    registered the provider must not make this screen unconstructible.
    String? selected;
    try {
      selected = context.read<SelectedAccountProvider>().accountId;
    } on ProviderNotFoundException {
      // Missing provider is the ONLY tolerated case (Copilot, PR #292) -- a
      // bare catch would also hide a real error from a present provider.
      selected = null;
    }
    if (selected != null && _distinctAccounts.contains(selected)) {
      return selected;
    }
    // 4. Last resort: the first known account.
    if (_distinctAccounts.isNotEmpty) return _distinctAccounts.first;
    return null;
  }

  /// The AppBar Refresh action.
  ///
  /// Harold, 2026-07-31 (manual validation), after the same finding on the
  /// No-Rule screen: *"same for refresh icon on Scan History screen?"* -- yes,
  /// identical shape. [_loadHistory] re-reads scan history from the local DB
  /// and finishes in milliseconds, so the spinner never paints a perceptible
  /// frame and an unchanged list looks like a dead button.
  ///
  /// This screen has one behaviour the No-Rule screen does not: `_loadHistory`
  /// PURGES scan results past the retention window, so a refresh can genuinely
  /// remove rows. Reporting that is the point -- rows silently disappearing is
  /// worse than a button that appears to do nothing.
  ///
  /// Separate from [_loadHistory] because that also runs on init, where a
  /// SnackBar would be noise.
  Future<void> _refreshFromUserAction() async {
    final before = _allScans.length;
    final ok = await _loadHistory();
    if (!mounted) return;

    // Load failed and already showed its error. Reporting "N scans removed" or
    // "no changes" here would be a false statement about deleted data, and the
    // hideCurrentSnackBar() below would wipe the real diagnostic.
    if (!ok) return;

    final removed = before - _allScans.length;
    final String message;
    if (removed > 0) {
      // Purged by the retention window (_retentionDays), re-read fresh above.
      message = removed == 1
          ? '1 scan older than $_retentionDays days removed'
          : '$removed scans older than $_retentionDays days removed';
    } else if (_allScans.length > before) {
      final added = _allScans.length - before;
      message = added == 1 ? '1 new scan' : '$added new scans';
    } else {
      message = 'No changes -- history is up to date';
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  /// Returns true when the load SUCCEEDED, false when it failed -- see the note
  /// on `rules_management_screen._loadRules` (PR #292 review). It matters more
  /// here than elsewhere: this method also PURGES rows past the retention
  /// window, so a wrong "N scans removed" or "no changes" message is a claim
  /// about deleted data.
  Future<bool> _loadHistory() async {
    setState(() => _isLoading = true);
    var ok = true;

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
      ok = false;
      _logger.e('Failed to load scan history', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scan history: $e')),
        );
      }
    }
    return ok;
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
        // F55 (Sprint 33, v3): icon order --
        // <screen-specific> (Refresh), Accounts, Settings, Help, [X auto].
        // F87 (Sprint 38, Issue #251): Settings icon added so user can reach
        // Settings from sub-screens with one tap rather than back-navigating.
        // F134 (Sprint 52): canonical order from the ONE shared builder.
        // includeScanHistory: false -- this IS the Scan History screen.
        // The accountId comes from the F135 resolver, which consults the
        // session selection; when it returns null the builder omits Settings
        // rather than rendering a permanently-disabled icon (the previous
        // behavior: an always-present control that did nothing).
        actions: StandardAppBarActions.build(
          context: context,
          helpSection: HelpSection.scanHistory,
          accountId: _resolveAccountIdForSettings() ?? widget.accountId,
          accountEmail: widget.accountEmail,
          platformId: widget.platformId,
          platformDisplayName: widget.platformDisplayName,
          includeScanHistory: false,
          leading: [
            IconButton(
              icon: const Icon(Icons.refresh),
              // Same wording problem as the No-Rule screen: "Refresh" reads as
              // "go check the mail server", which this does not do. It re-reads
              // locally stored history and applies the retention purge.
              tooltip: 'Reload scan history (does not fetch new mail)',
              onPressed: _refreshFromUserAction,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // F109b (Sprint 44): explain why recent BACKGROUND scans may be absent
        // while the app is open -- they defer until the app is closed (F98).
        _buildBackgroundDeferralHint(),
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
          // F112 (Sprint 47): a small "Review No Rule Items" icon centered
          // directly above the "No Rule" chip (Column keeps it centered over
          // the chip regardless of chip width). Windows-desktop scoped.
          _buildNoRuleChipWithReviewIcon(totalNoRule),
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

  /// F112 (Sprint 47): the "No Rule" total chip with a small tappable
  /// "Review No Rule Items" icon centered directly above it. PR #335 cowork
  /// review: originally Windows-gated "consistent with the other Review
  /// entry points" -- F143 (Sprint 60) un-gated every other entry point, so
  /// the gate here had become the sole inconsistent holdout and is removed.
  Widget _buildNoRuleChipWithReviewIcon(int totalNoRule) {
    final chip = _buildTotalChip('No Rule', totalNoRule, Colors.grey,
        'Total unique emails currently with no rules assigned');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.rule_folder_outlined, size: 18),
          tooltip: 'Review No Rule Items',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(bottom: 2),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NoRuleReviewScreen()),
          ),
        ),
        chip,
      ],
    );
  }

  /// F109b (Sprint 44): a dismissable-feeling info hint (Windows only)
  /// clarifying that background scans pause while the app is open, so the
  /// absence of recent background entries is expected, not a failure.
  Widget _buildBackgroundDeferralHint() {
    if (!Platform.isWindows) return const SizedBox.shrink();
    return Container(
      key: const Key('scan_history_deferral_hint'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blueGrey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Background scans pause while this app is open; they resume on the '
              'next interval after you close it. Deferred runs appear here as '
              '"deferred".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
    // Sprint 60 MV (Harold): demo scans record scanType 'demo' but the old
    // binary manual/background labeling showed them as "Background" -- on a
    // platform with no background scheduler at all (F144/F161), a plainly
    // wrong badge. Three-way label; anything unknown still says Background.
    final typeLabel = isManual
        ? 'Manual'
        : (scan.scanType == 'demo' ? 'Demo' : 'Background');

    // Build subtitle with scan type badge and mode
    final modeLabel = _scanModeLabel(scan.scanMode);

    final accountEmail = _accountEmails[scan.accountId] ?? scan.accountId;

    // F133-S52 R-1 (Sprint 52): the scan card was a bare InkWell -- tappable
    // but unnamed, so a screen reader announced nothing about WHICH scan it
    // was. Wrapped per docs/ACCESSIBILITY_STANDARDS.md §2.
    //
    // The card body is pure text/decoration with no interactive children, so
    // `excludeSemantics: true` is safe and correct here: it merges the whole
    // card into ONE announced node instead of a stream of disconnected text
    // fragments. `button` and `onTap` are supplied ONLY when the card is
    // actually tappable -- an incomplete scan must not advertise an action it
    // does not have.
    final canOpen = isCompleted && scan.id != null;
    return Card(
      elevation: 1,
      child: Semantics(
        container: true,
        button: canOpen,
        excludeSemantics: true,
        label: '$typeLabel scan - $accountEmail - '
            '$modeLabel - ${scan.status}',
        hint: canOpen ? 'View scan results' : null,
        onTap: canOpen ? () => _navigateToResults(scan) : null,
        child: InkWell(
        onTap: canOpen ? () => _navigateToResults(scan) : null,
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
                      typeLabel,
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