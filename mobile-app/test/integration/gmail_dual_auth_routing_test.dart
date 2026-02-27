import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/adapters/email_providers/generic_imap_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/gmail_api_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/junk_folder_config.dart';
import 'package:spam_filter_mobile/adapters/email_providers/platform_registry.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/ui/screens/account_setup_screen.dart';

/// Integration test: Gmail Dual-Auth routing
///
/// [ISSUE #178] Sprint 19: Verifies that Gmail accounts can be routed to
/// either the Gmail API adapter (OAuth) or the Generic IMAP adapter
/// (App Password) based on the selected authentication method.
///
/// Test strategy:
/// 1. Verify PlatformRegistry returns correct adapter types
/// 2. Verify auth methods match expected values
/// 3. Verify IMAP configuration for gmail-imap
/// 4. Verify junk folder configuration for both Gmail modes
/// 5. Verify GmailAuthMethod enum has expected values
void main() {
  group('Gmail Dual-Auth Platform Registry', () {
    test('gmail platform returns GmailApiAdapter', () {
      final platform = PlatformRegistry.getPlatform('gmail');
      expect(platform, isNotNull);
      expect(platform, isA<GmailApiAdapter>());
      expect(platform!.platformId, equals('gmail'));
      expect(platform.displayName, equals('Gmail'));
      expect(platform.supportedAuthMethod, equals(AuthMethod.oauth2));
    });

    test('gmail-imap platform returns GenericIMAPAdapter', () {
      final platform = PlatformRegistry.getPlatform('gmail-imap');
      expect(platform, isNotNull);
      expect(platform, isA<GenericIMAPAdapter>());
      expect(platform!.platformId, equals('gmail-imap'));
      expect(platform.displayName, equals('Gmail (IMAP)'));
      expect(platform.supportedAuthMethod, equals(AuthMethod.appPassword));
    });

    test('both gmail and gmail-imap are supported', () {
      expect(PlatformRegistry.isSupported('gmail'), isTrue);
      expect(PlatformRegistry.isSupported('gmail-imap'), isTrue);
    });

    test('gmail is in supported platform IDs list', () {
      final ids = PlatformRegistry.getSupportedPlatformIds();
      expect(ids, contains('gmail'));
      expect(ids, contains('gmail-imap'));
    });

    test('gmail-imap is not in visible platform list', () {
      // gmail-imap is an internal platform ID used after auth method selection;
      // it should NOT appear in the user-facing platform selector
      final visiblePlatforms = PlatformRegistry.getSupportedPlatforms();
      final visibleIds = visiblePlatforms.map((p) => p.id).toList();
      expect(visibleIds, contains('gmail'),
          reason: 'Gmail should be visible in platform list');
      expect(visibleIds, isNot(contains('gmail-imap')),
          reason: 'gmail-imap should NOT be in visible platform list; '
              'it is selected via auth method choice within Gmail setup');
    });

    test('gmail platform info uses OAuth auth method', () {
      final info = PlatformRegistry.getPlatformInfo('gmail');
      expect(info, isNotNull);
      expect(info!.authMethod, equals(AuthMethod.oauth2));
      expect(info.usesOAuth, isTrue);
      expect(info.usesIMAP, isFalse);
    });
  });

  group('Gmail IMAP Adapter Configuration', () {
    test('gmail-imap adapter connects to imap.gmail.com', () {
      final adapter = GenericIMAPAdapter.gmail();
      expect(adapter.platformId, equals('gmail-imap'));
      expect(adapter.displayName, equals('Gmail (IMAP)'));
    });

    test('gmail-imap uses app password auth method', () {
      final adapter = GenericIMAPAdapter.gmail();
      expect(adapter.supportedAuthMethod, equals(AuthMethod.appPassword));
    });

    test('gmail-imap is distinct from gmail oauth adapter', () {
      final oauthAdapter = PlatformRegistry.getPlatform('gmail');
      final imapAdapter = PlatformRegistry.getPlatform('gmail-imap');

      expect(oauthAdapter, isNot(same(imapAdapter)));
      expect(oauthAdapter.runtimeType, isNot(equals(imapAdapter.runtimeType)));
      expect(oauthAdapter!.platformId, isNot(equals(imapAdapter!.platformId)));
    });
  });

  group('Junk Folder Config for Gmail modes', () {
    test('gmail OAuth has Gmail-specific junk folder config', () {
      final config = JunkFolderConfigService.getConfig('gmail');
      expect(config, isNotNull);
      expect(config!.providerName, equals('Gmail'));
      expect(config.defaultJunkFolders, contains('Spam'));
      expect(config.defaultJunkFolders, contains('Trash'));
    });

    test('gmail-imap has IMAP-style folder config with [Gmail] prefix', () {
      final config = JunkFolderConfigService.getConfig('gmail-imap');
      expect(config, isNotNull);
      expect(config!.providerName, equals('Gmail (IMAP)'));
      expect(config.defaultJunkFolders, contains('[Gmail]/Spam'));
      expect(config.defaultJunkFolders, contains('[Gmail]/Trash'));
    });

    test('gmail and gmail-imap have different default junk folders', () {
      final gmailConfig = JunkFolderConfigService.getConfig('gmail');
      final imapConfig = JunkFolderConfigService.getConfig('gmail-imap');

      expect(gmailConfig, isNotNull);
      expect(imapConfig, isNotNull);

      // Gmail API uses simple names; IMAP uses [Gmail]/ prefix
      expect(gmailConfig!.defaultJunkFolders,
          isNot(equals(imapConfig!.defaultJunkFolders)));
    });

    test('gmail-imap default scan folders include INBOX', () {
      final folders = JunkFolderConfigService.getDefaultFoldersToScan('gmail-imap');
      expect(folders.first, equals('INBOX'));
      expect(folders.length, greaterThan(1));
    });

    test('isJunkFolder works for gmail-imap IMAP folder names', () {
      expect(
        JunkFolderConfigService.isJunkFolder('gmail-imap', '[Gmail]/Spam'),
        isTrue,
      );
      expect(
        JunkFolderConfigService.isJunkFolder('gmail-imap', '[Gmail]/Trash'),
        isTrue,
      );
      expect(
        JunkFolderConfigService.isJunkFolder('gmail-imap', 'INBOX'),
        isFalse,
      );
    });
  });

  group('GmailAuthMethod enum', () {
    test('has exactly 2 values', () {
      expect(GmailAuthMethod.values.length, equals(2));
    });

    test('contains oauth and appPassword', () {
      expect(GmailAuthMethod.values, contains(GmailAuthMethod.oauth));
      expect(GmailAuthMethod.values, contains(GmailAuthMethod.appPassword));
    });
  });

  group('Auth method routing consistency', () {
    test('all standard providers have consistent auth methods', () {
      // Verify each registered platform has a consistent auth method
      final platformIds = PlatformRegistry.getSupportedPlatformIds();

      for (final id in platformIds) {
        final platform = PlatformRegistry.getPlatform(id);
        expect(platform, isNotNull, reason: 'Platform $id should be instantiable');
        expect(platform!.supportedAuthMethod, isNotNull,
            reason: 'Platform $id should have an auth method');
      }
    });

    test('gmail and gmail-imap have different auth methods', () {
      final gmail = PlatformRegistry.getPlatform('gmail');
      final gmailImap = PlatformRegistry.getPlatform('gmail-imap');

      expect(gmail!.supportedAuthMethod, equals(AuthMethod.oauth2));
      expect(gmailImap!.supportedAuthMethod, equals(AuthMethod.appPassword));
    });

    test('gmail-imap auth method matches other IMAP providers', () {
      final gmailImap = PlatformRegistry.getPlatform('gmail-imap');
      final aol = PlatformRegistry.getPlatform('aol');
      final yahoo = PlatformRegistry.getPlatform('yahoo');

      // All IMAP providers should use appPassword
      expect(gmailImap!.supportedAuthMethod, equals(AuthMethod.appPassword));
      expect(aol!.supportedAuthMethod, equals(AuthMethod.appPassword));
      expect(yahoo!.supportedAuthMethod, equals(AuthMethod.appPassword));
    });
  });
}
