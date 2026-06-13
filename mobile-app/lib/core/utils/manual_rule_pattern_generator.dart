/// Pattern generation utility for manual rule creation (F56) and rule testing (F25).
///
/// Extracted from `_ManualRuleCreateScreenState._generatePattern()` so that
/// both `ManualRuleCreateScreen` and `RuleTestScreen` (and future F35 rule
/// editing) share a single source of truth for plaintext-to-regex conversion.
///
/// Supports four pattern types matching the `ManualRuleType` enum:
/// - Top-level domain (TLD): user enters `.cc` -> `@.*\.cc$`
/// - Entire domain: user enters domain/email/URL -> `@(?:[a-z0-9-]+\.)*domain\.com$`
/// - Exact domain: user enters domain/email -> `@domain\.com$`
/// - Exact email: user enters email -> `^user@domain\.com$`
///
/// Auto-detection (`generateFromPlaintext`) infers the type from input shape
/// without requiring the user to select a type first. This is the entry point
/// for Sub-feature 2 of F25 (plain text auto-regex in RuleTestScreen).
library;

import 'domain_validation.dart';

/// Result of a pattern generation call.
///
/// Either holds a valid [pattern] string or a human-readable [error] message;
/// never both.
class PatternGenerationResult {
  /// The generated regex pattern. Empty string if generation failed.
  final String pattern;

  /// Detected or requested pattern type label (e.g., "Entire Domain").
  final String typeLabel;

  /// Human-readable error message. Null if generation succeeded.
  final String? error;

  const PatternGenerationResult._({
    required this.pattern,
    required this.typeLabel,
    this.error,
  });

  /// Whether the result represents a successfully generated pattern.
  bool get isSuccess => error == null && pattern.isNotEmpty;

  factory PatternGenerationResult.success({
    required String pattern,
    required String typeLabel,
  }) =>
      PatternGenerationResult._(pattern: pattern, typeLabel: typeLabel);

  factory PatternGenerationResult.failure({
    required String typeLabel,
    required String error,
  }) =>
      PatternGenerationResult._(
        pattern: '',
        typeLabel: typeLabel,
        error: error,
      );
}

/// Plaintext-to-regex generator for email spam filter rules.
///
/// All methods are static. No instances needed.
class ManualRulePatternGenerator {
  ManualRulePatternGenerator._();

  // ---------------------------------------------------------------------------
  // Explicit type generators (called when user has selected a type)
  // ---------------------------------------------------------------------------

  /// Generate a TLD (top-level domain) block pattern.
  ///
  /// [input] may include a leading dot (e.g., `.cc`) or not (e.g., `cc`).
  ///
  /// Returns `PatternGenerationResult.success` with pattern like `@.*\.cc$`,
  /// or `PatternGenerationResult.failure` with a validation error.
  static PatternGenerationResult generateTopLevelDomain(String input) {
    const typeLabel = 'Top-Level Domain';
    var tld = input.toLowerCase().trim();
    if (tld.startsWith('.')) tld = tld.substring(1);
    final tldError = DomainValidation.validateTld(tld);
    if (tldError != null) {
      return PatternGenerationResult.failure(
          typeLabel: typeLabel, error: tldError);
    }
    return PatternGenerationResult.success(
      pattern: '@.*\\.$tld\$',
      typeLabel: typeLabel,
    );
  }

  /// Generate an entire-domain block pattern (domain + all subdomains).
  ///
  /// [input] may be a plain domain, an email address, or a URL.
  ///
  /// Returns a pattern like `@(?:[a-z0-9-]+\.)*example\.com$`.
  static PatternGenerationResult generateEntireDomain(String input) {
    const typeLabel = 'Entire Domain';
    final cleaned = _extractDomainFromInput(input);
    final domain =
        cleaned.contains('@') ? cleaned.split('@').last : cleaned;
    final domainError = DomainValidation.validateDomain(domain);
    if (domainError != null) {
      return PatternGenerationResult.failure(
          typeLabel: typeLabel, error: domainError);
    }
    final escapedDomain = RegExp.escape(domain);
    return PatternGenerationResult.success(
      pattern: '@(?:[a-z0-9-]+\\.)*$escapedDomain\$',
      typeLabel: typeLabel,
    );
  }

