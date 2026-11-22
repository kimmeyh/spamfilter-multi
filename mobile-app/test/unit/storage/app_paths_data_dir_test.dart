// F354 (Sprint 85): AppPaths.dataDirectoryPath applies the ADR-0035 `_Dev`
// suffix exactly once.
//
// What this does NOT catch: whether a Windows DEV executable really reports
// ProductName "MyEmailSpamFilter_Dev" (that is the Runner.rc / CMake gate in
// test/policy/runner_product_name_test.dart plus the build check at Manual
// Validation), or a caller that builds a support path by hand (that is
// test/policy/data_dir_suffix_single_source_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';

void main() {
  group('AppPaths.dataDirectoryPath', () {
    test('production (no suffix) returns the support path unchanged', () {
      expect(
        AppPaths.dataDirectoryPath(
            r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter',
            suffix: ''),
        r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter',
      );
    });

    test('a pre-F354 DEV exe (production-named folder) gets the suffix', () {
      expect(
        AppPaths.dataDirectoryPath(
            r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter',
            suffix: '_Dev'),
        r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev',
      );
    });

    test('an F354 DEV exe (DEV product folder) is NOT suffixed twice', () {
      expect(
        AppPaths.dataDirectoryPath(
            r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev',
            suffix: '_Dev'),
        r'C:\Users\u\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev',
      );
    });

    test('a trailing separator does not defeat the once-only rule', () {
      expect(
        AppPaths.dataDirectoryPath(
            r'C:\R\MyEmailSpamFilter\MyEmailSpamFilter_Dev\',
            suffix: '_Dev'),
        r'C:\R\MyEmailSpamFilter\MyEmailSpamFilter_Dev',
      );
    });

    test('Android and iOS support folders are suffixed as before F354', () {
      expect(
        AppPaths.dataDirectoryPath('/data/user/0/com.myemailspamfilter.dev/files',
            suffix: '_Dev'),
        '/data/user/0/com.myemailspamfilter.dev/files_Dev',
      );
    });
  });
}
