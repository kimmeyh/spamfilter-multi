// Sprint 80 Task 16 (#504): the Windows tray icon must be found next to the
// exe, whatever the working directory, and the file must ship in the build.
//
// The right-click handler must also SHOW the menu (system_tray only reports
// the click).
//
// What these tests do NOT catch: whether Windows actually shows the icon or
// the menu (Shell_NotifyIcon, TrackPopupMenu, the notification-area settings),
// or whether initialize() registers handleTrayEvent. That is checked by
// starting the built exe from another folder and reading the notification
// area (Sprint 80 MV-4 rehearsal), not here.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_tray/system_tray.dart'
    show kSystemTrayEventRightClick;
import 'package:path/path.dart' as p;
import 'package:my_email_spam_filter/core/services/windows_system_tray_service.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowsSystemTrayService.trayIconPath', () {
    test('resolves from the exe folder, not the working directory', () {
      final exe = p.join('C:', 'Apps', 'Spam', 'MyEmailSpamFilter.exe');
      final result = WindowsSystemTrayService.trayIconPath(exe);
      expect(
        result,
        p.join('C:', 'Apps', 'Spam', 'data', 'flutter_assets', 'windows',
            'runner', 'resources', 'app_icon.ico'),
      );
      expect(result.startsWith(Directory.current.path), isFalse,
          reason: 'the working directory must not decide the icon path');
    });

    test('a different working directory gives the same path', () {
      final exe = p.join('D:', 'dist', 'dev', 'MyEmailSpamFilter-Dev.exe');
      final before = WindowsSystemTrayService.trayIconPath(exe);
      final saved = Directory.current;
      try {
        Directory.current = Directory.systemTemp;
        expect(WindowsSystemTrayService.trayIconPath(exe), before);
      } finally {
        Directory.current = saved;
      }
    });
  });

  group('WindowsSystemTrayService.handleTrayEvent', () {
    // The plugin's channels, recorded instead of reaching native code.
    final calls = <String>[];
    setUp(() {
      calls.clear();
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;
      for (final name in [
        'flutter/system_tray/tray',
        'flutter/system_tray/menu_manager',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          calls.add(call.method);
          return true;
        });
      }
    });

    test('right-click builds the menu and SHOWS it', () async {
      await WindowsSystemTrayService().handleTrayEvent(kSystemTrayEventRightClick);
      expect(calls, contains('SetContextMenu'));
      expect(calls.last, 'PopupContextMenu',
          reason: 'the menu only appears when the app asks for it');
    });

    test('an unknown event does nothing', () async {
      await WindowsSystemTrayService().handleTrayEvent('unknown-event');
      expect(calls, isEmpty);
    });
  });

  group('tray icon asset ships in the build', () {
    test('pubspec.yaml lists the asset key, and the file exists', () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final assets =
          ((pubspec['flutter'] as YamlMap)['assets'] as YamlList).cast<String>();
      expect(assets, contains(WindowsSystemTrayService.trayIconAssetKey));
      expect(File(WindowsSystemTrayService.trayIconAssetKey).existsSync(),
          isTrue);
    });

    test('the asset is the icon the runner embeds (one source)', () {
      final rc = File('windows/runner/Runner.rc').readAsStringSync();
      final relative = WindowsSystemTrayService.trayIconAssetKey
          .replaceFirst('windows/runner/', '')
          .replaceAll('/', r'\\');
      expect(rc, contains('IDI_APP_ICON'));
      expect(rc, contains('"$relative"'));
    });
  });
}
