/// F271 (Sprint 81): header-only reasons an unmatched ("No rule") email looks
/// like spam.
///
/// Pure Dart. No I/O, no clock, no platform branches (ADR-0042: the same code
/// runs on Windows, Android and iPhone). The signals are computed at scan time
/// from headers the scan already fetched; no body is fetched. A signal never
/// acts on mail: it is a short reason CODE stored beside the No Rule row and
/// shown as a chip on the No Rule Review screen (Harold, Q2 = 1: codes only,
/// no header text is stored).
///
/// Two-header comparisons (Reply-To against From) live here in Dart, not in
/// the YAML rule grammar (a grammar change would be a Class-2 decision).
library;

import '../utils/pattern_normalization.dart';

/// The reason codes. The string value is what is stored in
/// `unmatched_emails.heuristic_signals`; never rename one (rows already
/// written would stop matching their label).
class HeuristicSignal {
  const HeuristicSignal._();

  static const String replyToDiffers = 'reply_to_differs';
  static const String authFailed = 'auth_failed';
  static const String lookalikeDomain = 'lookalike_domain';
  static const String bulkNoUnsubscribe = 'bulk_no_unsubscribe';

  // REMOVED (7.7.1 review CR M-1 / SF M-4, Harold Q1 = 1, 2026-10-26):
  // 'blocked_tld'. An enabled TLD block rule already blocks the mail, so the
  // chip could appear only for a rule the user turned off, while its text
  // said the rule was active. Do not reuse the code: rows written by Sprint 81
  // builds may still hold it, and [decode] drops it because it has no label.
  // Replacement ideas (an often-abused TLD list; a TLD none of the user's
  // safe senders use) are on F306 / F311.

  /// Display order on a row (strongest evidence first).
  static const List<String> all = [
    authFailed,
    replyToDiffers,
    lookalikeDomain,
    bulkNoUnsubscribe,
  ];

  /// Plain-English chip labels. An unknown code (a row written by a newer
  /// build) has no label and is skipped by [labelFor] callers.
  static const Map<String, String> labels = {
    replyToDiffers: 'Reply-To differs',
    authFailed: 'Sign-in check failed',
    lookalikeDomain: 'Lookalike domain',
    bulkNoUnsubscribe: 'No unsubscribe link',
  };

  /// One-sentence explanation, used for the chip's Semantics label and tooltip.
  static const Map<String, String> explanations = {
    replyToDiffers:
        'Replies would go to a different domain than the sender address.',
    authFailed:
        'The sender could not be verified (SPF, DKIM and DMARC checks failed).',
    lookalikeDomain:
        'The sender domain is almost the same as one of your safe sender '
        'domains.',
    bulkNoUnsubscribe:
        'This looks like bulk mail but has no unsubscribe header.',
  };

  static String? labelFor(String code) => labels[code];

  /// Stored form: comma-joined codes, or null when there are none (so a row
  /// with no signal is indistinguishable from a row written before v16).
  static String? encode(List<String> codes) =>
      codes.isEmpty ? null : codes.join(',');

  /// Inverse of [encode]. Null, empty and unknown codes yield no entries.
  static List<String> decode(String? stored) {
    if (stored == null || stored.isEmpty) return const [];
    final known = stored
        .split(',')
        .map((c) => c.trim())
        .where(labels.containsKey)
        .toSet();
    return [for (final c in all) if (known.contains(c)) c];
  }
}

/// Facts about the user's own configuration the signals compare against.
/// Built once per scan, not once per email.
class HeuristicContext {
  /// Registrable domains the user trusts (from safe sender patterns).
  final Set<String> safeSenderRootDomains;

  const HeuristicContext({
    this.safeSenderRootDomains = const {},
  });

  static const HeuristicContext empty = HeuristicContext();

