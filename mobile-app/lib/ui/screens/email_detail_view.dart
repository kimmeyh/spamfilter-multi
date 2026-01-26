/// Detailed view of an unmatched email with quick-add actions
///
/// Displays full email information and provides quick-add buttons for:
/// - Adding the sender to safe senders list
/// - Creating an auto-delete rule
/// - Marking the email as processed

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/storage/unmatched_email_store.dart';

/// ✨ SPRINT 4: Detailed view for reviewing individual unmatched emails
class EmailDetailView extends StatefulWidget {
  final UnmatchedEmail email;
  final UnmatchedEmailStore unmatchedEmailStore;

  const EmailDetailView({
    Key? key,
    required this.email,
    required this.unmatchedEmailStore,
  }) : super(key: key);

  @override
  State<EmailDetailView> createState() => _EmailDetailViewState();
}

class _EmailDetailViewState extends State<EmailDetailView> {
  final Logger _logger = Logger();
  late bool _isProcessed;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _isProcessed = widget.email.processed;
    _currentStatus = widget.email.availabilityStatus;
  }

  void _markAsProcessed() async {
    try {
      final success = await widget.unmatchedEmailStore.markAsProcessed(
        widget.email.id!,
        !_isProcessed,
      );

      if (success) {
        setState(() => _isProcessed = !_isProcessed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isProcessed ? 'Marked as processed' : 'Marked as unprocessed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error updating processed status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _addSafeSender() {
    // TODO: Navigate to SafeSenderQuickAddScreen
    _logger.d('Add safe sender: ${widget.email.fromEmail}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add safe sender feature coming in Sprint 6')),
    );
  }

  void _createAutoDeleteRule() {
    // TODO: Navigate to RuleQuickAddScreen
    _logger.d('Create auto-delete rule for: ${widget.email.fromEmail}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto-delete rule feature coming in Sprint 6')),
    );
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email headers
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(_currentStatus),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Chip(
                          label: Text(_getStatusLabel(_currentStatus)),
                          backgroundColor: _getStatusColor(_currentStatus).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _getStatusColor(_currentStatus),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Subject
                    Text(
                      'Subject',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    SizedBox(height: 4),
                    Text(
                      (widget.email.subject?.isNotEmpty ?? false) ? widget.email.subject! : '(No subject)',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),

                    SizedBox(height: 16),

                    // From
                    Text(
                      'From',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.email.fromEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (widget.email.fromName != null && widget.email.fromName!.isNotEmpty)
                      Text(
                        widget.email.fromName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),

                    SizedBox(height: 16),

                    // Folder and date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Folder',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                widget.email.folderName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                widget.email.emailDate != null
                                    ? widget.email.emailDate!
                                        .toString()
                                        .split('.')[0]
                                    : 'Unknown',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Body preview
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  widget.email.bodyPreview ?? '(No preview available)',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Quick-add actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addSafeSender,
                icon: Icon(Icons.person_add),
                label: Text('Add Safe Sender'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createAutoDeleteRule,
                icon: Icon(Icons.delete_forever),
                label: Text('Create Auto-Delete Rule'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),

            SizedBox(height: 24),

            // Mark as processed
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _markAsProcessed,
                icon: Icon(_isProcessed ? Icons.done_all : Icons.done),
                label: Text(_isProcessed ? 'Mark as Unprocessed' : 'Mark as Processed'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
