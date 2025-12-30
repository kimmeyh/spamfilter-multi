import '../../core/models/email_message.dart';

/// Credentials for email provider authentication
class Credentials {
  final String email;
  final String? password;
  final String? accessToken;
  final Map<String, String>? additionalParams;

  Credentials({
    required this.email,
    this.password,
    this.accessToken,
    this.additionalParams,
  });
}

/// Abstract interface for email provider implementations
abstract class EmailProvider {
  /// Connect to the email provider
  Future<void> connect(Credentials credentials);

  /// Fetch messages from specified folders
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  });

  /// Delete a message by ID
  Future<void> deleteMessage(String messageId);

  /// Move a message to a target folder
  Future<void> moveMessage(String messageId, String targetFolder);

  /// List available folders
  Future<List<String>> listFolders();

  /// Disconnect from the provider
  Future<void> disconnect();
}
