/// Registry and factory for all supported email platform adapters
/// 
/// This module provides:
/// - Platform discovery and instantiation
/// - Platform metadata (name, icon, auth method)
/// - Phase-based feature rollout information
library;

import 'spam_filter_platform.dart';
import 'generic_imap_adapter.dart';
import 'gmail_api_adapter.dart';
// import 'gmail_adapter.dart';  // Phase 2 legacy stub
// import 'outlook_adapter.dart';  // Phase 2

/// Registry of all supported email platforms
class PlatformRegistry {
  /// Private constructor to prevent instantiation
  PlatformRegistry._();

  /// Factory methods for creating platform adapters
  static final Map<String, SpamFilterPlatform Function()> _factories = {
    'aol': () => GenericIMAPAdapter.aol(),
    'gmail': () => GmailApiAdapter(),
    'yahoo': () => GenericIMAPAdapter.yahoo(),
    'icloud': () => GenericIMAPAdapter.icloud(),
    'imap': () => GenericIMAPAdapter.custom(),
    // Phase 2 additions:
    // 'gmail': () => GmailAdapter(),
    // 'outlook': () => OutlookAdapter(),
  };

  /// Get platform instance by ID
  /// 
  /// Returns null if platform ID is not recognized
  static SpamFilterPlatform? getPlatform(String platformId) {
    final factory = _factories[platformId];
    return factory?.call();
  }

  /// Check if a platform is supported
  static bool isSupported(String platformId) {
    return _factories.containsKey(platformId);
  }

  /// Get all supported platform IDs
  static List<String> getSupportedPlatformIds() {
    return _factories.keys.toList();
  }

  /// Get metadata for all supported platforms
  /// 
  /// Returns list sorted by implementation phase and display name
  static List<PlatformInfo> getSupportedPlatforms() {
    return [
      // Phase 1 - MVP (IMAP-based)
      PlatformInfo(
        id: 'aol',
        displayName: 'AOL Mail',
        phase: 1,
        authMethod: AuthMethod.appPassword,
        icon: 'assets/icons/aol.png',
        description: 'AOL Mail via IMAP (requires app password)',
        setupInstructions: 'Go to AOL Account Security → Generate app password',
        imapConfig: IMAPConfig(
          host: 'imap.aol.com',
          port: 993,
          isSecure: true,
        ),
      ),

      // Gmail OAuth now available (native API)
      PlatformInfo(
        id: 'gmail',
        displayName: 'Gmail',
        phase: 1, // Make selectable in the provider list
        authMethod: AuthMethod.oauth2,
        icon: 'assets/icons/gmail.png',
        description: 'Google Gmail via Gmail API (OAuth 2.0 sign-in)',
        setupInstructions: 'Sign in with your Google account',
      ),
      
      // PlatformInfo(
      //   id: 'outlook',
      //   displayName: 'Outlook / Office 365',
      //   phase: 2,
      //   authMethod: AuthMethod.oauth2,
      //   icon: 'assets/icons/outlook.png',
      //   description: 'Microsoft Outlook via Graph API',
      //   setupInstructions: 'Sign in with your Microsoft account',
      // ),

      PlatformInfo(
        id: 'yahoo',
        displayName: 'Yahoo Mail',
        phase: 2,
        authMethod: AuthMethod.appPassword,
        icon: 'assets/icons/yahoo.png',
        description: 'Yahoo Mail via IMAP (requires app password)',
        setupInstructions: 'Go to Yahoo Account Security → Generate app password',
        imapConfig: IMAPConfig(
          host: 'imap.mail.yahoo.com',
          port: 993,
          isSecure: true,
        ),
      ),

      // Phase 3 - Additional consumer platforms
      PlatformInfo(
        id: 'icloud',
        displayName: 'iCloud Mail',
        phase: 3,
        authMethod: AuthMethod.appPassword,
        icon: 'assets/icons/icloud.png',
        description: 'Apple iCloud Mail via IMAP (requires app-specific password)',
        setupInstructions: 'Go to Apple ID → Security → Generate app-specific password',
        imapConfig: IMAPConfig(
          host: 'imap.mail.me.com',
          port: 993,
          isSecure: true,
        ),
      ),

      // Phase 4 - Custom IMAP
      PlatformInfo(
        id: 'imap',
        displayName: 'Custom IMAP Server',
        phase: 4,
        authMethod: AuthMethod.basicAuth,
        icon: 'assets/icons/generic.png',
        description: 'Any email server with IMAP support',
        setupInstructions: 'Enter your IMAP server details manually',
      ),
    ];
  }

  /// Get platforms available in a specific phase
  static List<PlatformInfo> getPlatformsByPhase(int phase) {
    return getSupportedPlatforms()
        .where((info) => info.phase <= phase)
        .toList();
  }

  /// Get platform metadata by ID
  static PlatformInfo? getPlatformInfo(String platformId) {
    return getSupportedPlatforms()
        .where((info) => info.id == platformId)
        .firstOrNull;
  }
}

/// Metadata about an email platform
class PlatformInfo {
  /// Unique identifier (matches factory key)
  final String id;

  /// Display name for UI
  final String displayName;

  /// Implementation phase (1=MVP, 2=Native APIs, etc.)
  final int phase;

  /// Authentication method required
  final AuthMethod authMethod;

  /// Path to platform icon asset
  final String icon;

  /// User-friendly description
  final String description;

  /// Setup instructions for users
  final String setupInstructions;

  /// IMAP configuration (if applicable)
  final IMAPConfig? imapConfig;

  const PlatformInfo({
    required this.id,
    required this.displayName,
    required this.phase,
    required this.authMethod,
    required this.icon,
    required this.description,
    required this.setupInstructions,
    this.imapConfig,
  });

  /// Whether this platform uses OAuth
  bool get usesOAuth => authMethod == AuthMethod.oauth2;

  /// Whether this platform uses IMAP
  bool get usesIMAP => imapConfig != null;

  @override
  String toString() => '$displayName (Phase $phase, ${authMethod.name})';
}

/// IMAP server configuration
class IMAPConfig {
  /// IMAP server hostname
  final String host;

  /// IMAP server port (typically 993 for SSL)
  final int port;

  /// Whether to use SSL/TLS
  final bool isSecure;

  const IMAPConfig({
    required this.host,
    required this.port,
    this.isSecure = true,
  });

  @override
  String toString() => '$host:$port${isSecure ? ' (SSL)' : ''}';
}
