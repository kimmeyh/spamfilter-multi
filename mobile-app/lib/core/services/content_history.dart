/// R76-4 (Sprint 78, ADR-0047): the dev-only content history -- the gate and
/// the per-scan capture.
///
/// **Gate (ADR-0047 item 1).** Capture runs only when this is a DEV build
/// ([AppEnvironment.isDev]) AND the Settings > General "Content history"
/// switch is on. A prod build (Store MSIX, Play AAB) can never capture: the
/// switch is not shown and [isActive] checks the environment first.
///
/// **Unique emails, decided from headers (item 4).** For each scan batch the
/// identities are computed from the headers the scan already fetched and
/// looked up in ONE query; a body is fetched only for an identity not stored.
/// A repeat sighting updates last-seen date, folder and outcome only.
///
/// **Never fails a scan (item 11).** Every capture call catches, logs through
/// [DiagnosticLogger], and returns.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

import '../models/email_message.dart';
import '../models/evaluation_result.dart';
import '../storage/content_history_store.dart';
import '../storage/settings_store.dart';
import 'app_environment.dart';
import 'auth_results_parser.dart';
import 'content_text_extractor.dart';
import 'diagnostic_logger.dart';

class ContentHistory {
  ContentHistory._();

  static final Logger _logger = Logger();

  /// Test seam: force the environment answer (the real one is a compile-time
  /// constant).
  @visibleForTesting
  static bool? debugIsDevOverride;

  /// Whether this build can EVER capture: dev builds only.
  static bool get isAvailable => debugIsDevOverride ?? AppEnvironment.isDev;

  /// Whether capture runs now: a dev build AND the switch on.
  static Future<bool> isActive(SettingsStore settings) async {
    if (!isAvailable) return false;
    try {
      return await settings.getContentHistoryEnabled();
    } catch (e) {
      // Unreadable switch = off (never capture on a guess), but say so.
      _logger.w('Content history switch could not be read; treating as off: '
          '$e');
      return false;
    }
  }

  /// ADR-0047 item 4: SHA-256 of the account and the RFC 5322 Message-ID;
  /// without a Message-ID, of the account, the provider id and the folder.
  static String identityHash(String accountId, EmailMessage m) {
    final mid = m.messageIdHeader;
    final key = (mid != null && mid.isNotEmpty)
        ? '$accountId\u0000mid:$mid'
        : '$accountId\u0000pid:${m.id}\u0000${m.folderName}';
    return sha256.convert(utf8.encode(key)).toString();
  }

  /// The scan outcome label stored for [result].
  static String outcomeLabel(EvaluationResult result) {
    if (result.isSafeSender) return 'safe_sender';
    if (result.shouldDelete) return 'delete';
    if (result.shouldMove) return 'move';
    if (result.matchedRule.isNotEmpty) return 'rule';
    return 'no_rule';
  }

  /// Records the user's decision on [email] when the history is active
  /// (R-6). [decision] is e.g. 'safe_sender:exact' or 'block:entireDomain'.
  /// Best effort: never throws.
  static Future<void> recordDecision({
    required SettingsStore settings,
    required String accountId,
    required EmailMessage email,
    required String decision,
    String? providerId,
    ContentHistoryStore? store,
  }) async {
    try {
      if (!await isActive(settings)) return;
      final s = store ?? ContentHistoryStore.instance;
      if (!s.fileExists()) return;
      final hasMid = (email.messageIdHeader ?? '').isNotEmpty;
      await s.recordDecision(
        accountId: accountId,
        identityHash: hasMid ? identityHash(accountId, email) : null,
        providerId: providerId ?? email.id,
        decision: decision,
      );
    } catch (e) {
      await _logFailure('decision', e);
    }
  }

  /// F-PRECHECK class 6: always a console warning, plus the user-shareable
  /// diagnostic log (which writes only while diagnostic logging is on).
  static Future<void> _logFailure(String what, Object e) {
    _logger.w('Content history $what failed: $e');
    return DiagnosticLogger.failure(
      context: 'content-history',
      kind: DiagnosticLogger.kindException,
      reason: '$what failed: ${e.runtimeType}',
    );
  }
}

/// Capture for ONE scan. Created only when [ContentHistory.isActive] is true.
class ContentHistoryCapture {
  ContentHistoryCapture({
    required this.accountId,
    required this.scanType,
    required this.platform,
    required this.fetchText,
    ContentHistoryStore? store,
    DateTime Function()? now,
  })  : _store = store ?? ContentHistoryStore.instance,
        _now = now ?? DateTime.now;

