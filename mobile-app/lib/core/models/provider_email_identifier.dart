/// Abstraction for provider-specific email identifiers
///
/// Different email providers use different identifier systems:
/// - Gmail: Message-ID from REST API (persistent, string format)
/// - IMAP (AOL, Yahoo, ProtonMail): UID (folder-specific, integer format)
///
/// This class provides a unified abstraction for storing and working with
/// provider-specific identifiers in a provider-agnostic way.
///
/// Example usage:
/// ```dart
/// // Gmail identifier
/// final gmailId = ProviderEmailIdentifier.gmail('18d4f2e8a1b2c3d4');
///
/// // IMAP identifier
/// final aolId = ProviderEmailIdentifier.imap('aol', 12345);
///
/// // Serialize for database storage
/// final json = gmailId.toJson();
///
/// // Deserialize from database
/// final restored = ProviderEmailIdentifier.fromJson(json);
/// ```
class ProviderEmailIdentifier {
  /// Provider type (e.g., 'gmail', 'aol', 'yahoo', 'outlook', 'protonmail')
  final String providerType;

  /// Type of identifier used by provider
  /// - 'gmail_message_id': Gmail REST API Message-ID
  /// - 'imap_uid': IMAP UID (folder-specific)
  final String identifierType;

  /// Actual identifier value as string
  final String identifierValue;

  ProviderEmailIdentifier({
    required this.providerType,
    required this.identifierType,
    required this.identifierValue,
  });

  /// Factory constructor for Gmail Message-ID
  ///
  /// Gmail uses persistent message IDs from the REST API that survive
  /// moves between folders and labels.
  factory ProviderEmailIdentifier.gmail(String messageId) {
    return ProviderEmailIdentifier(
      providerType: 'gmail',
      identifierType: 'gmail_message_id',
      identifierValue: messageId,
    );
  }

  /// Factory constructor for IMAP UID
  ///
  /// IMAP providers (AOL, Yahoo, ProtonMail) use folder-specific UIDs.
  /// UIDs are unique within a folder but may change if emails are moved.
  ///
  /// Note: providerType should be lowercase: 'aol', 'yahoo', 'protonmail'
  factory ProviderEmailIdentifier.imap(String providerType, int uid) {
    return ProviderEmailIdentifier(
      providerType: providerType.toLowerCase(),
      identifierType: 'imap_uid',
      identifierValue: uid.toString(),
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
        'provider_type': providerType,
        'identifier_type': identifierType,
        'identifier_value': identifierValue,
      };

  /// Create from JSON deserialization
  factory ProviderEmailIdentifier.fromJson(Map<String, dynamic> json) {
    return ProviderEmailIdentifier(
      providerType: json['provider_type'] as String,
      identifierType: json['identifier_type'] as String,
      identifierValue: json['identifier_value'] as String,
    );
  }

  /// Equality comparison based on all three fields
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderEmailIdentifier &&
          runtimeType == other.runtimeType &&
          providerType == other.providerType &&
          identifierType == other.identifierType &&
          identifierValue == other.identifierValue;

  @override
  int get hashCode =>
      providerType.hashCode ^ identifierType.hashCode ^ identifierValue.hashCode;

  @override
  String toString() =>
      'ProviderEmailIdentifier($providerType, $identifierType, $identifierValue)';

  /// Check if this is a Gmail identifier
  bool get isGmail => identifierType == 'gmail_message_id';

  /// Check if this is an IMAP identifier
  bool get isImap => identifierType == 'imap_uid';

  /// Get IMAP UID as integer (only valid for IMAP identifiers)
  ///
  /// Throws StateError if called on non-IMAP identifier.
  int get imapUid {
    if (!isImap) {
      throw StateError('Cannot get IMAP UID from non-IMAP identifier: $identifierType');
    }
    return int.parse(identifierValue);
  }
}
