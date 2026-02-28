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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../widgets/app_bar_with_exit.dart';

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

  /// Classify a safe sender pattern into its category based on regex structure
  static SafeSenderCategory categorize(SafeSenderPattern sender) {
    final pattern = sender.pattern;
    final type = sender.patternType;

    // Use stored patternType as primary signal, with pattern analysis as fallback
    if (type == 'subdomain' || pattern.contains('@(?:[a-z0-9-]+\\.)*')) {
      return SafeSenderCategory.entireDomain;
    } else if (type == 'email' ||
        (pattern.startsWith('^') && pattern.endsWith(r'$') && pattern.contains('@'))) {
      return SafeSenderCategory.exactEmail;
    } else if (type == 'domain' ||
        (pattern.contains('@') && !pattern.startsWith('^'))) {
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
    extends State<SafeSendersManagementScreen> {
  final Logger _logger = Logger();
  late final SafeSenderDatabaseStore _store;
  List<SafeSenderPattern> _safeSenders = [];
  List<SafeSenderPattern> _filteredSenders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<SafeSenderCategory> _selectedCategories = {};

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
        content: Column(
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSafeSenders,
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
                Text(
                  _selectedCategories.isEmpty && _searchQuery.isEmpty
                      ? '${_safeSenders.length} safe sender${_safeSenders.length == 1 ? '' : 's'}'
                      : '${_filteredSenders.length} of ${_safeSenders.length} shown',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
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
                                _filteredSenders[index]);
                          },
                        ),
                      ),
          ),
        ],
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

  Widget _buildSafeSenderTile(SafeSenderPattern sender) {
    final hasExceptions = sender.exceptionPatterns != null &&
        sender.exceptionPatterns!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          _getPatternTypeIcon(sender),
          color: Colors.green.shade700,
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
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          tooltip: 'Delete',
          onPressed: () => _deleteSafeSender(sender),
        ),
        onTap: () => _showPatternDetails(sender),
      ),
    );
  }
}
