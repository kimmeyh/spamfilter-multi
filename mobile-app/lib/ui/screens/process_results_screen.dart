/// Screen for reviewing and processing unmatched emails from scan results
///
/// Displays emails that did not match any filtering rules, allowing users to:
/// - View unmatched emails with availability status
/// - Filter by availability (all, available only, deleted, moved)
/// - Sort by different criteria
/// - Search by sender or subject
/// - Mark emails as processed
/// - Quick-add safe senders or rules

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/storage/rule_database_store.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import 'email_detail_view.dart';

/// [NEW] SPRINT 4: Screen for processing unmatched emails from scan results
/// [NEW] SPRINT 6: Added quick-add screen integration
class ProcessResultsScreen extends StatefulWidget {
  final int scanResultId;
  final String accountEmail;
  final ScanResultStore scanResultStore;
  final UnmatchedEmailStore unmatchedEmailStore;
  final SafeSenderDatabaseStore? safeSenderStore;
  final RuleDatabaseStore? ruleStore;

  const ProcessResultsScreen({
    Key? key,
    required this.scanResultId,
    required this.accountEmail,
    required this.scanResultStore,
    required this.unmatchedEmailStore,
    this.safeSenderStore,
    this.ruleStore,
  }) : super(key: key);

  @override
  State<ProcessResultsScreen> createState() => _ProcessResultsScreenState();
}

class _ProcessResultsScreenState extends State<ProcessResultsScreen> {
  final Logger _logger = Logger();
  late Future<ScanResult?> _scanResultFuture;
  late Future<List<UnmatchedEmail>> _unmatchedEmailsFuture;

  String _filterMode = 'all';  // all, available, deleted, moved
  String _sortMode = 'date';   // date, from, subject
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _scanResultFuture = widget.scanResultStore.getScanResultById(widget.scanResultId);
    _unmatchedEmailsFuture = widget.unmatchedEmailStore.getUnmatchedEmailsByScan(widget.scanResultId);
  }

  List<UnmatchedEmail> _filterAndSort(List<UnmatchedEmail> emails) {
    // Apply filter
    var filtered = emails.where((email) {
      if (_filterMode == 'all') return true;
      if (_filterMode == 'available') return email.availabilityStatus == 'available';
      if (_filterMode == 'deleted') return email.availabilityStatus == 'deleted';
      if (_filterMode == 'moved') return email.availabilityStatus == 'moved';
      return true;
    }).toList();

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((email) {
        final query = _searchQuery.toLowerCase();
        return email.fromEmail.toLowerCase().contains(query) ||
            (email.subject?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sort
    switch (_sortMode) {
      case 'from':
        filtered.sort((a, b) => a.fromEmail.compareTo(b.fromEmail));
        break;
      case 'subject':
        filtered.sort((a, b) => (a.subject ?? '').compareTo(b.subject ?? ''));
        break;
      default: // date
        filtered.sort((a, b) {
          final aDate = a.emailDate?.millisecondsSinceEpoch ?? 0;
          final bDate = b.emailDate?.millisecondsSinceEpoch ?? 0;
          return bDate.compareTo(aDate);
        });
    }

    return filtered;
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by Availability', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text('All'),
                  selected: _filterMode == 'all',
                  onSelected: (selected) {
                    setState(() => _filterMode = 'all');
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: Text('Available'),
                  selected: _filterMode == 'available',
                  onSelected: (selected) {
                    setState(() => _filterMode = 'available');
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: Text('Deleted'),
                  selected: _filterMode == 'deleted',
                  onSelected: (selected) {
                    setState(() => _filterMode = 'deleted');
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: Text('Moved'),
                  selected: _filterMode == 'moved',
                  onSelected: (selected) {
                    setState(() => _filterMode = 'moved');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unmatched Emails - ${widget.accountEmail}'),
        elevation: 0,
      ),
      body: FutureBuilder<ScanResult?>(
        future: _scanResultFuture,
        builder: (context, scanSnapshot) {
          if (scanSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!scanSnapshot.hasData || scanSnapshot.data == null) {
            return Center(child: Text('Scan not found'));
          }

          final scanResult = scanSnapshot.data!;

          return FutureBuilder<List<UnmatchedEmail>>(
            future: _unmatchedEmailsFuture,
            builder: (context, emailSnapshot) {
              if (emailSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!emailSnapshot.hasData) {
                return Center(child: Text('Failed to load emails'));
              }

              final allEmails = emailSnapshot.data!;
              final filtered = _filterAndSort(allEmails);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No unmatched emails',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Search and filter bar
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by from or subject...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.filter_list),
                          onPressed: _showFilters,
                          tooltip: 'Filter',
                        ),
                      ],
                    ),
                  ),

                  // Summary and info
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${filtered.length} of ${allEmails.length} emails',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        DropdownButton<String>(
                          value: _sortMode,
                          items: [
                            DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                            DropdownMenuItem(value: 'from', child: Text('Sort by From')),
                            DropdownMenuItem(value: 'subject', child: Text('Sort by Subject')),
                          ],
                          onChanged: (value) {
                            setState(() => _sortMode = value ?? 'date');
                          },
                        ),
                      ],
                    ),
                  ),

                  // Email list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final email = filtered[index];
                        return UnmatchedEmailCard(
                          email: email,
                          onTap: () {
                            _logger.d('Tapped email: ${email.fromEmail}');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmailDetailView(
                                  email: email,
                                  unmatchedEmailStore: widget.unmatchedEmailStore,
                                  safeSenderStore: widget.safeSenderStore,
                                  ruleStore: widget.ruleStore,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// [NEW] SPRINT 4: Card widget for displaying unmatched email summary
class UnmatchedEmailCard extends StatelessWidget {
  final UnmatchedEmail email;
  final VoidCallback? onTap;

  const UnmatchedEmailCard({
    Key? key,
    required this.email,
    this.onTap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'deleted':
        return Colors.red;
      case 'moved':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'deleted':
        return 'Deleted';
      case 'moved':
        return 'Moved';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getStatusColor(email.availabilityStatus),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          (email.subject?.isNotEmpty ?? false) ? email.subject! : '(No subject)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${email.fromEmail}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    _getStatusLabel(email.availabilityStatus),
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(email.availabilityStatus).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _getStatusColor(email.availabilityStatus),
                    fontWeight: FontWeight.bold,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (email.processed)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text('Processed', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      labelStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        isThreeLine: true,
      ),
    );
  }
}
