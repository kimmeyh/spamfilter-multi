import '../utils/pattern_normalization.dart';

/// Represents an email message across all providers
class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final String body;
  final Map<String, String> headers;
  final DateTime receivedDate;
  final String folderName;

  /// F91 (Sprint 39): the RFC 5322 `Message-ID` header value, including the
  /// surrounding angle brackets (for example `<abc123@mail.example.com>`).
  ///
  /// Null when the source message had no `Message-ID` header or the provider
  /// did not fetch headers. This is a STABLE cross-folder identity for a
  /// message: unlike the IMAP UID (which is mailbox-scoped and is reassigned
  /// when a server re-injects a copy), the `Message-ID` stays the same across
  /// copies. F91 uses it to recognize "the same message I already rescued"
  /// during post-safe-sender-move source-folder deduplication.
  final String? messageIdHeader;

  EmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.body,
    required this.headers,
    required this.receivedDate,
    required this.folderName,
    this.messageIdHeader,
  });

  /// Extract sender email from 'From' header
  /// Uses PatternNormalization to handle plus-sign subaddressing
  String getSenderEmail() {
    return PatternNormalization.normalizeFromHeader(from);
  }

  /// Get header value by key (case-insensitive)
  String? getHeader(String key) {
    final lowerKey = key.toLowerCase();
    return headers.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == lowerKey,
          orElse: () => const MapEntry('', ''),
        )
        .value;
  }

  /// F91 (Sprint 39): extract and normalize the RFC 5322 `Message-ID` value
  /// from a raw header value (case-insensitive lookup is the caller's job).
  ///
  /// Returns the trimmed value including the angle brackets, for example
  /// `<abc@host>`. Returns null when [rawValue] is null, empty, or whitespace
  /// only. The angle brackets are preserved because IMAP `SEARCH HEADER
  /// Message-ID` matches the literal header value, which includes them.
  ///
  /// This does NOT attempt to repair malformed headers (missing brackets,
  /// multiple IDs). It returns the trimmed value as-is so the dedup search
  /// stays faithful to what the server stored.
  static String? parseMessageId(String? rawValue) {
    if (rawValue == null) return null;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  String toString() {
    return 'EmailMessage(id: $id, from: $from, subject: $subject, date: $receivedDate)';
  }
}