  /// Builds the context from stored safe sender patterns (the maps
  /// `DatabaseHelper.querySafeSenders` returns).
  factory HeuristicContext.fromRows({
    required Iterable<Map<String, dynamic>> safeSenderRows,
  }) {
    final domains = <String>{};
    for (final row in safeSenderRows) {
      final domain = HeuristicSignals.domainFromSafeSenderPattern(
          row['pattern'] as String?);
      if (domain == null) continue;
      final root = PatternNormalization.extractRootDomain(domain);
      if (root != null) domains.add(root);
    }
    return HeuristicContext(safeSenderRootDomains: domains);
  }
}

class HeuristicSignals {
  const HeuristicSignals._();

  /// The smallest registrable-domain label (the part before the TLD) that the
  /// lookalike rule will compare. Short names (`ibm`, `hp`) are one edit from
  /// many unrelated names, so they are never flagged.
  static const int lookalikeMinLabelLength = 5;

  /// Computes the signal codes for one message, in display order.
  ///
  /// [headers] is the message header map in any key case. [from] is the From
  /// header (or a bare address). [authClassificationName] is the stored
  /// SPF/DKIM/DMARC class name (`AuthResultsParser.classifyHeaders(..).name`);
  /// it is reused, not re-parsed.
  static List<String> compute({
    required Map<String, String> headers,
    required String from,
    String? authClassificationName,
    HeuristicContext context = HeuristicContext.empty,
  }) {
    final h = {for (final e in headers.entries) e.key.toLowerCase(): e.value};
    final sender = PatternNormalization.normalizeFromHeader(from);
    final senderDomain = _domainOf(sender);
    final found = <String>{};

    // auth_failed: the RED class only (SPF or DKIM failed AND DMARC failed).
    // YELLOW and GREY are common for legitimate mail and are not a signal.
    if (authClassificationName == 'red') found.add(HeuristicSignal.authFailed);

    // reply_to_differs: compared by registrable domain, so
    // `mail.example.com` against `example.com` is NOT a hit.
    // A Reply-To may list several addresses. normalizeFromHeader takes the
    // first `<...>`, but with bare addresses (`a@x.com, b@y.com`) it would
    // strip the comma and join them, so cut at the first comma first.
    var rawReplyTo = h['reply-to'];
    if (rawReplyTo != null && !rawReplyTo.contains('<')) {
      rawReplyTo = rawReplyTo.split(',').first;
    }
    final replyTo = PatternNormalization.normalizeFromHeader(rawReplyTo);
    final replyDomain = _domainOf(replyTo);
    if (senderDomain != null && replyDomain != null) {
      if (PatternNormalization.extractRootDomain(senderDomain) !=
          PatternNormalization.extractRootDomain(replyDomain)) {
        found.add(HeuristicSignal.replyToDiffers);
      }
    }

    if (senderDomain != null) {
      if (isLookalike(senderDomain, context.safeSenderRootDomains)) {
        found.add(HeuristicSignal.lookalikeDomain);
      }
    }

    // bulk_no_unsubscribe: bulk or list mail (Precedence: bulk/list, or a
    // List-Id) with no List-Unsubscribe header.
    final precedence = (h['precedence'] ?? '').trim().toLowerCase();
    final isBulk = precedence == 'bulk' ||
        precedence == 'list' ||
        (h['list-id'] ?? '').trim().isNotEmpty;
    final hasUnsubscribe = (h['list-unsubscribe'] ?? '').trim().isNotEmpty;
    if (isBulk && !hasUnsubscribe) {
      found.add(HeuristicSignal.bulkNoUnsubscribe);
    }

    return [for (final c in HeuristicSignal.all) if (found.contains(c)) c];
  }

