/// Policy gate (Sprint 59): WinWright scripts must not reference RETIRED
/// user-facing strings.
///
/// WHY THIS EXISTS (Claude cowork review finding, Harold 2026-08-15): the
/// WinWright scripts in `test/winwright/*.json` encode the same user-facing
/// strings (AppBar tooltips, screen names, button labels) as the Dart source,
/// but sit OUTSIDE the Dart test net -- F155's app-wide rename was verified
/// with a Dart-only suite plus a Dart-only mutation check, and the scripts
/// silently kept the old strings until the next live sweep failed with a
/// misleading regression signal. The Sprint 59 sweep run surfaced exactly
/// that: stale `Review "No Rule" Items` selectors, plus two tooltips renamed
/// back in Sprint 52 (`Refresh`) and the Settings account-picker removed by
/// F135 -- none of which any Dart gate could see.
///
/// This gate greps the scripts for strings KNOWN to be retired. It cannot
/// prove a selector matches a live element (only a live sweep can); it proves
/// the scripts never reference a string the app has explicitly renamed away.
/// Add an entry here every time a user-facing string that scripts rely on is
/// renamed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each entry: retired literal -> where it went (for the failure message).
  const retired = <String, String>{
    // F155 (Sprint 59): nested quotes dropped from the screen name.
    'Review "No Rule" Items': "renamed to 'Review No Rule Items' (F155)",
    // Sprint 52 (Harold): 'Refresh' tooltips renamed to say what they do.
    // Selector form only -- the bare word appears legitimately in prose.
    "name='Refresh'":
        "tooltip renamed -- No Rule screen: 'Re-check the last scan (does "
            "not fetch new mail)'; Manage Rules: 'Reload rules from the "
            "database' (Sprint 52)",
    // F135 (Sprint 52): the Settings account-picker overlay no longer exists.
    "name='Select account ":
        'the Settings account-picker was removed by F135 (lazy account '
            'resolution) -- do not script against it',
  };

  test('WinWright scripts reference no retired user-facing strings', () {
    final dir = Directory('test/winwright');
    expect(dir.existsSync(), isTrue,
        reason: 'test/winwright/ moved? Update this gate alongside it.');

    final offenses = <String>[];
    final scripts = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(scripts, isNotEmpty,
        reason: 'No WinWright scripts found -- glob broken?');

    for (final file in scripts) {
      final content = file.readAsStringSync();
      // JSON files escape the inner quotes, so match both raw and
      // JSON-escaped forms of each retired literal.
      for (final entry in retired.entries) {
        final raw = entry.key;
        final escaped = raw.replaceAll('"', r'\"');
        if (content.contains(raw) || content.contains(escaped)) {
          offenses.add('${file.path}: contains retired string `$raw` '
              '-- ${entry.value}');
        }
      }
    }

    expect(offenses, isEmpty,
        reason: 'WinWright scripts reference retired UI strings. These '
            'scripts sit outside the Dart rename net, so they rot silently '
            'until a live sweep fails with a misleading signal:\n'
            '${offenses.join('\n')}');
  });
}
