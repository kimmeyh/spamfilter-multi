// F142 (Sprint 57) -- Android bottom-nav placeholder removal gate.
//
// WHY: F142 removed MainNavigationScreen's Android-specific bottom-nav
// branch (Platform.isAndroid check, NavigationBar, and the two dead-end
// _PlaceholderScreen tabs backing "Rules" and "Settings"), replacing it with
// the same default-screen decision desktop already used. A behavior test
// alone (desktop_default_screen_test.dart) proves the REPLACEMENT works --
// it does not prove the OLD scaffolding is actually gone, only that the new
// path is reachable. Per this project's standing lesson (source gates prove
// existence, not behavior; behavior tests prove a handler works, not that
// dead code was removed) this is a source-text gate PAIRED with that
// behavior test, not a substitute for it.
//
// SCOPE: only main_navigation_screen.dart, since the placeholder shell and
// its Platform.isAndroid branch were entirely self-contained there
// (confirmed via a repo-wide grep during F142 planning -- no other file
// referenced _PlaceholderScreen or the bottom NavigationBar).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _targetFile = 'lib/ui/screens/main_navigation_screen.dart';

/// Tokens that must NOT appear in the file post-F142. Checked as plain
/// substring matches (not regex) -- these are exact identifiers/class names
/// from the removed scaffolding, not patterns that could have a legitimate
/// unrelated match elsewhere in this specific file.
const _removedTokens = <String>[
  'Platform.isAndroid',
  '_PlaceholderScreen',
  'NavigationBar(',
  'bottomNavigationBar',
];

void main() {
  group('F142 Android nav-shell removal invariant (Sprint 57)', () {
    test('main_navigation_screen.dart no longer contains the removed '
        'Android bottom-nav scaffolding', () {
      final target = File(_targetFile);
      if (!target.existsSync()) {
        fail('Expected $_targetFile to exist');
      }

      final content = target.readAsStringSync();
      final violations = <String>[];
      for (final token in _removedTokens) {
        if (content.contains(token)) {
          violations.add(token);
        }
      }

      expect(violations, isEmpty,
          reason: 'main_navigation_screen.dart still contains removed F142 '
              'scaffolding: ${violations.join(', ')}. The Android bottom-nav '
              'placeholder shell (Platform.isAndroid branch, NavigationBar, '
              '_PlaceholderScreen) was removed in F142 (Sprint 57) -- Android '
              'now shares the same default-screen decision desktop uses. If '
              'this fails, either the removal regressed, or this gate needs '
              'updating alongside a deliberate, documented reintroduction.');
    });
  });
}