  /// Lookalike rule (documented, deliberately narrow to keep false positives
  /// low). A sender is a lookalike when ALL hold:
  ///  1. its registrable domain is NOT itself one of the user's safe domains;
  ///  2. some safe registrable domain has the SAME top-level suffix;
  ///  3. both second-level labels are at least [lookalikeMinLabelLength]
  ///     characters long; and
  ///  4. after folding common look-alike characters (`0`->`o`, `1`->`l`,
  ///     `3`->`e`, `5`->`s`, `rn`->`m`, `vv`->`w`) the two labels are the
  ///     same, or are one edit apart (one insertion, deletion, substitution or
  ///     adjacent swap).
  /// Different-TLD pairs (`amazon.com` and `amazon.de`) are legitimate far
  /// more often than not and are never flagged.
  static bool isLookalike(String senderDomain, Set<String> safeRootDomains) {
    if (safeRootDomains.isEmpty) return false;
    final senderRoot = PatternNormalization.extractRootDomain(senderDomain);
    if (senderRoot == null || safeRootDomains.contains(senderRoot)) {
      return false;
    }
    final s = _splitRoot(senderRoot);
    if (s == null || s.label.length < lookalikeMinLabelLength) return false;
    for (final safe in safeRootDomains) {
      final t = _splitRoot(safe);
      if (t == null || t.suffix != s.suffix) continue;
      if (t.label.length < lookalikeMinLabelLength) continue;
      final a = _fold(s.label);
      final b = _fold(t.label);
      if (a == b || _withinOneEdit(a, b)) return true;
    }
    return false;
  }

  /// The domain a stored safe sender regex trusts, or null when the pattern is
  /// an unrecognized shape or has no domain. Handles the shapes the app
  /// writes: `^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$`, `@example\.com$` and
  /// an exact email `^user@example\.com$` (and the same without the anchors).
  /// An exact safe email also yields its domain: for the lookalike check, a
  /// trusted address at `paypal.com` makes `paypa1.com` suspicious too.
  static String? domainFromSafeSenderPattern(String? pattern) {
    if (pattern == null) return null;
    final at = pattern.lastIndexOf('@');
    if (at < 0) return null;
    var tail = pattern.substring(at + 1);
    const wildcard = r'(?:[a-z0-9-]+\.)*';
    if (tail.startsWith(wildcard)) tail = tail.substring(wildcard.length);
    if (tail.endsWith(r'$')) tail = tail.substring(0, tail.length - 1);
    final domain = tail.replaceAll(r'\.', '.').toLowerCase();
    return RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(domain)
        ? domain
        : null;
  }

  static String? _domainOf(String address) {
    final at = address.lastIndexOf('@');
    if (at < 0 || at == address.length - 1) return null;
    return address.substring(at + 1);
  }

  static ({String label, String suffix})? _splitRoot(String root) {
    final dot = root.indexOf('.');
    if (dot <= 0 || dot == root.length - 1) return null;
    return (label: root.substring(0, dot), suffix: root.substring(dot + 1));
  }

  static String _fold(String label) => label
      .replaceAll('rn', 'm')
      .replaceAll('vv', 'w')
      .replaceAll('0', 'o')
      .replaceAll('1', 'l')
      .replaceAll('3', 'e')
      .replaceAll('5', 's');

  /// True when [a] and [b] differ by exactly one insertion, deletion,
  /// substitution or adjacent swap.
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return false;
    final la = a.length;
    final lb = b.length;
    if ((la - lb).abs() > 1) return false;
    if (la == lb) {
      final diffs = <int>[];
      for (var i = 0; i < la; i++) {
        if (a[i] != b[i]) {
          diffs.add(i);
          if (diffs.length > 2) return false;
        }
      }
      if (diffs.length == 1) return true;
      return diffs.length == 2 &&
          diffs[1] == diffs[0] + 1 &&
          a[diffs[0]] == b[diffs[1]] &&
          a[diffs[1]] == b[diffs[0]];
    }
    final longer = la > lb ? a : b;
    final shorter = la > lb ? b : a;
    var i = 0;
    while (i < shorter.length && longer[i] == shorter[i]) {
      i++;
    }
    return longer.substring(i + 1) == shorter.substring(i);
  }
}
