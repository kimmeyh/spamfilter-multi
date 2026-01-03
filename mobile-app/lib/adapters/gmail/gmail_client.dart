/// Gmail API client wrapper with authenticated HTTP requests.
///
/// ## Usage
/// ```dart
/// final authService = GoogleAuthService();
/// final client = GmailClient(authService: authService);
///
/// final messages = await client.listMessages(query: 'in:inbox after:2025/01/01');
/// ```
///
/// ## Authentication
/// - Automatically refreshes tokens when expired
/// - Handles invalid_grant by prompting re-authentication
/// - Never exposes tokens to calling code
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:spam_filter_mobile/adapters/auth/google_auth_service.dart';
import 'package:spam_filter_mobile/util/redact.dart';

/// Gmail API base URL.
const String _gmailApiBase = 'https://gmail.googleapis.com/gmail/v1';

/// Gmail message summary (list view).
class GmailMessageSummary {
  final String id;
  final String threadId;

  GmailMessageSummary({required this.id, required this.threadId});

  factory GmailMessageSummary.fromJson(Map<String, dynamic> json) =>
      GmailMessageSummary(
        id: json['id'] as String,
        threadId: json['threadId'] as String,
      );
}

/// Gmail message with full content.
class GmailMessage {
  final String id;
  final String threadId;
  final List<String> labelIds;
  final String snippet;
  final Map<String, String> headers;
  final String? bodyPlainText;
  final String? bodyHtml;
  final int internalDate;

  GmailMessage({
    required this.id,
    required this.threadId,
    required this.labelIds,
    required this.snippet,
    required this.headers,
    this.bodyPlainText,
    this.bodyHtml,
    required this.internalDate,
  });

  String? get from => headers['From'];
  String? get to => headers['To'];
  String? get subject => headers['Subject'];
  String? get date => headers['Date'];
  
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(internalDate);
}

/// Gmail label (folder).
class GmailLabel {
  final String id;
  final String name;
  final String type;
  final int? messagesTotal;
  final int? messagesUnread;

  GmailLabel({
    required this.id,
    required this.name,
    required this.type,
    this.messagesTotal,
    this.messagesUnread,
  });

  factory GmailLabel.fromJson(Map<String, dynamic> json) => GmailLabel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'user',
        messagesTotal: json['messagesTotal'] as int?,
        messagesUnread: json['messagesUnread'] as int?,
      );
}

/// Result of a message list operation with pagination.
class MessageListResult {
  final List<GmailMessageSummary> messages;
  final String? nextPageToken;
  final int resultSizeEstimate;

  MessageListResult({
    required this.messages,
    this.nextPageToken,
    required this.resultSizeEstimate,
  });
}

/// Gmail API client with automatic token management.
class GmailClient {
  final GoogleAuthService _authService;
  final http.Client _httpClient;

  GmailClient({
    required GoogleAuthService authService,
    http.Client? httpClient,
  })  : _authService = authService,
        _httpClient = httpClient ?? http.Client();

