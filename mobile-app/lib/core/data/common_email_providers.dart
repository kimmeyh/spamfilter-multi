/// Reference table of common email provider domains.
///
/// Application-managed, not user-editable. Used by rule suggestion logic to
/// distinguish personal provider emails from business/organizational domains.
/// When a sender uses a common provider like Gmail or Yahoo, rules should
/// target the specific email address rather than the entire domain.
///
/// Loaded as compile-time constants for zero-cost initialization and fast
/// HashSet-based lookups.
library;

/// Provider metadata for domain classification.
class EmailProvider {
  /// Human-readable provider name (e.g., "Gmail", "Yahoo Mail").
  final String name;

  /// All domains associated with this provider.
  final List<String> domains;

  const EmailProvider({required this.name, required this.domains});
}

/// Static reference data for common email providers.
///
/// Usage:
/// ```dart
/// CommonEmailProviders.isCommonProvider('gmail.com')       // true
/// CommonEmailProviders.getProviderName('hotmail.com')      // 'Microsoft'
/// CommonEmailProviders.isCommonProvider('company.com')     // false
/// ```
class CommonEmailProviders {
  CommonEmailProviders._();

  /// All known email providers with their domains.
  static const List<EmailProvider> providers = [
    EmailProvider(
      name: 'Gmail',
      domains: ['gmail.com', 'googlemail.com'],
    ),
    EmailProvider(
      name: 'AOL',
      domains: ['aol.com', 'aim.com'],
    ),
    EmailProvider(
      name: 'Yahoo',
      domains: [
        'yahoo.com',
        'yahoo.co.uk',
        'yahoo.co.jp',
        'yahoo.com.br',
        'yahoo.ca',
        'yahoo.fr',
        'yahoo.de',
        'yahoo.it',
        'yahoo.es',
        'yahoo.in',
        'yahoo.co.in',
        'ymail.com',
        'rocketmail.com',
        'myyahoo.com',
      ],
    ),
    EmailProvider(
      name: 'Microsoft',
      domains: [
        'outlook.com',
        'hotmail.com',
        'live.com',
        'msn.com',
        'hotmail.co.uk',
        'hotmail.fr',
        'hotmail.de',
        'hotmail.it',
        'hotmail.es',
        'live.co.uk',
        'live.fr',
        'live.de',
        'live.it',
      ],
    ),
    EmailProvider(
      name: 'Proton',
      domains: ['protonmail.com', 'proton.me', 'pm.me'],
    ),
    EmailProvider(
      name: 'iCloud',
      domains: ['icloud.com', 'me.com', 'mac.com'],
    ),
    EmailProvider(
      name: 'Zoho',
      domains: ['zoho.com', 'zohomail.com'],
    ),
    EmailProvider(
      name: 'GMX',
      domains: ['gmx.com', 'gmx.net', 'gmx.de', 'gmx.at', 'gmx.ch'],
    ),
    EmailProvider(
      name: 'Mail.com',
      domains: [
        'mail.com',
        'email.com',
        'usa.com',
        'post.com',
        'europe.com',
      ],
    ),
    EmailProvider(
      name: 'Yandex',
      domains: ['yandex.com', 'yandex.ru', 'ya.ru'],
    ),
    EmailProvider(
      name: 'Comcast',
      domains: ['comcast.net', 'xfinity.com'],
    ),
    EmailProvider(
      name: 'AT&T',
      domains: ['att.net', 'sbcglobal.net', 'bellsouth.net'],
    ),
    EmailProvider(
      name: 'Verizon',
      domains: ['verizon.net'],
    ),
    EmailProvider(
      name: 'Cox',
      domains: ['cox.net'],
    ),
    EmailProvider(
      name: 'Charter/Spectrum',
      domains: ['charter.net', 'spectrum.net'],
    ),
  ];

  /// Lazily-initialized lookup set for O(1) domain checks.
  static final Set<String> _domainSet = _buildDomainSet();

  /// Lazily-initialized domain-to-provider-name map.
  static final Map<String, String> _domainToProvider = _buildProviderMap();

  static Set<String> _buildDomainSet() {
    final set = <String>{};
    for (final provider in providers) {
      set.addAll(provider.domains);
    }
    return set;
  }

  static Map<String, String> _buildProviderMap() {
    final map = <String, String>{};
    for (final provider in providers) {
      for (final domain in provider.domains) {
        map[domain] = provider.name;
      }
    }
    return map;
  }

  /// Check if a domain belongs to a known email provider.
  ///
  /// [domain] should be the bare domain (e.g., "gmail.com"), not a full
  /// email address. The domain is lowercased before lookup.
  ///
  /// Returns true for common providers like Gmail, Yahoo, Outlook, etc.
  static bool isCommonProvider(String domain) {
    return _domainSet.contains(domain.toLowerCase().trim());
  }

  /// Get the provider name for a domain, or null if not a known provider.
  ///
  /// [domain] should be the bare domain (e.g., "hotmail.com").
  ///
  /// Returns the provider name (e.g., "Microsoft") or null.
  static String? getProviderName(String domain) {
    return _domainToProvider[domain.toLowerCase().trim()];
  }

  /// Get the provider name for an email address, or null if not a known provider.
  ///
  /// [email] should be a full email address (e.g., "user@gmail.com").
  /// Extracts the domain part automatically.
  static String? getProviderForEmail(String email) {
    final atIndex = email.lastIndexOf('@');
    if (atIndex < 0 || atIndex >= email.length - 1) return null;
    final domain = email.substring(atIndex + 1).toLowerCase().trim();
    return _domainToProvider[domain];
  }

  /// Total number of provider domains in the reference table.
  static int get domainCount => _domainSet.length;

  /// Total number of providers in the reference table.
  static int get providerCount => providers.length;
}
