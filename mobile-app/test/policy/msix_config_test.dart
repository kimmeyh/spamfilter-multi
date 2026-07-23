import 'dart:convert';
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
/// F119-b (Sprint 47, post-0.5.5): the 0.5.5 Store MSIX ALSO shipped as
/// APP_ENV=dev -- a SECOND, independent cause. `secrets.prod.json` contained a
/// JSON key with SPACES in its name (`"comment OR try this"`). `--dart-define-
/// from-file` turns every JSON key into a `key=value` dart-define, and a key
/// with spaces corrupts flutter's dart-define stream during the build, silently
/// dropping `APP_ENV=prod` -> the app falls back to its 'dev' default. The
/// build log still echoed the correct command, so Step 4.0's log check passed
/// while the compiled build was dev. The `_wellFormedSecrets` test below makes
/// that malformed-key class a FAILING TEST.
///
/// These assertions make those exact failure modes FAILING TESTS instead of
/// silent Store-shipping bugs:
/// 1. The typo'd key `build_windows_args` must NEVER appear (msix ignores it).
/// 2. The correct key `windows_build_args` must be present and must inject
///    `APP_ENV=prod` and the prod secrets file.
/// 3. Every dart-define-from-file secrets JSON present in the worktree must
///    have ONLY well-formed keys (no spaces, no empty keys) so no key silently
///    corrupts the dart-define stream at build time.
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

  group('native APP_ENV derivation (F119-c)', () {
    // WHY: the native runner's window title is compiled from the
    // SPAMFILTER_APP_ENV CMake definition. The Sprint 37 design read ONLY an
    // environment variable that the Store MSIX path never set, so the 0.5.5
    // AND 0.5.6 Store releases shipped a "[DEV]" native title on a
    // correctly-prod Dart build. F119-c derives the CMake value from the
    // APP_ENV dart-define recorded in ephemeral/generated_config.cmake
    // (base64("APP_ENV=prod") == "QVBQX0VOVj1wcm9k", deterministic), and the
    // runner passes its compiled value to Dart (--native-app-env=) so the
    // --print-env probe verifies BOTH compiled sides. These pins fail if any
    // link of that chain is removed.
    test('runner/CMakeLists.txt derives SPAMFILTER_APP_ENV from the '
        'APP_ENV dart-define (not env-var-only)', () {
      final cmake =
          File('windows/runner/CMakeLists.txt').readAsStringSync();
      expect(cmake, contains('QVBQX0VOVj1wcm9k'),
          reason: 'F119-c: CMake must match the base64 APP_ENV=prod token '
              'from generated_config.cmake -- env-var-only sourcing shipped '
              '[DEV] titles to the Store twice (0.5.5, 0.5.6).');
      expect(cmake, contains('generated_config.cmake'),
          reason: 'F119-c: the dart-define source is the flutter-generated '
              'ephemeral/generated_config.cmake.');
    });

    test('main.cpp passes the native env to Dart via --native-app-env', () {
      final mainCpp = File('windows/runner/main.cpp').readAsStringSync();
      expect(mainCpp, contains('--native-app-env='),
          reason: 'F119-c: the runner must expose its compiled '
              'SPAMFILTER_APP_ENV so the --print-env probe verifies the '
              'native side, not just the Dart side.');
    });

    test('the --print-env probe reports NATIVE_APP_ENV', () {
      final mainDart = File('lib/main.dart').readAsStringSync();
      expect(mainDart, contains('NATIVE_APP_ENV='),
          reason: 'F119-c: Step 4.0 relies on the probe printing the native '
              'compiled environment.');
    });
  });

  group('dart-define-from-file secrets well-formedness (F119-b)', () {
    // A JSON key that becomes a dart-define MUST NOT contain a space (or be
    // empty). `--dart-define-from-file` serializes each key as `key=value` into
    // the dart-define stream; a space in the key corrupts that stream and
    // silently drops later defines (e.g. APP_ENV=prod) -> the build compiles as
    // dev. This is what shipped the 0.5.5 Store MSIX as [DEV].
    //
    // We validate EVERY secrets file present in this worktree (dev worktree ->
    // secrets.dev.json; prod worktree -> secrets.prod.json). The malformed-key
    // defect breaks both builds identically, so both must be clean. Template /
    // example files are skipped (they are not passed to a real build).
    final secretsFiles = Directory('.')
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.last.toLowerCase();
          return name.startsWith('secrets.') &&
              name.endsWith('.json') &&
              !name.contains('.example.') &&
              !name.contains('.template') &&
              // Skip backups -- they are never passed to a real build.
              !name.contains('bak') &&
              !name.contains('bck') &&
              !name.contains('backup');
        })
        .toList();

    test('at least the presence check is meaningful (informational)', () {
      // Not a hard requirement -- CI/other worktrees may have no secrets file.
      // This just documents what was scanned.
      // ignore: avoid_print
      print('[F119-b] secrets files scanned: '
          '${secretsFiles.map((f) => f.uri.pathSegments.last).toList()}');
    });

    for (final file in secretsFiles) {
      final name = file.uri.pathSegments.last;
      test('$name has only well-formed dart-define keys (no spaces/empties)',
          () {
        final Object? parsed;
        try {
          parsed = jsonDecode(file.readAsStringSync());
        } catch (e) {
          fail('$name is not valid JSON: $e');
        }
        expect(parsed, isA<Map>(),
            reason: '$name must be a JSON object of key/value defines.');
        final map = parsed as Map;

        final badKeys = map.keys
            .map((k) => k.toString())
            .where((k) => k.isEmpty || k.contains(' '))
            .toList();

        expect(
          badKeys,
          isEmpty,
          reason: 'F119-b: $name has dart-define key(s) with spaces or empty '
              'names: $badKeys. `--dart-define-from-file` turns each key into a '
              '`key=value` dart-define; a space in the key corrupts the '
              'dart-define stream and silently drops APP_ENV=prod, shipping a '
              'dev build. Remove comment/note keys and any key with a space -- '
              'keep only real credential keys.',
        );
      });
    }
  });
}
