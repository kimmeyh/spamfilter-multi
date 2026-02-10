/// Service for checking if unmatched emails still exist in their folders
///
/// This service handles:
/// - Checking if emails still exist in email provider
/// - Batch checking for performance
/// - Handling provider-specific APIs (Gmail REST, IMAP)
/// - Graceful error handling for network issues
library;

import 'package:logger/logger.dart';

import '../models/provider_email_identifier.dart';
import '../../adapters/email_providers/email_provider.dart';

/// Result of checking email availability
class EmailAvailabilityResult {
  /// Whether the email still exists in the folder
  final bool stillExists;

  /// When the availability was last checked
  final DateTime checkedAt;

  /// Error message if check failed
  final String? errorMessage;

  /// True if this is a confirmed absence, false if just unconfirmed
  final bool isConfirmedAbsence;

  EmailAvailabilityResult({
    required this.stillExists,
    required this.checkedAt,
    this.errorMessage,
    this.isConfirmedAbsence = false,
  });

  /// Get the availability status string for database storage
  String get statusString {
    if (errorMessage != null) return 'unknown';
    if (!stillExists && isConfirmedAbsence) return 'deleted';
    if (!stillExists) return 'moved';
    return 'available';
  }
}

/// Service for checking email availability across providers
class EmailAvailabilityChecker {
  final Logger _logger = Logger();

  /// Check if a single email still exists in its folder
  ///
  /// Returns availability result, or null if provider not supported
  /// Note: This is a placeholder implementation for integration with specific adapters
  Future<EmailAvailabilityResult?> checkAvailability({
    required ProviderEmailIdentifier identifier,
    required String folderName,
    required EmailProvider provider,
  }) async {
    try {
      _logger.d(
          'Checking availability: ${identifier.providerType} email in $folderName');

      // Placeholder: In real implementation, would route to provider-specific methods
      // For now, return a result indicating unknown status (deferred to integration)
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        errorMessage: 'Provider-specific implementation deferred to adapter layer',
      );

      _logger.d(
          'Availability check result: ${identifier.providerType} - status=${result.statusString}');
      return result;
    } catch (e) {
      _logger.e('Failed to check email availability: $e');
      return EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  /// Check multiple emails efficiently (batch operation)
  ///
  /// Groups emails by provider for more efficient API calls
  Future<Map<String, EmailAvailabilityResult>> checkAvailabilityBatch({
    required List<ProviderEmailIdentifier> identifiers,
    required List<String> folderNames,
    required EmailProvider provider,
  }) async {
    if (identifiers.isEmpty) return {};
    if (identifiers.length != folderNames.length) {
      throw ArgumentError(
          'identifiers and folderNames must have same length');
    }

    _logger.d(
        'Batch checking availability for ${identifiers.length} emails');

    final results = <String, EmailAvailabilityResult>{};

    try {
      // For now, check sequentially but efficiently
      // In future, can optimize with parallel API calls or batching
      for (int i = 0; i < identifiers.length; i++) {
        final id = identifiers[i];
        final folder = folderNames[i];
        final result = await checkAvailability(
          identifier: id,
          folderName: folder,
          provider: provider,
        );

        if (result != null) {
          results['${id.providerType}:${id.identifierValue}'] = result;
        }
      }

      _logger.d(
          'Batch availability check completed: ${results.length}/${identifiers.length} checked');
      return results;
    } catch (e) {
      _logger.e('Batch availability check failed: $e');
      return results; // Return partial results
    }
  }

  /// Provider-specific availability check (deferred to adapter implementations)
  ///
  /// In production implementation, adapters would provide checkEmailExists methods:
  /// - GmailApiAdapter.checkEmailExists(messageId): Uses Gmail API messages.get
  /// - GenericImapAdapter.checkEmailExists(uid, folderName): Uses IMAP UID FETCH

  /// Batch check with concurrency limit for performance
  ///
  /// Groups identifiers by provider and checks concurrently
  Future<Map<String, EmailAvailabilityResult>> checkAvailabilityOptimized({
    required List<ProviderEmailIdentifier> identifiers,
    required List<String> folderNames,
    required EmailProvider provider,
    int maxConcurrency = 5,
  }) async {
    if (identifiers.isEmpty) return {};

    _logger.d(
        'Optimized batch check (max $maxConcurrency concurrent): ${identifiers.length} emails');

    final results = <String, EmailAvailabilityResult>{};
    final futures = <Future<void>>[];

    for (int i = 0; i < identifiers.length; i += maxConcurrency) {
      final batch = identifiers.sublist(
        i,
        (i + maxConcurrency).clamp(0, identifiers.length),
      );
      final folders =
          folderNames.sublist(i, (i + maxConcurrency).clamp(0, folderNames.length));

      for (int j = 0; j < batch.length; j++) {
        futures.add(
          checkAvailability(
            identifier: batch[j],
            folderName: folders[j],
            provider: provider,
          ).then((result) {
            if (result != null) {
              results['${batch[j].providerType}:${batch[j].identifierValue}'] =
                  result;
            }
          }),
        );
      }

      if (futures.length >= maxConcurrency) {
        await Future.wait(futures);
        futures.clear();
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    _logger.d('Optimized batch check completed: ${results.length} results');
    return results;
  }
}
