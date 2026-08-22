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

  /// F96 (Sprint 43): the SPF/DKIM/DMARC classification name
  /// (`green`/`yellow`/`red`/`grey`) persisted at scan time and re-hydrated on
  /// the off-scan quick-add paths (Scan History reload, email-detail view).
  ///
  /// Live-scan `EmailMessage` objects leave this null and carry the full
  /// authentication headers instead -- the quick-add screens parse those
  /// directly. The historical / email-detail paths reconstruct the message
  /// from the database with only `From`/`Subject` headers (no
  /// `Authentication-Results`), so a fresh parse would always classify GREY
  /// and the RED anti-phishing warning could never fire (F89's coverage gap,
  /// PR #260 review). When this override is present, consumers use it instead
  /// of re-parsing the (now-absent) headers. Per ADR / Sprint 43 Class-1
  /// decision, only the classification ENUM is persisted (not the raw headers),
  /// so a re-hydrated RED warning fires but cannot show the original
  /// per-protocol breakdown.
  final String? authClassificationOverride;

  EmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.body,
    required this.headers,
    required this.receivedDate,
    required this.folderName,
    this.messageIdHeader,
    this.authClassificationOverride,
  });

  /// F177 (Sprint 62): a copy of this message whose [body] is truncated to
  /// [maxBodyLength] characters. Used by EmailScanner AFTER rule evaluation
  /// so retained per-scan records stop holding full message bodies (the
  /// ~7-10MB-per-message retention behind the Sprint 61 LOW_MEMORY kills).
  /// Everything a downstream consumer needs survives: headers (auth
  /// classification), messageIdHeader (dedup/target-folder search), id,
  /// from, subject, folder. Nothing in the UI or persistence reads more
  /// than a 100-character body preview (kBodyPreviewMaxLength, SEC-14).
  EmailMessage copyWithTruncatedBody(int maxBodyLength) {
    if (body.length <= maxBodyLength) return this;
    return EmailMessage(
      id: id,
      from: from,
      subject: subject,
      body: body.substring(0, maxBodyLength),
      headers: headers,
      receivedDate: receivedDate,
      folderName: folderName,
      messageIdHeader: messageIdHeader,
      authClassificationOverride: authClassificationOverride,
    );
  }

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
