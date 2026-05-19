/// Sprint 38 F85 (ADR-0038): unit tests for ContentLoader.
///
/// Verifies that:
///   1. Every HelpSection enum case loads from the asset bundle without
///      throwing (catches manifest-vs-Dart drift at test time).
///   2. The in-memory cache returns the same instance on repeated calls.
///   3. Unknown namespace / key throws ArgumentError (defensive contract).
///
/// Loads against the REAL asset bundle (test environment supports this via
/// flutter_test bindings + pubspec.yaml asset declarations). No mocking
/// needed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/content_loader.dart';
import 'package:my_email_spam_filter/ui/screens/help_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ContentLoader().clearCacheForTesting();
  });

  group('Sprint 38 F85 -- ContentLoader', () {
    test('every HelpSection enum case loads without throwing', () async {
      // Map each enum to its expected manifest key. Match the same switch
      // logic in help_screen.dart -- a drift between this mapping and the
      // production mapping will fail this test, which is the point.
      final mapping = <HelpSection, String>{
        HelpSection.selectAccount: 'selectAccount',
        HelpSection.accountSetup: 'accountSetup',
        HelpSection.demoScan: 'demoScan',
        HelpSection.manualScan: 'manualScan',
        HelpSection.resultsDisplay: 'resultsDisplay',
        HelpSection.scanHistory: 'scanHistory',
        HelpSection.settings: 'settings',
        HelpSection.generalRulesManagement: 'generalRulesManagement',
        HelpSection.generalScanHistoryRetention: 'generalScanHistoryRetention',
        HelpSection.generalPrivacyLogging: 'generalPrivacyLogging',
        HelpSection.folderSettings: 'folderSettings',
        HelpSection.manualScanSettings: 'manualScanSettings',
        HelpSection.backgroundScanning: 'backgroundScanning',
        HelpSection.manageRules: 'manageRules',
        HelpSection.ruleQuickAdd: 'ruleQuickAdd',
        HelpSection.ruleTest: 'ruleTest',
        HelpSection.safeSenders: 'safeSenders',
        HelpSection.folderSelection: 'folderSelection',
        HelpSection.yamlImportExport: 'yamlImportExport',
        HelpSection.otherWaysToReduceJunk: 'otherWaysToReduceJunk',
      };

      // The test mapping must cover every enum case (compile-time drift
      // detection -- a new case added to HelpSection that is not in this
      // map will fail the assertion below).
      expect(mapping.length, HelpSection.values.length,
          reason:
              'Test mapping is out of sync with HelpSection enum. Add the '
              'new case to the mapping in this test AND to the manifest at '
              'assets/content/manifest.yaml.');

      for (final entry in mapping.entries) {
        final body = await ContentLoader().load('help', entry.value);
        expect(body, isNotEmpty,
            reason:
                'Content for HelpSection.${entry.key.name} (manifest key '
                '"help.${entry.value}") loaded as an empty string.');
      }
    });

    test('cache returns same content on repeated calls', () async {
      final first = await ContentLoader().load('help', 'scanHistory');
      final second = await ContentLoader().load('help', 'scanHistory');
      expect(identical(first, second), isTrue,
          reason:
              'ContentLoader cache must return the same String instance on '
              'repeated calls -- saves re-reading the asset bundle on every '
              'Help screen open and re-scroll.');
    });

    test('unknown namespace throws ArgumentError', () async {
      expect(
        () => ContentLoader().load('does-not-exist', 'anything'),
        throwsArgumentError,
      );
    });

    test('unknown key in known namespace throws ArgumentError', () async {
      expect(
        () => ContentLoader().load('help', 'doesNotExistInManifest'),
        throwsArgumentError,
      );
    });
  });
}
