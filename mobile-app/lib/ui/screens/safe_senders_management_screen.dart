/// Safe Senders management screen for viewing, searching, and deleting patterns
///
/// [ISSUE #147] Sprint 15: Allows users to manage safe sender patterns
/// from Settings without direct database access.
/// [ISSUE #180] Sprint 19: Added filter chips for pattern categories
///
/// Features:
/// - List all safe sender patterns with type and date
/// - Search/filter patterns
/// - Filter by pattern category (Exact Email, Exact Domain, Entire Domain, Other)
/// - Delete individual patterns with confirmation
/// - View pattern details and exceptions
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../widgets/copy_all_shortcut.dart';
import '../widgets/list_selection_controller.dart';
import '../../core/storage/settings_store.dart';
import '../widgets/app_bar_with_exit.dart';
import 'help_screen.dart';
import 'manual_rule_create_screen.dart';

/// Categories for filtering safe sender patterns by structure
enum SafeSenderCategory {
  /// Exact email match: anchored pattern with specific user@domain
  /// Example: ^user@domain\.com$
  exactEmail('Exact Email', Icons.person_outline),

  /// Exact domain match: unanchored @domain pattern
  /// Example: @domain.com
  exactDomain('Exact Domain', Icons.domain),

  /// Entire domain including subdomains
  /// Example: ^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$
  entireDomain('Entire Domain', Icons.account_tree_outlined),

  /// Patterns that do not fit other categories
  other('Other', Icons.code);

  final String label;
  final IconData icon;
  const SafeSenderCategory(this.label, this.icon);

  /// Classify a safe sender pattern into its category based on regex structure.
  /// Priority: stored patternType first, then pattern analysis as fallback.
  static SafeSenderCategory categorize(SafeSenderPattern sender) {
    final pattern = sender.pattern;
    final type = sender.patternType;

    // 1. Stored patternType is authoritative when present
    if (type == 'subdomain') return SafeSenderCategory.entireDomain;
    if (type == 'domain') return SafeSenderCategory.exactDomain;
    if (type == 'email') return SafeSenderCategory.exactEmail;

    // 2. Pattern analysis fallback (for type == 'custom' or 'unknown')
    if (pattern.contains(r'@(?:[a-z0-9-]+\.)*')) {
      return SafeSenderCategory.entireDomain;
    } else if (pattern.startsWith('^') && pattern.endsWith(r'$') && pattern.contains('@')) {
      // Anchored pattern with @ - check if exact domain or exact email
      if (pattern.contains(r'[^@\s]+@') || pattern.contains(r'[^@\\s]+@')) {
        return SafeSenderCategory.exactDomain;
      }
      return SafeSenderCategory.exactEmail;
    } else if (pattern.contains('@') && !pattern.startsWith('^')) {
      return SafeSenderCategory.exactDomain;
    }
    return SafeSenderCategory.other;
  }
}

/// Screen for managing safe sender patterns
class SafeSendersManagementScreen extends StatefulWidget {
  const SafeSendersManagementScreen({super.key});

  @override
  State<SafeSendersManagementScreen> createState() =>
      _SafeSendersManagementScreenState();
}

