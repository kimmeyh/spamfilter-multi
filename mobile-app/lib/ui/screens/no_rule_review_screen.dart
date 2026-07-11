import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/rule_set_provider.dart';
import '../../core/services/auth_results_parser.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/services/rule_quick_action_service.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/provider_sender_grouping.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/provider_group_markers.dart';
import '../widgets/auth_warning_dialog.dart';
import '../widgets/empty_state.dart';

/// F39 (Sprint 46): cross-account "No rule" review screen.
///
/// Aggregates unprocessed "No rule" items from each configured account's
/// LATEST completed scan (not full history -- a user reviewing weekly
/// wants this week's unaddressed items, not a re-scan of history) into one
/// list, filterable down to a single account. Supports multi-select
/// (Ctrl+click, Shift+click on Windows desktop) and bulk rule application
/// across the selection, batching the summary notification once per bulk
/// operation rather than once per item.
class NoRuleReviewScreen extends StatefulWidget {
  const NoRuleReviewScreen({super.key});

  @override
  State<NoRuleReviewScreen> createState() => _NoRuleReviewScreenState();
}

/// A "No rule" item paired with the account it came from, for display and
/// bulk-action purposes in the aggregated cross-account list.
class _NoRuleItem {
  final UnmatchedEmail email;
  final String accountId;
  final String accountEmail;

  const _NoRuleItem({
    required this.email,
    required this.accountId,
    required this.accountEmail,
  });
}

class _NoRuleReviewScreenState extends State<NoRuleReviewScreen> {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late final ScanResultStore _scanResultStore;
  late final UnmatchedEmailStore _unmatchedStore;

  bool _isLoading = true;
  List<_NoRuleItem> _allItems = [];
  List<_NoRuleItem> _filteredItems = [];
  String _accountFilter = 'all';
  List<String> _distinctAccounts = [];
  Map<String, String> _accountEmails = {};

  // Multi-select state. Keyed by unmatched_emails row id (stable across
  // reloads within a session; ids are non-null once persisted).
  final Set<int> _selectedIds = {};
  int? _lastClickedIndex;

