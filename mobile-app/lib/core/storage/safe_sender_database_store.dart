import 'dart:convert';

import 'package:logger/logger.dart';

import 'database_helper.dart';

/// Exception thrown when safe sender database operations fail
class SafeSenderDatabaseException implements Exception {
  final String message;
  final dynamic originalError;

  SafeSenderDatabaseException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SafeSenderDatabaseException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Safe sender pattern with optional exceptions
///
/// Represents a single safe sender pattern with optional exception patterns.
/// Example: pattern = "@company.com", exceptions = ["spammer@company.com", "@marketing.company.com"]
class SafeSenderPattern {
  final String pattern;
  final String patternType; // 'email', 'domain', 'subdomain'
  final List<String>? exceptionPatterns;
  final int dateAdded;
  final String createdBy;

  SafeSenderPattern({
    required this.pattern,
    required this.patternType,
    this.exceptionPatterns,
    required this.dateAdded,
    this.createdBy = 'manual',
  });

  /// Convert to database row format
  Map<String, dynamic> toDatabase() => {
    'pattern': pattern,
    'pattern_type': patternType,
    'exception_patterns': exceptionPatterns != null ? jsonEncode(exceptionPatterns) : null,
    'date_added': dateAdded,
    'created_by': createdBy,
  };

  /// Convert from database row format
  static SafeSenderPattern fromDatabase(Map<String, dynamic> row) {
    List<String>? exceptions;
    if (row['exception_patterns'] != null) {
      try {
        final decoded = jsonDecode(row['exception_patterns'] as String);
        exceptions = List<String>.from(decoded as List);
      } catch (e) {
        // Log malformed JSON but do not fail
        Logger().w('Malformed exception_patterns for pattern "${row['pattern']}": $e');
      }
    }

    return SafeSenderPattern(
      pattern: row['pattern'] as String,
      patternType: row['pattern_type'] as String,
      exceptionPatterns: exceptions,
      dateAdded: row['date_added'] as int,
      createdBy: row['created_by'] as String? ?? 'manual',
    );
  }
}

/// Database-backed storage for safe senders with exception support
///
/// This storage implementation provides safe sender management with exceptions:
/// - CRUD operations for safe_senders table
/// - JSON serialization for exception_patterns field
/// - Pattern type detection (email, domain, subdomain)
/// - Proper error handling with custom exceptions
///
/// Example:
/// ```dart
/// final dbHelper = DatabaseHelper();
/// final store = SafeSenderDatabaseStore(dbHelper);
///
/// // Add a safe sender with exceptions
/// final pattern = SafeSenderPattern(
///   pattern: '@company.com',
///   patternType: 'domain',
///   exceptionPatterns: ['spammer@company.com'],
///   dateAdded: DateTime.now().millisecondsSinceEpoch,
/// );
/// await store.addSafeSender(pattern);
///
/// // Load all safe senders
/// final senders = await store.loadSafeSenders();
///
/// // Add exception to existing safe sender
/// await store.addException('@company.com', 'spammer@company.com');
///
/// // Remove safe sender
/// await store.removeSafeSender('@company.com');
/// ```
class SafeSenderDatabaseStore {
  final RuleDatabaseProvider databaseProvider;
  final Logger _logger = Logger();

  SafeSenderDatabaseStore(RuleDatabaseProvider provider) : databaseProvider = provider;

  /// Load all safe sender patterns from database
  ///
  /// Returns a list of all safe sender patterns with their exceptions.
  /// If no patterns exist, returns empty list.
  /// Gracefully handles malformed JSON exception data.
  Future<List<SafeSenderPattern>> loadSafeSenders() async {
    try {
      _logger.i('Loading safe senders from database');

      final sendersData = await databaseProvider.querySafeSenders();
      final senders = <SafeSenderPattern>[];

      for (final senderData in sendersData) {
        try {
          final sender = SafeSenderPattern.fromDatabase(senderData);
          senders.add(sender);
        } catch (e) {
          _logger.w('Failed to load safe sender "${senderData['pattern']}": $e');
          // Continue loading other patterns, skip malformed ones
        }
      }

      _logger.i('Loaded ${senders.length} safe sender patterns from database');
      return senders;
    } catch (e) {
      throw SafeSenderDatabaseException('Failed to load safe senders from database', e);
    }
  }

