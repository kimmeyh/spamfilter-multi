/// Manual rule creation screen for adding block rules and safe sender rules
///
/// Sprint 34, F56: Provides a guided form for users to create rules by entering
/// an email address, domain, URL, or TLD. The screen auto-detects the input type
/// and generates the appropriate regex pattern.
///
/// Block rules (4 types, accessible from Manage Rules):
/// - Top-level domain: user enters TLD (e.g., .cc) -> @.*\.cc$
/// - Exact domain: user enters domain -> @domain\.com$
/// - Entire domain: user enters domain -> @(?:[a-z0-9-]+\.)*domain\.com$
/// - Exact email: user enters email -> ^user@domain\.com$
///
/// Safe sender rules (3 types, accessible from Manage Safe Senders):
/// - Exact domain, entire domain, exact email (no TLD for safe senders)
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/pattern_compiler.dart';
import '../../core/storage/database_helper.dart';
import '../../core/utils/domain_validation.dart';
import '../utils/accessibility_helper.dart';

/// Whether we are creating a block rule or a safe sender
enum ManualRuleMode { blockRule, safeSender }

/// The type of pattern the user wants to create
enum ManualRuleType {
  topLevelDomain('Top-Level Domain', 'Block all emails from a TLD (e.g., .cc, .xyz)'),
  entireDomain('Entire Domain', 'Block domain and all subdomains'),
  exactDomain('Exact Domain', 'Block only the exact domain'),
  exactEmail('Exact Email', 'Block a specific email address');

  final String label;
  final String description;
  const ManualRuleType(this.label, this.description);
}

class ManualRuleCreateScreen extends StatefulWidget {
  final ManualRuleMode mode;

  const ManualRuleCreateScreen({
    super.key,
    required this.mode,
  });

  @override
  State<ManualRuleCreateScreen> createState() => _ManualRuleCreateScreenState();
}