  final String accountId;
  final String scanType;

  /// Where it ran: 'windows' or 'android' (ADR-0042 parity analysis).
  final String platform;

  /// Fetches one message's plain text (the provider's content method).
  final Future<String?> Function(EmailMessage message) fetchText;

  final ContentHistoryStore _store;
  final DateTime Function() _now;

  Set<String> _known = {};

  /// How many bodies this capture fetched (tests and the scan log).
  int bodiesFetched = 0;

  /// How many new emails were stored.
  int stored = 0;

  /// Call once per batch BEFORE its messages are evaluated: one lookup of
  /// which identities are already stored.
  Future<void> beginBatch(List<EmailMessage> batch) async {
    try {
      _known = await _store.knownIdentities(
          accountId, batch.map((m) => ContentHistory.identityHash(accountId, m)));
    } catch (e) {
      _known = {};
      await ContentHistory._logFailure('lookup', e);
    }
  }

  /// Records [message] with its evaluation [result]: a repeat sighting is an
  /// update; a new email fetches its body once and is stored.
  Future<void> record(EmailMessage message, EvaluationResult result) async {
    try {
      final hash = ContentHistory.identityHash(accountId, message);
      final outcome = ContentHistory.outcomeLabel(result);
      final seenAt = _now();
      if (_known.contains(hash)) {
        await _store.recordSighting(
          accountId: accountId,
          identityHash: hash,
          folder: message.folderName,
          seenAt: seenAt,
          outcome: outcome,
          matchedRule: _nullIfEmpty(result.matchedRule),
          matchedPattern: _nullIfEmpty(result.matchedPattern),
        );
        return;
      }
      bodiesFetched++;
      final rawText = await fetchText(message);
      final capped = rawText == null ? null : capContentText(rawText);
      final headers = _lowerKeys(message.headers);
      final inserted = await _store.insertNew(ContentHistoryRow(
        accountId: accountId,
        identityHash: hash,
        messageId: message.messageIdHeader,
        providerId: message.id,
        fromAddress: message.from,
        fromName: fromDisplayName(headers['from']),
        replyTo: _nullIfEmpty(headers['reply-to']),
        returnPathDomain: returnPathDomain(headers['return-path']),
        subject: message.subject,
        receivedAt: message.receivedDate,
        folder: message.folderName,
        seenAt: seenAt,
        authClass: message.authClassificationOverride ??
            AuthResultsParser.classifyHeaders(message.headers).name,
        listUnsubscribe: headers.containsKey('list-unsubscribe'),
        outcome: outcome,
        matchedRule: _nullIfEmpty(result.matchedRule),
        matchedPattern: _nullIfEmpty(result.matchedPattern),
        scanType: scanType,
        platform: platform,
        bodyText: capped?.text,
        bodyTruncated: capped?.truncated ?? false,
      ));
      _known.add(hash);
      if (inserted) {
        stored++;
      } else {
        // Another writer stored it first: this is a sighting.
        await _store.recordSighting(
          accountId: accountId,
          identityHash: hash,
          folder: message.folderName,
          seenAt: seenAt,
          outcome: outcome,
          matchedRule: _nullIfEmpty(result.matchedRule),
          matchedPattern: _nullIfEmpty(result.matchedPattern),
        );
      }
    } catch (e) {
      await ContentHistory._logFailure('capture', e);
    }
  }

  static String? _nullIfEmpty(String? s) =>
      (s == null || s.isEmpty) ? null : s;

  static Map<String, String> _lowerKeys(Map<String, String> h) =>
      {for (final e in h.entries) e.key.toLowerCase(): e.value};

  /// The display name of a From header (`"Name" <a@b>` -> `Name`), or null.
  @visibleForTesting
  static String? fromDisplayName(String? from) {
    if (from == null) return null;
    final lt = from.indexOf('<');
    if (lt <= 0) return null;
    final name = from.substring(0, lt).trim().replaceAll('"', '').trim();
    return name.isEmpty ? null : name;
  }

  /// The domain of a Return-Path header (`<bounce@x.example>` -> `x.example`).
  @visibleForTesting
  static String? returnPathDomain(String? returnPath) {
    if (returnPath == null) return null;
    final at = returnPath.lastIndexOf('@');
    if (at < 0) return null;
    final domain = returnPath.substring(at + 1).replaceAll('>', '').trim();
    return domain.isEmpty ? null : domain.toLowerCase();
  }
}
