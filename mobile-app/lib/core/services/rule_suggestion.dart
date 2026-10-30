/// F306 (Sprint 82): the ONE rule suggested for a No Rule email.
///
/// A suggestion is advice shown in the No Rule Item pop-up. It never acts on
/// mail: the user still taps a button, and that tap runs the existing quick
/// action, which saves the pattern [RuleQuickActionService] builds.
///
/// Basis (Task 6 counts on DEV data, Harold Q4): the ONLY basis is "the
/// sender authentication class is YELLOW, so suggest a block rule". It fires
/// on 35 of 254 No Rule rows (14 percent) and agrees with 5 of 6 of the 69
/// decisions that touched it (83 percent). A sender at a shared email provider
/// gets Block Email (the address); any other sender gets Block Entire Domain
/// (the root domain), exactly the value the pop-up button passes.
///
/// RED guard (R-5 / AC-3): [suggest] drops any SAFE-sender result when the
/// classification is RED, whatever basis produced it. The guard is generic, so
/// a safe-sender basis added later cannot bypass it. The current basis list is
/// block-only, so a test injects a hypothetical always-safe basis through
/// `basis` to prove the guard on its own.
///
/// SEC-14: only codes and short rule values are kept; no body text.
///
/// ADR-0042: pure shared Dart. It runs the same on Windows, Android and iOS,
/// at scan time (manual and background scans share `EmailScanProvider`) and at
/// pop-up time on the Results screen.
library;

import 'package:flutter/foundation.dart';

import '../data/common_email_providers.dart';
import '../utils/pattern_normalization.dart';
import 'auth_results_parser.dart';
import 'email_body_parser.dart';
import 'rule_quick_action_service.dart';

/// What a basis proposes, before the pattern is built.
typedef SuggestionDraft = ({
  String kind,
  String type,
  String value,
  String reasonCode,
});

/// A basis: proposes at most one draft for a sender and its auth class.
typedef SuggestionBasis = SuggestionDraft? Function(
    String fromEmail, AuthClassification? auth);

/// Reason code for the YELLOW basis.
const String kSuggestionReasonAuthYellow = 'auth_yellow';

/// The stored `suggestion_kind` values.
const String kSuggestionKindSafe = 'safe';
const String kSuggestionKindBlock = 'block';

@immutable
class RuleSuggestion {
  const RuleSuggestion({
    required this.kind,
    required this.type,
    required this.value,
    required this.pattern,
    required this.reasonCode,
  });

  /// 'safe' or 'block'.
  final String kind;

  /// The quick-action type: safe 'exact' | 'exactDomain' | 'entireDomain';
  /// block 'from' | 'exactDomain' | 'entireDomain' | 'subject'.
  final String type;

  /// The value the quick action is given.
  final String value;

  /// The exact regex the quick action saves.
  final String pattern;

  /// A short code; [reasonText] turns it into the sentence the user reads.
  final String reasonCode;

  bool get isBlock => kind == kSuggestionKindBlock;

  /// One plain sentence for the user. Unknown codes (a row written by a newer
  /// build) get a generic sentence, never an empty line.
  String get reasonText {
    switch (reasonCode) {
      case kSuggestionReasonAuthYellow:
        return 'Sender authentication (SPF/DKIM/DMARC) did not fully pass '
            'for this email.';
      default:
        return 'This rule fits the email.';
    }
  }

  static const _columnNames = <String>[
    'suggestion_kind',
    'suggestion_type',
    'suggestion_value',
    'suggestion_pattern',
    'suggestion_reason',
  ];

  /// The five `unmatched_emails` columns. A null suggestion writes five nulls,
  /// so a refreshed row loses a suggestion that no longer applies.
  static Map<String, Object?> toColumns(RuleSuggestion? s) => {
        'suggestion_kind': s?.kind,
        'suggestion_type': s?.type,
        'suggestion_value': s?.value,
        'suggestion_pattern': s?.pattern,
        'suggestion_reason': s?.reasonCode,
      };

  /// Reads the columns back. Null unless all five are present (a v16 row has
  /// none).
  static RuleSuggestion? fromColumns(Map<String, Object?> map) {
    for (final c in _columnNames) {
      final v = map[c];
      if (v is! String || v.isEmpty) return null;
    }
    return RuleSuggestion(
      kind: map['suggestion_kind']! as String,
      type: map['suggestion_type']! as String,
      value: map['suggestion_value']! as String,
      pattern: map['suggestion_pattern']! as String,
      reasonCode: map['suggestion_reason']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RuleSuggestion &&
      other.kind == kind &&
      other.type == type &&
      other.value == value &&
      other.pattern == pattern &&
      other.reasonCode == reasonCode;

  @override
  int get hashCode => Object.hash(kind, type, value, pattern, reasonCode);

  @override
  String toString() => 'RuleSuggestion($kind/$type, $reasonCode)';

  /// The suggestion for a No Rule email, or null.
  ///
  /// [fromEmail] is the raw From header. [authClassification] is the stored
  /// class name (`green`/`yellow`/`red`/`grey`) or null. Pure: it depends only
  /// on these two inputs, so a re-seen row recomputes the same answer.
  ///
  /// [basis] replaces the basis list in tests only.
  static RuleSuggestion? suggest({
    required String fromEmail,
    required String? authClassification,
    @visibleForTesting List<SuggestionBasis>? basis,
  }) {
    final auth = AuthResultsParser.classificationFromName(authClassification);
    for (final b in basis ?? _bases) {
      final draft = b(fromEmail, auth);
      if (draft == null) continue;
      // R-5 / AC-3: a RED email is never suggested as a safe sender.
      if (draft.kind == kSuggestionKindSafe && auth == AuthClassification.red) {
        continue;
      }
      final pattern = draft.kind == kSuggestionKindSafe
          ? RuleQuickActionService.safeSenderPatternFor(draft.type, draft.value)
          : RuleQuickActionService.blockPatternFor(draft.type, draft.value);
      if (pattern == null) continue;
      return RuleSuggestion(
        kind: draft.kind,
        type: draft.type,
        value: draft.value,
        pattern: pattern,
        reasonCode: draft.reasonCode,
      );
    }
    return null;
  }

  static final List<SuggestionBasis> _bases = [_authYellowBlock];

  /// YELLOW authentication -> block. Mirrors the pop-up buttons' values:
  /// Block Email passes the extracted address; Block Entire Domain passes the
  /// root domain (or the domain when no root is found).
  static SuggestionDraft? _authYellowBlock(
      String fromEmail, AuthClassification? auth) {
    if (auth != AuthClassification.yellow) return null;
    final parser = EmailBodyParser();
    final address = parser.extractEmailAddress(fromEmail);
    final domain = parser.extractDomainFromEmail(fromEmail);
    if (domain == null) return null;
    if (CommonEmailProviders.isCommonProvider(domain)) {
      return (
        kind: kSuggestionKindBlock,
        type: 'from',
        value: address,
        reasonCode: kSuggestionReasonAuthYellow,
      );
    }
    return (
      kind: kSuggestionKindBlock,
      type: 'entireDomain',
      value: PatternNormalization.extractRootDomain(domain) ?? domain,
      reasonCode: kSuggestionReasonAuthYellow,
    );
  }
}
