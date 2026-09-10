import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F133-S52 R-4 (Sprint 52): build-failing gate on text contrast.
///
/// Target is **WCAG 2.1 AA** per `docs/adr/0037-ui-accessibility-standards.md`:
/// 4.5:1 for normal text, 3:1 for large text. Against white, computed with the
/// WCAG relative-luminance formula (ratios CORRECTED in the PR #292 re-review
/// -- the original table overstated every ratio, and wrongly gave shade500 an
/// AA-large PASS; the situation was WORSE than documented, so the floor
/// conclusion survives unchanged):
///
/// | Shade                    | Contrast on white | AA normal | AA large |
/// |--------------------------|-------------------|-----------|----------|
/// | `grey.shade400` #BDBDBD  | ~1.9:1            | FAIL      | FAIL     |
/// | `grey.shade500` #9E9E9E  | ~2.7:1            | FAIL      | FAIL     |
/// | `grey.shade600` #757575  | ~4.6:1            | PASS      | PASS     |
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

      // Bare `Colors.grey` IS `shade500` (~2.7:1 on white) -- it fails AA for
      // BOTH normal and large text. The original pattern matched only the
      // explicit shades, so the gate documented a floor it did not enforce
      // and 13 real text sites sat below it undetected (PR #292 review). The
      // negative lookahead keeps `grey.shade600`, `greyAccent` and
      // `grey[700]` out of the match.
      final failingGrey = RegExp(r'Colors\.grey\.shade(400|500)'
          r'|Colors\.grey\[(400|500)\]'
          r'|Colors\.grey(?![.\[A-Za-z0-9])');
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
            '    grey.shade400 (~1.9:1) and grey.shade500 (~2.7:1, = bare '
            'Colors.grey) FAIL WCAG AA for normal AND large text. Use '
            'grey.shade600 (~4.6:1) or darker, or prefer '
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

  /// F197 (Sprint 68): the MIXED pattern -- a hardcoded container surface
  /// wrapping text that takes its colour from the theme.
  ///
  /// **Why this is a separate invariant from the one above.** The F133 gate
  /// asks "is this text colour dark enough on WHITE?". That question assumes a
  /// light background. This one catches the case where the background is
  /// PINNED and the foreground is NOT: `Colors.blue.shade50` is a fixed
  /// near-white in every theme, so when the text inside it resolves through
  /// `Theme.of(context).textTheme` it turns near-white in dark mode and the
  /// card becomes unreadable. The Sprint 67 account header measured **1.14:1**
  /// this way -- it passed the F133 gate, because the text colour was never
  /// hardcoded at all.
  ///
  /// **What is NOT a defect, and the distinction is the whole difficulty:**
  ///
  /// - A **fully hardcoded** card pins BOTH halves and holds in any theme.
  ///   Settings > Manual Scan > Default Folders is `blue.shade900` on
  ///   `blue.shade50` and measures **7.56:1**. Correct. Must not flag.
  /// - A **fully theme-derived** card (`secondaryContainer` +
  ///   `onSecondaryContainer`) is the preferred fix and is correct by
  ///   construction.
  /// - An **icon tint** or a **border** on a hardcoded surface is decoration,
  ///   not text, and WCAG 1.4.3 does not apply the text minimum to it.
  ///
  /// So the defect is precisely: surface hardcoded, text from the theme. The
  /// original F197 card said "28 sites to fix" -- that was a grep of
  /// `Colors.*.shadeNN` repo-wide, which is the easy proxy and not the defect.
  /// Auditing for the MIX finds two, and both were already fixed (F195 account
  /// header; Scan History background-scan strip). **This gate exists to stop
  /// the third**, which is the only part of F197 with lasting value.
  group('Dark-mode surface/text mix invariant (F197, Sprint 68)', () {
    /// A container surface pinned to a literal shade. Deliberately EXCLUDES
    /// `TextStyle(color: ...)` (that is a hardcoded TEXT colour -- the F133
    /// gate's business, and safe here because it pins the foreground too),
    /// `Icon(...)` tints, and borders.
    bool isHardcodedSurface(String line) {
      final hasShade = RegExp(
        r'(?:^|[\s(,])(?:color|backgroundColor):\s*Colors\.[a-z]+\.shade\d+',
      ).hasMatch(line);
      if (!hasShade) return false;
      if (line.contains('TextStyle')) return false;
      if (line.contains('Icon(')) return false;
      if (line.contains('BorderSide') || line.contains('border:')) return false;
      return true;
    }

    /// Is line [i] a colour INSIDE a `TextStyle(...)` that opened on an
    /// earlier line?
    ///
    /// **Why a single-line check was not enough (PR #403 review).** The
    /// original `isHardcodedSurface` rejected text colours with
    /// `line.contains('TextStyle')`, which only works when `TextStyle(` and
    /// `color:` share a line. `dart format` splits them as soon as the call
    /// grows:
    ///
    /// ```dart
    /// style: TextStyle(
    ///   color: Colors.blue.shade900,   // <- read as a SURFACE
    /// ),
    /// ```
    ///
    /// Measured against the real tree: 63 lines matched `isHardcodedSurface`
    /// and **31 of them were text colours inside a multi-line TextStyle**.
    /// The gate did not fire only because none of those 31 happened to have
    /// theme-derived text within the window below it -- so a correct,
    /// fully-hardcoded card would have started failing the moment someone
    /// added a themed label to it. That is the exact false positive the group
    /// doc warns about, hiding inside the check meant to prevent it.
    ///
    /// Walks BACKWARD tracking bracket depth: a `TextStyle(` found while depth
    /// is negative is still open at line [i].
    bool insideMultiLineTextStyle(List<String> lines, int i) {
      var depth = 0;
      for (var k = i - 1; k >= 0 && k >= i - 6; k--) {
        depth += ')'.allMatches(lines[k]).length -
            '('.allMatches(lines[k]).length;
        if (lines[k].contains('TextStyle(') && depth < 0) return true;
      }
      return false;
    }

    /// Text whose colour resolves through the theme, so it FLIPS with the
    /// theme while the surface above does not.
    final themeDerivedText =
        RegExp(r'Theme\.of\(context\)\.textTheme|\.textTheme\.[a-zA-Z]+');

    /// How far below a surface declaration its content can appear. 12 lines
    /// covers a Card/Container + padding + Row + Text without reaching into
    /// the NEXT widget -- verified against the two real instances.
    const windowLines = 12;

    test('the matcher self-checks: it flags the mix and allows the safe shapes',
        () {
      // The real defect shape (Sprint 67 account header, 1.14:1 in dark mode).
      const mixed = [
        'color: Colors.blue.shade50,',
        'child: Text(',
        '  account.email,',
        '  style: Theme.of(context).textTheme.titleMedium,',
        '),',
      ];
      expect(isHardcodedSurface(mixed[0]), isTrue,
          reason: 'a bare shade on `color:` IS a pinned surface');
      expect(themeDerivedText.hasMatch(mixed.join(' ')), isTrue,
          reason: 'textTheme inside the window is the flipping half');

      // Fully hardcoded -- Default Folders, 7.56:1. Both halves pinned.
      const hardcoded = [
        'color: Colors.blue.shade50,',
        'child: Text("Default folders",',
        '  style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),',
      ];
      expect(themeDerivedText.hasMatch(hardcoded.join(' ')), isFalse,
          reason: 'a fully hardcoded card holds in any theme and must NOT be '
              'flagged -- this is the false positive that would make the gate '
              'block correct work');

      // THE REGRESSION CASE (PR #403 review): `dart format` splits a long
      // TextStyle across lines, so the colour line carries no 'TextStyle'
      // token at all. isHardcodedSurface alone says "surface"; the bracket
      // walk is what says "text".
      const splitTextStyle = [
        'style: TextStyle(',
        '  color: Colors.blue.shade900,',
        '  fontSize: 13,',
        '),',
      ];
      expect(isHardcodedSurface(splitTextStyle[1]), isTrue,
          reason: 'the single-line check cannot see the TextStyle above it -- '
              'this is why insideMultiLineTextStyle exists');
      expect(insideMultiLineTextStyle(splitTextStyle, 1), isTrue,
          reason: 'a hardcoded TEXT colour must never be treated as a surface, '
              'however dart format chose to wrap it');

      // A real surface must still be seen as one when it follows a CLOSED
      // TextStyle -- the walk must not over-reach.
      const closedThenSurface = [
        'style: TextStyle(fontSize: 13),',
        'color: Colors.blue.shade50,',
      ];
      expect(insideMultiLineTextStyle(closedThenSurface, 1), isFalse,
          reason: 'the TextStyle on the previous line is CLOSED; the surface '
              'below it is a genuine surface');

      // An icon tint on a hardcoded surface is decoration, not text.
      expect(isHardcodedSurface('Icon(Icons.info, color: Colors.blue.shade700)'),
          isFalse);
      // A hardcoded TEXT colour pins the foreground; F133 owns that question.
      expect(
          isHardcodedSurface(
              'style: TextStyle(color: Colors.grey.shade600, fontSize: 12),'),
          isFalse);
      // A border is not text.
      expect(
          isHardcodedSurface(
              'border: Border(top: BorderSide(color: Colors.grey.shade300)),'),
          isFalse);
    });

    test('no hardcoded surface wraps theme-derived text', () {
      final uiDir = Directory('lib/ui');
      expect(uiDir.existsSync(), isTrue,
          reason: 'run this test from the mobile-app/ directory');

      final violations = <String>[];

      for (final entity in uiDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final fileName = entity.uri.pathSegments.last;
        final lines = entity.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          if (!isHardcodedSurface(lines[i])) continue;
          // PR #403 review: 31 real lines reach here as false "surfaces".
          if (insideMultiLineTextStyle(lines, i)) continue;

          final end = i + windowLines >= lines.length
              ? lines.length
              : i + windowLines + 1;
          for (var j = i + 1; j < end; j++) {
            if (!themeDerivedText.hasMatch(lines[j])) continue;
            violations.add(
              '$fileName:${i + 1} pins a surface -- ${lines[i].trim()}\n'
              '    but $fileName:${j + 1} takes its text colour from the '
              'theme -- ${lines[j].trim()}\n'
              '    The surface does NOT flip with the theme and the text DOES, '
              'so this is readable in one mode and not the other (the Sprint 67 '
              'account header measured 1.14:1 in dark mode). Fix by making BOTH '
              'halves theme-derived -- `colorScheme.secondaryContainer` with '
              '`onSecondaryContainer` -- which is what F195 did. Pinning the '
              'text instead also works but keeps the card fixed in dark mode.',
            );
            break;
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'A pinned surface with theme-derived text inside it is '
            'unreadable in one of the two themes (ADR-0037, WCAG 2.1 AA 4.5:1). '
            'See docs/ACCESSIBILITY_STANDARDS.md section 4.\n\n'
            '${violations.join('\n\n')}',
      );
    });
  });
}
