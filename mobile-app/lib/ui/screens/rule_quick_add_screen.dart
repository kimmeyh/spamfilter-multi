import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/rule_set.dart';
import '../../core/models/safe_sender_list.dart';
import '../../core/services/rule_conflict_detector.dart';
import '../../core/storage/rule_database_store.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/pattern_generation.dart';
import 'rule_test_screen.dart';

enum RuleActionType { delete, move }
enum ConditionBucket { fromHeader, subject, body, bodyUrl }

class RuleQuickAddScreen extends StatefulWidget {
  final EmailMessage email;
  final RuleDatabaseStore ruleStore;
  final SafeSenderDatabaseStore? safeSenderStore;

  const RuleQuickAddScreen({
    Key? key,
    required this.email,
    required this.ruleStore,
    this.safeSenderStore,
  }) : super(key: key);

  @override
  State<RuleQuickAddScreen> createState() => _RuleQuickAddScreenState();
}

class _RuleQuickAddScreenState extends State<RuleQuickAddScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _ruleNameController = TextEditingController();
  final _moveToFolderController = TextEditingController();
  final _fromPatternController = TextEditingController();
  final _subjectPatternController = TextEditingController();
  final _bodyPatternController = TextEditingController();
  final _bodyUrlPatternController = TextEditingController();

  final Map<ConditionBucket, bool> _selectedBuckets = {
    ConditionBucket.fromHeader: true,
    ConditionBucket.subject: false,
    ConditionBucket.body: false,
    ConditionBucket.bodyUrl: false,
  };

  String _conditionLogic = 'OR';
  RuleActionType _selectedAction = RuleActionType.delete;
  bool _isSaving = false;

  String _normalizedEmail = '';
  String _normalizedSubject = '';
  String _normalizedBody = '';
  List<String> _extractedUrls = [];

  @override
  void initState() {
    super.initState();
    _initializeFromEmail();
  }

  @override
  void dispose() {
    _ruleNameController.dispose();
    _moveToFolderController.dispose();
    _fromPatternController.dispose();
    _subjectPatternController.dispose();
    _bodyPatternController.dispose();
    _bodyUrlPatternController.dispose();
    super.dispose();
  }

  void _initializeFromEmail() {
    _normalizedEmail = PatternNormalization.normalizeFromHeader(widget.email.from);
    _normalizedSubject = PatternNormalization.normalizeSubject(widget.email.subject);
    _normalizedBody = PatternNormalization.normalizeBodyText(widget.email.body);
    _extractedUrls = PatternNormalization.extractUrls(widget.email.body);

    _ruleNameController.text = _generateRuleName();
    _fromPatternController.text = PatternGeneration.generateDomainPattern(_normalizedEmail);
    _moveToFolderController.text = 'Junk Email';
  }

  String _generateRuleName() {
    if (_normalizedEmail.isEmpty) return 'AutoDeleteRule';
    final atIndex = _normalizedEmail.lastIndexOf('@');
    if (atIndex < 0) return 'AutoDeleteRule';
    final domain = _normalizedEmail.substring(atIndex + 1);
    final parts = domain.split('.');
    final pascalCase = parts
        .map((part) => part.isNotEmpty ? '${part[0].toUpperCase()}${part.substring(1)}' : '')
        .join('');
    return 'AutoDelete$pascalCase';
  }

  bool _validatePattern(String pattern) {
    if (pattern.isEmpty) return true;
    try {
      RegExp(pattern, caseSensitive: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  TextEditingController _getControllerForBucket(ConditionBucket bucket) {
    switch (bucket) {
      case ConditionBucket.fromHeader:
        return _fromPatternController;
      case ConditionBucket.subject:
        return _subjectPatternController;
      case ConditionBucket.body:
        return _bodyPatternController;
      case ConditionBucket.bodyUrl:
        return _bodyUrlPatternController;
    }
  }

  String _getBucketLabel(ConditionBucket bucket) {
    switch (bucket) {
      case ConditionBucket.fromHeader:
        return 'From Header';
      case ConditionBucket.subject:
        return 'Subject';
      case ConditionBucket.body:
        return 'Body';
      case ConditionBucket.bodyUrl:
        return 'Body URL';
    }
  }

  String _getSuggestedPattern(ConditionBucket bucket) {
    switch (bucket) {
      case ConditionBucket.fromHeader:
        return PatternGeneration.generateDomainPattern(_normalizedEmail);
      case ConditionBucket.subject:
        return _normalizedSubject.isNotEmpty ? RegExp.escape(_normalizedSubject) : '';
      case ConditionBucket.body:
        return _normalizedBody.isNotEmpty
            ? RegExp.escape(_normalizedBody.substring(0, _normalizedBody.length > 50 ? 50 : _normalizedBody.length))
            : '';
      case ConditionBucket.bodyUrl:
        if (_extractedUrls.isNotEmpty) {
          final domain = PatternNormalization.extractDomain(_extractedUrls.first);
          return domain.isNotEmpty ? RegExp.escape(domain) : '';
        }
        return '';
    }
  }

  Future<int> _getNextExecutionOrder() async {
    try {
      final ruleSet = await widget.ruleStore.loadRules();
      if (ruleSet.rules.isEmpty) return 10;
      final maxOrder = ruleSet.rules.map((r) => r.executionOrder).reduce((a, b) => a > b ? a : b);
      return maxOrder + 10;
    } catch (e) {
      _logger.w('Failed to get next execution order: $e');
      return 10;
    }
  }

  /// Remove safe senders that would conflict with the new block rule
  /// Returns the number of safe senders removed
  Future<int> _removeConflictingSafeSenders() async {
    if (widget.safeSenderStore == null) return 0;

    try {
      final safeSenders = await widget.safeSenderStore!.loadSafeSenders();
      int removedCount = 0;

      for (final safeSender in safeSenders) {
        // Check if the safe sender pattern matches the email being blocked
        try {
          final regex = RegExp(safeSender.pattern, caseSensitive: false);
          if (regex.hasMatch(_normalizedEmail)) {
            _logger.i('Removing conflicting safe sender: ${safeSender.pattern}');
            await widget.safeSenderStore!.removeSafeSender(safeSender.pattern);
            removedCount++;
          }
        } catch (e) {
          // If pattern is not valid regex, check exact match
          if (safeSender.pattern.toLowerCase() == _normalizedEmail.toLowerCase()) {
            _logger.i('Removing conflicting safe sender (exact match): ${safeSender.pattern}');
            await widget.safeSenderStore!.removeSafeSender(safeSender.pattern);
            removedCount++;
          }
        }
      }

      if (removedCount > 0) {
        _logger.i('Removed $removedCount conflicting safe sender(s)');
      }

      return removedCount;
    } catch (e) {
      _logger.w('Failed to check/remove conflicting safe senders: $e');
      return 0;
    }
  }

  /// Build the Rule object from current form state
  Future<Rule> _buildRuleFromForm() async {
    final executionOrder = await _getNextExecutionOrder();
    final fromPatterns = _selectedBuckets[ConditionBucket.fromHeader]! && _fromPatternController.text.isNotEmpty
        ? [_fromPatternController.text]
        : <String>[];
    final subjectPatterns = _selectedBuckets[ConditionBucket.subject]! && _subjectPatternController.text.isNotEmpty
        ? [_subjectPatternController.text]
        : <String>[];
    final bodyPatterns = <String>[];
    if (_selectedBuckets[ConditionBucket.body]! && _bodyPatternController.text.isNotEmpty) {
      bodyPatterns.add(_bodyPatternController.text);
    }
    if (_selectedBuckets[ConditionBucket.bodyUrl]! && _bodyUrlPatternController.text.isNotEmpty) {
      bodyPatterns.add(_bodyUrlPatternController.text);
    }

    final conditions = RuleConditions(
      type: _conditionLogic,
      from: fromPatterns,
      header: <String>[],
      subject: subjectPatterns,
      body: bodyPatterns,
    );

    final actions = RuleActions(
      delete: _selectedAction == RuleActionType.delete,
      moveToFolder: _selectedAction == RuleActionType.move ? _moveToFolderController.text.trim() : null,
    );

    return Rule(
      name: _ruleNameController.text.trim(),
      enabled: true,
      isLocal: true,
      executionOrder: executionOrder,
      conditions: conditions,
      actions: actions,
      metadata: {
        'created_by': 'quick_add',
        'source_email_id': widget.email.id,
        'source_from': widget.email.from,
      },
    );
  }

  /// Check for rule conflicts before saving
  Future<List<RuleConflict>> _checkForConflicts(Rule newRule) async {
    try {
      final detector = RuleConflictDetector();
      final ruleSet = await widget.ruleStore.loadRules();

      // Load safe senders if store is available
      SafeSenderList safeSenderList;
      if (widget.safeSenderStore != null) {
        final safeSenders = await widget.safeSenderStore!.loadSafeSenders();
        safeSenderList = SafeSenderList(
          safeSenders: safeSenders.map((s) => s.pattern).toList(),
        );
      } else {
        safeSenderList = SafeSenderList(safeSenders: []);
      }

      return detector.detectConflicts(
        email: widget.email,
        newRule: newRule,
        ruleSet: ruleSet,
        safeSenderList: safeSenderList,
      );
    } catch (e) {
      _logger.w('Failed to check for rule conflicts: $e');
      return [];
    }
  }

  /// Show conflict warning dialog and return true if user wants to proceed
  Future<bool> _showConflictWarning(List<RuleConflict> conflicts) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Rule Conflict Detected'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The new rule may not take effect because existing rules '
                'or safe senders would match this email first:',
              ),
              const SizedBox(height: 16),
              ...conflicts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: c.isSafeSenderConflict
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              c.isSafeSenderConflict
                                  ? Icons.verified_user
                                  : Icons.rule,
                              size: 16,
                              color: c.isSafeSenderConflict
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.conflictingRuleName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    final hasSelectedBucket = _selectedBuckets.values.any((selected) => selected);
    if (!hasSelectedBucket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one condition bucket'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedAction == RuleActionType.move && _moveToFolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name for move action'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final rule = await _buildRuleFromForm();

      // [NEW] ISSUE #139: Check for rule conflicts before saving
      final conflicts = await _checkForConflicts(rule);
      if (conflicts.isNotEmpty && mounted) {
        final proceed = await _showConflictWarning(conflicts);
        if (!proceed) {
          setState(() => _isSaving = false);
          return;
        }
      }

      // Remove conflicting safe senders that match this email
      // This ensures the new block rule will take effect
      int removedSafeSenders = 0;
      if (widget.safeSenderStore != null) {
        removedSafeSenders = await _removeConflictingSafeSenders();
      }

      await widget.ruleStore.addRule(rule);
      _logger.i('Added rule: ${rule.name}');

      if (mounted) {
        final message = removedSafeSenders > 0
            ? 'Rule added. Removed $removedSafeSenders conflicting safe sender(s).'
            : 'Rule added successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _logger.e('Failed to add rule: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add rule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Auto-Delete Rule'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Test pattern against sample emails',
            onPressed: () {
              // Determine the active pattern and condition type
              String? pattern;
              String conditionType = 'from';
              if (_selectedBuckets[ConditionBucket.fromHeader] == true &&
                  _fromPatternController.text.isNotEmpty) {
                pattern = _fromPatternController.text;
                conditionType = 'header';
              } else if (_selectedBuckets[ConditionBucket.subject] == true &&
                  _subjectPatternController.text.isNotEmpty) {
                pattern = _subjectPatternController.text;
                conditionType = 'subject';
              } else if (_selectedBuckets[ConditionBucket.body] == true &&
                  _bodyPatternController.text.isNotEmpty) {
                pattern = _bodyPatternController.text;
                conditionType = 'body';
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RuleTestScreen(
                    initialPattern: pattern,
                    initialConditionType: conditionType,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmailContextCard(),
              const SizedBox(height: 24),
              _buildRuleNameField(),
              const SizedBox(height: 24),
              _buildConditionBuckets(),
              const SizedBox(height: 24),
              _buildConditionLogic(),
              const SizedBox(height: 24),
              _buildActionSelection(),
              const SizedBox(height: 24),
              _buildExecutionOrderField(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailContextCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email Context', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From', style: Theme.of(context).textTheme.labelSmall),
                      Text(_normalizedEmail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.subject, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subject', style: Theme.of(context).textTheme.labelSmall),
                      Text(widget.email.subject.isNotEmpty ? widget.email.subject : '(No subject)',
                          style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.description, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Body Preview', style: Theme.of(context).textTheme.labelSmall),
                      Text(
                          widget.email.body.isNotEmpty
                              ? widget.email.body.substring(0, widget.email.body.length > 100 ? 100 : widget.email.body.length)
                              : '(No body)',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Folder', style: Theme.of(context).textTheme.labelSmall),
                      Text(widget.email.folderName, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleNameField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rule Name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ruleNameController,
              decoration: const InputDecoration(
                hintText: 'Enter rule name',
                border: OutlineInputBorder(),
                helperText: 'Auto-generated from email, editable',
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a rule name' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionBuckets() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition Buckets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Select which email fields to match against', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 16),
            _buildConditionBucket(ConditionBucket.fromHeader, Icons.email, 'From Header', 'Pre-filled with sender email pattern'),
            const Divider(),
            _buildConditionBucket(ConditionBucket.subject, Icons.subject, 'Subject', 'Optional: match email subject'),
            const Divider(),
            _buildConditionBucket(ConditionBucket.body, Icons.description, 'Body', 'Optional: match email body text'),
            const Divider(),
            _buildConditionBucket(
              ConditionBucket.bodyUrl,
              Icons.link,
              'Body URL',
              _extractedUrls.isNotEmpty ? 'Optional: match URLs in body (${_extractedUrls.length} found)' : 'Optional: match URLs in body (none found)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionBucket(ConditionBucket bucket, IconData icon, String label, String description) {
    final isSelected = _selectedBuckets[bucket]!;
    return Row(
      children: [
        Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              _selectedBuckets[bucket] = value ?? false;
            });
          },
        ),
        Icon(icon, size: 20, color: isSelected ? Colors.blue : Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () {},
          tooltip: 'Edit pattern',
        ),
      ],
    );
  }

  Widget _buildConditionLogic() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition Logic', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('OR'),
              subtitle: const Text('Match if ANY condition matches'),
              value: 'OR',
              groupValue: _conditionLogic,
              onChanged: (String? value) {
                if (value != null) setState(() => _conditionLogic = value);
              },
            ),
            RadioListTile<String>(
              title: const Text('AND'),
              subtitle: const Text('Match only if ALL conditions match'),
              value: 'AND',
              groupValue: _conditionLogic,
              onChanged: (String? value) {
                if (value != null) setState(() => _conditionLogic = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<RuleActionType>(
              title: const Text('Delete'),
              subtitle: const Text('Permanently delete matching emails'),
              value: RuleActionType.delete,
              groupValue: _selectedAction,
              onChanged: (RuleActionType? value) {
                if (value != null) setState(() => _selectedAction = value);
              },
            ),
            RadioListTile<RuleActionType>(
              title: const Text('Move to Folder'),
              subtitle: const Text('Move matching emails to specified folder'),
              value: RuleActionType.move,
              groupValue: _selectedAction,
              onChanged: (RuleActionType? value) {
                if (value != null) setState(() => _selectedAction = value);
              },
            ),
            if (_selectedAction == RuleActionType.move) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _moveToFolderController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  hintText: 'e.g., Junk Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                validator: (value) =>
                    _selectedAction == RuleActionType.move && (value == null || value.trim().isEmpty) ? 'Please enter a folder name' : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionOrderField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Execution Order', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Auto-assigned',
                border: OutlineInputBorder(),
                helperText: 'Rules execute in ascending order (10, 20, 30...)',
                enabled: false,
              ),
              controller: TextEditingController(text: 'Auto'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isValid = _ruleNameController.text.isNotEmpty && !_isSaving;
    return Row(
      children: [
        Expanded(child: OutlinedButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('Cancel'))),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: isValid ? _saveRule : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Text('Save Rule'),
          ),
        ),
      ],
    );
  }
}
