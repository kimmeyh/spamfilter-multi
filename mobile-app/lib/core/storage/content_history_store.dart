/// R76-4 (Sprint 78, ADR-0047): the dev-only content history -- ONE row per
/// email per account, in its own SQLite file (`content_history.db`, beside
/// `spam_filter.db`; ADR-0047 item 7), so the main schema and its version are
/// untouched and "Delete content history" removes one file.
///
/// Writes are single statements: a new email is `INSERT OR IGNORE` against the
/// UNIQUE index on (account_id, identity_hash), so the UI and a background
/// scan (another process on Windows, another isolate on Android) can never
/// write the same email twice; a repeat sighting is one `UPDATE`.
library;

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

/// One stored email (the fields of ADR-0047 item 5).
class ContentHistoryRecord {
  const ContentHistoryRecord({
    required this.accountId,
    required this.identityHash,
    this.messageId,
    this.providerId,
    this.fromAddress,
    this.fromName,
    this.replyTo,
    this.returnPathDomain,
    this.subject,
    this.receivedAt,
    required this.folder,
    required this.seenAt,
    this.authClass,
    this.listUnsubscribe = false,
    required this.outcome,
    this.matchedRule,
    this.matchedPattern,
    required this.scanType,
    required this.platform,
    this.bodyText,
    this.bodyTruncated = false,
  });

  final String accountId;
  final String identityHash;
  final String? messageId;
  final String? providerId;
  final String? fromAddress;
  final String? fromName;
  final String? replyTo;
  final String? returnPathDomain;
  final String? subject;
  final DateTime? receivedAt;
  final String folder;
  final DateTime seenAt;
  final String? authClass;
  final bool listUnsubscribe;
  final String outcome;
  final String? matchedRule;
  final String? matchedPattern;
  final String scanType;
  final String platform;
  final String? bodyText;
  final bool bodyTruncated;

  Map<String, Object?> toMap() => {
        'account_id': accountId,
        'identity_hash': identityHash,
        'message_id': messageId,
        'provider_id': providerId,
        'from_address': fromAddress,
        'from_name': fromName,
        'reply_to': replyTo,
        'return_path_domain': returnPathDomain,
        'subject': subject,
        'received_at': receivedAt?.millisecondsSinceEpoch,
        'first_folder': folder,
        'first_seen_at': seenAt.millisecondsSinceEpoch,
        'last_folder': folder,
        'last_seen_at': seenAt.millisecondsSinceEpoch,
        'auth_class': authClass,
        'list_unsubscribe': listUnsubscribe ? 1 : 0,
        'outcome': outcome,
        'matched_rule': matchedRule,
        'matched_pattern': matchedPattern,
        'scan_type': scanType,
        'platform': platform,
        'body_text': bodyText,
        'body_truncated': bodyTruncated ? 1 : 0,
      };
}

class ContentHistoryStore {
  /// [path] overrides the file (tests); otherwise
  /// [DatabaseHelper.contentHistoryDatabasePath].
  ContentHistoryStore({String? path}) : _pathOverride = path;

  /// The app's one store.
  static final ContentHistoryStore instance = ContentHistoryStore();

  final String? _pathOverride;
  final Logger _logger = Logger();
  Database? _db;

  static const _table = 'content_history';

