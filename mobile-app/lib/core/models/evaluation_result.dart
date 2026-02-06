/// Result of evaluating an email against rules
class EvaluationResult {
  final bool shouldDelete;
  final bool shouldMove;
  final String? targetFolder;
  final String matchedRule;
  final String matchedPattern;
  final bool isSafeSender;

  EvaluationResult({
    required this.shouldDelete,
    required this.shouldMove,
    this.targetFolder,
    required this.matchedRule,
    required this.matchedPattern,
    this.isSafeSender = false,
  });

  /// Create result for safe sender match
  factory EvaluationResult.safeSender(String pattern) {
    return EvaluationResult(
      shouldDelete: false,
      shouldMove: false,
      matchedRule: 'SafeSender',
      matchedPattern: pattern,
      isSafeSender: true,
    );
  }

  /// Create result for no match
  factory EvaluationResult.noMatch() {
    return EvaluationResult(
      shouldDelete: false,
      shouldMove: false,
      matchedRule: '',
      matchedPattern: '',
    );
  }

  @override
  String toString() {
    if (isSafeSender) {
      return 'Safe sender: $matchedPattern';
    }
    if (shouldDelete) {
      return 'Delete (Rule: $matchedRule, Pattern: $matchedPattern)';
    }
    if (shouldMove) {
      return 'Move to $targetFolder (Rule: $matchedRule, Pattern: $matchedPattern)';
    }
    return 'No action';
  }
}
