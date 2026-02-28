/// Junk folder configuration per email provider
/// 
/// This service manages provider-specific junk folder names and scanning logic.
/// Each email provider has unique folder naming conventions for spam/junk/bulk mail.
/// 
/// Phase 2 Sprint 3 Enhancement: Default checking of junk folders for each account
library;

import 'package:logger/logger.dart';

/// Configuration for junk folders per provider
class JunkFolderConfig {
  /// Email provider ID (e.g., 'aol', 'gmail', 'outlook')
  final String providerId;

  /// Display name for the provider
  final String providerName;

  /// List of canonical folder names to scan by default
  /// (in addition to INBOX)
  final List<String> defaultJunkFolders;

  /// Alternative/legacy folder names that may exist on some servers
  final List<String> alternativeFolderNames;

  /// Whether this provider supports custom folder creation
  final bool supportsCustomFolders;

  JunkFolderConfig({
    required this.providerId,
    required this.providerName,
    required this.defaultJunkFolders,
    this.alternativeFolderNames = const [],
    this.supportsCustomFolders = true,
  });

  /// Get all folder names to scan (includes alternatives for search)
  List<String> getAllFolderNamesToScan() {
    return <String>[...defaultJunkFolders, ...alternativeFolderNames];
  }
}

/// Service for managing junk folder configuration
class JunkFolderConfigService {
  static final Logger _logger = Logger();

  /// Provider-specific junk folder configurations
  /// Updated December 17, 2025: Added default scanning of junk folders
  static final Map<String, JunkFolderConfig> _providerConfigs = {
    'aol': JunkFolderConfig(
      providerId: 'aol',
      providerName: 'AOL Mail',
      defaultJunkFolders: ['Bulk Mail', 'Spam'],
      alternativeFolderNames: ['Junk', 'Spam Folder', 'Bulk'],
      supportsCustomFolders: true,
    ),
    'gmail': JunkFolderConfig(
      providerId: 'gmail',
      providerName: 'Gmail',
      // Gmail uses labels, not folders
      // In GmailApiAdapter, these are mapped to label queries
      defaultJunkFolders: ['Spam', 'Trash'],
      alternativeFolderNames: ['[Gmail]/Spam', '[Gmail]/Trash', 'SPAM', 'TRASH'],
      supportsCustomFolders: false, // Gmail uses labels, not custom folders
    ),
    // [ISSUE #178] Gmail IMAP: Uses standard IMAP folder structure with [Gmail] prefix
    'gmail-imap': JunkFolderConfig(
      providerId: 'gmail-imap',
      providerName: 'Gmail (IMAP)',
      defaultJunkFolders: ['[Gmail]/Spam', '[Gmail]/Trash'],
      alternativeFolderNames: ['Spam', 'Trash', 'SPAM', 'TRASH', '[Gmail]/All Mail'],
      supportsCustomFolders: false,
    ),
    'yahoo': JunkFolderConfig(
      providerId: 'yahoo',
      providerName: 'Yahoo Mail',
      defaultJunkFolders: ['Bulk', 'Spam'],
      alternativeFolderNames: ['Junk', 'Bulk Mail', 'Junk E-mail'],
      supportsCustomFolders: true,
    ),
    'icloud': JunkFolderConfig(
      providerId: 'icloud',
      providerName: 'iCloud Mail',
      defaultJunkFolders: ['Junk', 'Trash'],
      alternativeFolderNames: ['Spam', 'Junk Mail', 'JUNK'],
      supportsCustomFolders: true,
    ),
    'outlook': JunkFolderConfig(
      providerId: 'outlook',
      providerName: 'Outlook.com',
      defaultJunkFolders: ['Junk Email', 'Spam', 'Trash'],
      alternativeFolderNames: ['Junk', 'Deleted Items', '[Outlook]/Junk'],
      supportsCustomFolders: false, // Outlook uses well-known folders
    ),
    'protonmail': JunkFolderConfig(
      providerId: 'protonmail',
      providerName: 'ProtonMail',
      defaultJunkFolders: ['Spam', 'Trash'],
      alternativeFolderNames: [],
      supportsCustomFolders: true,
    ),
    // Generic IMAP servers typically use standard folder names
    'imap': JunkFolderConfig(
      providerId: 'imap',
      providerName: 'IMAP Server',
      defaultJunkFolders: ['Spam', 'Junk', 'Trash'],
      alternativeFolderNames: ['Bulk', 'Spam Folder', 'Deleted', 'Deleted Items'],
      supportsCustomFolders: true,
    ),
  };

  /// Get configuration for a specific provider
  static JunkFolderConfig? getConfig(String providerId) {
    final config = _providerConfigs[providerId.toLowerCase()];
    if (config == null) {
      _logger.w('No junk folder config for provider: $providerId, using generic IMAP defaults');
      return _providerConfigs['imap'];
    }
    return config;
  }

  /// Get default junk folders for a provider
  static List<String> getDefaultJunkFolders(String providerId) {
    return getConfig(providerId)?.defaultJunkFolders ?? [];
  }

  /// Check if a folder name is a junk folder for the given provider
  /// (handles case-insensitive matching and alternatives)
  static bool isJunkFolder(String providerId, String folderName) {
    final config = getConfig(providerId);
    if (config == null) return false;

    final folderLower = folderName.toLowerCase();
    final allNames = config.getAllFolderNamesToScan();

    return allNames.any((name) => name.toLowerCase() == folderLower);
  }

  /// Get the canonical folder name for a given folder
  /// (matches user-provided folder against config and returns canonical name)
  static String? getCanonicalFolderName(String providerId, String folderName) {
    final config = getConfig(providerId);
    if (config == null) return folderName;

    final folderLower = folderName.toLowerCase();

    // Check default folders first
    for (final defaultFolder in config.defaultJunkFolders) {
      if (defaultFolder.toLowerCase() == folderLower) {
        return defaultFolder;
      }
    }

    // Check alternative names
    for (final altFolder in config.alternativeFolderNames) {
      if (altFolder.toLowerCase() == folderLower) {
        // Return the canonical (default) version
        return config.defaultJunkFolders.first;
      }
    }

    // Not a junk folder
    return null;
  }

  /// Get all providers with their configs
  static List<JunkFolderConfig> getAllConfigs() {
    return _providerConfigs.values.toList();
  }

  /// Get default folders to scan for a provider (INBOX + junk folders)
  /// This is used for default scan configuration
  static List<String> getDefaultFoldersToScan(String providerId) {
    final junkFolders = getDefaultJunkFolders(providerId);
    // Always include INBOX first
    return <String>['INBOX', ...junkFolders];
  }

  /// Log all configurations (for debugging)
  static void logAllConfigs() {
    _logger.i('=== Junk Folder Configurations ===');
    for (final config in _providerConfigs.values) {
      _logger.i(
        '${config.providerName}: ${config.defaultJunkFolders.join(', ')}',
      );
    }
  }
}
