// F354 (Sprint 85): the ADR-0035 `_Dev` suffix is applied to the app-support
// folder in ONE place, AppPaths.dataDirectoryPath. Before F354 five callers
// appended it by hand; when the Windows DEV executable got its own product
// name, each hand-built path would have become `..._Dev_Dev`. This gate fails
// when a new use of AppEnvironment.dataDirSuffix appears in lib/ outside the
// listed, reviewed uses.
//
// What this does NOT catch: a caller that hard-codes the literal '_Dev' or the
// folder name instead of reading dataDirSuffix (the existing hard-coded names
// in dev_environment_seeder.dart build sibling-folder paths from the parent
// and are correct either way).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Reviewed uses: file (relative to lib/, forward slashes) -> line count.
const Map<String, int> _allowed = {
  // The definition.
  'core/services/app_environment.dart': 1,
  // The single source: AppPaths.dataDirectoryPath.
  'adapters/storage/app_paths.dart': 1,
  // A folder NAME under Documents ('diagnostics_Dev'), not the support path.
  'core/services/diagnostic_logger.dart': 1,
  // A folder NAME under Documents ('MyEmailSpamFilter_Dev').
  'core/services/export_directories.dart': 1,
  // The --release-self-test prints and checks the value itself.
  'main.dart': 2,
};

void main() {
  test('dataDirSuffix is used only through AppPaths.dataDirectoryPath '
      '(plus the reviewed uses)', () {
    final found = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = p.relative(f.path, from: 'lib').replaceAll(r'\', '/');
      final n = f
          .readAsLinesSync()
          .where((l) => l.contains('dataDirSuffix'))
          .length;
      if (n > 0) found[rel] = n;
    }
    expect(found, _allowed,
        reason: 'Build a data, log or credential folder from the app-support '
            'directory with AppPaths.dataDirectoryPath(supportPath), not by '
            'appending AppEnvironment.dataDirSuffix: since F354 a Windows DEV '
            'support folder already ends in _Dev. If a new use is a folder '
            'NAME (not the support path), add it to _allowed with a reason.');
  });
}
