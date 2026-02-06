// Detailed view of an unmatched email with quick-add actions
//
// Displays full email information and provides quick-add buttons for:
// - Adding the sender to safe senders list (exact email, domain, or pattern)
// - Creating an auto-delete rule (multiple types)
// - Viewing extracted domains from body links
// - Marking the email as processed

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/rule_set.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/storage/rule_database_store.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import 'rule_quick_add_screen.dart';
import 'safe_sender_quick_add_screen.dart';

/// ✨ SPRINT 4: Detailed view for reviewing individual unmatched emails
/// ✨ SPRINT 6: Added quick-add screen integration
/// ✨ SPRINT 12: Enhanced with domain extraction, tabbed view, improved actions
class EmailDetailView extends StatefulWidget {
  final UnmatchedEmail email;
  final UnmatchedEmailStore unmatchedEmailStore;
  final SafeSenderDatabaseStore? safeSenderStore;
  final RuleDatabaseStore? ruleStore;

  const EmailDetailView({
    super.key,
    required this.email,
    required this.unmatchedEmailStore,
    this.safeSenderStore,
    this.ruleStore,
  });

  @override
  State<EmailDetailView> createState() => _EmailDetailViewState();
}

class _EmailDetailViewState extends State<EmailDetailView>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final EmailBodyParser _bodyParser = EmailBodyParser();

  late TabController _tabController;
  late bool _isProcessed;
  late String _currentStatus;
  late DomainExtractionResult _extractedDomains;
  late String? _senderDomain;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isProcessed = widget.email.processed;
    _currentStatus = widget.email.availabilityStatus;

    // Extract domains from body preview
    _extractedDomains = _bodyParser.extractDomains(
      widget.email.bodyPreview,
      widget.email.bodyPreview,
    );

    // Extract sender domain
    _senderDomain = _bodyParser.extractDomainFromEmail(widget.email.fromEmail);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _markAsProcessed() async {
    try {
      final success = await widget.unmatchedEmailStore.markAsProcessed(
        widget.email.id!,
        !_isProcessed,
      );

      if (success) {
        setState(() => _isProcessed = !_isProcessed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(_isProcessed ? 'Marked as processed' : 'Marked as unprocessed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error updating processed status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showSafeSenderOptions() {
    if (widget.safeSenderStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe sender store not available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Safe Sender',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Option 1: Exact email
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Exact Email Address'),
                subtitle: Text(widget.email.fromEmail),
                onTap: () {
                  Navigator.pop(context);
                  _addSafeSenderWithPattern(
                    _bodyParser.generateExactEmailPattern(widget.email.fromEmail),
                    'Exact: ${widget.email.fromEmail}',
                  );
                },
              ),
              // Option 2: Domain
              if (_senderDomain != null)
                ListTile(
                  leading: const Icon(Icons.domain),
                  title: const Text('Entire Domain'),
                  subtitle: Text('*@$_senderDomain'),
                  onTap: () {
                    Navigator.pop(context);
                    _addSafeSenderWithPattern(
                      _bodyParser.generateDomainBlockPattern(_senderDomain!),
                      'Domain: $_senderDomain',
                    );
                  },
                ),
              // Option 3: Custom pattern (navigate to full screen)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Custom Pattern'),
                subtitle: const Text('Create a regex pattern'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToSafeSenderScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSafeSenderWithPattern(String pattern, String description) async {
    try {
      final safeSender = SafeSenderPattern(
        pattern: pattern,
        patternType: 'regex',
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'email_detail_view',
      );
      await widget.safeSenderStore!.addSafeSender(safeSender);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safe sender added: $description')),
        );
      }
    } catch (e) {
      _logger.e('Error adding safe sender: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _navigateToSafeSenderScreen() {
    final emailMessage = _createEmailMessage();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SafeSenderQuickAddScreen(
          email: emailMessage,
          safeSenderStore: widget.safeSenderStore!,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Safe sender added successfully')),
        );
      }
    });
  }

  void _showRuleOptions() {
    if (widget.ruleStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rule store not available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  'Create Auto-Delete Rule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose what to match:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // From Header - Exact Email
                _buildRuleOption(
                  icon: Icons.person,
                  title: 'From: Exact Email',
                  subtitle: widget.email.fromEmail,
                  onTap: () => _createQuickRule(
                    conditionType: 'from',
                    pattern: _bodyParser.generateExactEmailPattern(widget.email.fromEmail),
                    description: 'Block ${widget.email.fromEmail}',
                  ),
                ),

                // From Header - Domain
                if (_senderDomain != null)
                  _buildRuleOption(
                    icon: Icons.domain,
                    title: 'From: Entire Domain',
                    subtitle: '*@$_senderDomain',
                    onTap: () => _createQuickRule(
                      conditionType: 'from',
                      pattern: _bodyParser.generateDomainBlockPattern(_senderDomain!),
                      description: 'Block *@$_senderDomain',
                    ),
                  ),

                const Divider(),

                // Subject match
                if (widget.email.subject?.isNotEmpty ?? false)
                  _buildRuleOption(
                    icon: Icons.subject,
                    title: 'Subject Contains',
                    subtitle: widget.email.subject!,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToRuleScreen();
                    },
                  ),

                // Body domains (if any)
                if (_extractedDomains.domains.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Block by Body URL Domain',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ..._extractedDomains.domains.take(5).map((domain) =>
                      _buildRuleOption(
                        icon: Icons.link,
                        title: 'Body contains link to:',
                        subtitle: domain,
                        onTap: () => _createQuickRule(
                          conditionType: 'body',
                          pattern: _bodyParser.generateBodyDomainPattern(domain),
                          description: 'Block emails with links to $domain',
                        ),
                      )),
                ],

                const Divider(),

                // Custom rule (navigate to full screen)
                _buildRuleOption(
                  icon: Icons.edit,
                  title: 'Custom Rule',
                  subtitle: 'Create a custom rule with full options',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToRuleScreen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _createQuickRule({
    required String conditionType,
    required String pattern,
    required String description,
  }) async {
    try {
      // Build conditions based on condition type
      final conditions = RuleConditions(
        type: 'OR',
        from: conditionType == 'from' ? [pattern] : [],
        subject: conditionType == 'subject' ? [pattern] : [],
        body: conditionType == 'body' ? [pattern] : [],
        header: conditionType == 'header' ? [pattern] : [],
      );

      final rule = Rule(
        name: description,
        enabled: true,
        isLocal: true,
        executionOrder: 0,
        conditions: conditions,
        actions: RuleActions(delete: true),
        metadata: {
          'created_by': 'email_detail_view',
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      await widget.ruleStore!.addRule(rule);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rule created: $description')),
        );
      }
    } catch (e) {
      _logger.e('Error creating rule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _navigateToRuleScreen() {
    final emailMessage = _createEmailMessage();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RuleQuickAddScreen(
          email: emailMessage,
          ruleStore: widget.ruleStore!,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule created successfully')),
        );
      }
    });
  }

  EmailMessage _createEmailMessage() {
    return EmailMessage(
      id: widget.email.id?.toString() ?? 'unknown',
      from: widget.email.fromEmail,
      subject: widget.email.subject ?? '(No subject)',
      body: widget.email.bodyPreview ?? '',
      headers: {'from': widget.email.fromEmail},
      receivedDate: widget.email.emailDate ?? DateTime.now(),
      folderName: widget.email.folderName,
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
        title: const Text('Email Details'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Summary'),
            const Tab(text: 'Body'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Domains'),
                  if (_extractedDomains.domains.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_extractedDomains.domains.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildBodyTab(),
                _buildDomainsTab(),
              ],
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and processed indicator
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_getStatusLabel(_currentStatus)),
                        backgroundColor:
                            _getStatusColor(_currentStatus).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _getStatusColor(_currentStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isProcessed)
                        Chip(
                          label: const Text('Processed'),
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Subject
                  Text(
                    'Subject',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (widget.email.subject?.isNotEmpty ?? false)
                        ? widget.email.subject!
                        : '(No subject)',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 16),

                  // From
                  Text(
                    'From',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email.fromEmail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.email.fromName != null &&
                      widget.email.fromName!.isNotEmpty)
                    Text(
                      widget.email.fromName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_senderDomain != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Domain: $_senderDomain',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],

                  const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          // Preview
          Text(
            'Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
        ],
      ),
    );
  }

  Widget _buildBodyTab() {
    final bodyText = widget.email.bodyPreview ?? '(No body content available)';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Message Body',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '${bodyText.length} characters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                bodyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainsTab() {
    if (_extractedDomains.domains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No domains found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No URLs were found in the email body',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Found ${_extractedDomains.domains.length} unique domain(s) in ${_extractedDomains.totalUrlsProcessed} URL(s)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ..._extractedDomains.domains.map((domain) {
          final urls = _extractedDomains.domainUrls[domain] ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.language),
              title: Text(domain),
              subtitle: Text('${urls.length} URL(s)'),
              trailing: IconButton(
                icon: const Icon(Icons.block),
                tooltip: 'Block this domain',
                onPressed: () => _createQuickRule(
                  conditionType: 'body',
                  pattern: _bodyParser.generateBodyDomainPattern(domain),
                  description: 'Block emails with links to $domain',
                ),
              ),
              children: urls
                  .map((url) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          url,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: Colors.blue[700],
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSafeSenderOptions,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Safe Sender'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showRuleOptions,
                  icon: const Icon(Icons.block),
                  label: const Text('Block Rule'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _markAsProcessed,
              icon: Icon(_isProcessed ? Icons.done_all : Icons.done),
              label:
                  Text(_isProcessed ? 'Mark as Unprocessed' : 'Mark as Processed'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
