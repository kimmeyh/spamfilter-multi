import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import '../../core/utils/pattern_normalization.dart';

/// Screen for testing rule patterns against sample emails.
///
/// Users can enter a regex pattern, select a condition type (from, subject,
/// body, header), and see which sample emails from recent scans would match.
/// Accessible from Rule Quick Add and Manage Rules screens.
class RuleTestScreen extends StatefulWidget {
  /// Optional pre-filled pattern to test.
  final String? initialPattern;

  /// Optional pre-selected condition type ('from', 'subject', 'body', 'header').
  final String? initialConditionType;

  const RuleTestScreen({
    super.key,
    this.initialPattern,
    this.initialConditionType,
  });

  @override
  State<RuleTestScreen> createState() => _RuleTestScreenState();
}

class _RuleTestScreenState extends State<RuleTestScreen> {
  final Logger _logger = Logger();
  final TextEditingController _patternController = TextEditingController();
  final PatternCompiler _compiler = PatternCompiler();

  String _conditionType = 'from';
  bool _isLoading = true;
  List<_TestableEmail> _sampleEmails = [];
  List<_TestResult> _testResults = [];
  String? _patternError;
  bool _hasTestedOnce = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPattern != null) {
      _patternController.text = widget.initialPattern!;
    }
    if (widget.initialConditionType != null) {
      _conditionType = widget.initialConditionType!;
    }
    _loadSampleEmails();
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _loadSampleEmails() async {
    setState(() => _isLoading = true);
    try {
      final databaseHelper = DatabaseHelper();
      final scanResultStore = ScanResultStore(databaseHelper);
      final unmatchedEmailStore = UnmatchedEmailStore(databaseHelper);

      // Get most recent scan results
      final recentScans = await scanResultStore.getAllScanHistory(limit: 3);
      final emails = <_TestableEmail>[];

      for (final scan in recentScans) {
        final unmatched = await unmatchedEmailStore.getUnmatchedEmailsByScan(
          scan.id!,
        );
        for (final ue in unmatched) {
          emails.add(_TestableEmail(
            from: ue.fromEmail,
            subject: ue.subject ?? '(No subject)',
            bodyPreview: ue.bodyPreview ?? '',
            folderName: ue.folderName,
            emailDate: ue.emailDate,
          ));
        }
      }

      // Deduplicate by from+subject and limit to 50 most recent
      final seen = <String>{};
      final deduplicated = <_TestableEmail>[];
      for (final email in emails) {
        final key = '${email.from}|${email.subject}';
        if (!seen.contains(key)) {
          seen.add(key);
          deduplicated.add(email);
        }
        if (deduplicated.length >= 50) break;
      }

      if (mounted) {
        setState(() {
          _sampleEmails = deduplicated;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to load sample emails: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _runTest() {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      setState(() {
        _patternError = 'Enter a pattern to test';
        _testResults = [];
      });
      return;
    }

    // Validate pattern
    final warnings = _compiler.validatePattern(pattern);
    try {
      RegExp(pattern, caseSensitive: false);
    } catch (e) {
      setState(() {
        _patternError = 'Invalid regex: ${e.toString().replaceAll('FormatException: ', '')}';
        _testResults = [];
      });
      return;
    }

    setState(() {
      _patternError = warnings.isNotEmpty ? warnings.first : null;
      _hasTestedOnce = true;
    });

    final regex = _compiler.compile(pattern);
    final results = <_TestResult>[];

    for (final email in _sampleEmails) {
      final testValue = _getTestValue(email);
      final normalized = _normalizeForType(testValue);
      final match = regex.firstMatch(normalized);

      if (match != null) {
        results.add(_TestResult(
          email: email,
          matched: true,
          matchedText: match.group(0) ?? '',
          fieldTested: _conditionType,
          fullValue: normalized,
        ));
      }
    }

    // Sort: matches first
    setState(() => _testResults = results);
  }

  String _getTestValue(_TestableEmail email) {
    switch (_conditionType) {
      case 'from':
        return email.from;
      case 'subject':
        return email.subject;
      case 'body':
        return email.bodyPreview;
      case 'header':
        return email.from; // Header patterns match from address
      default:
        return email.from;
    }
  }

  String _normalizeForType(String value) {
    switch (_conditionType) {
      case 'subject':
        return PatternNormalization.normalizeSubject(value);
      case 'body':
        return PatternNormalization.normalizeBodyText(value);
      default:
        return value.toLowerCase().trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Rule Pattern'),
      ),
      body: Column(
        children: [
          // Pattern input area
          _buildPatternInput(),
          const Divider(height: 1),
          // Results area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition type selector
          const Text('Match against: ', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'from', label: Text('From')),
              ButtonSegment(value: 'subject', label: Text('Subject')),
              ButtonSegment(value: 'body', label: Text('Body')),
              ButtonSegment(value: 'header', label: Text('Header')),
            ],
            selected: {_conditionType},
            onSelectionChanged: (selection) {
              setState(() {
                _conditionType = selection.first;
                if (_hasTestedOnce) _runTest();
              });
            },
          ),
          const SizedBox(height: 12),
          // Pattern text field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _patternController,
                  decoration: InputDecoration(
                    labelText: 'Regex pattern',
                    hintText: _getHintForType(),
                    border: const OutlineInputBorder(),
                    errorText: _patternError,
                    suffixIcon: _patternController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _patternController.clear();
                              setState(() {
                                _testResults = [];
                                _patternError = null;
                                _hasTestedOnce = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _runTest(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _runTest,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test'),
              ),
            ],
          ),
          if (_hasTestedOnce) ...[
            const SizedBox(height: 8),
            Text(
              '${_testResults.length} of ${_sampleEmails.length} emails match',
              style: TextStyle(
                color: _testResults.isEmpty ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getHintForType() {
    switch (_conditionType) {
      case 'from':
        return r'@(?:[a-z0-9-]+\.)*spam\.com$';
      case 'subject':
        return r'(?:verify|confirm).*account';
      case 'body':
        return r'(?:click|tap).*(?:here|link)';
      case 'header':
        return r'@spam\.com$';
      default:
        return 'Enter regex pattern';
    }
  }

  Widget _buildResults() {
    if (!_hasTestedOnce && _sampleEmails.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No sample emails available.\n\n'
            'Run a scan first to load emails for testing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (!_hasTestedOnce) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Enter a pattern and press Test to see which of '
                '${_sampleEmails.length} sample emails match.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_testResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No matches found in ${_sampleEmails.length} sample emails.\n\n'
                'Try a broader pattern or different condition type.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _testResults.length,
      itemBuilder: (context, index) {
        final result = _testResults[index];
        return _buildResultTile(result);
      },
    );
  }

  Widget _buildResultTile(_TestResult result) {
    final email = result.email;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email info
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email.from,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Subject
            Text(
              email.subject,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Match info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Matched ${result.fieldTested}: "${result.matchedText}"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue),
                  ),
                  if (result.fullValue.length <= 200) ...[
                    const SizedBox(height: 2),
                    _buildHighlightedText(result.fullValue, result.matchedText),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build text with the matched portion highlighted.
  Widget _buildHighlightedText(String fullText, String matchedText) {
    if (matchedText.isEmpty) {
      return Text(fullText, style: const TextStyle(fontSize: 10, color: Colors.grey));
    }

    final lowerFull = fullText.toLowerCase();
    final lowerMatch = matchedText.toLowerCase();
    final matchIndex = lowerFull.indexOf(lowerMatch);

    if (matchIndex < 0) {
      return Text(fullText, style: const TextStyle(fontSize: 10, color: Colors.grey));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, color: Colors.grey),
        children: [
          if (matchIndex > 0)
            TextSpan(text: fullText.substring(0, matchIndex)),
          TextSpan(
            text: fullText.substring(matchIndex, matchIndex + matchedText.length),
            style: const TextStyle(
              backgroundColor: Color(0x40FFC107),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (matchIndex + matchedText.length < fullText.length)
            TextSpan(text: fullText.substring(matchIndex + matchedText.length)),
        ],
      ),
    );
  }
}

/// Internal model for testable email data.
class _TestableEmail {
  final String from;
  final String subject;
  final String bodyPreview;
  final String folderName;
  final DateTime? emailDate;

  _TestableEmail({
    required this.from,
    required this.subject,
    required this.bodyPreview,
    required this.folderName,
    this.emailDate,
  });
}

/// Internal model for test results.
class _TestResult {
  final _TestableEmail email;
  final bool matched;
  final String matchedText;
  final String fieldTested;
  final String fullValue;

  _TestResult({
    required this.email,
    required this.matched,
    required this.matchedText,
    required this.fieldTested,
    required this.fullValue,
  });
}