  /// Generate an exact-domain block pattern (only the bare domain, no subs).
  ///
  /// [input] may be a plain domain or an email address.
  ///
  /// Returns a pattern like `@example\.com$`.
  static PatternGenerationResult generateExactDomain(String input) {
    const typeLabel = 'Exact Domain';
    final cleaned = _extractDomainFromInput(input);
    final domain =
        cleaned.contains('@') ? cleaned.split('@').last : cleaned;
    final domainError = DomainValidation.validateDomain(domain);
    if (domainError != null) {
      return PatternGenerationResult.failure(
          typeLabel: typeLabel, error: domainError);
    }
    final escapedDomain = RegExp.escape(domain);
    return PatternGenerationResult.success(
      pattern: '@$escapedDomain\$',
      typeLabel: typeLabel,
    );
  }

  /// Generate an exact-email block pattern (one specific address).
  ///
  /// [input] must be a fully-qualified email address.
  ///
  /// Returns a pattern like `^user@example\.com$`.
  static PatternGenerationResult generateExactEmail(String input) {
    const typeLabel = 'Exact Email';
    final cleaned = _extractDomainFromInput(input);
    final emailError = DomainValidation.validateEmail(cleaned);
    if (emailError != null) {
      return PatternGenerationResult.failure(
          typeLabel: typeLabel, error: emailError);
    }
    final escaped = RegExp.escape(cleaned);
    return PatternGenerationResult.success(
      pattern: '^$escaped\$',
      typeLabel: typeLabel,
    );
  }

  // ---------------------------------------------------------------------------
  // Auto-detection (Sub-feature 2: plain-text -> regex in RuleTestScreen)
  // ---------------------------------------------------------------------------

  /// Auto-detect the input type and generate the best-fit regex pattern.
  ///
  /// Detection rules (applied in order):
  /// 1. If [input] starts with `.` and has no `@`, treat as TLD.
  /// 2. If [input] contains `@`, treat as exact email.
  /// 3. If [input] starts with `http://` or `https://`, strip protocol and
  ///    treat as entire domain.
  /// 4. Otherwise, if it looks like a bare TLD (single label, no dots beyond
  ///    the leading dot already stripped), treat as TLD; else entire domain.
  ///
  /// Returns a `PatternGenerationResult` with the detected type embedded.
  static PatternGenerationResult generateFromPlaintext(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return PatternGenerationResult.failure(
          typeLabel: 'Unknown', error: 'Input is empty');
    }

    // Rule 1: leading dot with no @ -> TLD
    if (trimmed.startsWith('.') && !trimmed.contains('@')) {
      return generateTopLevelDomain(trimmed);
    }

    // Rule 2: contains @ -> treat as exact email (also handles email@domain)
    if (trimmed.contains('@')) {
      return generateExactEmail(trimmed);
    }

    // Rule 3: URL with protocol -> strip and treat as entire domain
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return generateEntireDomain(trimmed);
    }

    // Rule 4: single label (no dots) -> treat as TLD; otherwise entire domain
    if (!trimmed.contains('.')) {
      // Bare word with no dot -- try TLD first
      return generateTopLevelDomain(trimmed);
    }

    // Default: entire domain
    return generateEntireDomain(trimmed);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Strip protocol, path, port from a URL or email to isolate the host/domain.
  ///
  /// Mirrors `_ManualRuleCreateScreenState._extractDomainFromInput` exactly
  /// so that ManualRuleCreateScreen can delegate to this static version.
  static String _extractDomainFromInput(String input) {
    var cleaned = input.trim().toLowerCase();

    // Remove protocol if present
    if (cleaned.startsWith('http://')) cleaned = cleaned.substring(7);
    if (cleaned.startsWith('https://')) cleaned = cleaned.substring(8);

    // Remove path, query string, fragment
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex > 0) cleaned = cleaned.substring(0, slashIndex);

    // Remove port
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex > 0) cleaned = cleaned.substring(0, colonIndex);

    return cleaned;
  }

  /// Public exposure of the domain extraction helper for callers that need
  /// to parse input independently (e.g., ManualRuleCreateScreen).
  static String extractDomainFromInput(String input) =>
      _extractDomainFromInput(input);
}
