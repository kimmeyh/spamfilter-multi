/// Sprint 74 Manual Validation (Harold Q5): every YAML export on Android
/// failed with "Bytes are required on Android & iOS when saving a file" --
/// file_picker 8.3.7's `saveFile` REQUIRES the bytes on Android and iOS and
/// writes the file itself; the app passed none and planned to write the file
/// afterwards, the desktop contract.
///
/// These tests drive [saveYamlExport] with a recording fake picker.
///
/// What they do NOT catch: the real Android save dialog (the platform channel
/// and SAF), and whether the plugin's returned value is shown sensibly in the
/// status line -- both are Manual Validation on the phone.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/yaml_import_export_screen.dart';

class _RecordingPicker implements FilePicker {
  _RecordingPicker(this.returns);

  final String? returns;
  Uint8List? bytes;
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
}
