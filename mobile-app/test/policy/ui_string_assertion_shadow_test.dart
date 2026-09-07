import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Substring-shadow guard for gates that assert exact UI text
/// (Sprint 65 retro IMP-3, from the Manual Validation finding).
///
/// **The defect this generalises.** GP-18's reviewer instructions told a Play
/// reviewer to tap a card labelled "Try Demo Mode". The screen a FRESH
/// INSTALL actually shows -- which is exactly a reviewer's situation -- offers
/// "Try Demo Mode instead" (`empty_state.dart`). The instructions named a
/// control that was not on screen, which is a rejection risk.
///
/// The gate meant to prevent that asserted the instructions contain
/// "Try Demo Mode" -- and PASSED the whole time, because that string is a
/// SUBSTRING of the real label. A containment assertion cannot distinguish a
/// label from a longer label that contains it. Harold found it by looking at
/// the actual screen.
///
/// **What this test does.** For each exact-UI-string assertion registered
/// below, it searches `lib/` for a LONGER user-facing string that contains
/// the asserted one. If it finds one, the assertion is ambiguous: it would
/// pass against either label, so it proves less than it appears to.
///
/// **What it deliberately does not do.** It does not try to discover
/// assertions automatically by parsing test sources. That would be a fragile
/// regex over Dart, and a gate that is itself unreliable is worse than none.
/// The registry below is explicit, which also makes the cost of adding a new
/// exact-string assertion visible: you register it here too.
void main() {
  /// Exact UI strings that a policy gate asserts somewhere, paired with the
  /// gate that asserts them. Add an entry whenever a gate starts asserting a
  /// user-facing literal.
  const assertedUiStrings = <String, String>{
    'Try Demo Mode instead': 'app_content_declarations_test.dart',
    'Start Demo Scan (Testing)': 'app_content_declarations_test.dart',
    'No Accounts Yet': 'app_content_declarations_test.dart',
  };

  /// Collect user-facing string literals from lib/. Deliberately coarse: it
  /// looks for quoted literals rather than parsing Dart, because the question
  /// here is only "does a longer label containing this one exist", and a
  /// false positive costs a one-line registry note rather than a wrong pass.
  List<String> collectLibStrings() {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return const [];

    final literal = RegExp(r"'((?:[^'\\\n]|\\.){3,120})'");
    final found = <String>{};

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final value = match.group(1)!;
        // Skip things that are plainly not display text: paths, identifiers,
        // package URIs, format tokens.
        if (value.contains('/') ||
            value.contains(r'$') ||
            value.startsWith('package:') ||
            !value.contains(' ')) {
          continue;
        }
        found.add(value);
      }
    }
    return found.toList();
  }

  test('no asserted UI string is shadowed by a longer label in lib/', () {
    final libStrings = collectLibStrings();
    expect(libStrings, isNotEmpty,
        reason: 'expected to find user-facing strings in lib/ -- if this is '
            'empty the collector is broken and the whole gate is vacuous');

    final ambiguous = <String>[];

    assertedUiStrings.forEach((asserted, gate) {
      final shadows = libStrings
          .where((s) => s != asserted && s.contains(asserted))
          .toList();
      if (shadows.isNotEmpty) {
        ambiguous.add(
            '"$asserted" (asserted by $gate) is a substring of: $shadows');
      }
    });

    expect(ambiguous, isEmpty,
        reason: 'These exact-UI-string assertions are SHADOWED: a longer '
            'label in lib/ contains the asserted string, so the assertion '
            'passes against either one and proves less than it looks like it '
            'does. This is the Sprint 65 MV defect: a gate asserting "Try '
            'Demo Mode" passed while the instructions named the wrong '
            'control, because the real label was "Try Demo Mode instead". '
            'Fix by asserting the FULL label (and registering it here), not '
            'by loosening the check.\n\n${ambiguous.join('\n')}');
  });

  test('every registered string still exists in lib/', () {
    // A registry that drifts from the app is worse than no registry: it
    // would keep asserting a label the UI no longer has, and the shadow
    // check above would silently have nothing to compare against.
    final libStrings = collectLibStrings();
    final missing = assertedUiStrings.keys
        .where((s) => !libStrings.any((l) => l.contains(s)))
        .toList();

    expect(missing, isEmpty,
        reason: 'these registered UI strings no longer appear in lib/, so '
            'either the UI changed and the gate asserting them is now wrong, '
            'or the registry is stale: $missing');
  });
}
