/// F323 R-1 (Sprint 83, Harold Q4 = 2026-11-01): the value of the Block Body
/// button in the No Rule Item pop-up.
///
/// The value is the domain of the FIRST link in the message body whose domain
/// does not exactly match the sender's email domain, skipping any link domain
/// that is a safe sender (exact domain or entire domain). When no link
/// qualifies there is no value, and the pop-up shows no Block Body choice.
///
/// The text read here must be the text the saved rule will be matched against.
/// `RuleEvaluator` matches a body rule against the body that
/// `SpamFilterPlatform.fetchFullBody` returns. Since Sprint 83 7.7.1 (Harold
/// Q1 = 1) that is the text/plain part, else the HTML part converted to text
/// (`content_text_extractor.dart` `selectBodyText`), the same text the pop-up
/// reads with `fetchContentText`. Links are found in the TEXT: an HTML link
/// whose address appears only in its `href` attribute is not in the text, so
/// it is not a candidate here and a rule could not match it either.
///
/// SEC-14: the body is read in memory for the pop-up and never stored. Only the
/// resulting domain reaches a rule.
///
/// ADR-0042: pure shared Dart, identical on Windows, Android and iOS.
library;

import 'email_body_parser.dart';

/// Why the Block Body choice has no value, or its value.
enum BodyLinkOutcome {
  /// The body is still being fetched.
  loading,

  /// A qualifying link was found; the value is its domain.
  found,

  /// The body was read and no link qualifies.
  noOutsideLink,

  /// The body could not be read (offline, busy account, sign-in needed).
  couldNotLoad,
}

/// What the pop-up knows about the Block Body choice.
class BodyLinkResult {
  const BodyLinkResult._(this.outcome, this.domain);

  /// The body is still being fetched.
  const BodyLinkResult.loading() : this._(BodyLinkOutcome.loading, null);

  /// A qualifying link domain.
  const BodyLinkResult.found(String domain)
      : this._(BodyLinkOutcome.found, domain);

  /// The body was read; no link qualifies.
  const BodyLinkResult.noOutsideLink()
      : this._(BodyLinkOutcome.noOutsideLink, null);

  /// The body could not be read.
  const BodyLinkResult.couldNotLoad()
      : this._(BodyLinkOutcome.couldNotLoad, null);

  final BodyLinkOutcome outcome;

  /// Set only when [outcome] is [BodyLinkOutcome.found].
  final String? domain;
}

/// The first link domain in [body] that is not [senderDomain] and not a safe
/// sender, or null.
///
/// [senderDomain] is the sender's email domain. The match is exact (after
/// lower-casing): a link to `shop.example.com` from a sender at `example.com`
/// differs, so it qualifies. [isSafeDomain] answers whether a link domain is a
/// safe sender, exact or entire domain.
String? firstOutsideLinkDomain({
  required String body,
  required String? senderDomain,
  required bool Function(String linkDomain) isSafeDomain,
}) {
  if (body.isEmpty) return null;
  final sender = senderDomain?.toLowerCase().trim();
  // domainUrls keeps first-appearance order (a map literal is insertion
  // ordered); `domains` is sorted, so it is NOT used here.
  final result = EmailBodyParser().extractDomains(null, body);
  for (final raw in result.domainUrls.keys) {
    // A trailing dot or bracket is sentence punctuation after the URL.
    final domain = raw.toLowerCase().replaceAll(RegExp(r'[.,;)\]>]+$'), '');
    if (domain.isEmpty) continue;
    if (sender != null && domain == sender) continue;
    if (isSafeDomain(domain)) continue;
    return domain;
  }
  return null;
}
