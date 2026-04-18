/// Rules management screen for viewing, toggling, filtering, and deleting block rules
///
/// [ISSUE #149] Sprint 20: Overhaul with filter chips, search, and individual
/// pattern display after monolithic rule split.
///
/// Features:
/// - Filter chips by pattern category (header_from, subject, body)
/// - Filter chips by pattern sub-type (entire_domain, exact_domain, exact_email, top_level_domain)
/// - Search across rule names and source domains
/// - Toggle rule enable/disable
/// - Delete individual rules with confirmation
/// - View rule details (conditions, pattern, action)
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/models/rule_set.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/rule_database_store.dart';
import '../widgets/app_bar_with_exit.dart';
import 'help_screen.dart';
import 'manual_rule_create_screen.dart';
import 'rule_test_screen.dart';

/// Screen for managing spam filtering rules
class RulesManagementScreen extends StatefulWidget {
  const RulesManagementScreen({super.key});

  @override
  State<RulesManagementScreen> createState() => _RulesManagementScreenState();
}

class _RulesManagementScreenState extends State<RulesManagementScreen> {
  final Logger _logger = Logger();
  late final RuleDatabaseStore _store;
  List<Rule> _rules = [];
  List<Rule> _filteredRules = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedSubTypes = {};

  // Category display labels
  static const Map<String, String> _categoryLabels = {
    'header_from': 'Header / From',
    'subject': 'Subject',
    'body': 'Body',
  };

  static const Map<String, String> _subTypeLabels = {
    'entire_domain': 'Entire Domain',
    'exact_domain': 'Exact Domain',
    'exact_email': 'Exact Email',
    'top_level_domain': 'Top-Level Domain',
  };

