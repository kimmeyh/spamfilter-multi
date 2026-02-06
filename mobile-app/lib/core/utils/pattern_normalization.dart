import 'package:logger/logger.dart';

/// Utility class for normalizing email, subject, and body text for pattern matching.
/// All normalization follows the principle of lowercase conversion and removal of
/// special characters that do not affect pattern matching logic.
class PatternNormalization {
  static final Logger _logger = Logger();

  /// Normalizes an email address from a "Name <email@domain.com>" format to lowercase.
  ///
  /// Handles three input formats:
  /// - "user@example.com" → "user@example.com"
  /// - "Name <user@example.com>" → "user@example.com"
  /// - "user@example.com (Name)" → "user@example.com"
  ///
  /// Keeps characters: [0-9a-z@._+-]
  /// Removes: spaces, parentheses, angle brackets
  ///
  /// Returns empty string if input is null or empty.
  static String normalizeFromHeader(String? email) {
    if (email == null || email.isEmpty) {
      return '';
    }

    try {
      String result = email.toLowerCase().trim();

      // Extract email from "Name <email@domain.com>" format
      if (result.contains('<') && result.contains('>')) {
        final startIndex = result.indexOf('<');
        final endIndex = result.indexOf('>');
        if (startIndex < endIndex) {
          result = result.substring(startIndex + 1, endIndex);
        }
      }

      // Remove (Name) format at end
      if (result.contains('(')) {
        result = result.substring(0, result.indexOf('(')).trim();
      }

      // Keep only alphanumeric, @, ., _, +, -
      result = result.replaceAll(RegExp(r'[^0-9a-z@._+-]'), '');

      return result;
    } catch (e) {
      _logger.w('Error normalizing email header: $e');
      return '';
    }
  }

  /// Normalizes a subject line for pattern matching.
  ///
  /// Operations:
  /// - Convert to lowercase
  /// - Collapse multiple spaces to single space
  /// - Trim whitespace
  ///
  /// Preserves: letters, numbers, spaces, punctuation (.,!?:-'")
  ///
  /// Returns empty string if input is null or empty.
  static String normalizeSubject(String? subject) {
    if (subject == null || subject.isEmpty) {
      return '';
    }

    try {
      String result = subject.toLowerCase().trim();

      // Collapse multiple spaces to single space
      result = result.replaceAll(RegExp(r'\s+'), ' ');

      return result;
    } catch (e) {
      _logger.w('Error normalizing subject: $e');
      return '';
    }
  }

  /// Normalizes email body text for pattern matching.
  ///
  /// Operations:
  /// - Convert to lowercase
  /// - Collapse multiple spaces to single space
  /// - Remove 3+ repeated characters (e.g., "!!!!" → "!")
  /// - Trim whitespace
  ///
  /// Returns empty string if input is null or empty.
  static String normalizeBodyText(String? body) {
    if (body == null || body.isEmpty) {
      return '';
    }

    try {
      String result = body.toLowerCase().trim();

      // Collapse multiple spaces to single space
      result = result.replaceAll(RegExp(r'\s+'), ' ');

      // Remove 3+ repeated characters (e.g., "!!!!" → "!")
      // Replace pattern like "!!!!" with just "!" by matching 3+ repeating chars
      final buffer = StringBuffer();
      int i = 0;
      while (i < result.length) {
        int j = i;
        // Count consecutive identical characters
        while (j < result.length && result[j] == result[i]) {
          j++;
        }
        // If 3 or more identical chars, keep only 1; otherwise keep all
        final count = j - i;
        if (count >= 3) {
          buffer.write(result[i]);
        } else {
          buffer.write(result.substring(i, j));
        }
        i = j;
      }

      return buffer.toString();
    } catch (e) {
      _logger.w('Error normalizing body text: $e');
      return '';
    }
  }

  /// Extracts URLs from text.
  ///
  /// Finds URLs matching:
  /// - http://...
  /// - https://...
  /// - www....
  ///
  /// Returns list of extracted URLs (lowercase), empty list if no URLs found or input is null.
  static List<String> extractUrls(String? text) {
    if (text == null || text.isEmpty) {
      return [];
    }

    try {
      final urls = <String>[];

      // Find http://, https://, and www. URLs
      final urlPattern = RegExp(
        r'(?:https?://|www\.)[^\s]+',
        caseSensitive: false,
      );

      final matches = urlPattern.allMatches(text.toLowerCase());
      for (final match in matches) {
        final url = match.group(0);
        if (url != null) {
          urls.add(url);
        }
      }

      if (urls.isNotEmpty) {
        _logger.d('Extracted ${urls.length} URLs from text');
      }

      return urls;
    } catch (e) {
      _logger.w('Error extracting URLs: $e');
      return [];
    }
  }