  /// Get authenticated headers for API requests.
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      throw StateError('Not authenticated. Call signIn() first.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Make authenticated GET request.
  Future<Map<String, dynamic>> _get(String endpoint) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$_gmailApiBase$endpoint');

    Redact.logSafe('GET $endpoint');
    final response = await _httpClient.get(url, headers: headers);

    if (response.statusCode == 401) {
      // Token expired during request - try refresh
      Redact.logSafe('401 received, attempting token refresh');
      final refreshResult = await _authService.initialize();
      if (!refreshResult.success) {
        throw StateError('Session expired. Please sign in again.');
      }
      // Retry with new token
      final newHeaders = await _getAuthHeaders();
      final retryResponse = await _httpClient.get(url, headers: newHeaders);
      if (retryResponse.statusCode != 200) {
        throw Exception('Gmail API error: ${retryResponse.statusCode} ${retryResponse.body}');
      }
      return jsonDecode(retryResponse.body);
    }

    if (response.statusCode != 200) {
      throw Exception('Gmail API error: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// Make authenticated POST request.
  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$_gmailApiBase$endpoint');

    Redact.logSafe('POST $endpoint');
    final response = await _httpClient.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      Redact.logSafe('401 received, attempting token refresh');
      final refreshResult = await _authService.initialize();
      if (!refreshResult.success) {
        throw StateError('Session expired. Please sign in again.');
      }
      final newHeaders = await _getAuthHeaders();
      final retryResponse = await _httpClient.post(
        url,
        headers: newHeaders,
        body: jsonEncode(body),
      );
      if (retryResponse.statusCode != 200) {
        throw Exception('Gmail API error: ${retryResponse.statusCode} ${retryResponse.body}');
      }
      return jsonDecode(retryResponse.body);
    }

    if (response.statusCode != 200) {
      throw Exception('Gmail API error: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// Make authenticated DELETE request.
  Future<void> _delete(String endpoint) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$_gmailApiBase$endpoint');

    Redact.logSafe('DELETE $endpoint');
    final response = await _httpClient.delete(url, headers: headers);

    if (response.statusCode == 401) {
      Redact.logSafe('401 received, attempting token refresh');
      final refreshResult = await _authService.initialize();
      if (!refreshResult.success) {
        throw StateError('Session expired. Please sign in again.');
      }
      final newHeaders = await _getAuthHeaders();
      final retryResponse = await _httpClient.delete(url, headers: newHeaders);
      if (retryResponse.statusCode != 200 && retryResponse.statusCode != 204) {
        throw Exception('Gmail API error: ${retryResponse.statusCode} ${retryResponse.body}');
      }
      return;
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gmail API error: ${response.statusCode} ${response.body}');
    }
  }

  /// List messages matching a query.
  ///
  /// [query] uses Gmail search syntax (e.g., "in:inbox after:2025/01/01")
  /// [maxResults] limits the number of messages returned (default 100)
  /// [labelIds] filters by labels (e.g., ['INBOX'])
  Future<MessageListResult> listMessages({
    String? query,
    int maxResults = 100,
    String? pageToken,
    List<String>? labelIds,
  }) async {
    var endpoint = '/users/me/messages?maxResults=$maxResults';
    if (query != null) {
      endpoint += '&q=${Uri.encodeComponent(query)}';
    }
    if (pageToken != null) {
      endpoint += '&pageToken=$pageToken';
    }
    if (labelIds != null && labelIds.isNotEmpty) {
      for (final labelId in labelIds) {
        endpoint += '&labelIds=$labelId';
      }
    }

    final response = await _get(endpoint);
    final messages = (response['messages'] as List<dynamic>? ?? [])
        .map((m) => GmailMessageSummary.fromJson(m as Map<String, dynamic>))
        .toList();

    return MessageListResult(
      messages: messages,
      nextPageToken: response['nextPageToken'] as String?,
      resultSizeEstimate: response['resultSizeEstimate'] as int? ?? 0,
    );
  }

  /// Get full message by ID.
  ///
  /// [format] can be 'full', 'metadata', 'minimal', or 'raw'
  Future<GmailMessage> getMessage(String messageId, {String format = 'full'}) async {
    final response = await _get('/users/me/messages/$messageId?format=$format');

    final labelIds = List<String>.from(response['labelIds'] ?? []);
    final snippet = response['snippet'] as String? ?? '';
    final internalDate = int.parse(response['internalDate'] as String? ?? '0');

    // Parse headers
    final headers = <String, String>{};
    String? bodyPlainText;
    String? bodyHtml;
    
    final payload = response['payload'] as Map<String, dynamic>?;
    if (payload != null) {
      final headersList = payload['headers'] as List<dynamic>? ?? [];
      for (final h in headersList) {
        final header = h as Map<String, dynamic>;
        headers[header['name'] as String] = header['value'] as String;
      }

      // Extract body
      final body = payload['body'] as Map<String, dynamic>?;
      if (body != null && body['data'] != null) {
        final data = body['data'] as String;
        bodyPlainText = _decodeBase64Url(data);
      }

      // Check parts for multipart messages
      final parts = payload['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          final partData = part as Map<String, dynamic>;
          final mimeType = partData['mimeType'] as String?;
          final partBody = partData['body'] as Map<String, dynamic>?;
          
          if (partBody != null && partBody['data'] != null) {
            final data = partBody['data'] as String;
            final decoded = _decodeBase64Url(data);
            
            if (mimeType == 'text/plain') {
              bodyPlainText = decoded;
            } else if (mimeType == 'text/html') {
              bodyHtml = decoded;
            }
          }
        }
      }
    }

    return GmailMessage(
      id: response['id'] as String,
      threadId: response['threadId'] as String,
      labelIds: labelIds,
      snippet: snippet,
      headers: headers,
      bodyPlainText: bodyPlainText,
      bodyHtml: bodyHtml,
      internalDate: internalDate,
    );
  }

  /// Decode base64url encoded string.
  String _decodeBase64Url(String data) {
    try {
      // Add padding if needed
      var padded = data;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      // Convert base64url to standard base64
      final standard = padded.replaceAll('-', '+').replaceAll('_', '/');
      return utf8.decode(base64.decode(standard));
    } catch (e) {
      Redact.logSafe('Failed to decode base64url: ${e.runtimeType}');
      return '';
    }
  }

  /// Move message to trash.
  Future<void> trashMessage(String messageId) async {
    await _post('/users/me/messages/$messageId/trash', {});
    Redact.logSafe('Trashed message: $messageId');
  }

  /// Remove message from trash.
  Future<void> untrashMessage(String messageId) async {
    await _post('/users/me/messages/$messageId/untrash', {});
    Redact.logSafe('Untrashed message: $messageId');
  }

  /// Permanently delete message.
  Future<void> deleteMessage(String messageId) async {
    await _delete('/users/me/messages/$messageId');
    Redact.logSafe('Deleted message: $messageId');
  }

  /// Modify message labels.
  Future<void> modifyMessage(
    String messageId, {
    List<String>? addLabelIds,
    List<String>? removeLabelIds,
  }) async {
    final body = <String, dynamic>{};
    if (addLabelIds != null && addLabelIds.isNotEmpty) {
      body['addLabelIds'] = addLabelIds;
    }
    if (removeLabelIds != null && removeLabelIds.isNotEmpty) {
      body['removeLabelIds'] = removeLabelIds;
    }
    
    await _post('/users/me/messages/$messageId/modify', body);
    Redact.logSafe('Modified labels for message: $messageId');
  }

  /// Add labels to message.
  Future<void> addLabels(String messageId, List<String> labelIds) async {
    await modifyMessage(messageId, addLabelIds: labelIds);
  }

  /// Remove labels from message.
  Future<void> removeLabels(String messageId, List<String> labelIds) async {
    await modifyMessage(messageId, removeLabelIds: labelIds);
  }

  /// Mark message as read.
  Future<void> markAsRead(String messageId) async {
    await removeLabels(messageId, ['UNREAD']);
  }

  /// Mark message as unread.
  Future<void> markAsUnread(String messageId) async {
    await addLabels(messageId, ['UNREAD']);
  }

  /// List all labels (folders) in the mailbox.
  Future<List<GmailLabel>> listLabels() async {
    final response = await _get('/users/me/labels');
    final labels = (response['labels'] as List<dynamic>? ?? [])
        .map((l) => GmailLabel.fromJson(l as Map<String, dynamic>))
        .toList();
    return labels;
  }

  /// Get a specific label by ID.
  Future<GmailLabel> getLabel(String labelId) async {
    final response = await _get('/users/me/labels/$labelId');
    return GmailLabel.fromJson(response);
  }

  /// Get user profile (email address).
  Future<String> getUserEmail() async {
    final response = await _get('/users/me/profile');
    return response['emailAddress'] as String;
  }

  /// Get mailbox profile with message/thread counts.
  Future<Map<String, dynamic>> getProfile() async {
    return await _get('/users/me/profile');
  }

  /// Batch modify messages (add/remove labels in bulk).
  Future<void> batchModify({
    required List<String> messageIds,
    List<String>? addLabelIds,
    List<String>? removeLabelIds,
  }) async {
    final body = <String, dynamic>{
      'ids': messageIds,
    };
    if (addLabelIds != null && addLabelIds.isNotEmpty) {
      body['addLabelIds'] = addLabelIds;
    }
    if (removeLabelIds != null && removeLabelIds.isNotEmpty) {
      body['removeLabelIds'] = removeLabelIds;
    }

    await _post('/users/me/messages/batchModify', body);
    Redact.logSafe('Batch modified ${messageIds.length} messages');
  }

  /// Batch delete messages permanently.
  Future<void> batchDelete(List<String> messageIds) async {
    await _post('/users/me/messages/batchDelete', {'ids': messageIds});
    Redact.logSafe('Batch deleted ${messageIds.length} messages');
  }

  /// Close the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