  @override
  void initState() {
    super.initState();
    _scanResultStore = ScanResultStore(_dbHelper);
    _unmatchedStore = UnmatchedEmailStore(_dbHelper);
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      final credStore = SecureCredentialsStore();
      final configuredAccounts = await credStore.getSavedAccounts();
      final sortedAccounts = List<String>.from(configuredAccounts)..sort();

      final emailMap = <String, String>{};
      for (final accountId in sortedAccounts) {
        final dashIndex = accountId.indexOf('-');
        emailMap[accountId] = (dashIndex > 0 && dashIndex < accountId.length - 1)
            ? accountId.substring(dashIndex + 1)
            : accountId;
      }

      final items = <_NoRuleItem>[];
      for (final accountId in sortedAccounts) {
        final latestScan = await _scanResultStore.getLatestCompletedScan(accountId);
        if (latestScan == null || latestScan.id == null) continue;

        final unmatched = await _unmatchedStore.getUnmatchedEmailsByScanFiltered(
          latestScan.id!,
          unprocessedOnly: true,
        );

        for (final email in unmatched) {
          items.add(_NoRuleItem(
            email: email,
            accountId: accountId,
            accountEmail: emailMap[accountId] ?? accountId,
          ));
        }
      }

      // Newest first, matching the existing scan-history/results ordering
      // convention (getUnmatchedEmailsByScan already orders by created_at
      // DESC per-scan; sort again here since we merged across accounts).
      items.sort((a, b) => b.email.createdAt.compareTo(a.email.createdAt));

      if (mounted) {
        setState(() {
          _allItems = items;
          _distinctAccounts = sortedAccounts;
          _accountEmails = emailMap;
          _applyFilter();
          _isLoading = false;
          _selectedIds.clear();
          _lastClickedIndex = null;
        });
      }
    } catch (e) {
      _logger.e('Failed to load No Rule review items', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load items: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    final filtered = _accountFilter == 'all'
        ? List<_NoRuleItem>.from(_allItems)
        : _allItems.where((i) => i.accountId == _accountFilter).toList();
    // Sprint 46 retro IMP-1 (Harold): email-provider senders group at the
    // top (stable partition -- newest-first order kept within both groups);
    // heading/end indicator rendered by _buildList when non-empty.
    final partitioned = ProviderSenderGrouping.partitionProviderFirst(
        filtered, (i) => i.email.fromEmail);
    _filteredItems = partitioned.items;
    _providerGroupCount = partitioned.providerCount;
  }

  /// Provider-sender group size within the current filtered list (IMP-1).
  int _providerGroupCount = 0;

  // --- Selection ---

  void _handleItemTap(int index, {required bool ctrlPressed, required bool shiftPressed}) {
    final id = _filteredItems[index].email.id;
    if (id == null) return;

    setState(() {
      if (shiftPressed && _lastClickedIndex != null) {
        final start = _lastClickedIndex!.clamp(0, _filteredItems.length - 1);
        final lo = start < index ? start : index;
        final hi = start < index ? index : start;
        for (var i = lo; i <= hi; i++) {
          final rowId = _filteredItems[i].email.id;
          if (rowId != null) _selectedIds.add(rowId);
        }
      } else if (ctrlPressed) {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
        _lastClickedIndex = index;
      } else {
        // Plain click: toggle single selection (this screen's list is
        // triage-only -- there is no "open detail" navigation target,
        // so a plain click behaves as select/unselect for consistency
        // with the checkbox).
        if (_selectedIds.length == 1 && _selectedIds.contains(id)) {
          _selectedIds.clear();
        } else {
          _selectedIds
            ..clear()
            ..add(id);
        }
        _lastClickedIndex = index;
      }
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _lastClickedIndex = null;
    });
  }

  List<_NoRuleItem> get _selectedItems =>
      _filteredItems.where((i) => i.email.id != null && _selectedIds.contains(i.email.id)).toList();

  // --- Bulk actions ---

  /// Runs [action] once per selected item, then shows ONE summary
  /// notification for the whole batch (F39 batching decision, Sprint 46 --
  /// realistic weekly volume is <50 items, so this is about avoiding N
  /// stacked SnackBars, not raw performance). Marks successfully-actioned
  /// items as processed so they drop out of the "No rule" pool on reload.
  Future<void> _runBulkAction(
    String actionLabel,
    Future<RuleQuickActionResult> Function(_NoRuleItem item) action,
  ) async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    int succeeded = 0;
    int failed = 0;
    int conflictsRemoved = 0;

    for (final item in selected) {
      final result = await action(item);
      if (result.success) {
        succeeded++;
        conflictsRemoved += result.conflictsRemoved;
        final id = item.email.id;
        if (id != null) {
          await _unmatchedStore.markAsProcessed(id, true);
        }
      } else {
        failed++;
        _logger.w('Bulk action "$actionLabel" failed for '
            '${item.email.fromEmail}: ${result.error}');
      }
    }

    if (!mounted) return;

    final parts = <String>['$actionLabel: $succeeded succeeded'];
    if (failed > 0) parts.add('$failed failed');
    if (conflictsRemoved > 0) {
      parts.add('$conflictsRemoved conflicting rule/sender${conflictsRemoved > 1 ? "s" : ""} removed');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' -- ')),
        backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _clearSelection();
    await _loadItems();
  }

  Future<void> _bulkAddSafeSender(String type) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final service = RuleQuickActionService(ruleProvider: ruleProvider);

    // F96-style RED-sender gate (mirrors ResultsDisplayScreen._addSafeSender):
    // if ANY selected item has a RED auth classification, confirm once
    // before whitelisting the whole batch rather than gating per-item.
    final hasRed = _selectedItems.any((i) =>
        AuthResultsParser.classificationFromName(i.email.authClassification) ==
        AuthClassification.red);
    if (hasRed) {
      final proceed = await AuthWarningDialog.showSafeSenderWarning(
        context,
        senderEmail: 'one or more selected senders',
        authResult: AuthResultsParser.syntheticResultFor(AuthClassification.red),
      );
      if (!proceed || !mounted) return;
    }

    final label = switch (type) {
      'exact' => 'Add Safe Sender (Exact Email)',
      'exactDomain' => 'Add Safe Sender (Exact Domain)',
      'entireDomain' => 'Add Safe Sender (Entire Domain)',
      _ => 'Add Safe Sender',
    };

    await _runBulkAction(label, (item) {
      final bodyParser = EmailBodyParser();
      final rawSenderEmail = bodyParser.extractEmailAddress(item.email.fromEmail);
      final rawSenderDomain = bodyParser.extractDomainFromEmail(item.email.fromEmail);
      final rootDomain = PatternNormalization.extractRootDomain(rawSenderDomain);
      final normalizedEmail = PatternNormalization.normalizeFromHeader(item.email.fromEmail);

      final value = switch (type) {
        'exact' => normalizedEmail,
        'exactDomain' => '@$rawSenderDomain',
        'entireDomain' => rootDomain ?? rawSenderDomain ?? '',
        _ => '',
      };

      return service.addSafeSender(
        value: value,
        type: type,
        senderEmailForConflictCheck: rawSenderEmail,
      );
    });
  }

  Future<void> _bulkCreateBlockRule(String type) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final service = RuleQuickActionService(ruleProvider: ruleProvider);

    final label = switch (type) {
      'from' => 'Add Block Rule (Exact Email)',
      'exactDomain' => 'Add Block Rule (Exact Domain)',
      'entireDomain' => 'Add Block Rule (Entire Domain)',
      _ => 'Add Block Rule',
    };

    await _runBulkAction(label, (item) {
      final bodyParser = EmailBodyParser();
      final rawSenderEmail = bodyParser.extractEmailAddress(item.email.fromEmail);
      final rawSenderDomain = bodyParser.extractDomainFromEmail(item.email.fromEmail);
      final rootDomain = PatternNormalization.extractRootDomain(rawSenderDomain);

      final value = switch (type) {
        'from' => rawSenderEmail,
        'exactDomain' => '@$rawSenderDomain',
        'entireDomain' => rootDomain ?? rawSenderDomain ?? '',
        _ => '',
      };

      return service.createBlockRule(
        type: type,
        value: value,
        senderEmailForConflictCheck: rawSenderEmail,
      );
    });
  }

  /// "Remove Current Rule" (7th bulk action): simply marks the selected
  /// items as processed without creating any new rule/safe-sender -- the
  /// user has reviewed them and chosen to dismiss them from the "No rule"
  /// pool without further action.
  Future<void> _bulkMarkReviewed() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    var succeeded = 0;
    for (final item in selected) {
      final id = item.email.id;
      if (id == null) continue;
      final ok = await _unmatchedStore.markAsProcessed(id, true);
      if (ok) succeeded++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked $succeeded item${succeeded == 1 ? "" : "s"} as reviewed'),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _clearSelection();
    await _loadItems();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Review "No Rule" Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadItems,
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
        if (_distinctAccounts.length > 1) _buildAccountFilter(),
        _buildSelectionBar(),
        const Divider(height: 1),
        Expanded(
          child: _filteredItems.isEmpty ? _buildEmptyState() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildAccountFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAccountChip('All Accounts (${_allItems.length})', 'all'),
              const SizedBox(width: 8),
              ..._distinctAccounts.map((accountId) {
                final count = _allItems.where((i) => i.accountId == accountId).length;
                final email = _accountEmails[accountId] ?? accountId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildAccountChip('$email ($count)', accountId),
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
          _clearSelection();
        });
      },
    );
  }

  Widget _buildSelectionBar() {
    final count = _selectedIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            count > 0 ? '$count selected' : '${_filteredItems.length} item${_filteredItems.length == 1 ? "" : "s"}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (count > 0) ...[
            TextButton(onPressed: _clearSelection, child: const Text('Clear')),
            const SizedBox(width: 8),
            _buildBulkActionMenu(),
          ],
        ],
      ),
    );
  }

  /// 7 bulk actions per F39 acceptance criteria, in a right-click-style
  /// menu (PopupMenuButton -- Flutter's cross-platform equivalent that also
  /// responds to a primary click, satisfying the "right-click context menu"
  /// requirement on Windows desktop via secondary-click launch below).
  Widget _buildBulkActionMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Bulk Actions',
      child: const Chip(
        avatar: Icon(Icons.rule_folder, size: 18),
        label: Text('Apply Rule'),
      ),
      onSelected: (value) {
        switch (value) {
          case 'safe_exact':
            _bulkAddSafeSender('exact');
            break;
          case 'safe_exactDomain':
            _bulkAddSafeSender('exactDomain');
            break;
          case 'safe_entireDomain':
            _bulkAddSafeSender('entireDomain');
            break;
          case 'block_from':
            _bulkCreateBlockRule('from');
            break;
          case 'block_exactDomain':
            _bulkCreateBlockRule('exactDomain');
            break;
          case 'block_entireDomain':
            _bulkCreateBlockRule('entireDomain');
            break;
          case 'remove_rule':
            _bulkMarkReviewed();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'safe_exact', child: Text('Add Safe Sender - Exact Email')),
        PopupMenuItem(value: 'safe_exactDomain', child: Text('Add Safe Sender - Exact Domain')),
        PopupMenuItem(value: 'safe_entireDomain', child: Text('Add Safe Sender - Entire Domain')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'block_from', child: Text('Add Block Rule - Exact Email')),
        PopupMenuItem(value: 'block_exactDomain', child: Text('Add Block Rule - Exact Domain')),
        PopupMenuItem(value: 'block_entireDomain', child: Text('Add Block Rule - Entire Domain')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'remove_rule', child: Text('Remove Current Rule')),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: 'No unaddressed items',
      message: 'All "No rule" emails from the latest scans have been reviewed.',
    );
  }

  Widget _buildList() {
    final n = _providerGroupCount;
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredItems.length + (n > 0 ? 2 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        // IMP-1 (Sprint 46 retro): provider-group heading + end indicator
        // wrap the first n tiles; without provider senders the list renders
        // exactly as before.
        if (n <= 0) return _buildItemTile(index);
        if (index == 0) return ProviderGroupHeader(count: n);
        if (index <= n) return _buildItemTile(index - 1);
        if (index == n + 1) return const ProviderGroupEnd();
        return _buildItemTile(index - 2);
      },
    );
  }

  Widget _buildItemTile(int index) {
    final item = _filteredItems[index];
    final id = item.email.id;
    final isSelected = id != null && _selectedIds.contains(id);
    final decodedFrom = PatternNormalization.normalizeAndDecodeEmail(item.email.fromEmail);
    final subject = item.email.subject?.isNotEmpty == true ? item.email.subject! : 'No subject';

    return Card(
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4) : null,
      child: InkWell(
        onTap: () => _handleItemTap(
          index,
          ctrlPressed: HardwareKeyboard.instance.isControlPressed,
          shiftPressed: HardwareKeyboard.instance.isShiftPressed,
        ),
        onSecondaryTapDown: (details) {
          if (id != null && !_selectedIds.contains(id)) {
            setState(() {
              _selectedIds
                ..clear()
                ..add(id);
              _lastClickedIndex = index;
            });
          }
          _showContextMenu(context, details.globalPosition);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => id != null ? _toggleSelection(id) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_distinctAccounts.length > 1)
                      Text(
                        item.accountEmail,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Text(decodedFrom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      subject,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'safe_exact', child: Text('Add Safe Sender - Exact Email')),
        PopupMenuItem(value: 'safe_exactDomain', child: Text('Add Safe Sender - Exact Domain')),
        PopupMenuItem(value: 'safe_entireDomain', child: Text('Add Safe Sender - Entire Domain')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'block_from', child: Text('Add Block Rule - Exact Email')),
        PopupMenuItem(value: 'block_exactDomain', child: Text('Add Block Rule - Exact Domain')),
        PopupMenuItem(value: 'block_entireDomain', child: Text('Add Block Rule - Entire Domain')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'remove_rule', child: Text('Remove Current Rule')),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'safe_exact':
          _bulkAddSafeSender('exact');
          break;
        case 'safe_exactDomain':
          _bulkAddSafeSender('exactDomain');
          break;
        case 'safe_entireDomain':
          _bulkAddSafeSender('entireDomain');
          break;
        case 'block_from':
          _bulkCreateBlockRule('from');
          break;
        case 'block_exactDomain':
          _bulkCreateBlockRule('exactDomain');
          break;
        case 'block_entireDomain':
          _bulkCreateBlockRule('entireDomain');
          break;
        case 'remove_rule':
          _bulkMarkReviewed();
          break;
      }
    });
  }
}
