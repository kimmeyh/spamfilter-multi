/// Sprint 74 Manual Validation (Harold Q5): every YAML export on Android
/// failed with "Bytes are required on Android & iOS when saving a file" --
/// file_picker 8.3.7's `saveFile` REQUIRES the bytes on Android and iOS and
/// writes the file itself; the app passed none and planned to write the file
/// afterwards, the desktop contract.
///
/// These tests drive [saveYamlExport] with a recording fake picker.
///
/// Sprint 75 (Harold Q5 at Manual Validation): the dialog now OPENS in the
/// export folder (Settings > General, else the platform default) -- on Android
/// it opened in Downloads although the default folder is Documents.
///
/// What they do NOT catch: the real Android save dialog (the platform channel
/// and SAF -- whether the OS honors the starting URI), and whether the plugin's
/// returned value is shown sensibly in the status line -- both are Manual
/// Validation on the device.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/export_directories.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';
import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

class _BrokenSettings extends SettingsStore {
  @override
  Future<String?> getCsvExportDirectory() async =>
      throw StateError('no database');
}

class _RecordingPicker implements FilePicker {
  _RecordingPicker(this.returns);

  final String? returns;
  Uint8List? bytes;
  String? initialDirectory;
  int saveCalls = 0;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saveCalls++;
    this.bytes = bytes;
    this.initialDirectory = initialDirectory;
    return returns;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const yaml = "rules:\n  - name: 'x'\n";

  test('Android/iOS: the bytes go TO the picker, and the app writes nothing',
      () async {
    final picker = _RecordingPicker('/storage/emulated/0/Download/rules.yaml');
    var appWrites = 0;
    final result = await saveYamlExport(
      picker: picker,
      isMobile: true,
      dialogTitle: 't',
      fileName: 'rules.yaml',
      yaml: yaml,
      writeDesktopFile: (_) async => appWrites++,
    );
    expect(picker.bytes, isNotNull,
        reason: 'without bytes file_picker throws on Android -- the Fold8 bug');
    expect(utf8.decode(picker.bytes!), yaml,
        reason: 'the exported text must be byte-for-byte the rendered YAML');
    expect(appWrites, 0,
        reason: 'the plugin wrote the file; its return value is not a '
            'writable path');
    expect(result, isNotNull);
  });

  test('desktop: no bytes to the picker; the app writes the chosen path',
      () async {
    final picker = _RecordingPicker(r'C:\Users\x\Downloads\rules.yaml');
    final written = <String>[];
    await saveYamlExport(
      picker: picker,
      isMobile: false,
      dialogTitle: 't',
      fileName: 'rules.yaml',
      yaml: yaml,
      writeDesktopFile: (p) async => written.add(p),
    );
    expect(picker.bytes, isNull);
    expect(written, [r'C:\Users\x\Downloads\rules.yaml']);
  });

  test('a cancelled dialog writes nothing on either platform', () async {
    for (final mobile in [true, false]) {
      var appWrites = 0;
      final result = await saveYamlExport(
        picker: _RecordingPicker(null),
        isMobile: mobile,
        dialogTitle: 't',
        fileName: 'rules.yaml',
        yaml: yaml,
        writeDesktopFile: (_) async => appWrites++,
      );
      expect(result, isNull);
      expect(appWrites, 0, reason: 'mobile=$mobile');
    }
  });

  group('Sprint 75: the dialog opens in the export folder', () {
    test('the starting folder reaches the picker on BOTH paths', () async {
      for (final mobile in [true, false]) {
        final picker = _RecordingPicker(null);
        await saveYamlExport(
          picker: picker,
          isMobile: mobile,
          dialogTitle: 't',
          fileName: 'rules.yaml',
          yaml: yaml,
          writeDesktopFile: (_) async {},
          initialDirectory: 'START',
        );
        expect(picker.initialDirectory, 'START', reason: 'mobile=$mobile');
      }
    });

    test('Android: a shared-storage path becomes the document URI the save '
        'dialog takes', () {
      expect(
          ExportDirectories.androidDocumentUri('/storage/emulated/0/Documents'),
          'content://com.android.externalstorage.documents/document/'
          'primary%3ADocuments');
      expect(
          ExportDirectories.androidDocumentUri(
              '/storage/emulated/0/Documents/Spam Exports/'),
          'content://com.android.externalstorage.documents/document/'
          'primary%3ADocuments%2FSpam%20Exports');
      expect(ExportDirectories.androidDocumentUri('/storage/emulated/0'),
          'content://com.android.externalstorage.documents/document/primary%3A');
    });

    test('Android: anything else gives NO hint rather than a guessed URI', () {
      for (final p in [
        '/storage/emulated/10/Documents', // another user / work profile
        '/storage/emulated/01/Documents', // not the primary root
        '/data/user/0/com.myemailspamfilter/files',
        'C:\\Users\\x\\Downloads',
      ]) {
        expect(ExportDirectories.androidDocumentUri(p), isNull, reason: p);
      }
    });

    test('saveDialogStart falls back to the platform default and never throws '
        'when the setting cannot be read', () async {
      final dir = Directory.systemTemp.createTempSync('s75_q5_');
      addTearDown(() {
        ExportDirectories.overrideDefaultForTest(null);
        ExportDirectories.debugWritableOverride = null;
        dir.deleteSync(recursive: true);
      });
      ExportDirectories.overrideDefaultForTest(dir.path);
      ExportDirectories.debugWritableOverride = true;
      final start = await ExportDirectories.saveDialogStart(
          settingsStore: _BrokenSettings());
      // The test host is Windows or Linux (CI): a filesystem path.
      expect(start, dir.path);
    });

    test('both export buttons pass the export folder (source gate)', () {
      final src = File('lib/ui/screens/yaml_import_export_screen.dart')
          .readAsStringSync();
      expect(
          'initialDirectory: await ExportDirectories.saveDialogStart(),'
              .allMatches(src)
              .length,
          2);
    });
  });
}
