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
import 'dart:convert';
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

  // F284 (Sprint 78) T-1: the default sweep must be CURSOR-FREE so it can run
  // while Harold uses the PC or with the workstation locked (a locked session
  // refuses SetCursorPos / SendInput; UIA pattern steps are unaffected).
  //
  // Keep this list in step with `$cursorTools` in
  // scripts/run-winwright-tests.ps1 (the runner's locked-PC gate).
  const cursorTools = <String>[
    'ww_click',
    'ww_hover',
    'ww_drag_drop',
    'ww_scroll',
    'ww_keyboard',
    'ww_type',
    'ww_select_text',
  ];

  // KNOWN PENDING, not a waiver: test_s75 still hovers two Settings > Account
  // rows to prove their resolved-folder subtitles. Whether UIA exposes those
  // as a cursor-free read needs the F284 live probe (45-minute time-box).
  // Remove this entry when the hovers are converted. The exact count is pinned
  // so a THIRD cursor step in that script still fails.
  const knownPending = <String, Map<String, int>>{
    'test_s75_new_controls.json': {'ww_hover': 2},
  };

  test('default-sweep WinWright scripts contain no cursor-driven steps', () {
    // The runner owns the sweep membership: read its exclusion list rather
    // than duplicating it (a duplicate would drift silently).
    final runner = File('scripts/run-winwright-tests.ps1');
    expect(runner.existsSync(), isTrue,
        reason: 'scripts/run-winwright-tests.ps1 moved? Update this gate.');
    final match = RegExp(r'\$excludedFromSweep\s*=\s*@\(([^)]*)\)')
        .firstMatch(runner.readAsStringSync());
    expect(match, isNotNull,
        reason: r'Could not find $excludedFromSweep in the runner.');
    final excluded = RegExp(r'"([^"]+)"')
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    expect(excluded, isNotEmpty);

    final sweep = Directory('test/winwright')
        .listSync()
        .whereType<File>()
        .where((f) {
      final name = f.uri.pathSegments.last;
      return name.startsWith('test_') &&
          name.endsWith('.json') &&
          !excluded.any((e) => name.contains(e));
    }).toList();
    expect(sweep, isNotEmpty, reason: 'Default sweep is empty -- glob broken?');

    final offenses = <String>[];
    for (final file in sweep) {
      final name = file.uri.pathSegments.last;
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final counts = <String, int>{};
      for (final tc in (doc['testCases'] as List)) {
        for (final step in ((tc as Map)['steps'] as List)) {
          final tool = (step as Map)['tool'];
          if (tool is String && cursorTools.contains(tool)) {
            counts[tool] = (counts[tool] ?? 0) + 1;
          }
        }
      }
      final allowed = knownPending[name] ?? const <String, int>{};
      for (final e in counts.entries) {
        if (e.value != (allowed[e.key] ?? 0)) {
          offenses.add('$name: ${e.value} x ${e.key} step(s) '
              '(allowed: ${allowed[e.key] ?? 0})');
        }
      }
    }

    expect(offenses, isEmpty,
        reason: 'Default-sweep WinWright scripts must use UIA pattern steps '
            '(ww_invoke, ww_set_checked, ww_get_value, ...) so the sweep '
            'runs with the PC locked or in use. Convert the step, or if it '
            'truly needs the cursor, move the script out of the default '
            'sweep:\n${offenses.join('\n')}');
  });

  // WHAT THIS DOES NOT CATCH: it reads step "tool" names only. It cannot tell
  // that a ww_invoke selector still resolves (a live sweep does), that
  // ww_set_checked / ww_get_value are replayed by the installed runner, or
  // that a pattern tool silently falls back to a cursor click (ww_invoke on a
  // control without InvokePattern errors rather than clicking, but a future
  // WinWright build could change that). It also trusts the runner's
  // $excludedFromSweep line and the cursorTools list above to be right.
}
