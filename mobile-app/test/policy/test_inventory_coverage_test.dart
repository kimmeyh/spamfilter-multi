import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F350 (Sprint 85) policy gate: the test inventory lists every Dart test file.
///
/// `scripts/test-inventory.py` is the inventory of every test artifact (ADR-0051 tooling). If a
/// `*_test.dart` file exists under `mobile-app/test` or `mobile-app/integration_test` that the script
/// would not list, the inventory (and every risk-tier decision made from it) silently misses that
/// test. This gate lists the files with its OWN walk of the two folders and compares them with
/// `python scripts/test-inventory.py --list-paths`. The two walks are independent on purpose: a
/// change to the script's discovery rule (for example scanning only one folder) makes the sets
/// differ and fails this test.
///
/// Both sides skip a folder named `scratch` (the gitignored `test/scratch` probe folder, which never
/// reaches a commit) and build output folders. A new test file in a NEW folder is found by both
/// walks because both walk the whole tree.
///
/// What this does NOT catch: a test artifact of another kind (WinWright JSON, hook cases, Python
/// tests) missing from the inventory, because this gate compares only `*_test.dart` paths; the Python
/// unittest in scripts/tests covers those kinds. It also cannot tell whether an entry's kind, tier or
/// "where it runs" is right.
///
/// Platforms (ADR-0042): the gate runs wherever `flutter test` runs (Windows host and CI Linux),
/// because it needs only the file system and a Python interpreter. It fails (does not skip) when
/// Python is missing on Windows; it skips with a stated reason only on a non-Windows host without
/// Python, because the Linux CI runner always has `python3`.
const _skipDirs = {'scratch', 'build', '.dart_tool', 'node_modules'};

Set<String> _walk(String root) {
  final result = <String>{};
  final dir = Directory(root);
  if (!dir.existsSync()) return result;
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (!path.endsWith('_test.dart')) continue;
    final segments = path.split('/');
    // Skip only the directory segments, never the file name.
    if (segments.sublist(0, segments.length - 1).any(_skipDirs.contains)) {
      continue;
    }
    result.add('mobile-app/$path');
  }
  return result;
}

String? _findPython() {
  final probe = Platform.isWindows ? 'where' : 'which';
  for (final name in ['python', 'python3', 'py']) {
    try {
      final r = Process.runSync(probe, [name]);
      if (r.exitCode == 0) return name;
    } on ProcessException {
      continue;
    }
  }
  return null;
}

void main() {
  test('the test inventory script lists every *_test.dart file', () {
    final python = _findPython();
    if (python == null) {
      if (Platform.isWindows) {
        fail('Python was not found on PATH. The inventory gate needs python '
            '(ADR-0051); install it or fix PATH.');
      }
      markTestSkipped('No python or python3 on this non-Windows host; the '
          'Linux CI runner has python3, so this skip never hides a CI result.');
      return;
    }
    // flutter test runs with the working directory at mobile-app/.
    final result = Process.runSync(
      python,
      ['-I', '../scripts/test-inventory.py', '--list-paths'],
      stdoutEncoding: const SystemEncoding(),
    );
    expect(result.exitCode, 0,
        reason: 'test-inventory.py --list-paths failed: ${result.stderr}');
    final listed = (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim().replaceAll('\\', '/'))
        .where((l) => l.endsWith('_test.dart'))
        .where((l) =>
            l.startsWith('mobile-app/test/') ||
            l.startsWith('mobile-app/integration_test/'))
        .toSet();

    final onDisk = {..._walk('test'), ..._walk('integration_test')};
    expect(onDisk, isNotEmpty, reason: 'the walk found no test files');

    final missing = onDisk.difference(listed).toList()..sort();
    expect(missing, isEmpty,
        reason: 'Test files the inventory does not list. Add the folder to '
            'discover() in scripts/test-inventory.py:\n${missing.join('\n')}');
    final phantom = listed.difference(onDisk).toList()..sort();
    expect(phantom, isEmpty,
        reason: 'Paths the inventory lists that this gate does not find:\n'
            '${phantom.join('\n')}');
  });
}
