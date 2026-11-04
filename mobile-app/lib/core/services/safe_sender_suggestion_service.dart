/// F270 v1 (Sprint 83): suggested safe senders from stored No Rule history.
///
/// A suggestion is advice shown on Manage Safe Senders. It never changes a
/// rule: the user taps Accept (and then one of the three safe-sender choices)
/// or Reject, and Accept runs the existing quick action
/// ([RuleQuickActionService.addSafeSender]).
///
/// A sender is a candidate only when ALL of these hold (R-1):
/// - it has at least [kSuggestionMinCount] stored No Rule emails (N = 3);
/// - EVERY one of those emails has the stored authentication class GREEN. GREY
///   (no headers), YELLOW and RED mean "could not check" or "failed", so one
///   such email removes the sender (Sprint 82 IMP-4: a check that did not run
///   must not make a sender look safe);
/// - no scan action ever deleted mail from it (`email_actions.action_type =
///   'delete'`) and no stored email from it is recorded as gone from the
///   mailbox (`availability_status = 'deleted'`, the user or a rule removed
///   it);
/// - it is not already covered by a saved safe-sender pattern;
/// - the user has not rejected it before.
///
/// GREEN here is the stored class (`AuthResultsParser.classify`), which means
/// every SPF/DKIM/DMARC method that returned a verdict passed and at least one
/// did. It is a proxy for "DMARC pass", the same proxy the F310 miner states.
///
/// The recommended choice follows the F306 pop-up rule
/// ([RuleSuggestion]): a sender at a shared email provider gets Exact Email,
/// any other sender gets Entire Domain (the root domain). Exact Domain is
/// offered but never recommended.
///
/// Data: `unmatched_emails` and `email_actions` hold scan results, so the
/// service works in production builds (the content history is DEV only).
///
/// ADR-0042 / ADR-0049 / ADR-0050: pure shared Dart over the shared scan
/// store, identical on Windows, Android and iPhone. No platform branch.
library;

import 'package:logger/logger.dart';

import '../data/common_email_providers.dart';
import '../storage/database_helper.dart';
import '../utils/pattern_normalization.dart';
import 'email_body_parser.dart';
import 'rule_quick_action_service.dart';

/// N: the smallest number of stored No Rule emails a candidate needs. Set from
/// the DEV count in the Task 5 card: 6 senders at N = 3 (14 at N = 2, 2 at
/// N = 5).
const int kSuggestionMinCount = 3;

/// The stored class a candidate's emails must all have.
const String kSuggestionRequiredAuth = 'green';

/// One of the three safe-sender choices offered when the user taps Accept.
class SafeSenderChoice {
  const SafeSenderChoice({
    required this.type,
    required this.value,
    required this.label,
    required this.pattern,
    required this.recommended,
  });

  /// `exact`, `exactDomain` or `entireDomain` (the quick action's types).
  final String type;

  /// The value the quick action takes (an address, `@domain` or a root domain).
  final String value;

  /// The label the Accept dialog shows.
  final String label;

  /// The regex the quick action will save for this choice.
  final String pattern;

  /// True for the one choice the app recommends.
  final bool recommended;
}

/// A sender the app suggests adding to Safe Senders.
class SafeSenderCandidate {
  const SafeSenderCandidate({
    required this.address,
    required this.count,
    required this.choices,
  });

  /// The lowercase sender address.
  final String address;

  /// Stored No Rule emails seen from this sender.
  final int count;

  /// Exact Email, Exact Domain and Entire Domain, in that order.
  final List<SafeSenderChoice> choices;

  SafeSenderChoice get recommended =>
      choices.firstWhere((c) => c.recommended);
}

class SafeSenderSuggestionService {
  SafeSenderSuggestionService({DatabaseHelper? databaseHelper, Logger? logger})
      : _db = databaseHelper ?? DatabaseHelper(),
        _logger = logger ?? Logger();

  final DatabaseHelper _db;
  final Logger _logger;

  /// The three choices for [address], with the recommended one marked. Null
  /// when [address] has no usable domain.
  static List<SafeSenderChoice>? choicesFor(String address) {
    final parser = EmailBodyParser();
    final clean = parser.extractEmailAddress(address);
    final domain = parser.extractDomainFromEmail(clean);
    if (domain == null) return null;
    final shared = CommonEmailProviders.isCommonProvider(domain);
    final root = PatternNormalization.extractRootDomain(domain) ?? domain;
    SafeSenderChoice make(String type, String value, String label, bool rec) {
      return SafeSenderChoice(
        type: type,
        value: value,
        label: label,
        pattern: RuleQuickActionService.safeSenderPatternFor(type, value) ?? '',
        recommended: rec,
      );
    }

    final choices = [
      make('exact', clean, 'Exact Email: $clean', shared),
      make('exactDomain', '@$domain', 'Exact Domain: @$domain', false),
      make('entireDomain', root, 'Entire Domain: @*.$root', !shared),
    ];
    return choices.any((c) => c.pattern.isEmpty) ? null : choices;
  }

  /// True when any of [safePatterns] matches [address]. A pattern that does
  /// not compile cannot match, so it is skipped (it also cannot protect mail).
  static bool isCovered(String address, List<String> safePatterns) {
    for (final p in safePatterns) {
      try {
        if (RegExp(p, caseSensitive: false).hasMatch(address)) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// The candidates, most No Rule emails first (ties by address).
  ///
  /// [rejected] holds lowercase addresses the user rejected. [safePatterns]
  /// are the saved safe-sender regexes. Throws on a database error: the caller
  /// shows it (a check that did not run is not "no suggestions").
  Future<List<SafeSenderCandidate>> findCandidates({
    required Set<String> rejected,
    required List<String> safePatterns,
    int minCount = kSuggestionMinCount,
  }) async {
    final db = await _db.database;
    final parser = EmailBodyParser();
    String addressOf(String from) => parser.extractEmailAddress(from).trim();

    final deleted = <String>{};
    final delRows = await db.rawQuery(
        "SELECT DISTINCT email_from FROM email_actions WHERE action_type = 'delete'");
    for (final r in delRows) {
      deleted.add(addressOf(r['email_from'] as String));
    }

    final rows = await db.rawQuery(
        'SELECT from_email, auth_classification, availability_status '
        'FROM unmatched_emails');
    final counts = <String, int>{};
    final disqualified = <String>{};
    for (final r in rows) {
      final address = addressOf(r['from_email'] as String);
      if (!address.contains('@')) continue;
      counts[address] = (counts[address] ?? 0) + 1;
      final auth = (r['auth_classification'] as String?)?.toLowerCase();
      if (auth != kSuggestionRequiredAuth ||
          r['availability_status'] == 'deleted') {
        disqualified.add(address);
      }
    }

    final result = <SafeSenderCandidate>[];
    counts.forEach((address, count) {
      if (count < minCount) return;
      if (disqualified.contains(address)) return;
      if (deleted.contains(address)) return;
      if (rejected.contains(address)) return;
      if (isCovered(address, safePatterns)) return;
      final choices = choicesFor(address);
      if (choices == null) return;
      result.add(
          SafeSenderCandidate(address: address, count: count, choices: choices));
    });
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.address.compareTo(b.address);
    });
    _logger.d('F270: ${result.length} suggested safe sender(s) '
        'from ${counts.length} No Rule sender(s)');
    return result;
  }
}
