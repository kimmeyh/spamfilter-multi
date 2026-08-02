import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F133-S52 R-4 (Sprint 52): build-failing gate on text contrast.
///
/// Target is **WCAG 2.1 AA** per `docs/adr/0037-ui-accessibility-standards.md`:
/// 4.5:1 for normal text, 3:1 for large text. Against a light background:
///
/// | Shade            | Contrast on white | AA normal | AA large |
/// |------------------|-------------------|-----------|----------|
/// | `grey.shade400`  | ~2.6:1            | FAIL      | FAIL     |
/// | `grey.shade500`  | ~3.9:1            | FAIL      | PASS     |
/// | `grey.shade600`  | ~5.4:1            | PASS      | PASS     |
///
/// So `shade600` is the floor for text a user must read. Lighter greys remain
/// correct for NON-informational decoration: dividers, borders, disabled fills.
///
/// The Sprint 52 audit found 113 hardcoded grey shades, of which 10 were on
/// text that fails AA. This gate stops the eleventh.
void main() {
  group('Text contrast invariant (F133-S52 R-4, Sprint 52)', () {
    /// Sites where a light grey is CORRECT and must not be "fixed".
    /// Every entry needs a reason -- an unexplained exemption is how a gate
    /// quietly stops gating.
    ///
    /// Keyed `'<file>::<code substring that must appear ON the line>'` so an
    /// exemption covers ONE construct, not a whole file. Keying by file alone
    /// (the original form) meant ANY future low-contrast text anywhere in that
    /// screen would bypass the invariant -- a blind spot Copilot caught on
    /// PR #292. The substring is matched against the offending line itself, so
    /// moving the code does not silently widen the exemption.
    const allowedExemptions = <String, String>{
      'rules_management_screen.dart::rule.enabled ?':
          'Disabled-rule subtitle: the color is the false branch of '
          '`rule.enabled ? ... : Colors.grey.shade400`. WCAG 1.4.3 exempts '
          'DISABLED controls from the contrast minimum, and the disabled state '
          'is additionally conveyed by a line-through on the title, so meaning '
          'is not carried by color alone. Darkening it would weaken the visual '
          'distinction between enabled and disabled rules.',
    };

    test('the matcher self-checks: it detects a failing text color', () {
      const sample = 'style: TextStyle(fontSize: 12, color: Colors.grey.shade500),';
      expect(
        RegExp(r'Colors\.grey\.shade(400|500)|Colors\.grey\[(400|500)\]')
            .hasMatch(sample),
        isTrue,
      );
    });

    test('no TextStyle uses a grey shade below the AA floor', () {
      final uiDir = Directory('lib/ui');
      expect(uiDir.existsSync(), isTrue,
          reason: 'run this test from the mobile-app/ directory');

      final failingGrey =
          RegExp(r'Colors\.grey\.shade(400|500)|Colors\.grey\[(400|500)\]');
      final violations = <String>[];

      for (final entity in uiDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final fileName = entity.uri.pathSegments.last;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!failingGrey.hasMatch(lines[i])) continue;

          // Per-CONSTRUCT exemption: the key's code substring must appear on
          // the offending line itself. The file keeps being scanned, so a new
          // low-contrast text color elsewhere in it still fails.
          final exempt = allowedExemptions.keys.any((k) {
            final parts = k.split('::');
            if (parts.length != 2 || parts[0] != fileName) return false;
            return lines[i].contains(parts[1]);
          });
          if (exempt) continue;

          // Only TEXT colors are in scope. Look back a few lines for the
          // enclosing TextStyle -- a grey on a Border, Divider or fill is fine.
          final from = i - 3 < 0 ? 0 : i - 3;
          final context = lines.sublist(from, i + 1).join(' ');
          if (!context.contains('TextStyle')) continue;

          violations.add(
            '$fileName:${i + 1} -- ${lines[i].trim()}\n'
            '    grey.shade400 (~2.6:1) and grey.shade500 (~3.9:1) FAIL WCAG '
            'AA for normal text. Use grey.shade600 or darker, or prefer '
            'Theme.of(context).colorScheme.* so dark mode inherits correctly.',
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Text a user must READ has to meet the AA contrast floor '
            '(ADR-0037). See docs/ACCESSIBILITY_STANDARDS.md section 4.\n\n'
            '${violations.join('\n\n')}',
      );
    });
  });
}
