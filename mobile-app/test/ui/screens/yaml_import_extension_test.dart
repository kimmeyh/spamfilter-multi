import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

/// F208 (Sprint 69): YAML import was BROKEN on Android. `FileType.custom` is
/// resolved by MIME type there, not by extension, and `.yaml`/`.yml` have no
/// MIME mapping -- so the picker rejected the filter before a file was ever
/// chosen, and the app's only backup-and-restore path did not work at all.
///
/// The fix uses `FileType.any` and validates here instead, on BOTH platforms.
/// That removes the platform difference rather than encoding it (ADR-0042),
/// but it also means the picker no longer greys out non-YAML files -- so this
/// predicate is the only thing standing between a wrongly-chosen file and an
/// import that REPLACES every rule of its type.
void main() {
  group('F208 YAML import extension validation', () {
    bool isYaml(String path) => YamlImportExportScreen.isYamlPath(path);

    test('accepts the extensions this app exports', () {
      expect(isYaml('/storage/emulated/0/Documents/rules.yaml'), isTrue);
      expect(isYaml('/storage/emulated/0/Documents/safe_senders.yml'), isTrue);
      expect(isYaml(r'D:\Data\Harold\rules.yaml'), isTrue);
    });

    test('accepts any casing -- pickers return the file as it was created', () {
      expect(isYaml('/Documents/Rules.YAML'), isTrue);
      expect(isYaml('/Documents/RULES.Yml'), isTrue);
    });

    test('rejects a non-YAML file rather than importing it', () {
      // Each of these REPLACES every rule if it gets through.
      expect(isYaml('/Documents/photo.jpg'), isFalse);
      expect(isYaml('/Documents/scan_results.csv'), isFalse);
      expect(isYaml('/Documents/rules.json'), isFalse);
      expect(isYaml('/Documents/rules.txt'), isFalse);
      expect(isYaml('/Documents/notes.md'), isFalse);
    });

    test('rejects a name that merely CONTAINS the extension', () {
      // The check is an endsWith, not a contains. A file called
      // "rules.yaml.bak" is a backup of a YAML file, not a YAML file, and
      // "yaml_notes.txt" is not one either.
      expect(isYaml('/Documents/rules.yaml.bak'), isFalse);
      expect(isYaml('/Documents/yaml_notes.txt'), isFalse);
      expect(isYaml('/Documents/my.yml.zip'), isFalse);
    });

    group('the file name shown in the rejection message', () {
      // F-PRECHECK class 4 (fragile parsing), found at 5.1.2: the original
      // split on Platform.pathSeparator alone, so on Windows a path using
      // forward slashes -- and on Android a content URI, which always does --
      // printed the WHOLE path where a file name belongs.
      String name(String path) => YamlImportExportScreen.fileNameOf(path);

      test('handles a Windows path', () {
        expect(name(r'D:\Data\Harold\photo.jpg'), 'photo.jpg');
      });

      test('handles a POSIX path', () {
        expect(name('/storage/emulated/0/Documents/photo.jpg'), 'photo.jpg');
      });

      test('handles a Windows path written with forward slashes', () {
        expect(name('D:/Data/Harold/photo.jpg'), 'photo.jpg');
      });

      test('handles an Android content URI', () {
        expect(
          name('content://com.android.providers.downloads/document/msf%3A42'),
          'msf%3A42',
        );
      });

      test('a bare file name is returned unchanged', () {
        expect(name('photo.jpg'), 'photo.jpg');
      });
    });

    test('rejects an extensionless file', () {
      expect(isYaml('/Documents/rules'), isFalse);
      expect(isYaml(''), isFalse);
    });
  });
}