class _ManualRuleCreateScreenState extends State<ManualRuleCreateScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  ManualRuleType _selectedType = ManualRuleType.entireDomain;
  String _generatedPattern = '';
  String _sourceDomain = '';
  String? _patternError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // TLD type is not available for safe senders
    if (widget.mode == ManualRuleMode.safeSender) {
      _selectedType = ManualRuleType.entireDomain;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Available types based on mode
  List<ManualRuleType> get _availableTypes {
    if (widget.mode == ManualRuleMode.safeSender) {
      // No TLD for safe senders
      return [
        ManualRuleType.entireDomain,
        ManualRuleType.exactDomain,
        ManualRuleType.exactEmail,
      ];
    }
    return ManualRuleType.values.toList();
  }

  String get _screenTitle {
    return widget.mode == ManualRuleMode.blockRule
        ? 'Add Block Rule'
        : 'Add Safe Sender';
  }

  String get _inputHint {
    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        return 'Enter TLD (e.g., .cc, .xyz, .store)';
      case ManualRuleType.entireDomain:
        return 'Enter email, domain, or URL';
      case ManualRuleType.exactDomain:
        return 'Enter email, domain, or URL';
      case ManualRuleType.exactEmail:
        return 'Enter email address';
    }
  }

  String get _inputExample {
    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        return 'Examples: .cc, .xyz, .store, .ru';
      case ManualRuleType.entireDomain:
        return 'Examples: spam@example.com, example.com, https://example.com/page';
      case ManualRuleType.exactDomain:
        return 'Examples: spam@example.com, example.com';
      case ManualRuleType.exactEmail:
        return 'Example: spam@example.com';
    }
  }

  /// Parse input and extract domain/email based on what the user entered
  String _extractDomainFromInput(String input) {
    input = input.trim().toLowerCase();

    // Remove protocol if present
    if (input.startsWith('http://')) input = input.substring(7);
    if (input.startsWith('https://')) input = input.substring(8);

    // Remove path, query string, fragment
    final slashIndex = input.indexOf('/');
    if (slashIndex > 0) input = input.substring(0, slashIndex);

    // Remove port
    final colonIndex = input.indexOf(':');
    if (colonIndex > 0) input = input.substring(0, colonIndex);

    return input;
  }


  /// Generate the regex pattern from user input
  void _generatePattern() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _generatedPattern = '';
        _sourceDomain = '';
        _patternError = null;
      });
      return;
    }

    String pattern = '';
    String sourceDomain = '';
    String? error;

    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        // Strip leading dot if present
        var tld = input.toLowerCase().trim();
        if (tld.startsWith('.')) tld = tld.substring(1);
        final tldError = DomainValidation.validateTld(tld);
        if (tldError != null) {
          error = tldError;
          break;
        }
        pattern = '@.*\\.$tld\$';
        sourceDomain = '.*.$tld';
        break;

      case ManualRuleType.entireDomain:
        final cleaned = _extractDomainFromInput(input);
        // If it looks like an email, extract just the domain part
        String domain;
        if (cleaned.contains('@')) {
          domain = cleaned.split('@').last;
        } else {
          domain = cleaned;
        }
        final domainError = DomainValidation.validateDomain(domain);
        if (domainError != null) {
          error = domainError;
          break;
        }
        final escapedDomain = RegExp.escape(domain);
        pattern = '@(?:[a-z0-9-]+\\.)*$escapedDomain\$';
        sourceDomain = domain;
        break;

      case ManualRuleType.exactDomain:
        final cleaned = _extractDomainFromInput(input);
        String domain;
        if (cleaned.contains('@')) {
          domain = cleaned.split('@').last;
        } else {
          domain = cleaned;
        }
        final domainError = DomainValidation.validateDomain(domain);
        if (domainError != null) {
          error = domainError;
          break;
        }
        final escapedDomain = RegExp.escape(domain);
        pattern = '@$escapedDomain\$';
        sourceDomain = domain;
        break;

      case ManualRuleType.exactEmail:
        final cleaned = _extractDomainFromInput(input);
        final emailError = DomainValidation.validateEmail(cleaned);
        if (emailError != null) {
          error = emailError;
          break;
        }
        final escaped = RegExp.escape(cleaned);
        pattern = '^$escaped\$';
        sourceDomain = cleaned;
        break;
    }

    // Validate pattern with ReDoS check
    if (pattern.isNotEmpty && error == null) {
      final redosWarnings = PatternCompiler.detectReDoS(pattern);
      if (redosWarnings.isNotEmpty) {
        error = 'Pattern rejected: ${redosWarnings.first}';
      }
    }

    // Try to compile pattern
    if (pattern.isNotEmpty && error == null) {
      try {
        RegExp(pattern, caseSensitive: false);
      } catch (e) {
        error = 'Invalid regex pattern: $e';
      }
    }

    setState(() {
      _generatedPattern = pattern;
      _sourceDomain = sourceDomain;
      _patternError = error;
    });
  }

  /// Save the rule to the database
  Future<void> _saveRule() async {
    if (_generatedPattern.isEmpty || _patternError != null) return;

    setState(() => _isSaving = true);

    try {
      final dbHelper = DatabaseHelper();

      if (widget.mode == ManualRuleMode.blockRule) {
        await _saveBlockRule(dbHelper);
      } else {
        await _saveSafeSender(dbHelper);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mode == ManualRuleMode.blockRule
                ? 'Block rule created'
                : 'Safe sender added'),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      // Log full exception details for debugging; show user-friendly message
      // in the SnackBar to avoid leaking internal details (Copilot review
      // PR #236 finding -- April 2026).
      _logger.e('Failed to save rule', error: e);
      if (mounted) {
        final userMessage = _userFriendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Map an exception to a user-facing message that does not leak internal
  /// detail. Logs already capture the full exception via _logger.e.
  String _userFriendlyErrorMessage(Object error) {
    if (error is DatabaseException) {
      if (error.isUniqueConstraintError()) {
        return widget.mode == ManualRuleMode.blockRule
            ? 'A block rule with this pattern already exists.'
            : 'A safe sender with this pattern already exists.';
      }
      return 'Could not save -- a database error occurred. See logs for details.';
    }
    return 'Could not save. See logs for details.';
  }

  Future<void> _saveBlockRule(DatabaseHelper dbHelper) async {
    // Determine execution order based on type
    int executionOrder;
    String patternSubType;
    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        executionOrder = 10;
        patternSubType = 'top_level_domain';
        break;
      case ManualRuleType.entireDomain:
        executionOrder = 20;
        patternSubType = 'entire_domain';
        break;
      case ManualRuleType.exactDomain:
        executionOrder = 30;
        patternSubType = 'exact_domain';
        break;
      case ManualRuleType.exactEmail:
        executionOrder = 40;
        patternSubType = 'exact_email';
        break;
    }

    // Generate a unique name
    final name = 'manual_${_sourceDomain.replaceAll(RegExp(r'[^\w.-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';

    final db = await dbHelper.database;
    await db.insert('rules', {
      'name': name,
      'enabled': 1,
      'is_local': 1,
      'execution_order': executionOrder,
      'condition_type': 'OR',
      'condition_header': jsonEncode([_generatedPattern]),
      'action_delete': 1,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'manual',
      'pattern_category': 'header_from',
      'pattern_sub_type': patternSubType,
      'source_domain': _sourceDomain,
    });

    _logger.i('Created block rule: $name (pattern: $_generatedPattern)');
  }

  Future<void> _saveSafeSender(DatabaseHelper dbHelper) async {
    String patternType;
    switch (_selectedType) {
      case ManualRuleType.entireDomain:
        patternType = 'entire_domain';
        break;
      case ManualRuleType.exactDomain:
        patternType = 'exact_domain';
        break;
      case ManualRuleType.exactEmail:
        patternType = 'exact_email';
        break;
      case ManualRuleType.topLevelDomain:
        patternType = 'top_level_domain'; // Should not happen for safe senders
        break;
    }

    final db = await dbHelper.database;
    await db.insert('safe_senders', {
      'pattern': _generatedPattern,
      'pattern_type': patternType,
      'date_added': DateTime.now().millisecondsSinceEpoch,
      'created_by': 'manual',
    });

    _logger.i('Created safe sender: $_generatedPattern (type: $patternType)');
  }

  /// Show confirmation dialog before saving
  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    _generatePattern();
    if (_generatedPattern.isEmpty || _patternError != null) return;

    final actionLabel = widget.mode == ManualRuleMode.blockRule ? 'block' : 'allow';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${widget.mode == ManualRuleMode.blockRule ? "Block Rule" : "Safe Sender"}'),
        content: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will $actionLabel emails matching:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _generatedPattern,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Type: ${_selectedType.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Source: $_sourceDomain',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveRule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(_screenTitle),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: AccessibilityHelper.backLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SelectionArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Rule type selector
              Text(
                'Rule Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._availableTypes.map((type) => Semantics(
                    label: '${type.label}: ${type.description}',
                    child: RadioListTile<ManualRuleType>(
                      title: Text(type.label),
                      subtitle: Text(type.description),
                      value: type,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                          _generatedPattern = '';
                          _patternError = null;
                        });
                        if (_inputController.text.isNotEmpty) {
                          _generatePattern();
                        }
                      },
                    ),
                  )),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Input field
              Text(
                'Input',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _inputExample,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _inputController,
                decoration: InputDecoration(
                  labelText: _inputHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: _inputController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear input',
                          onPressed: () {
                            _inputController.clear();
                            setState(() {
                              _generatedPattern = '';
                              _sourceDomain = '';
                              _patternError = null;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _generatePattern(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a value';
                  }
                  return null;
                },
              ),

              // Pattern preview
              if (_generatedPattern.isNotEmpty || _patternError != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Generated Pattern',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_patternError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            _patternError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _generatedPattern,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type: ${_selectedType.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Source: $_sourceDomain',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // Save button
              Semantics(
                label: 'Save ${widget.mode == ManualRuleMode.blockRule ? "block rule" : "safe sender"}',
                child: FilledButton.icon(
                  onPressed: _isSaving ||
                          _generatedPattern.isEmpty ||
                          _patternError != null
                      ? null
                      : _confirmAndSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