  /// Get single safe sender pattern by pattern string
  ///
  /// Returns the pattern if found, null if not found.
  /// Includes all exception patterns if present.
  Future<SafeSenderPattern?> getSafeSender(String pattern) async {
    try {
      final result = await databaseProvider.getSafeSender(pattern);

      if (result == null) {
        return null;
      }

      return SafeSenderPattern.fromDatabase(result);
    } catch (e) {
      throw SafeSenderDatabaseException('Failed to get safe sender "$pattern"', e);
    }
  }

  /// Add new safe sender pattern to database
  ///
  /// Inserts a new safe sender pattern with optional exception patterns.
  /// Throws exception if pattern already exists (UNIQUE constraint).
  /// Pattern type is auto-detected if not provided.
  Future<void> addSafeSender(SafeSenderPattern safeSender) async {
    try {
      _logger.i('Adding safe sender "${safeSender.pattern}" to database');

      await databaseProvider.insertSafeSender(safeSender.toDatabase());

      _logger.i('Added safe sender "${safeSender.pattern}" to database');
    } catch (e) {
      throw SafeSenderDatabaseException(
        'Failed to add safe sender "${safeSender.pattern}"',
        e,
      );
    }
  }

  /// Update existing safe sender pattern in database
  ///
  /// Updates the safe sender pattern with new data.
  /// Can update pattern_type, exception_patterns, or created_by fields.
  /// Throws exception if pattern does not exist.
  Future<void> updateSafeSender(String pattern, SafeSenderPattern updatedSender) async {
    try {
      _logger.i('Updating safe sender "$pattern" in database');

      // Check if pattern exists
      final existing = await databaseProvider.getSafeSender(pattern);
      if (existing == null) {
        throw SafeSenderDatabaseException('Safe sender "$pattern" does not exist');
      }

      final updateData = {
        'pattern': updatedSender.pattern,
        'pattern_type': updatedSender.patternType,
        'exception_patterns': updatedSender.exceptionPatterns != null
            ? jsonEncode(updatedSender.exceptionPatterns)
            : null,
        'date_added': updatedSender.dateAdded,
        'created_by': updatedSender.createdBy,
      };

      await databaseProvider.updateSafeSender(pattern, updateData);

      _logger.i('Updated safe sender "$pattern" in database');
    } catch (e) {
      if (e is SafeSenderDatabaseException) {
        rethrow;
      }
      throw SafeSenderDatabaseException(
        'Failed to update safe sender "$pattern"',
        e,
      );
    }
  }

  /// Delete safe sender pattern from database
  ///
  /// Removes the entire safe sender pattern including all exceptions.
  /// Throws exception if pattern does not exist.
  Future<void> removeSafeSender(String pattern) async {
    try {
      _logger.i('Deleting safe sender "$pattern" from database');

      final deletedCount = await databaseProvider.deleteSafeSender(pattern);

      if (deletedCount == 0) {
        throw SafeSenderDatabaseException('Safe sender "$pattern" does not exist');
      }

      _logger.i('Deleted safe sender "$pattern" from database');
    } catch (e) {
      if (e is SafeSenderDatabaseException) {
        rethrow;
      }
      throw SafeSenderDatabaseException(
        'Failed to delete safe sender "$pattern"',
        e,
      );
    }
  }

