/// Rules management screen for viewing, toggling, and deleting block rules
///
/// [ISSUE #148] Sprint 15: Allows users to manage spam filtering rules
/// from Settings without direct database or YAML access.
///
/// Features:
/// - List all rules with name, action, and enabled status
/// - Toggle rule enable/disable
/// - Delete individual rules with confirmation
/// - View rule details (conditions, exceptions, action)
/// - Search/filter rules
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/models/rule_set.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/rule_database_store.dart';
import '../widgets/app_bar_with_exit.dart';

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
      // Sort by execution order
      _rules.sort((a, b) => a.executionOrder.compareTo(b.executionOrder));
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
    if (_searchQuery.isEmpty) {
      _filteredRules = List.from(_rules);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredRules = _rules.where((rule) {
        return rule.name.toLowerCase().contains(query) ||
            _getActionLabel(rule).toLowerCase().contains(query) ||
            _getConditionSummary(rule).toLowerCase().contains(query);
      }).toList();
    }
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
                rule.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
            const SnackBar(content: Text('Rule deleted')),
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
              child: Text(
                rule.name,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailSection('Status', rule.enabled ? 'Enabled' : 'Disabled'),
              _detailSection('Action', _getActionLabel(rule)),
              _detailSection('Execution Order', '${rule.executionOrder}'),
              _detailSection('Condition Logic', rule.conditions.type),
              if (rule.isLocal) _detailSection('Source', 'User-created'),

              // Conditions
              const SizedBox(height: 12),
              const Text(
                'Conditions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              if (rule.conditions.from.isNotEmpty)
                _patternList('From', rule.conditions.from),
              if (rule.conditions.header.isNotEmpty)
                _patternList('Header', rule.conditions.header),
              if (rule.conditions.subject.isNotEmpty)
                _patternList('Subject', rule.conditions.subject),
              if (rule.conditions.body.isNotEmpty)
                _patternList('Body', rule.conditions.body),

              // Exceptions
              if (rule.exceptions != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Exceptions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                if (rule.exceptions!.from.isNotEmpty)
                  _patternList('From', rule.exceptions!.from),
                if (rule.exceptions!.header.isNotEmpty)
                  _patternList('Header', rule.exceptions!.header),
                if (rule.exceptions!.subject.isNotEmpty)
                  _patternList('Subject', rule.exceptions!.subject),
                if (rule.exceptions!.body.isNotEmpty)
                  _patternList('Body', rule.exceptions!.body),
              ],
            ],
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
              child: Text(
                p,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

  IconData _getActionIcon(Rule rule) {
    if (rule.actions.delete) return Icons.delete_outline;
    if (rule.actions.moveToFolder != null) return Icons.drive_file_move_outlined;
    if (rule.actions.assignToCategory != null) return Icons.label_outline;
    return Icons.help_outline;
  }

  Color _getActionColor(Rule rule) {
    if (rule.actions.delete) return Colors.red.shade700;
    if (rule.actions.moveToFolder != null) return Colors.orange.shade700;
    if (rule.actions.assignToCategory != null) return Colors.blue.shade700;
    return Colors.grey;
  }

  String _getConditionSummary(Rule rule) {
    final parts = <String>[];
    if (rule.conditions.from.isNotEmpty) {
      parts.add('from: ${rule.conditions.from.length}');
    }
    if (rule.conditions.header.isNotEmpty) {
      parts.add('header: ${rule.conditions.header.length}');
    }
    if (rule.conditions.subject.isNotEmpty) {
      parts.add('subject: ${rule.conditions.subject.length}');
    }
    if (rule.conditions.body.isNotEmpty) {
      parts.add('body: ${rule.conditions.body.length}');
    }
    if (parts.isEmpty) return 'No conditions';
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _rules.where((r) => r.enabled).length;
    final disabledCount = _rules.length - enabledCount;

    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Manage Rules'),
        actions: [
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rules...',
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

          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _searchQuery.isEmpty
                      ? '${_rules.length} rule${_rules.length == 1 ? '' : 's'}'
                      : '${_filteredRules.length} of ${_rules.length} shown',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$enabledCount active',
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                if (disabledCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$disabledCount disabled',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                              _searchQuery.isEmpty
                                  ? Icons.rule
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No rules configured'
                                  : 'No rules match "$_searchQuery"',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Import rules from YAML or add via Quick Add',
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getActionIcon(rule),
              color: rule.enabled ? _getActionColor(rule) : Colors.grey.shade400,
            ),
            Text(
              '#${rule.executionOrder}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        title: Text(
          rule.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: rule.enabled ? null : Colors.grey.shade500,
            decoration: rule.enabled ? null : TextDecoration.lineThrough,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              _getActionLabel(rule),
              style: TextStyle(
                fontSize: 12,
                color: rule.enabled
                    ? _getActionColor(rule)
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getConditionSummary(rule),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (_) => _toggleRule(rule),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              tooltip: 'Delete',
              onPressed: () => _deleteRule(rule),
            ),
          ],
        ),
        onTap: () => _showRuleDetails(rule),
      ),
    );
  }
}
