/// Domain, TLD, and email validators used by the manual rule creation UI (F56).
///
/// These validators reject malformed inputs before they reach the regex engine
/// or the database. Rules:
///
/// - Domain: per RFC 1035 / 1123 -- labels of [a-z0-9-] separated by dots,
///   no leading/trailing dots, no consecutive dots, no leading/trailing hyphens
///   in any label, must have a TLD label.
/// - TLD: a single label without dots, [a-z][a-z0-9-]*, 2-63 chars.
/// - Email: local@domain where local is [a-z0-9._%+-]+ and domain is valid.
///
/// All validators return null if input is valid, or a human-readable error
/// message if invalid. Inputs are expected to already be lowercased and
/// trimmed.
library;

class DomainValidation {
  /// Validate that a domain is well-formed per RFC 1035 / RFC 1123.
  static String? validateDomain(String domain) {
    if (domain.isEmpty) return 'Domain cannot be empty';
    if (domain.length > 253) return 'Domain too long (max 253 characters)';

    if (domain.startsWith('.')) return 'Domain cannot start with a dot';
    if (domain.endsWith('.')) return 'Domain cannot end with a dot';
    if (domain.contains('..')) return 'Domain cannot contain consecutive dots';

    if (!domain.contains('.')) {
      return 'Domain must include a TLD (e.g., example.com)';
    }

    final labels = domain.split('.');
    for (final label in labels) {
      if (label.isEmpty) return 'Domain has an empty label';
      if (label.length > 63) {
        return 'Domain label "$label" exceeds 63 characters';
      }
      if (label.startsWith('-')) {
        return 'Domain label cannot start with a hyphen';
      }
      if (label.endsWith('-')) return 'Domain label cannot end with a hyphen';
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(label)) {
        return 'Domain label "$label" contains invalid characters '
            '(only letters, digits, and hyphens allowed)';
      }
    }

    final tld = labels.last;
    if (tld.length < 2) {
      return 'TLD "$tld" too short (must be at least 2 chars)';
    }
    if (!RegExp(r'[a-z]').hasMatch(tld)) {
      return 'TLD "$tld" must contain at least one letter';
    }

    return null;
  }

  /// Validate a TLD value (without the leading dot).
  static String? validateTld(String tld) {
    if (tld.isEmpty) return 'TLD cannot be empty';
    if (tld.contains('.')) {
      return 'Enter a single TLD without dots (e.g., cc, xyz)';
    }
    if (tld.contains('@')) return 'TLD cannot contain @';
    if (tld.length < 2) return 'TLD too short (must be at least 2 chars)';
    if (tld.length > 63) return 'TLD too long (max 63 chars)';
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(tld)) {
      return 'TLD must start with a letter and contain only letters, digits, hyphens';
    }
    if (tld.startsWith('-') || tld.endsWith('-')) {
      return 'TLD cannot start or end with a hyphen';
    }
    return null;
  }

  /// Validate an email address.
  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Email cannot be empty';
    if (!email.contains('@')) return 'Email must contain @';

    final atCount = '@'.allMatches(email).length;
    if (atCount > 1) return 'Email must contain exactly one @';

    final parts = email.split('@');
    final local = parts[0];
    final domain = parts[1];

    if (local.isEmpty) return 'Email must have a username before @';
    if (local.length > 64) return 'Email username too long (max 64 characters)';

    if (!RegExp(r"^[a-z0-9._%+\-]+$").hasMatch(local)) {
      return 'Email username contains invalid characters';
    }

    final domainError = validateDomain(domain);
    if (domainError != null) return 'Domain part: $domainError';

    return null;
  }
}
