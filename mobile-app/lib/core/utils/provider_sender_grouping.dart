import '../data/common_email_providers.dart';
import '../services/email_body_parser.dart';

/// Sprint 46 retro IMP-1 (Harold): in every presentation of scan results,
/// emails whose SENDER DOMAIN is a known email provider (gmail.com, aol.com,
/// yahoo.com, ... per [CommonEmailProviders]) are grouped at the TOP of the
/// list, under a heading and with an end indicator, because they should be
/// processed together and first (provider senders get per-address rules, not
/// domain rules, so they need individual attention).
///
/// Screen-agnostic so `ResultsDisplayScreen` (live + historical) and
/// `NoRuleReviewScreen` share one implementation.
class ProviderSenderGrouping {
  ProviderSenderGrouping._();

  static final EmailBodyParser _parser = EmailBodyParser();

  /// True when [fromHeader]'s sender domain belongs to a known email
  /// provider. Accepts a raw From header or a bare address.
  static bool isProviderSender(String fromHeader) {
    final domain = _parser.extractDomainFromEmail(fromHeader);
    if (domain == null || domain.isEmpty) return false;
    return CommonEmailProviders.isCommonProvider(domain);
  }

  /// Stable-partitions [items] so provider-sender items come first, keeping
  /// each group's existing relative order (the caller's sort is preserved
  /// within both groups). Returns the reordered list and the provider count
  /// (the boundary index for rendering the heading / end indicator).
  static ({List<T> items, int providerCount}) partitionProviderFirst<T>(
    List<T> items,
    String Function(T item) senderOf,
  ) {
    final provider = <T>[];
    final other = <T>[];
    for (final item in items) {
      if (isProviderSender(senderOf(item))) {
        provider.add(item);
      } else {
        other.add(item);
      }
    }
    return (items: [...provider, ...other], providerCount: provider.length);
  }
}
