/// Rule editing screen -- F35 (Sprint 40)
///
/// Allows the user to edit an existing block rule by modifying its:
/// - Enabled / disabled state
/// - Execution order
/// - Action (delete, move to folder)
/// - Pattern -- either via plaintext-to-regex generation (reusing
///   [ManualRulePatternGenerator]) or by direct regex entry with validation
///   via [PatternCompiler] ReDoS checks.
/// - Pattern preview (shows the generated / validated regex)
///
/// The rule `name` field is the database primary key and is NOT exposed for
/// editing. All other user-visible metadata fields are editable.
///
/// On Save, calls [RuleDatabaseStore.updateRule] (same store the
/// [RulesManagementScreen] uses directly) and pops with `true` so the
/// caller knows to refresh its rule list.
///
/// Placement: navigated to via "Edit" [OutlinedButton.icon] in the
/// `_showRuleDetails` AlertDialog in [RulesManagementScreen].
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/models/rule_set.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/storage/rule_database_store.dart';
import '../../core/utils/manual_rule_pattern_generator.dart';
import '../utils/accessibility_helper.dart';
import 'manual_rule_create_screen.dart' show ManualRuleType;

/// Screen for editing an existing block rule.
class RuleEditScreen extends StatefulWidget {
  /// The rule to edit. Its [Rule.name] is the DB key and cannot be changed.
  final Rule rule;

  /// The database store to use for persisting the update. Passed in so the
  /// screen shares the same store instance as the caller (no second open).
  final RuleDatabaseStore store;

  const RuleEditScreen({
    super.key,
    required this.rule,
    required this.store,
  });

  @override
  State<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends State<RuleEditScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();

  // Pattern input mode
  bool _isDirectRegexMode = false;

  // Plaintext-mode fields (mirrors ManualRuleCreateScreen)
  final _inputController = TextEditingController();
  ManualRuleType _selectedType = ManualRuleType.entireDomain;
  String _generatedPattern = '';
  String _sourceDomain = '';
  String? _patternError;

  // Direct-regex mode field
  final _directRegexController = TextEditingController();
  String? _directRegexError;

  // Metadata fields
  late bool _enabled;
  late int _executionOrder;
  final _executionOrderController = TextEditingController();