  @override
  void initState() {
    super.initState();
    _store = RuleDatabaseStore(DatabaseHelper());
    _loadRules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final ruleSet = await _store.loadRules();
      _rules = List.from(ruleSet.rules);
      _rules.sort((a, b) {
        // Sort by execution order, then by sourceDomain/name
        final orderCompare = a.executionOrder.compareTo(b.executionOrder);
        if (orderCompare != 0) return orderCompare;
        final aDisplay = a.sourceDomain ?? a.name;
        final bDisplay = b.sourceDomain ?? b.name;
        return aDisplay.compareTo(bDisplay);
      });
      _applyFilter();
    } catch (e) {
      _logger.e('Failed to load rules', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rules: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filteredRules = _rules.where((rule) {
      // Category filter
      if (_selectedCategories.isNotEmpty) {
        final cat = rule.patternCategory ?? '';
        if (!_selectedCategories.contains(cat)) return false;
      }

      // SubType filter
      if (_selectedSubTypes.isNotEmpty) {
        final sub = rule.patternSubType ?? '';
        if (!_selectedSubTypes.contains(sub)) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final displayName = (rule.sourceDomain ?? rule.name).toLowerCase();
        final ruleName = rule.name.toLowerCase();
        if (!displayName.contains(query) && !ruleName.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  /// Count rules per category
  Map<String, int> _getCategoryCounts() {
    final counts = <String, int>{};
    for (final rule in _rules) {
      final cat = rule.patternCategory ?? 'uncategorized';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  /// Count rules per sub-type
  Map<String, int> _getSubTypeCounts() {
    final counts = <String, int>{};
    for (final rule in _rules) {
      final sub = rule.patternSubType ?? 'unknown';
      counts[sub] = (counts[sub] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _toggleRule(Rule rule) async {
    try {
      final updatedRule = Rule(
        name: rule.name,
        enabled: !rule.enabled,
        isLocal: rule.isLocal,
        executionOrder: rule.executionOrder,
        conditions: rule.conditions,
        actions: rule.actions,
        exceptions: rule.exceptions,
        metadata: rule.metadata,
        patternCategory: rule.patternCategory,
        patternSubType: rule.patternSubType,
        sourceDomain: rule.sourceDomain,
      );
      await _store.updateRule(updatedRule);
      _logger.i('${rule.enabled ? "Disabled" : "Enabled"} rule: ${rule.name}');
      await _loadRules();
    } catch (e) {
      _logger.e('Failed to toggle rule', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update rule: $e')),
        );
      }
    }
  }

  Future<void> _deleteRule(Rule rule) async {
    final displayName = rule.sourceDomain ?? rule.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this rule?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _store.deleteRule(rule.name);
        _logger.i('Deleted rule: ${rule.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted: $displayName')),
          );
        }
        await _loadRules();
      } catch (e) {
        _logger.e('Failed to delete rule', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _showRuleDetails(Rule rule) {
    final displayName = rule.sourceDomain ?? rule.name;
    final categoryLabel = _categoryLabels[rule.patternCategory] ?? rule.patternCategory ?? 'Unknown';
    final subTypeLabel = _subTypeLabels[rule.patternSubType] ?? rule.patternSubType ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              rule.enabled ? Icons.check_circle : Icons.cancel,
              color: rule.enabled ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                displayName,
                style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        // Sprint 33 fix: dialogs in Flutter sit in a separate overlay and
        // are not covered by the screen-level SelectionArea. Wrap the dialog
        // body in its own SelectionArea so users can copy rule/pattern text.
        content: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailSection('Status', rule.enabled ? 'Enabled' : 'Disabled'),
                _detailSection('Category', categoryLabel),
                _detailSection('Sub-Type', subTypeLabel),
                _detailSection('Action', _getActionLabel(rule)),
                _detailSection('Exec Order', '${rule.executionOrder}'),
                if (rule.name != displayName) _detailSection('Rule Name', rule.name),

                const SizedBox(height: 12),
                const Text(
                  'Pattern',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                if (rule.conditions.header.isNotEmpty)
                  _patternList('Header', rule.conditions.header),
                if (rule.conditions.from.isNotEmpty)
                  _patternList('From', rule.conditions.from),
                if (rule.conditions.subject.isNotEmpty)
                  _patternList('Subject', rule.conditions.subject),
                if (rule.conditions.body.isNotEmpty)
                  _patternList('Body', rule.conditions.body),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleRule(rule);
            },
            child: Text(rule.enabled ? 'Disable' : 'Enable'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRule(rule);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _patternList(String category, List<String> patterns) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$category:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          ...patterns.map(
            (p) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: SelectableText(
                p,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionLabel(Rule rule) {
    if (rule.actions.delete) return 'Delete';
    if (rule.actions.moveToFolder != null) {
      return 'Move to ${rule.actions.moveToFolder}';
    }
    if (rule.actions.assignToCategory != null) {
      return 'Categorize as ${rule.actions.assignToCategory}';
    }
    return 'No action';
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'header_from':
        return Icons.alternate_email;
      case 'subject':
        return Icons.subject;
      case 'body':
        return Icons.article_outlined;
      default:
        return Icons.rule;
    }
  }

  Color _getSubTypeColor(String? subType) {
    switch (subType) {
      case 'entire_domain':
        return Colors.blue.shade700;
      case 'exact_domain':
        return Colors.teal.shade700;
      case 'exact_email':
        return Colors.purple.shade700;
      case 'top_level_domain':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryCounts = _getCategoryCounts();
    final subTypeCounts = _getSubTypeCounts();
    final hasFilters = _selectedCategories.isNotEmpty || _selectedSubTypes.isNotEmpty;

    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Manage Rules'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(context, HelpSection.manageRules),
          ),
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Test a pattern against sample emails',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RuleTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRules,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by domain, email, or keyword...',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilter();
                });
              },
            ),
          ),

          // Category filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              children: [
                ..._categoryLabels.entries.map((entry) {
                  final count = categoryCounts[entry.key] ?? 0;
                  final isSelected = _selectedCategories.contains(entry.key);
                  return FilterChip(
                    label: Text('${entry.value} ($count)'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(entry.key);
                        } else {
                          _selectedCategories.remove(entry.key);
                        }
                        _applyFilter();
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade800,
                  );
                }),
                if (hasFilters)
                  ActionChip(
                    label: const Text('Clear'),
                    avatar: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedCategories.clear();
                        _selectedSubTypes.clear();
                        _applyFilter();
                      });
                    },
                  ),
              ],
            ),
          ),

          // Sub-type filter chips (header_from scope only -- subject/body
          // rules do not have these sub-types)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Header / From sub-types:',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              children: _subTypeLabels.entries.map((entry) {
                final count = subTypeCounts[entry.key] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final isSelected = _selectedSubTypes.contains(entry.key);
                return FilterChip(
                  label: Text('${entry.value} ($count)'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSubTypes.add(entry.key);
                      } else {
                        _selectedSubTypes.remove(entry.key);
                      }
                      _applyFilter();
                    });
                  },
                  selectedColor: Colors.teal.shade100,
                  checkmarkColor: Colors.teal.shade800,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  hasFilters || _searchQuery.isNotEmpty
                      ? '${_filteredRules.length} of ${_rules.length} shown'
                      : '${_rules.length} rules',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  iconSize: 24,
                  tooltip: 'Add block rule',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManualRuleCreateScreen(
                          mode: ManualRuleMode.blockRule,
                        ),
                      ),
                    );
                    if (result == true) {
                      await _loadRules();
                    }
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_rules.where((r) => r.enabled).length} active',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Rules list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isEmpty && !hasFilters
                                  ? Icons.rule
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && !hasFilters
                                  ? 'No rules configured'
                                  : 'No rules match current filters',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRules,
                        child: ListView.builder(
                          itemCount: _filteredRules.length,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemBuilder: (context, index) {
                            return _buildRuleTile(_filteredRules[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTile(Rule rule) {
    final displayName = rule.sourceDomain ?? rule.name;
    final categoryLabel = _categoryLabels[rule.patternCategory] ?? rule.patternCategory ?? '';
    final subTypeLabel = _subTypeLabels[rule.patternSubType] ?? rule.patternSubType ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(
          _getCategoryIcon(rule.patternCategory),
          color: rule.enabled ? _getSubTypeColor(rule.patternSubType) : Colors.grey.shade400,
          size: 22,
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: rule.enabled ? null : Colors.grey.shade500,
            decoration: rule.enabled ? null : TextDecoration.lineThrough,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$categoryLabel - $subTypeLabel',
          style: TextStyle(
            fontSize: 11,
            color: rule.enabled ? _getSubTypeColor(rule.patternSubType) : Colors.grey.shade400,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
          tooltip: 'Delete',
          onPressed: () => _deleteRule(rule),
        ),
        onTap: () => _showRuleDetails(rule),
      ),
    );
  }
}
