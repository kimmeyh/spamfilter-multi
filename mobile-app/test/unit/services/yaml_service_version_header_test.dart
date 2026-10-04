/// F236 (Sprint 75): a version and date header in YAML rule exports.
///
/// Before: an exported rules.yaml or rules_safe_senders.yaml did not say
/// which app version produced it. After: the first line reads
/// `# Exported by MyEmailSpamFilter <version> on <yyyy-mm-dd>`, and importing
/// the file ignores the comment.
///
/// ADR-0042 parity: Android and iOS save the text from `renderRules` /
/// `renderSafeSenders`; Windows writes the file through `exportRules` /
/// `exportSafeSenders`. Both paths are tested, because the first version of
/// this change put the header on the mobile path only.
///
/// What these do NOT catch: that the Import/Export screen passes the REAL
/// app version (it reads `AppVersion.get()`; pinned by a source gate below,
/// not a behavior test), and third-party YAML readers that reject comments.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';
import 'package:my_email_spam_filter/core/models/safe_sender_list.dart';
import 'package:my_email_spam_filter/core/services/yaml_service.dart';

RuleSet _ruleSet() => RuleSet(
      version: '1.0',
      settings: const {},
      rules: [
        Rule(
          name: 'blockspam',
          enabled: true,
          isLocal: true,
          executionOrder: 10,
          conditions: RuleConditions(
            type: 'OR',
            header: [r'@(?:[a-z0-9-]+\.)*spam\.com$'],
          ),
          actions: RuleActions(delete: true),
        ),
      ],
    );

SafeSenderList _senders() => SafeSenderList(
    safeSenders: [r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$']);

final _header =
    RegExp(r'^# Exported by MyEmailSpamFilter 0\.17\.0 on \d{4}-\d{2}-\d{2}$');

void main() {
  final yaml = YamlService();

  group('mobile path (render)', () {
    test('rules export starts with the version header', () {
      final text = yaml.renderRules(_ruleSet(), appVersion: '0.17.0');
      expect(text.split('\n').first.trim(), matches(_header));
    });

    test('safe senders export starts with the version header', () {
      final text = yaml.renderSafeSenders(_senders(), appVersion: '0.17.0');
      expect(text.split('\n').first.trim(), matches(_header));
    });

    test('no version given, no header', () {
      expect(yaml.renderRules(_ruleSet()).startsWith('#'), isFalse);
    });

    test('import ignores the header (round trip)', () {
      final rules = yaml.parseRulesFromString(
          yaml.renderRules(_ruleSet(), appVersion: '0.17.0'));
      expect(rules.rules.single.name, 'blockspam');
      expect(rules.rules.single.conditions.header,
          [r'@(?:[a-z0-9-]+\.)*spam\.com$']);
      final senders = yaml.parseSafeSendersFromString(
          yaml.renderSafeSenders(_senders(), appVersion: '0.17.0'));
      expect(senders.safeSenders, [r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$']);
    });
  });

  group('Windows path (file export)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('f236_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('rules and safe senders files start with the version header',
        () async {
      final rulesPath = '${dir.path}/rules.yaml';
      final sendersPath = '${dir.path}/rules_safe_senders.yaml';
      await yaml.exportRules(_ruleSet(), rulesPath, appVersion: '0.17.0');
      await yaml.exportSafeSenders(_senders(), sendersPath,
          appVersion: '0.17.0');
      expect(File(rulesPath).readAsLinesSync().first.trim(), matches(_header));
      expect(
          File(sendersPath).readAsLinesSync().first.trim(), matches(_header));
    });
  });

  test('the screen passes AppVersion.get() to BOTH paths (source gate)', () {
    final src =
        File('lib/ui/screens/yaml_import_export_screen.dart').readAsStringSync();
    expect('await AppVersion.get()'.allMatches(src).length, 2);
    for (final call in [
      'renderRules(ruleSet, appVersion: appVersion)',
      'renderSafeSenders(safeSenders, appVersion: appVersion)',
      'exportRules(ruleSet, path, appVersion: appVersion)',
    ]) {
      expect(src, contains(call));
    }
    expect(
        RegExp(r'exportSafeSenders\(safeSenders, path,\s+appVersion: appVersion\)')
            .hasMatch(src),
        isTrue);
  });
}