  // Action fields
  late bool _actionDelete;
  late String? _actionMoveToFolder;
  final _folderController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromRule(widget.rule);
  }

  /// Pre-populate all editable fields from the existing rule.
  void _initFromRule(Rule rule) {
    _enabled = rule.enabled;
    _executionOrder = rule.executionOrder;
    _executionOrderController.text = rule.executionOrder.toString();

    _actionDelete = rule.actions.delete;
    _actionMoveToFolder = rule.actions.moveToFolder;
    _folderController.text = rule.actions.moveToFolder ?? '';

    // Determine the current pattern and mode.
    // The existing pattern is taken from the first available condition list,
    // preferring header (most common for block rules) then from/subject/body.
    final existingPattern = _firstPattern(rule);

    // Determine sub-type from patternSubType field (set at creation time).
    _selectedType = _subTypeToManualRuleType(rule.patternSubType);

    if (existingPattern != null) {
      // Start in plaintext mode only when the pattern matches what the
      // generator would produce for the stored source domain. For any other
      // pattern, start in direct-regex mode so the user edits it as-is.
      final sourceDomain = rule.sourceDomain;
      if (sourceDomain != null) {
        // Pre-fill the plaintext input with the source domain so the user
        // can regenerate or tweak from a known starting point.
        _inputController.text = sourceDomain;
        _generatePattern(); // updates _generatedPattern and _sourceDomain
        // If the regenerated pattern matches the stored pattern exactly,
        // stay in plaintext mode. Otherwise switch to direct-regex mode.
        if (_generatedPattern != existingPattern) {
          _isDirectRegexMode = true;
          _directRegexController.text = existingPattern;
          _validateDirectRegex(existingPattern);
        }
      } else {
        // No source domain -- go straight to direct-regex mode.
        _isDirectRegexMode = true;
        _directRegexController.text = existingPattern;
        _validateDirectRegex(existingPattern);
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _directRegexController.dispose();
    _executionOrderController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract the first pattern from any condition list.
  String? _firstPattern(Rule rule) {
    if (rule.conditions.header.isNotEmpty) return rule.conditions.header.first;
    if (rule.conditions.from.isNotEmpty) return rule.conditions.from.first;
    if (rule.conditions.subject.isNotEmpty) return rule.conditions.subject.first;
    if (rule.conditions.body.isNotEmpty) return rule.conditions.body.first;
    return null;
  }

  /// Map a DB `pattern_sub_type` string to the [ManualRuleType] enum.
  ManualRuleType _subTypeToManualRuleType(String? subType) {
    switch (subType) {
      case 'top_level_domain':
        return ManualRuleType.topLevelDomain;
      case 'exact_domain':
        return ManualRuleType.exactDomain;
      case 'exact_email':
        return ManualRuleType.exactEmail;
      case 'entire_domain':
      default:
        return ManualRuleType.entireDomain;
    }
  }

  /// Return the DB `pattern_sub_type` string for the current [_selectedType].
  String _manualRuleTypeToSubType(ManualRuleType type) {
    switch (type) {
      case ManualRuleType.topLevelDomain:
        return 'top_level_domain';
      case ManualRuleType.entireDomain:
        return 'entire_domain';
      case ManualRuleType.exactDomain:
        return 'exact_domain';
      case ManualRuleType.exactEmail:
        return 'exact_email';
    }
  }

  /// Determine the execution order from the selected sub-type.
  ///
  /// Mirrors the ordering from [ManualRuleCreateScreen._saveBlockRule] so
  /// that newly-edited rules keep consistent ordering semantics.
  int _defaultExecutionOrderForType(ManualRuleType type) {
    switch (type) {
      case ManualRuleType.topLevelDomain:
        return 10;
      case ManualRuleType.entireDomain:
        return 20;
      case ManualRuleType.exactDomain:
        return 30;
      case ManualRuleType.exactEmail:
        return 40;
    }
  }

  /// Available types for block rules (all four; safe senders are not editable here).
  List<ManualRuleType> get _availableTypes => ManualRuleType.values.toList();

  String get _inputHint {
    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        return 'Enter TLD (e.g., .cc, .xyz, .store)';
      case ManualRuleType.entireDomain:
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
      case ManualRuleType.exactDomain:
        return 'Examples: spam@example.com, example.com';
      case ManualRuleType.exactEmail:
        return 'Example: spam@example.com';
    }
  }

  // ---------------------------------------------------------------------------
  // Pattern generation (plaintext mode) -- mirrors ManualRuleCreateScreen
  // ---------------------------------------------------------------------------

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

    PatternGenerationResult result;
    switch (_selectedType) {
      case ManualRuleType.topLevelDomain:
        result = ManualRulePatternGenerator.generateTopLevelDomain(input);
        break;
      case ManualRuleType.entireDomain:
        result = ManualRulePatternGenerator.generateEntireDomain(input);
        break;
      case ManualRuleType.exactDomain:
        result = ManualRulePatternGenerator.generateExactDomain(input);
        break;
      case ManualRuleType.exactEmail:
        result = ManualRulePatternGenerator.generateExactEmail(input);
        break;
    }

    String pattern = result.pattern;
    String? error = result.error;

    String sourceDomain = '';
    if (result.isSuccess) {
      final cleaned = ManualRulePatternGenerator.extractDomainFromInput(input);
      switch (_selectedType) {
        case ManualRuleType.topLevelDomain:
          var tld = input.toLowerCase().trim();
          if (tld.startsWith('.')) tld = tld.substring(1);
          sourceDomain = '*.$tld';
          break;
        case ManualRuleType.entireDomain:
        case ManualRuleType.exactDomain:
          sourceDomain =
              cleaned.contains('@') ? cleaned.split('@').last : cleaned;
          break;
        case ManualRuleType.exactEmail:
          sourceDomain = cleaned;
          break;
      }
    }

    // ReDoS check
    if (pattern.isNotEmpty && error == null) {
      final redosWarnings = PatternCompiler.detectReDoS(pattern);
      if (redosWarnings.isNotEmpty) {
        error = 'Pattern rejected: ${redosWarnings.first}';
        pattern = '';
      }
    }

    // Compile check
    if (pattern.isNotEmpty && error == null) {
      try {
        RegExp(pattern, caseSensitive: false);
      } catch (e) {
        error = 'Invalid regex pattern: $e';
        pattern = '';
      }
    }

    setState(() {
      _generatedPattern = pattern;
      _sourceDomain = sourceDomain;
      _patternError = error;
    });
  }

  // ---------------------------------------------------------------------------
  // Pattern validation (direct-regex mode)
  // ---------------------------------------------------------------------------

  void _validateDirectRegex(String value) {
    if (value.trim().isEmpty) {
      setState(() => _directRegexError = null);
      return;
    }

    String? error;

    // ReDoS check
    final redosWarnings = PatternCompiler.detectReDoS(value.trim());
    if (redosWarnings.isNotEmpty) {
      error = 'Pattern rejected: ${redosWarnings.first}';
    }

    // Compile check
    if (error == null) {
      try {
        RegExp(value.trim(), caseSensitive: false);
      } catch (e) {
        error = 'Invalid regex: $e';
      }
    }

    setState(() => _directRegexError = error);
  }

  // ---------------------------------------------------------------------------
  // Effective pattern (whichever mode is active)
  // ---------------------------------------------------------------------------

  String get _effectivePattern {
    if (_isDirectRegexMode) return _directRegexController.text.trim();
    return _generatedPattern;
  }

  bool get _patternReady {
    if (_isDirectRegexMode) {
      return _directRegexController.text.trim().isNotEmpty &&
          _directRegexError == null;
    }
    return _generatedPattern.isNotEmpty && _patternError == null;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_patternReady) return;

    final pattern = _effectivePattern;
    if (pattern.isEmpty) return;

    // Parse execution order from the text field (user may have changed it).
    final parsedOrder =
        int.tryParse(_executionOrderController.text.trim()) ?? _executionOrder;

    // Determine the condition list to store the pattern in.
    // The original rule's patternCategory determines which condition bucket to
    // use. For the edit case we preserve the same bucket.
    final category = widget.rule.patternCategory ?? 'header_from';
    final RuleConditions conditions;
    switch (category) {
      case 'subject':
        conditions = RuleConditions(type: 'OR', subject: [pattern]);
        break;
      case 'body':
        conditions = RuleConditions(type: 'OR', body: [pattern]);
        break;
      case 'header_from':
      default:
        conditions = RuleConditions(type: 'OR', header: [pattern]);
        break;
    }

    // Determine action
    final String? folderName = _actionMoveToFolder;
    final RuleActions actions = RuleActions(
      delete: _actionDelete,
      moveToFolder: folderName,
    );

    // Source domain: use plaintext input if in plaintext mode, else keep original.
    final sourceDomain = _isDirectRegexMode
        ? widget.rule.sourceDomain
        : (_sourceDomain.isNotEmpty ? _sourceDomain : widget.rule.sourceDomain);

    final updatedRule = Rule(
      name: widget.rule.name, // PK -- never changed
      enabled: _enabled,
      isLocal: widget.rule.isLocal,
      executionOrder: parsedOrder,
      conditions: conditions,
      actions: actions,
      exceptions: widget.rule.exceptions,
      metadata: widget.rule.metadata,
      patternCategory: widget.rule.patternCategory,
      patternSubType: _isDirectRegexMode
          ? widget.rule.patternSubType
          : _manualRuleTypeToSubType(_selectedType),
      sourceDomain: sourceDomain,
    );

    setState(() => _isSaving = true);

    try {
      await widget.store.updateRule(updatedRule);
      _logger.i('Updated rule: ${widget.rule.name}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule updated')),
        );
        Navigator.of(context).pop(true); // true = caller should refresh
      }
    } catch (e) {
      _logger.e('Failed to update rule', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_userFriendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Map an exception to a user-facing message without leaking internal detail.
  String _userFriendlyError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('redos') || msg.contains('rejected')) {
      return 'Pattern rejected: it could cause performance issues.';
    }
    if (msg.contains('does not exist')) {
      return 'Rule no longer exists -- it may have been deleted.';
    }
    if (msg.contains('unique') || msg.contains('constraint')) {
      return 'A rule with this name already exists.';
    }
    return 'Could not save -- a database error occurred. See logs for details.';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Edit Rule'),
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
              // Read-only rule name banner
              _buildRuleNameBanner(),
              const SizedBox(height: 16),

              // Enabled toggle
              _buildEnabledToggle(),
              const SizedBox(height: 8),

              // Execution order
              _buildExecutionOrderField(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Action section
              _buildActionSection(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Pattern section
              _buildPatternSection(),
              const SizedBox(height: 24),

              // Save button
              Semantics(
                label: 'Save rule edits',
                child: FilledButton.icon(
                  key: const Key('rule_edit_save_button'),
                  onPressed: _isSaving || !_patternReady ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleNameBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rule (read-only ID)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            widget.rule.sourceDomain ?? widget.rule.name,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          if (widget.rule.sourceDomain != null) ...[
            const SizedBox(height: 2),
            SelectableText(
              widget.rule.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnabledToggle() {
    return SwitchListTile(
      title: const Text('Enabled'),
      subtitle: Text(_enabled ? 'Rule is active' : 'Rule is disabled'),
      value: _enabled,
      onChanged: (value) => setState(() => _enabled = value),
    );
  }

  Widget _buildExecutionOrderField() {
    return TextFormField(
      controller: _executionOrderController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Execution Order',
        helperText: 'Lower numbers run first (e.g., 10=TLD, 20=entire domain, 30=exact domain, 40=exact email)',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter an execution order';
        }
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < 0) {
          return 'Must be a non-negative integer';
        }
        return null;
      },
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Action', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioListTile<bool>(
          title: const Text('Delete'),
          subtitle: const Text('Move email to Trash'),
          value: true,
          groupValue: _actionDelete,
          onChanged: (value) {
            setState(() {
              _actionDelete = true;
              _actionMoveToFolder = null;
              _folderController.clear();
            });
          },
        ),
        RadioListTile<bool>(
          title: const Text('Move to Folder'),
          subtitle: const Text('Move email to a specific IMAP folder'),
          value: false,
          groupValue: _actionDelete,
          onChanged: (value) {
            setState(() {
              _actionDelete = false;
            });
          },
        ),
        if (!_actionDelete) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _folderController,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              hintText: 'e.g., Spam, Junk',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _actionMoveToFolder = value.trim().isEmpty ? null : value.trim();
              });
            },
            validator: (value) {
              if (!_actionDelete &&
                  (value == null || value.trim().isEmpty)) {
                return 'Please enter a folder name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPatternSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pattern', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // Mode toggle
        Row(
          children: [
            ChoiceChip(
              label: const Text('Guided (plaintext)'),
              selected: !_isDirectRegexMode,
              onSelected: (_) {
                setState(() {
                  _isDirectRegexMode = false;
                  _directRegexError = null;
                });
                if (_inputController.text.isNotEmpty) _generatePattern();
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Direct regex'),
              selected: _isDirectRegexMode,
              onSelected: (_) {
                setState(() {
                  _isDirectRegexMode = true;
                  // Pre-fill the direct-regex field with whatever is currently
                  // generated so the user can continue from there.
                  if (_directRegexController.text.isEmpty &&
                      _generatedPattern.isNotEmpty) {
                    _directRegexController.text = _generatedPattern;
                  }
                });
                _validateDirectRegex(_directRegexController.text);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_isDirectRegexMode) _buildPlaintextPatternSection(),
        if (_isDirectRegexMode) _buildDirectRegexSection(),
      ],
    );
  }

  Widget _buildPlaintextPatternSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rule type selector
        Text(
          'Rule Type',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
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
                    // Suggest the canonical execution order for this type.
                    _executionOrderController.text =
                        _defaultExecutionOrderForType(value).toString();
                  });
                  if (_inputController.text.isNotEmpty) _generatePattern();
                },
              ),
            )),

        const SizedBox(height: 8),

        // Input field
        Text(
          'Input',
          style: Theme.of(context).textTheme.titleSmall,
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
          _buildPatternPreview(
            pattern: _generatedPattern,
            error: _patternError,
            typeLabel: _selectedType.label,
            sourceDomain: _sourceDomain,
          ),
        ],
      ],
    );
  }

  Widget _buildDirectRegexSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _directRegexController,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Regex pattern',
            hintText: r'e.g., @(?:[a-z0-9-]+\.)*example\.com$',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _validateDirectRegex(value),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a regex pattern';
            }
            if (_directRegexError != null) return _directRegexError;
            return null;
          },
        ),
        if (_directRegexController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPatternPreview(
            pattern: _directRegexError == null
                ? _directRegexController.text.trim()
                : '',
            error: _directRegexError,
            typeLabel: 'Direct Regex',
            sourceDomain: null,
          ),
        ],
      ],
    );
  }

  Widget _buildPatternPreview({
    required String pattern,
    required String? error,
    required String typeLabel,
    required String? sourceDomain,
  }) {
    if (error != null) {
      return Container(
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
                error,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    if (pattern.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            pattern,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Type: $typeLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sourceDomain != null)
            Text(
              'Source: $sourceDomain',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

