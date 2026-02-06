// Service for parsing email body content and extracting domains
//
// This service provides:
// - Domain extraction from HTML links (href attributes)
// - Domain extraction from plain text URLs
// - Pattern generation for domain-based rules

import 'package:logger/logger.dart';

/// Result of domain extraction from email body
class DomainExtractionResult {
  /// All unique domains found in the email body
  final List<String> domains;

  /// Map of domain to list of full URLs where it was found
  final Map<String, List<String>> domainUrls;

  /// Number of total URLs processed
  final int totalUrlsProcessed;

  const DomainExtractionResult({
    required this.domains,
    required this.domainUrls,
    required this.totalUrlsProcessed,
  });

  /// Empty result for emails with no URLs
  static const empty = DomainExtractionResult(
    domains: [],
    domainUrls: {},
    totalUrlsProcessed: 0,
  );
}

/// Service for parsing email body content
class EmailBodyParser {
  final Logger _logger = Logger();

  // Regex patterns for URL extraction
  static final RegExp _hrefPattern = RegExp(
    r'''href\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _plainUrlPattern = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );

  // Pattern to extract domain from URL
  static final RegExp _domainPattern = RegExp(
    r'^https?://(?:www\.)?([^/:?#]+)',
    caseSensitive: false,
  );

  /// Extract all unique domains from email body
  ///
  /// Parses both HTML content (href attributes) and plain text URLs
  /// Returns [DomainExtractionResult] with unique domains and their source URLs
  DomainExtractionResult extractDomains(String? bodyHtml, String? bodyText) {
    final allUrls = <String>{};
    final domainUrls = <String, List<String>>{};

    // Extract URLs from HTML href attributes
    if (bodyHtml != null && bodyHtml.isNotEmpty) {
      final hrefMatches = _hrefPattern.allMatches(bodyHtml);
      for (final match in hrefMatches) {
        final url = match.group(1);
        if (url != null && _isValidHttpUrl(url)) {
          allUrls.add(url);
        }
      }
    }

    // Extract URLs from plain text
    if (bodyText != null && bodyText.isNotEmpty) {
      final textMatches = _plainUrlPattern.allMatches(bodyText);
      for (final match in textMatches) {
        final url = match.group(0);
        if (url != null) {
          allUrls.add(url);
        }
      }
    }

    // Extract domains from URLs
    for (final url in allUrls) {
      final domain = _extractDomainFromUrl(url);
      if (domain != null && domain.isNotEmpty) {
        domainUrls.putIfAbsent(domain, () => []);
        domainUrls[domain]!.add(url);
      }
    }

    // Sort domains alphabetically
    final sortedDomains = domainUrls.keys.toList()..sort();

    _logger.d('Extracted ${sortedDomains.length} unique domains from ${allUrls.length} URLs');

    return DomainExtractionResult(
      domains: sortedDomains,
      domainUrls: domainUrls,
      totalUrlsProcessed: allUrls.length,
    );
  }

  /// Check if URL is a valid HTTP/HTTPS URL
  bool _isValidHttpUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Extract domain from a URL
  String? _extractDomainFromUrl(String url) {
    final match = _domainPattern.firstMatch(url);
    if (match != null) {
      return match.group(1)?.toLowerCase();
    }
    return null;
  }

  /// Generate regex pattern for blocking a domain and its subdomains
  ///
  /// Example: "spam.com" -> "^[^@\\s]+@(?:[a-z0-9-]+\\.)*spam\\.com$"
  /// This pattern matches:
  /// - user@spam.com
  /// - user@mail.spam.com
  /// - user@sub.domain.spam.com
  String generateDomainBlockPattern(String domain) {
    // Escape special regex characters in domain
    final escapedDomain = _escapeRegexSpecialChars(domain);
    return r'^[^@\s]+@(?:[a-z0-9-]+\.)*' + escapedDomain + r'$';
  }

  /// Generate regex pattern for blocking exact email address
  ///
  /// Example: "john.doe@spam.com" -> "^john\\.doe@spam\\.com$"
  String generateExactEmailPattern(String email) {
    final escapedEmail = _escapeRegexSpecialChars(email.toLowerCase());
    return '^$escapedEmail\$';
  }

  /// Generate regex pattern for blocking URL domain in email body
  ///
  /// Example: "scamsite.com" -> "scamsite\\.com"
  /// Used for body content matching, not email address matching
  String generateBodyDomainPattern(String domain) {
    return _escapeRegexSpecialChars(domain.toLowerCase());
  }

  /// Escape special regex characters
  String _escapeRegexSpecialChars(String input) {
    return input.replaceAllMapped(
      RegExp(r'[.^$*+?{}()|[\]\\]'),
      (match) => '\\${match.group(0)}',
    );
  }

  /// Extract email address from "Name \<email>" format
  ///
  /// Returns the email address portion, or the original string if not in that format
  String extractEmailAddress(String fromHeader) {
    // Match "Name <email@domain.com>" pattern
    final match = RegExp(r'<([^>]+)>').firstMatch(fromHeader);
    if (match != null) {
      return match.group(1)?.toLowerCase() ?? fromHeader.toLowerCase();
    }
    return fromHeader.toLowerCase().trim();
  }

  /// Extract domain from email address
  ///
  /// Returns null if email does not contain @
  String? extractDomainFromEmail(String email) {
    final cleanEmail = extractEmailAddress(email);
    final atIndex = cleanEmail.indexOf('@');
    if (atIndex > 0 && atIndex < cleanEmail.length - 1) {
      return cleanEmail.substring(atIndex + 1);
    }
    return null;
  }
}
