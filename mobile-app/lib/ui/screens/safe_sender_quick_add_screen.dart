import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/storage/safe_sender_database_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/pattern_generation.dart';

/// Pattern type enumeration
enum PatternType {
  exactEmail,     // Type 1: ^user@domain\.com$
  domain,         // Type 2: @domain\.com$
  subdomain,      // Type 3: @(?:[a-z0-9-]+\.)*domain\.com$
  custom,         // Type 4: User-provided regex
}

/// [NEW] SPRINT 6 TASK B: Quick-add screen for safe sender patterns
class SafeSenderQuickAddScreen extends StatefulWidget {
  final EmailMessage email;
  final SafeSenderDatabaseStore safeSenderStore;

  const SafeSenderQuickAddScreen({
    Key? key,
    required this.email,
    required this.safeSenderStore,
  }) : super(key: key);

  @override
  State<SafeSenderQuickAddScreen> createState() => _SafeSenderQuickAddScreenState();
}

class _SafeSenderQuickAddScreenState extends State<SafeSenderQuickAddScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _customPatternController = TextEditingController();
  final _exceptionController = TextEditingController();

  PatternType _selectedType = PatternType.exactEmail;
  bool _showPatternPreview = false;
  bool _enableExceptions = false;
  List<String> _exceptionPatterns = [];
  bool _isSaving = false;
  String? _validationError;

  String _normalizedEmail = '';
  String _generatedPattern = '';

  @override
  void initState() {
    super.initState();
    _normalizedEmail = PatternNormalization.normalizeFromHeader(widget.email.from);
    _updateGeneratedPattern();
  }

  @override
  void dispose() {
    _customPatternController.dispose();
    _exceptionController.dispose();
    super.dispose();
  }

  /// Update generated pattern when type changes
  void _updateGeneratedPattern() {
    setState(() {
      switch (_selectedType) {
        case PatternType.exactEmail:
          _generatedPattern = PatternGeneration.generateExactEmailPattern(_normalizedEmail);
          break;
        case PatternType.domain:
          _generatedPattern = PatternGeneration.generateDomainPattern(_normalizedEmail);
          break;
        case PatternType.subdomain:
          _generatedPattern = PatternGeneration.generateSubdomainPattern(_normalizedEmail);
          break;
        case PatternType.custom:
          _generatedPattern = _customPatternController.text;
          break;
      }
      _validationError = null;
    });
  }

  /// Validate pattern is a valid regex
  bool _validatePattern(String pattern) {
    if (pattern.isEmpty) {
      _validationError = 'Pattern cannot be empty';
      return false;
    }

    try {
      RegExp(pattern, caseSensitive: false);
      _validationError = null;
      return true;
    } catch (e) {
      _validationError = 'Invalid regex pattern: $e';
      return false;
    }
  }

  /// Add exception pattern to list
  void _addException() {
    final exception = _exceptionController.text.trim();
    if (exception.isEmpty) return;

    if (_validatePattern(exception)) {
      setState(() {
        _exceptionPatterns.add(exception);
        _exceptionController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError ?? 'Invalid exception pattern'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Remove exception pattern from list
  void _removeException(int index) {
    setState(() {
      _exceptionPatterns.removeAt(index);
    });
  }

  /// Save safe sender pattern to database
  Future<void> _saveSafeSender() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate pattern
    if (!_validatePattern(_generatedPattern)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError ?? 'Invalid pattern'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final safeSender = SafeSenderPattern(
        pattern: _generatedPattern,
        patternType: _getPatternTypeString(),
        exceptionPatterns: _enableExceptions && _exceptionPatterns.isNotEmpty
            ? _exceptionPatterns
            : null,
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'quick_add',
      );

      await widget.safeSenderStore.addSafeSender(safeSender);

      _logger.i('Added safe sender pattern: $_generatedPattern');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safe sender added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      _logger.e('Failed to add safe sender: $e');

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add safe sender: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Convert PatternType enum to database string
  String _getPatternTypeString() {
    switch (_selectedType) {
      case PatternType.exactEmail:
        return 'email';
      case PatternType.domain:
        return 'domain';
      case PatternType.subdomain:
        return 'subdomain';
      case PatternType.custom:
        return 'custom';
    }
  }

  /// Get pattern type description
  String _getPatternTypeDescription(PatternType type) {
    switch (type) {
      case PatternType.exactEmail:
        return 'Match this exact email address only';
      case PatternType.domain:
        return 'Match all emails from this domain';
      case PatternType.subdomain:
        return 'Match domain and all subdomains';
      case PatternType.custom:
        return 'Provide your own regex pattern';
    }
  }

  /// Get example matches for pattern preview
  List<String> _getExampleMatches() {
    final domain = _normalizedEmail.contains('@')
        ? _normalizedEmail.substring(_normalizedEmail.indexOf('@') + 1)
        : '';

    switch (_selectedType) {
      case PatternType.exactEmail:
        return [
          'check_circle $_normalizedEmail',
          'cancel other@$domain',
        ];
      case PatternType.domain:
        return [
          'check_circle $_normalizedEmail',
          'check_circle user@$domain',
          'check_circle admin@$domain',
          'cancel user@mail.$domain',
        ];
      case PatternType.subdomain:
        return [
          'check_circle $_normalizedEmail',
          'check_circle user@$domain',
          'check_circle user@mail.$domain',
          'check_circle user@sub.mail.$domain',
        ];
      case PatternType.custom:
        return [
          'info Enter custom pattern to see examples',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Safe Sender - $_normalizedEmail'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email Context Card (Read-only)
              _buildEmailContextCard(),

              const SizedBox(height: 24),

              // Pattern Type Selection
              _buildPatternTypeSelection(),

              const SizedBox(height: 16),

              // Custom Pattern Field (only for Type 4)
              if (_selectedType == PatternType.custom) ...[
                _buildCustomPatternField(),
                const SizedBox(height: 16),
              ],

              // Pattern Preview (Expandable)
              _buildPatternPreview(),

              const SizedBox(height: 24),

              // Exception Denylist Toggle
              _buildExceptionToggle(),

              if (_enableExceptions) ...[
                const SizedBox(height: 16),
                _buildExceptionList(),
              ],

              const SizedBox(height: 32),

              // Save/Cancel Buttons
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
            Text(
              'Email Context',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // From
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        _normalizedEmail,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Subject
            Row(
              children: [
                const Icon(Icons.subject, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subject',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        widget.email.subject.isNotEmpty
                            ? widget.email.subject
                            : '(No subject)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Folder
            Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternTypeSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pattern Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ...PatternType.values.map((type) => RadioListTile<PatternType>(
              title: Text(_getPatternTypeLabel(type)),
              subtitle: Text(
                _getPatternTypeDescription(type),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              value: type,
              groupValue: _selectedType,
              onChanged: (PatternType? value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    _updateGeneratedPattern();
                  });
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  String _getPatternTypeLabel(PatternType type) {
    switch (type) {
      case PatternType.exactEmail:
        return 'Type 1: Exact Email';
      case PatternType.domain:
        return 'Type 2: Domain';
      case PatternType.subdomain:
        return 'Type 3: Domain + Subdomains';
      case PatternType.custom:
        return 'Type 4: Custom Pattern';
    }
  }

  Widget _buildCustomPatternField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Regex Pattern',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customPatternController,
              decoration: const InputDecoration(
                hintText: 'Enter regex pattern (e.g., ^user@.*\\.com\$)',
                border: OutlineInputBorder(),
                helperText: 'Case-insensitive regex matching',
              ),
              onChanged: (_) => _updateGeneratedPattern(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a custom pattern';
                }
                if (!_validatePattern(value)) {
                  return _validationError;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternPreview() {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Pattern Preview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          initiallyExpanded: _showPatternPreview,
          onExpansionChanged: (expanded) {
            setState(() => _showPatternPreview = expanded);
          },
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Generated Pattern
                  Text(
                    'Regex Pattern:',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _generatedPattern.isNotEmpty ? _generatedPattern : '(empty)',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Example Matches
                  Text(
                    'Example Matches:',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  ..._getExampleMatches().map((example) {
                    final isMatch = example.startsWith('check_circle');
                    final icon = isMatch ? Icons.check_circle : Icons.cancel;
                    final color = isMatch ? Colors.green : Colors.red;
                    final text = example.replaceFirst(
                      isMatch ? 'check_circle' : 'cancel',
                      '',
                    ).replaceFirst('info', '').trim();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Enable Exception Denylist'),
        subtitle: const Text(
          'Add patterns to exclude from safe sender matching',
        ),
        value: _enableExceptions,
        onChanged: (bool value) {
          setState(() => _enableExceptions = value);
        },
      ),
    );
  }

  Widget _buildExceptionList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exception Patterns',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Exception input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _exceptionController,
                    decoration: const InputDecoration(
                      hintText: 'Enter exception pattern',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addException(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _addException,
                  tooltip: 'Add exception',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Exception list
            if (_exceptionPatterns.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No exception patterns added',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ..._exceptionPatterns.asMap().entries.map((entry) {
                final index = entry.key;
                final pattern = entry.value;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.block, size: 20, color: Colors.red),
                  title: Text(
                    pattern,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _removeException(index),
                    tooltip: 'Remove exception',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isValid = _generatedPattern.isNotEmpty &&
                    _validatePattern(_generatedPattern) &&
                    !_isSaving;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: isValid ? _saveSafeSender : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save Safe Sender'),
          ),
        ),
      ],
    );
  }
}
