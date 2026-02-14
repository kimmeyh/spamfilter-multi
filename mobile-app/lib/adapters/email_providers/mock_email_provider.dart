/// Mock email provider for demo mode
///
/// Implements SpamFilterPlatform interface with simulated data for UI testing
/// and demonstration without requiring live email account access.
library;

import 'dart:async';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/services/mock_email_data.dart';
import 'email_provider.dart';
import 'spam_filter_platform.dart';

/// Mock email provider for demo mode
class MockEmailProvider implements SpamFilterPlatform {
  /// Track actions performed during demo scan (for testing/verification)
  final List<Map<String, dynamic>> _actionLog = [];

  /// Simulated delay for operations (milliseconds)
  final int _operationDelayMs;

  /// Storage for deleted rule folder setting
  String? _deletedRuleFolder;

  MockEmailProvider({int operationDelayMs = 100})
      : _operationDelayMs = operationDelayMs;

  @override
  String get platformId => 'demo';

  @override
  String get displayName => 'Demo Mode';

  @override
  AuthMethod get supportedAuthMethod => AuthMethod.oauth2;

  /// Get log of all actions performed during demo
  List<Map<String, dynamic>> get actionLog => List.unmodifiable(_actionLog);

  /// Clear action log
  void clearActionLog() {
    _actionLog.clear();
  }

  @override
  Future<void> loadCredentials(Credentials credentials) async {
    // Simulate loading credentials
    await Future.delayed(Duration(milliseconds: _operationDelayMs));
    // Demo mode does not require real credentials
  }

  @override
  Future<List<EmailMessage>> fetchMessages({
    required int daysBack,
    required List<String> folderNames,
  }) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs * 2));

    // Get all sample emails
    final allEmails = MockEmailData.generateSampleEmails();

    // Filter by requested folders
    if (folderNames.contains('All Folders') || folderNames.isEmpty) {
      return allEmails;
    }

    return allEmails
        .where((email) => folderNames.contains(email.folderName))
        .toList();
  }

  @override
  Future<List<EvaluationResult>> applyRules({
    required List<EmailMessage> messages,
    required Map<String, Pattern> compiledRegex,
  }) async {
    // Simulate processing delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Mock provider does not do server-side filtering
    // Return empty results to let client-side evaluation handle it
    return messages.map((msg) {
      return EvaluationResult(
        shouldDelete: false,
        shouldMove: false,
        matchedRule: '',
        matchedPattern: '',
      );
    }).toList();
  }

  @override
  void setDeletedRuleFolder(String? folderName) {
    _deletedRuleFolder = folderName;
  }

  @override
  Future<void> takeAction({
    required EmailMessage message,
    required FilterAction action,
  }) async {
    // Simulate action delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Log the action (do not actually perform it)
    _actionLog.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action': action.name,
      'emailId': message.id,
      'from': message.from,
      'subject': message.subject,
      'folder': message.folderName,
      'targetFolder': _deletedRuleFolder,
    });
  }

  @override
  Future<void> moveToFolder({
    required EmailMessage message,
    required String targetFolder,
  }) async {
    // Simulate move delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Log the move action (do not actually perform it)
    _actionLog.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action': 'move',
      'emailId': message.id,
      'from': message.from,
      'subject': message.subject,
      'folder': message.folderName,
      'targetFolder': targetFolder,
    });
  }

  /// [ISSUE #138] Mock mark as read operation
  @override
  Future<void> markAsRead({
    required EmailMessage message,
  }) async {
    // Simulate mark as read delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Log the mark as read action (do not actually perform it)
    _actionLog.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action': 'markAsRead',
      'emailId': message.id,
      'from': message.from,
      'subject': message.subject,
    });
  }

  /// [ISSUE #138] Mock apply flag operation
  @override
  Future<void> applyFlag({
    required EmailMessage message,
    required String flagName,
  }) async {
    // Simulate apply flag delay
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Log the apply flag action (do not actually perform it)
    _actionLog.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action': 'applyFlag',
      'emailId': message.id,
      'from': message.from,
      'subject': message.subject,
      'flagName': flagName,
    });
  }

  @override
  Future<List<FolderInfo>> listFolders() async{
    // Simulate fetching folders
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    // Return demo folders
    final demoFolders = MockEmailData.getDemoFolders();
    return demoFolders.map((folderName) {
      final canonical = _getCanonicalFolder(folderName);
      return FolderInfo(
        id: folderName.toLowerCase(),
        displayName: folderName,
        canonicalName: canonical,
        messageCount: _getMessageCountForFolder(folderName),
        isWritable: true,
      );
    }).toList();
  }

  /// Get canonical folder type for folder name
  CanonicalFolder _getCanonicalFolder(String folderName) {
    switch (folderName.toUpperCase()) {
      case 'INBOX':
        return CanonicalFolder.inbox;
      case 'SPAM':
      case 'JUNK':
        return CanonicalFolder.junk;
      case 'TRASH':
        return CanonicalFolder.trash;
      case 'PROMOTIONS':
        return CanonicalFolder.custom;
      default:
        return CanonicalFolder.custom;
    }
  }

  /// Get message count for demo folder
  int _getMessageCountForFolder(String folderName) {
    final allEmails = MockEmailData.generateSampleEmails();
    return allEmails.where((e) => e.folderName == folderName).length;
  }

  @override
  Future<ConnectionStatus> testConnection() async {
    // Simulate connection test
    await Future.delayed(Duration(milliseconds: _operationDelayMs));

    return ConnectionStatus.success(serverInfo: {
      'provider': 'Demo Mode',
      'version': '1.0.0',
      'emailCount': MockEmailData.generateSampleEmails().length,
      'folders': MockEmailData.getDemoFolders().length,
    });
  }

  @override
  Future<void> disconnect() async {
    // Simulate disconnection
    await Future.delayed(Duration(milliseconds: _operationDelayMs ~/ 2));
    // Clear action log on disconnect
    _actionLog.clear();
  }
}
