import '../utils/pattern_normalization.dart';

/// Represents the safe senders whitelist
class SafeSenderList {
  final List<String> safeSenders;

  SafeSenderList({required this.safeSenders});

  /// Load from YAML-compatible map
  factory SafeSenderList.fromMap(Map<String, dynamic> map) {
    final senders = map['safe_senders'] as List? ?? [];
    return SafeSenderList(
      safeSenders: senders.map((s) => s.toString().toLowerCase().trim()).toList(),
    );
  }

  /// Convert to YAML-compatible map
  Map<String, dynamic> toMap() {
    return {
      'safe_senders': safeSenders,
    };
  }

  /// Check if email matches any safe sender pattern
  /// Uses PatternNormalization to handle plus-sign subaddressing
  bool isSafe(String email) {
    final normalized = PatternNormalization.normalizeFromHeader(email);
    return safeSenders.any((pattern) => _matchesPattern(normalized, pattern));
  }

  /// Check if email matches any safe sender pattern and return match info
  /// Returns a tuple of (pattern, patternType) or null if no match
  /// Uses PatternNormalization to handle plus-sign subaddressing
  ({String pattern, String patternType})? findMatch(String email) {
    final normalized = PatternNormalization.normalizeFromHeader(email);
    for (final pattern in safeSenders) {
      if (_matchesPattern(normalized, pattern)) {
        return (pattern: pattern, patternType: _determinePatternType(pattern));
      }
    }
    return null;
  }

  /// Determine the pattern type based on regex analysis
  String _determinePatternType(String pattern) {
    // Check for subdomain wildcard patterns (entire domain)
    // Patterns like: ^[^@\s]+@(?:[a-z0-9-]+\.)*domain\.com$
    if (pattern.contains(r'(?:') || pattern.contains(r'[a-z0-9-]+\.)*')) {
      return 'entire_domain';
    }

    // Check if pattern includes username part (exact email)
    // Patterns like: ^user@domain\.com$ or ^specific\.user@domain\.com$
    // Look for patterns that have content before @ that is not a wildcard
    if (pattern.startsWith('^') && pattern.contains('@')) {
      // Check if there is specific text before @ (not just wildcards)
      final beforeAt = pattern.substring(1).split('@')[0];
      // If it does not start with a wildcard pattern, it is an exact email
      if (!beforeAt.startsWith('[') && !beforeAt.startsWith('(') && beforeAt.isNotEmpty) {
        return 'exact_email';
      }
    }

    // Check for exact domain pattern (matches @domain.com without subdomains)
    // Patterns like: ^[^@\s]+@domain\.com$ or @domain\.com$
    if (pattern.contains('@') && !pattern.contains(r'(?:') && !pattern.contains(r'[a-z0-9-]+\.)*')) {
      return 'exact_domain';
    }

    // Default fallback
    return 'exact_domain';
  }

  /// Add a new safe sender pattern
  void add(String pattern) {
    final normalized = pattern.toLowerCase().trim();
    if (!safeSenders.contains(normalized)) {
      safeSenders.add(normalized);
      safeSenders.sort();
    }
  }

  /// Remove a safe sender pattern
  void remove(String pattern) {
    safeSenders.remove(pattern.toLowerCase().trim());
  }

  bool _matchesPattern(String email, String pattern) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      return regex.hasMatch(email);
    } catch (e) {
      // If pattern is not valid regex, treat as literal match
      return email == pattern;
    }
  }
}
