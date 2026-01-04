/// Represents an email message across all providers
class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final String body;
  final Map<String, String> headers;
  final DateTime receivedDate;
  final String folderName;

  EmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.body,
    required this.headers,
    required this.receivedDate,
    required this.folderName,
  });

  /// Extract sender email from 'From' header
  String getSenderEmail() {
    return from.toLowerCase().trim();
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

  @override
  String toString() {
    return 'EmailMessage(id: $id, from: $from, subject: $subject, date: $receivedDate)';
  }
}