  String _path() {
    final path = _pathOverride ?? DatabaseHelper().contentHistoryDatabasePath;
    if (path == null) {
      throw StateError('Content history path unknown: AppPaths not set');
    }
    return path;
  }

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final db = await openDatabase(
      _path(),
      version: 1,
      onConfigure: (db) async {
        // Same as the main database (F98/F156): wait for a writer instead of
        // failing; rawQuery because these PRAGMAs return a value.
        await db.rawQuery('PRAGMA busy_timeout = 30000');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id TEXT NOT NULL,
            identity_hash TEXT NOT NULL,
            message_id TEXT,
            provider_id TEXT,
            from_address TEXT,
            from_name TEXT,
            reply_to TEXT,
            return_path_domain TEXT,
            subject TEXT,
            received_at INTEGER,
            first_folder TEXT,
            first_seen_at INTEGER NOT NULL,
            last_folder TEXT,
            last_seen_at INTEGER NOT NULL,
            auth_class TEXT,
            list_unsubscribe INTEGER NOT NULL DEFAULT 0,
            outcome TEXT NOT NULL,
            matched_rule TEXT,
            matched_pattern TEXT,
            user_decision TEXT,
            user_decision_at INTEGER,
            scan_type TEXT,
            platform TEXT,
            body_text TEXT,
            body_truncated INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE UNIQUE INDEX idx_content_history_identity '
            'ON $_table(account_id, identity_hash)');
        await db.execute('CREATE INDEX idx_content_history_provider '
            'ON $_table(account_id, provider_id)');
      },
    );
    _db = db;
    return db;
  }

  /// Which of [hashes] are already stored for [accountId] -- ONE query per
  /// scan batch, from headers only (ADR-0047 item 4).
  Future<Set<String>> knownIdentities(
      String accountId, Iterable<String> hashes) async {
    final list = hashes.toSet().toList();
    if (list.isEmpty) return {};
    final db = await database;
    final known = <String>{};
    // SQLite's default host-parameter limit is 999; stay well under it.
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      final rows = await db.query(
        _table,
        columns: ['identity_hash'],
        where: 'account_id = ? AND identity_hash IN '
            '(${List.filled(chunk.length, '?').join(',')})',
        whereArgs: [accountId, ...chunk],
      );
      known.addAll(rows.map((r) => r['identity_hash'] as String));
    }
    return known;
  }

  /// Stores a NEW email. Returns false when the row already existed (another
  /// writer got there first) -- the caller then records a sighting.
  Future<bool> insertNew(ContentHistoryRecord row) async {
    final db = await database;
    final id = await db.insert(_table, row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id > 0;
  }

  /// A repeat sighting: last-seen date and folder, and the scan outcome when
  /// it changed. Never a new row, never a body.
  Future<void> recordSighting({
    required String accountId,
    required String identityHash,
    required String folder,
    required DateTime seenAt,
    required String outcome,
    String? matchedRule,
    String? matchedPattern,
  }) async {
    final db = await database;
    await db.update(
      _table,
      {
        'last_folder': folder,
        'last_seen_at': seenAt.millisecondsSinceEpoch,
        'outcome': outcome,
        'matched_rule': matchedRule,
        'matched_pattern': matchedPattern,
      },
      where: 'account_id = ? AND identity_hash = ?',
      whereArgs: [accountId, identityHash],
    );
  }

  /// The user's decision on an email (ADR-0047 item 5, R-6): matched by the
  /// identity hash, else -- for rows that reached the action without a
  /// Message-ID (Review's stored No Rule rows) -- by the provider id in the
  /// account. Returns the number of rows updated.
  Future<int> recordDecision({
    required String accountId,
    String? identityHash,
    String? providerId,
    required String decision,
    DateTime? at,
  }) async {
    final db = await database;
    final values = {
      'user_decision': decision,
      'user_decision_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
    };
    if (identityHash != null) {
      final n = await db.update(_table, values,
          where: 'account_id = ? AND identity_hash = ?',
          whereArgs: [accountId, identityHash]);
      if (n > 0) return n;
    }
    if (providerId != null && providerId.isNotEmpty) {
      return db.update(_table, values,
          where: 'account_id = ? AND provider_id = ?',
          whereArgs: [accountId, providerId]);
    }
    return 0;
  }

  /// How many emails are stored (Settings shows it).
  Future<int> count() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// "Remove an account": that account's rows.
  Future<int> deleteAccount(String accountId) async {
    final db = await database;
    return db.delete(_table, where: 'account_id = ?', whereArgs: [accountId]);
  }

  /// "Delete content history" and "delete all data": close the database, then
  /// delete the file (ADR-0047: on Windows a file with an open handle cannot
  /// be deleted, so close first; the same order on Android).
  Future<void> deleteAll() async {
    await close();
    final path = _path();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('$path$suffix');
      if (await f.exists()) await f.delete();
    }
    _logger.i('Content history deleted');
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }

  /// Whether the history file exists (no file means nothing was captured).
  bool fileExists() {
    final path = _pathOverride ?? DatabaseHelper().contentHistoryDatabasePath;
    return path != null && File(path).existsSync();
  }
}