  /// Extracts the domain (hostname) from a URL.
  ///
  /// Examples:
  /// - "https://www.example.com/path" → "example.com"
  /// - "http://mail.google.com:8080/inbox" → "mail.google.com"
  /// - "www.spam.co.uk" → "spam.co.uk"
  ///
  /// Returns empty string if domain cannot be extracted or input is null.
  static String extractDomain(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    try {
      String domain = url.toLowerCase().trim();

      // Remove protocol (http://, https://)
      if (domain.startsWith('http://')) {
        domain = domain.substring(7);
      } else if (domain.startsWith('https://')) {
        domain = domain.substring(8);
      }

      // Remove www. prefix
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }

      // Remove path (everything after /)
      if (domain.contains('/')) {
        domain = domain.substring(0, domain.indexOf('/'));
      }

      // Remove port (everything after :)
      if (domain.contains(':')) {
        domain = domain.substring(0, domain.indexOf(':'));
      }

      // Remove query parameters (everything after ?)
      if (domain.contains('?')) {
        domain = domain.substring(0, domain.indexOf('?'));
      }

      // Keep only alphanumeric, dots, and hyphens
      domain = domain.replaceAll(RegExp(r'[^a-z0-9.-]'), '');

      return domain;
    } catch (e) {
      _logger.w('Error extracting domain: $e');
      return '';
    }
  }

  /// Cleans subject text for display purposes.
  ///
  /// Operations:
  /// - Replace tabs with single space
  /// - Trim leading/trailing whitespace
  /// - Collapse consecutive spaces to single space
  /// - Reduce repeated punctuation (e.g., "......" → ".")
  /// - Remove non-keyboard characters (keeps letters, numbers, common punctuation)
  ///
  /// Returns empty string if input is null or empty.
  static String cleanSubjectForDisplay(String? subject) {
    if (subject == null || subject.isEmpty) {
      return '';
    }

    try {
      String result = subject;

      // Replace tabs with single space
      result = result.replaceAll('\t', ' ');

      // Remove non-printable and non-keyboard characters
      // Keep: ASCII printable characters (space through ~) which includes:
      //   - Letters a-z, A-Z
      //   - Numbers 0-9
      //   - Common punctuation and symbols typically on keyboards
      // Remove: control characters, Unicode symbols (™, ®, ©, emoji, etc.)
      result = result.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

      // Collapse consecutive spaces to single space
      result = result.replaceAll(RegExp(r' {2,}'), ' ');

      // Reduce repeated punctuation to single (e.g., "..." → ".", "!!!" → "!")
      // Handle common punctuation marks
      result = result.replaceAll(RegExp(r'\.{2,}'), '.');
      result = result.replaceAll(RegExp(r'!{2,}'), '!');
      result = result.replaceAll(RegExp(r'\?{2,}'), '?');
      result = result.replaceAll(RegExp(r'-{2,}'), '-');
      result = result.replaceAll(RegExp(r'_{2,}'), '_');
      result = result.replaceAll(RegExp(r'\*{2,}'), '*');
      result = result.replaceAll(RegExp(r'#{2,}'), '#');
      result = result.replaceAll(RegExp(r'@{2,}'), '@');
      result = result.replaceAll(RegExp(r'\${2,}'), r'$');
      result = result.replaceAll(RegExp(r'%{2,}'), '%');
      result = result.replaceAll(RegExp(r'\^{2,}'), '^');
      result = result.replaceAll(RegExp(r'&{2,}'), '&');
      result = result.replaceAll(RegExp(r'\+{2,}'), '+');
      result = result.replaceAll(RegExp(r'={2,}'), '=');
      result = result.replaceAll(RegExp(r'~{2,}'), '~');
      result = result.replaceAll(RegExp(r'`{2,}'), '`');

      // Trim whitespace
      result = result.trim();

      return result;
    } catch (e) {
      _logger.w('Error cleaning subject for display: $e');
      return subject ?? '';
    }
  }
}