class _SafeSendersManagementScreenState
    extends State<SafeSendersManagementScreen>
    with ListSelectionController<SafeSendersManagementScreen> {
  final Logger _logger = Logger();
  late final SafeSenderDatabaseStore _store;
  List<SafeSenderPattern> _safeSenders = [];
  List<SafeSenderPattern> _filteredSenders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<SafeSenderCategory> _selectedCategories = {};

  /// Sprint 37 round 6 (Alt-2 UX): tracks the currently-hovered or
  /// keyboard-focused row. The hover-revealed info_outline button is
  /// visible only for the row whose pattern matches this field.
  String? _hoveredPattern;

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _store = SafeSenderDatabaseStore(DatabaseHelper());
    _loadSafeSenders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeSenders() async {
    setState(() => _isLoading = true);
    try {
      _safeSenders = await _store.loadSafeSenders();
      _applyFilter();
    } catch (e) {
      _logger.e('Failed to load safe senders', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load safe senders: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    // S38-CI-3: reset multi-region row selection on every filter / search
    // / reload rebuild so selection indices cannot point at stale rows.
    clearRowSelection();
    var results = List<SafeSenderPattern>.from(_safeSenders);

    // Apply category filter (if any chips selected)
    if (_selectedCategories.isNotEmpty) {
      results = results.where((sender) {
        final category = SafeSenderCategory.categorize(sender);
        return _selectedCategories.contains(category);
      }).toList();
    }

    // Apply text search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((sender) {
        return sender.pattern.toLowerCase().contains(query) ||
            sender.patternType.toLowerCase().contains(query) ||
            sender.createdBy.toLowerCase().contains(query);
      }).toList();
    }

    _filteredSenders = results;
  }

  Future<void> _deleteSafeSender(SafeSenderPattern sender) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Safe Sender'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this safe sender pattern?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sender.pattern,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _store.removeSafeSender(sender.pattern);
        _logger.i('Deleted safe sender: ${sender.pattern}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Safe sender deleted')),
          );
        }
        await _loadSafeSenders();
      } catch (e) {
        _logger.e('Failed to delete safe sender', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _showPatternDetails(SafeSenderPattern sender) {
    final dateAdded = DateTime.fromMillisecondsSinceEpoch(sender.dateAdded);
    final dateStr =
        '${dateAdded.year}-${dateAdded.month.toString().padLeft(2, '0')}-${dateAdded.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Safe Sender Details'),
        // Sprint 33 fix: wrap in SelectionArea so users can copy pattern text.
        content: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Pattern', sender.pattern, monospace: true),
              const SizedBox(height: 8),
              _detailRow('Type', _formatPatternType(sender)),
              const SizedBox(height: 8),
              _detailRow('Added', dateStr),
              const SizedBox(height: 8),
              _detailRow('Source', _formatCreatedBy(sender.createdBy)),
              if (sender.exceptionPatterns != null &&
                  sender.exceptionPatterns!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Exceptions (${sender.exceptionPatterns!.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...sender.exceptionPatterns!.map(
                  (ex) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      ex,
                      style:
                          const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSafeSender(sender);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool monospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              fontSize: monospace ? 13 : null,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPatternType(SafeSenderPattern sender) {
    return SafeSenderCategory.categorize(sender).label;
  }

  String _formatCreatedBy(String createdBy) {
    switch (createdBy) {
      case 'manual':
        return 'Manual';
      case 'quick_add':
        return 'Quick Add';
      case 'imported':
        return 'Imported from YAML';
      default:
        return createdBy;
    }
  }

  IconData _getPatternTypeIcon(SafeSenderPattern sender) {
    return SafeSenderCategory.categorize(sender).icon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Manage Safe Senders'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(context, HelpSection.safeSenders),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSafeSenders,
          ),
          // Sprint 37 round 6: filter-aware bulk export.
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: _filteredSenders.isEmpty
                ? 'Nothing to export'
                : 'Export ${_filteredSenders.length} shown safe sender${_filteredSenders.length == 1 ? '' : 's'} as CSV',
            onPressed: _filteredSenders.isEmpty ? null : _exportFilteredSafeSenders,
          ),
        ],
      ),
      // Sprint 38 F84 Sub-task A (Issue #253): Ctrl+A / Cmd+A copies the
      // ENTIRE filtered safe-sender list to clipboard, not just the
      // viewport subset. Bypasses Flutter's selection model -- writes
      // joined row text directly.
      //
      // Sprint 39 S38-CI-3 (Sub-tasks B/C): when a multi-region row
      // selection exists (Shift+Click extend / Ctrl+Click disjoint),
      // Ctrl+A copies only the SELECTED rows; otherwise it copies the
      // whole filtered list (original Sub-task A behavior).
      body: CopyAllShortcut(
        itemLabel: 'safe senders',
        textBuilder: () {
          if (_filteredSenders.isEmpty) return '';
          final indices = hasRowSelection
              ? selectedRowIndices
              : List<int>.generate(_filteredSenders.length, (i) => i);
          return indices
              .map((i) =>
                  '${_filteredSenders[i].pattern}\t${_filteredSenders[i].patternType}')
              .join('\n');
        },
        child: SelectionArea(
          child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patterns...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilter();
                });
              },
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in SafeSenderCategory.values)
                      _buildFilterChip(category),
                    if (_selectedCategories.isNotEmpty)
                      ActionChip(
                        label: const Text('Clear'),
                        avatar: const Icon(Icons.clear, size: 16),
                        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                            _applyFilter();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _selectedCategories.isEmpty && _searchQuery.isEmpty
                          ? '${_safeSenders.length} safe sender${_safeSenders.length == 1 ? '' : 's'}'
                          : '${_filteredSenders.length} of ${_safeSenders.length} shown',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        // ADR-0037: use theme color (secondary for safe sender
                        // affordance to differentiate from block-rule add).
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      iconSize: 24,
                      tooltip: 'Add safe sender',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManualRuleCreateScreen(
                              mode: ManualRuleMode.safeSender,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadSafeSenders();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Safe senders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSenders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasActiveFilters
                                  ? Icons.filter_list_off
                                  : Icons.security,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasActiveFilters
                                  ? 'No patterns match current filters'
                                  : 'No safe senders configured',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            if (!_hasActiveFilters) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Add safe senders from scan results using Quick Add',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSafeSenders,
                        child: ListView.builder(
                          itemCount: _filteredSenders.length,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemBuilder: (context, index) {
                            return _buildSafeSenderTile(
                                _filteredSenders[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildFilterChip(SafeSenderCategory category) {
    final isSelected = _selectedCategories.contains(category);
    // Count how many patterns belong to this category
    final count = _safeSenders
        .where((s) => SafeSenderCategory.categorize(s) == category)
        .length;

    return FilterChip(
      label: Text('${category.label} ($count)'),
      avatar: Icon(category.icon, size: 16),
      selected: isSelected,
      labelStyle: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null),
      selectedColor: Colors.green.shade600,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCategories.add(category);
          } else {
            _selectedCategories.remove(category);
          }
          _applyFilter();
        });
      },
    );
  }

  Widget _buildSafeSenderTile(SafeSenderPattern sender, int index) {
    final hasExceptions = sender.exceptionPatterns != null &&
        sender.exceptionPatterns!.isNotEmpty;

    // Sprint 37 Phase 7 Imp-1 round 6 (Alt-2 final UX, supersedes rounds
    // 1-5b on this screen). See rules_management_screen.dart for the same
    // design rationale: leading icon decorative-only; trailing reveal-on-
    // hover info_outline; trailing delete REMOVED (delete remains
    // available inside the details dialog).
    final isRevealed = _hoveredPattern == sender.pattern;
    // S38-CI-3 (Sub-tasks B/C): multi-region row selection. See
    // rules_management_screen.dart::_buildRuleTile for the gesture +
    // drag-extend rationale (GestureDetector.onTap reads modifiers;
    // onPanStart begins a Ctrl-drag; MouseRegion.onEnter extends it).
    final isSelected = isRowSelected(index);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
          : null,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hoveredPattern = sender.pattern);
          handleRowDragTo(index, _filteredSenders.length);
        },
        onExit: (_) {
          if (_hoveredPattern == sender.pattern) {
            setState(() => _hoveredPattern = null);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => handleRowTap(index, _filteredSenders.length),
          onPanStart: (_) =>
              handleRowDragStart(index, _filteredSenders.length),
          onPanEnd: (_) => handleRowDragEnd(),
          onPanCancel: handleRowDragEnd,
          child: ListTile(
          // Sprint 37 round 7: leading icon is now ALSO clickable (Harold
          // feedback 2026-05-04). See rules_management_screen.dart for
          // rationale + the SizedBox constraint that prevents round-5b's
          // collapsed-hit-region failure.
          leading: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                _getPatternTypeIcon(sender),
                color: Colors.green.shade700.withValues(alpha: 0.85),
                size: 20,
                semanticLabel: '${_formatPatternType(sender)} category',
              ),
              tooltip: 'View safe sender details',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => _showPatternDetails(sender),
            ),
          ),
          title: Text(
            sender.pattern,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                _formatPatternType(sender),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (hasExceptions) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '${sender.exceptionPatterns!.length} exception${sender.exceptionPatterns!.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                setState(() => _hoveredPattern = sender.pattern);
              }
            },
            child: AnimatedOpacity(
              opacity: isRevealed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                tooltip: 'View safe sender details (Enter)',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showPatternDetails(sender),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// Sprint 37 round 6: export the currently-filtered safe sender list as
  /// a CSV file. Respects search query + filter chips. Mirrors
  /// `_exportFilteredRules` on the rules screen.
  Future<void> _exportFilteredSafeSenders() async {
    if (_filteredSenders.isEmpty) return;
    try {
      final settingsStore = SettingsStore();
      final configuredDir = await settingsStore.getCsvExportDirectory();

      String exportPath;
      if (configuredDir != null && configuredDir.isNotEmpty) {
        final dir = Directory(configuredDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        exportPath = configuredDir;
      } else {
        final directory = Platform.isAndroid || Platform.isIOS
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();
        if (directory == null) {
          throw Exception('Could not access storage directory');
        }
        exportPath = directory.path;
      }

      String normalizedPath = exportPath;
      while (normalizedPath.endsWith('/') || normalizedPath.endsWith('\\')) {
        normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
      }
      final separator = Platform.isWindows ? '\\' : '/';
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'manage_safe_senders_filtered_$timestamp.csv';
      final filePath = '$normalizedPath$separator$filename';

      // Sprint 37 round 8: align column order with the rules CSV export
      // for the columns that make sense on both sides:
      //   Source Domain | Rule Name | Pattern | Category | Sub-Type
      // Columns that do not apply to safe senders are intentionally
      // omitted (Action -- safe senders just bypass block rules with no
      // per-row action; Enabled -- safe senders have no disable flag;
      // Execution Order -- safe senders have no order). Safe-sender-
      // specific extras (Date Added, Source, Exceptions) are kept as
      // trailing columns so users do not lose information they had in
      // earlier exports.
      final buffer = StringBuffer();
      buffer.writeln('Source Domain,Rule Name,Pattern,Category,Sub-Type,Date Added,Source,Exceptions');
      for (final s in _filteredSenders) {
        final subTypeKey = _safeSenderSubTypeKey(s);
        final extracted =
            _extractBaseFromSafeSenderPattern(s.pattern, subTypeKey);
        final sourceDomain = _csvEscape(extracted ?? '');
        // Rule Name parity with the rules screen: rules use either the
        // explicit `name` field or `sourceDomain` for the displayed
        // identifier; safe senders fall back to the pattern when no
        // structural extraction is possible.
        final ruleName = _csvEscape(extracted ?? s.pattern);
        final pattern = _csvEscape(s.pattern);
        // Safe senders only ever match the From / Header field.
        final category = _csvEscape('Header / From');
        final subType = _csvEscape(_formatPatternType(s));
        final dateAdded = DateTime.fromMillisecondsSinceEpoch(s.dateAdded);
        final dateStr =
            '${dateAdded.year}-${dateAdded.month.toString().padLeft(2, '0')}-${dateAdded.day.toString().padLeft(2, '0')}';
        final sourceField = _csvEscape(_formatCreatedBy(s.createdBy));
        final exceptions = (s.exceptionPatterns?.length ?? 0).toString();
        buffer.writeln('$sourceDomain,$ruleName,$pattern,$category,$subType,$dateStr,$sourceField,$exceptions');
      }
      final file = File(filePath);
      await file.writeAsString(buffer.toString());
      _logger.i('[OK] Exported ${_filteredSenders.length} filtered safe senders to $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${_filteredSenders.length} safe sender${_filteredSenders.length == 1 ? '' : 's'} to $filename'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to export filtered safe senders', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Sprint 37 round 8: maps a SafeSenderPattern's category to the
  /// sub-type vocabulary used by `_extractBaseFromSafeSenderPattern`.
  /// Mirrors `manual_rule_duplicate_checker.dart::_extractBaseFromPattern`
  /// keys (`exact_email` / `exact_domain` / `entire_domain`).
  String _safeSenderSubTypeKey(SafeSenderPattern sender) {
    switch (SafeSenderCategory.categorize(sender)) {
      case SafeSenderCategory.exactEmail:
        return 'exact_email';
      case SafeSenderCategory.exactDomain:
        return 'exact_domain';
      case SafeSenderCategory.entireDomain:
        return 'entire_domain';
      case SafeSenderCategory.other:
        return 'other';
    }
  }

  /// Sprint 37 round 8: extract the human-readable domain (or
  /// user@domain for exact_email) from a safe-sender regex pattern.
  /// Mirrors the regex-shape recognition in
  /// `manual_rule_duplicate_checker.dart::_extractBaseFromPattern` so the
  /// CSV `Source Domain` column shows the same identifier the user sees
  /// when adding the rule (e.g. `cwru.edu`, not the raw regex). Returns
  /// null when the pattern does not match a known shape -- the export
  /// then falls back to using the pattern itself for the Rule Name
  /// column and leaves Source Domain blank.
  String? _extractBaseFromSafeSenderPattern(String pattern, String subType) {
    final trimmed = pattern.trim();
    switch (subType) {
      case 'entire_domain':
        final match =
            RegExp(r'^\^\[\^@\\s\]\+@\(\?:\[a-z0-9-\]\+\\\.\)\*(.+)\$$')
                .firstMatch(trimmed);
        if (match == null) return null;
        return _unescapeRegexLiteral(match.group(1)!);
      case 'exact_domain':
        // Two shapes seen on this screen:
        //   `@example.com` (unanchored)
        //   `^[^@\s]+@example\.com$` (anchored)
        // Either way the visible identifier is `example.com`.
        if (trimmed.startsWith('@') && !trimmed.startsWith('@(')) {
          return _unescapeRegexLiteral(trimmed.substring(1));
        }
        if (trimmed.startsWith('^') && trimmed.endsWith(r'$')) {
          final body = trimmed.substring(1, trimmed.length - 1);
          final atIdx = body.lastIndexOf('@');
          if (atIdx == -1) return null;
          return _unescapeRegexLiteral(body.substring(atIdx + 1));
        }
        return null;
      case 'exact_email':
        if (!trimmed.startsWith('^') || !trimmed.endsWith(r'$')) return null;
        final body = trimmed.substring(1, trimmed.length - 1);
        final unescaped = _unescapeRegexLiteral(body);
        return unescaped.contains('@') ? unescaped : null;
      default:
        return null;
    }
  }

  /// Reverse `RegExp.escape` for the limited set of characters used in
  /// domain/email patterns. Mirrors the helper in
  /// `manual_rule_duplicate_checker.dart`. NOT a general regex unescape.
  String _unescapeRegexLiteral(String escaped) {
    final buf = StringBuffer();
    var i = 0;
    while (i < escaped.length) {
      final c = escaped[i];
      if (c == r'\' && i + 1 < escaped.length) {
        buf.write(escaped[i + 1]);
        i += 2;
      } else {
        buf.write(c);
        i++;
      }
    }
    return buf.toString().toLowerCase();
  }

  /// Sprint 37 round 7: CSV-injection-safe escape (OWASP guidance). See
  /// rules_management_screen.dart::_csvEscape for full rationale -- regex
  /// patterns starting with `@(?:...)` would otherwise be read by Excel
  /// as a formula and produce `#NAME?` errors.
  String _csvEscape(String s) {
    if (s.isEmpty) return s;
    final first = s.codeUnitAt(0);
    final isFormulaTrigger = first == 0x3D /* = */ ||
        first == 0x2B /* + */ ||
        first == 0x2D /* - */ ||
        first == 0x40 /* @ */ ||
        first == 0x09 /* TAB */ ||
        first == 0x0D /* CR */;
    final escaped = isFormulaTrigger ? "'$s" : s;
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"${escaped.replaceAll('"', '""')}"';
    }
    return escaped;
  }
}
