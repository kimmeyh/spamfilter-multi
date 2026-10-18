/// F286 (Sprint 79): the text and ID of a background-scan completion
/// notification, built once for BOTH platforms.
///
/// Android posts it now (`android_background_scan_worker.dart`); Windows uses
/// the same builder for its toast (F287). One builder keeps the two platforms'
/// notifications word for word the same (ADR-0042 parity); only the delivery
/// (Android notification channel vs Windows toast) differs.
///
/// Text set by Harold (2026-10-10):
/// - Title `Back. scan k*@aol completed` -- the account masked as its first
///   letter, `*`, `@`, and the domain without its last label.
/// - Body `No rule 9 Deleted 1 Safe 0`, with ` Errors N` only when N > 0. No
///   colons or commas.
///
/// Modes other than live (Q1 = 1, Sprint 79): each count the mode did NOT act
/// on is struck through in the HTML body, AND the title names the mode
/// (`Back. scan k*@aol read-only completed`). The title word is what keeps the
/// notification true for a screen reader: TalkBack reads the text, not the
/// strikethrough, so "Deleted 1" alone would be heard as a real deletion.
///
/// Mask limit: two accounts on the same domain whose addresses start with the
/// same letter produce the same title.
library;

import '../providers/email_scan_provider.dart' show ScanMode;

/// One count in the body, and whether the scan's mode acted on it.
class ScanNotificationCount {
  final String label;
  final int value;

  /// False when the mode only REPORTED this count (for example Deleted in
  /// read-only mode): rendered struck through.
  final bool actedOn;

  const ScanNotificationCount(this.label, this.value, {required this.actedOn});

  String get text => '$label $value';
}

class ScanNotificationText {
  final String title;
  final List<ScanNotificationCount> counts;

  const ScanNotificationText._(this.title, this.counts);

  /// Builds the notification for one account's completed background scan.
  ///
  /// [accountId] is the saved account id -- the email address
  /// (`account_setup_screen.dart`, `accountId: email`).
  factory ScanNotificationText.build({
    required String accountId,
    required ScanMode mode,
    required int noRule,
    required int deleted,
    required int safe,
    required int errors,
  }) {
    final word = modeWord(mode);
    final title = 'Back. scan ${maskAccount(accountId)}'
        '${word == null ? '' : ' $word'} completed';
    final counts = <ScanNotificationCount>[
      // "No rule" is never an action, so it is never struck.
      ScanNotificationCount('No rule', noRule, actedOn: true),
      ScanNotificationCount('Deleted', deleted, actedOn: actsOnRules(mode)),
      ScanNotificationCount('Safe', safe, actedOn: actsOnSafeSenders(mode)),
      if (errors > 0) ScanNotificationCount('Errors', errors, actedOn: true),
    ];
    return ScanNotificationText._(title, counts);
  }

  /// The body as plain text -- no markup, for a surface that cannot render it.
  String get plainBody => counts.map((c) => c.text).join(' ');

  /// The body with `<s>` around each count the mode did not act on, for an
  /// HTML-formatted Android notification body. Every part is a fixed label or
  /// a number, so nothing here needs escaping.
  String get htmlBody =>
      counts.map((c) => c.actedOn ? c.text : '<s>${c.text}</s>').join(' ');

  /// True when the body contains any struck count (a mode other than live).
  bool get hasStruckCounts => counts.any((c) => !c.actedOn);

  /// Whether [mode] executes spam-rule actions (Deleted).
  static bool actsOnRules(ScanMode mode) =>
      mode == ScanMode.rulesOnly || mode == ScanMode.safeSendersAndRules;

  /// Whether [mode] executes safe-sender moves (Safe).
  static bool actsOnSafeSenders(ScanMode mode) =>
      mode == ScanMode.safeSendersOnly || mode == ScanMode.safeSendersAndRules;

  /// The title word for a mode other than live; null for live.
  static String? modeWord(ScanMode mode) {
    switch (mode) {
      case ScanMode.readOnly:
        return 'read-only';
      case ScanMode.rulesOnly:
        return 'rules-only';
      case ScanMode.safeSendersOnly:
        return 'safe-senders-only';
      case ScanMode.safeSendersAndRules:
        return null;
    }
  }

  /// `kimmeyharold@aol.com` -> `k*@aol`; `x@mail.example.co.uk` ->
  /// `x*@mail.example.co`. An id without `@` (not expected) -> `account`, so
  /// no raw identifier is ever shown.
  static String maskAccount(String accountId) {
    final at = accountId.lastIndexOf('@');
    if (at < 0) return 'account';
    final local = accountId.substring(0, at);
    final domain = accountId.substring(at + 1);
    final first = local.isEmpty ? '' : local[0];
    final dot = domain.lastIndexOf('.');
    final host = dot > 0 ? domain.substring(0, dot) : domain;
    return '$first*@$host';
  }

  /// The notification ID for [accountId]: FNV-1a (32-bit) of its UTF-16 code
  /// units, masked to 31 bits so it is a non-negative platform int.
  ///
  /// Deterministic across processes and Dart versions, unlike
  /// `String.hashCode`, which Dart does not promise to be stable. The same
  /// account always gets the same ID, so a newer notification replaces the
  /// older one; values are pinned by a test.
  static int notificationId(String accountId) {
    var hash = 0x811c9dc5;
    for (final unit in accountId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
