import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// F119 (Sprint 47) policy gate: the 0.5.4 Store MSIX shipped running as
/// APP_ENV=dev (and with empty OAuth credentials) because `msix_config` in
/// pubspec.yaml used the WRONG key `build_windows_args`. The msix package
/// (3.16.x) reads `windows_build_args`; the wrong key was silently ignored,
/// so the inner `flutter build windows` ran with no dart-defines and
/// APP_ENV fell back to its 'dev' default.
///
/// These assertions make that exact failure mode a FAILING TEST instead of a
/// silent Store-shipping bug:
/// 1. The typo'd key `build_windows_args` must NEVER appear (msix ignores it).
/// 2. The correct key `windows_build_args` must be present and must inject
///    `APP_ENV=prod` and the prod secrets file.
void main() {
  late YamlMap msixConfig;

  setUpAll(() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final doc = loadYaml(pubspec) as YamlMap;
    msixConfig = doc['msix_config'] as YamlMap;
  });

  group('msix_config windows-build-args (F119)', () {
    test('the typo key build_windows_args is absent (msix silently ignores it)',
        () {
      expect(
        msixConfig.containsKey('build_windows_args'),
        isFalse,
        reason: 'F119: `build_windows_args` is NOT a real msix key -- the '
            'package reads `windows_build_args`. Using the typo ships an '
            'MSIX that runs as dev with empty OAuth credentials.',
      );
    });

    test('windows_build_args is present and injects APP_ENV=prod + secrets',
        () {
      expect(msixConfig.containsKey('windows_build_args'), isTrue,
          reason: 'F119: required so msix:create forwards dart-defines to the '
              'inner flutter build windows.');
      final args = msixConfig['windows_build_args'].toString();
      expect(args, contains('--dart-define=APP_ENV=prod'),
          reason: 'F119: without APP_ENV=prod the Store MSIX runs as dev '
              '([DEV] title/About + _Dev data dir).');
      expect(args, contains('secrets.prod.json'),
          reason: 'F119: without the prod secrets file the MSIX ships with '
              'empty OAuth credentials (silent Gmail sign-in failure).');
    });

    test('store submission flags are set (store:true, install_certificate:false)',
        () {
      expect(msixConfig['store'], isTrue);
      expect(msixConfig['install_certificate'], isFalse);
    });
  });
}
