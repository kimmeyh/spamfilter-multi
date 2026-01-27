import 'package:logger/logger.dart';

/// Utility class for generating regex patterns for safe senders and rules.
///
/// Supports three pattern types:
/// - Type 1: Exact email match (case-insensitive)
/// - Type 2: Domain match (all emails from domain)
/// - Type 3: Subdomain match (domain and all subdomains)
class PatternGeneration {
  static final Logger _logger = Logger();

  /// Generates a Type 1 (exact email) safe sender pattern.
  ///
  /// Example:
  /// - Input: "user@example.com"
  /// - Output: "^user@example\\.com$"
  ///
  /// This pattern will match only "user@example.com" exactly.
  ///
  /// Returns empty string if email is null, empty, or invalid.
  static String generateExactEmailPattern(String? email) {
    if (email == null || email.isEmpty) {
      _logger.w('generateExactEmailPattern: email is null or empty');
      return '';
    }

    try {
      // Escape regex special characters in email
      final escaped = RegExp.escape(email);
      final pattern = '^$escaped\$';

      _logger.d('Generated exact email pattern: $pattern');
      return pattern;
    } catch (e) {
      _logger.w('Error generating exact email pattern: $e');
      return '';
    }
  }

  /// Generates a Type 2 (domain) safe sender pattern.
  ///
  /// Example:
  /// - Input: "user@example.com"
  /// - Output: "@example\\.com\$"
  ///
  /// This pattern will match any email from example.com:
  /// - user@example.com ✓
  /// - admin@example.com ✓
  /// - user@subdomain.example.com ✗
  ///
  /// Returns empty string if email is null, empty, or invalid.
  static String generateDomainPattern(String? email) {
    if (email == null || email.isEmpty) {
      _logger.w('generateDomainPattern: email is null or empty');
      return '';
    }

    try {
      // Extract domain from email
      final atIndex = email.lastIndexOf('@');
      if (atIndex < 0) {
        _logger.w('generateDomainPattern: email does not contain @');
        return '';
      }

      final domain = email.substring(atIndex);
      final escaped = RegExp.escape(domain);
      final pattern = '$escaped\$';

      _logger.d('Generated domain pattern: $pattern');
      return pattern;
    } catch (e) {
      _logger.w('Error generating domain pattern: $e');
      return '';
    }
  }

  /// Generates a Type 3 (subdomain) safe sender pattern.
  ///
  /// Example:
  /// - Input: "user@example.com"
  /// - Output: "@(?:[a-z0-9-]+\\.)*example\\.com\$"
  ///
  /// This pattern will match emails from example.com and any subdomain:
  /// - user@example.com ✓
  /// - user@mail.example.com ✓
  /// - user@subdomain.mail.example.com ✓
  ///
  /// Returns empty string if email is null, empty, or invalid.
  static String generateSubdomainPattern(String? email) {
    if (email == null || email.isEmpty) {
      _logger.w('generateSubdomainPattern: email is null or empty');
      return '';
    }

    try {
      // Extract domain from email
      final atIndex = email.lastIndexOf('@');
      if (atIndex < 0) {
        _logger.w('generateSubdomainPattern: email does not contain @');
        return '';
      }

      final domain = email.substring(atIndex + 1); // Remove @
      final escapedDomain = RegExp.escape(domain);

      // Build pattern: @(?:[a-z0-9-]+\.)*domain\.com$
      final pattern = '@(?:[a-z0-9-]+\\.)*$escapedDomain\$';

      _logger.d('Generated subdomain pattern: $pattern');
      return pattern;
    } catch (e) {
      _logger.w('Error generating subdomain pattern: $e');
      return '';
    }
  }

  /// Detects pattern type based on pattern content.
  ///
  /// Returns:
  /// - 1: Exact email (starts with ^ and ends with $ and contains @)
  /// - 2: Domain (contains @ but NOT @(?:) and doesn't start with ^)
  /// - 3: Subdomain (contains @(?:[a-z0-9-]+\.)*)
  /// - 0: Unknown/custom pattern
  static int detectPatternType(String? pattern) {
    if (pattern == null || pattern.isEmpty) {
      return 0;
    }

    try {
      if (pattern.contains('@(?:[a-z0-9-]+\\.)*')) {
        return 3; // Subdomain pattern
      } else if (pattern.startsWith('^') && pattern.endsWith('\$') && pattern.contains('@')) {
        return 1; // Exact email pattern (anchored with @ symbol)
      } else if (pattern.contains('@') && !pattern.startsWith('^')) {
        return 2; // Domain pattern (not anchored at start)
      }

      return 0; // Unknown/custom
    } catch (e) {
      _logger.w('Error detecting pattern type: $e');
      return 0;
    }
  }
}