  /// Add exception pattern to existing safe sender
  ///
  /// Adds an exception pattern to the safe sender's exception list.
  /// If safe sender does not have exceptions, creates new list with this exception.
  /// Throws exception if safe sender does not exist.
  Future<void> addException(String safeSenderPattern, String exceptionPattern) async {
    try {
      _logger.i('Adding exception "$exceptionPattern" to safe sender "$safeSenderPattern"');

      final existing = await getSafeSender(safeSenderPattern);
      if (existing == null) {
        throw SafeSenderDatabaseException(
          'Safe sender "$safeSenderPattern" does not exist',
        );
      }

      final exceptions = existing.exceptionPatterns ?? [];
      if (!exceptions.contains(exceptionPattern)) {
        exceptions.add(exceptionPattern);

        final updatedSender = SafeSenderPattern(
          pattern: existing.pattern,
          patternType: existing.patternType,
          exceptionPatterns: exceptions,
          dateAdded: existing.dateAdded,
          createdBy: existing.createdBy,
        );

        await updateSafeSender(safeSenderPattern, updatedSender);
        _logger.i('Added exception "$exceptionPattern" to safe sender "$safeSenderPattern"');
      }
    } catch (e) {
      if (e is SafeSenderDatabaseException) {
        rethrow;
      }
      throw SafeSenderDatabaseException(
        'Failed to add exception "$exceptionPattern" to safe sender "$safeSenderPattern"',
        e,
      );
    }
  }

  /// Remove exception pattern from existing safe sender
  ///
  /// Removes an exception pattern from the safe sender's exception list.
  /// If exception does not exist, operation is silent (idempotent).
  /// Throws exception if safe sender does not exist.
  Future<void> removeException(String safeSenderPattern, String exceptionPattern) async {
    try {
      _logger.i('Removing exception "$exceptionPattern" from safe sender "$safeSenderPattern"');

      final existing = await getSafeSender(safeSenderPattern);
      if (existing == null) {
        throw SafeSenderDatabaseException(
          'Safe sender "$safeSenderPattern" does not exist',
        );
      }

      final exceptions = existing.exceptionPatterns ?? [];
      if (exceptions.contains(exceptionPattern)) {
        exceptions.remove(exceptionPattern);

        final updatedSender = SafeSenderPattern(
          pattern: existing.pattern,
          patternType: existing.patternType,
          exceptionPatterns: exceptions.isEmpty ? null : exceptions,
          dateAdded: existing.dateAdded,
          createdBy: existing.createdBy,
        );

        await updateSafeSender(safeSenderPattern, updatedSender);
        _logger.i('Removed exception "$exceptionPattern" from safe sender "$safeSenderPattern"');
      }
    } catch (e) {
      if (e is SafeSenderDatabaseException) {
        rethrow;
      }
      throw SafeSenderDatabaseException(
        'Failed to remove exception "$exceptionPattern" from safe sender "$safeSenderPattern"',
        e,
      );
    }
  }

  /// Delete all safe senders from database
  ///
  /// CAUTION: This removes all safe sender patterns.
  /// Only use during testing or data reset operations.
  Future<void> deleteAllSafeSenders() async {
    try {
      _logger.w('CAUTION: Deleting all safe senders from database');
      await databaseProvider.deleteAllSafeSenders();
      _logger.i('Deleted all safe senders from database');
    } catch (e) {
      throw SafeSenderDatabaseException('Failed to delete all safe senders', e);
    }
  }

  /// Determine pattern type based on pattern content
  ///
  /// Heuristic pattern type detection:
  /// - 'email': Contains @ with text before it (local@domain format, no regex)
  /// - 'domain': Starts with @ (domain pattern)
  /// - 'subdomain': Contains regex constructs (advanced pattern)
  static String determinePatternType(String pattern) {
    if (pattern.isEmpty) return 'unknown';

    // Check if pattern contains regex special characters (excluding . which is common in emails/domains)
    // Look for: [ ] ( ) * + ? \ ^ $ |
    final hasRegex = pattern.contains(RegExp(r'[\[\]()*+?\\^$|]'));

    // Domain pattern: starts with @ and no regex special characters
    if (pattern.startsWith('@') && !hasRegex) {
      return 'domain';
    }

    // Email pattern: contains @ (with text before it) and no regex special characters
    if (pattern.contains('@') && !hasRegex) {
      return 'email';
    }

    // Subdomain/advanced pattern: contains regex constructs
    if (hasRegex) {
      return 'subdomain';
    }

    return 'unknown';
  }
}
