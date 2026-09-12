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
      for (var k = i - 1; k >= 0; k--) {
        depth +=
            ')'.allMatches(lines[k]).length - '('.allMatches(lines[k]).length;
        if (depth < 0) {
          // This line opened the bracket we sit inside. It DECIDES: a
          // TextStyle( here means we are inside text, anything else means we
          // are not. Returning true merely because a TextStyle( appeared
          // somewhere above is what made the gate skip real surfaces.
          return lines[k].contains('TextStyle(');
        }
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

  /// F210 (Sprint 69): the THIRD variant -- a hardcoded surface wrapping text
  /// that is theme-derived **BY OMISSION**.
  ///
  /// **Why the F197 gate above cannot see this.** F197 looks for text whose
  /// colour comes from `Theme.of(context).textTheme`. Here the `TextStyle`
  /// specifies NO colour at all:
  ///
  /// ```dart
  /// Container(
  ///   decoration: BoxDecoration(color: Colors.grey[200]),  // pinned surface
  ///   child: SelectableText(
  ///     filePath,
  ///     style: TextStyle(fontSize: 12, fontFamily: 'monospace'),  // NO colour
  ///   ),
  /// )
  /// ```
  ///
  /// Flutter resolves that omission from the theme, so it is near-white in dark
  /// mode on a near-white surface -- identical in effect to F197, with no
  /// `textTheme` token anywhere for the detector to match. Harold found it on
  /// an S24+ one day after the F197 gate shipped, on the Export Successful
  /// dialog: the file path, the one thing the dialog exists to convey.
  ///
  /// **Two additional gaps this group closes, both found by the audit:**
  ///
  /// 1. **Bracket-index shades were never matched.** F197's surface regex reads
  ///    `Colors\.[a-z]+\.shade\d+` only, so `Colors.grey[200]` -- the form all
  ///    four F210 instances actually used -- was invisible to it.
  /// 2. **Dialogs were never audited.** F197's sweep covered cards and
  ///    containers in screens. `showDialog` bodies were not looked at, which is
  ///    why the Export dialog survived. Nothing here special-cases dialogs; the
  ///    scan is over the same tree, and the point is that the SHAPE now matches.
  ///
  /// **The false positive to avoid is the same one F197 documents**: a fully
  /// hardcoded card pins both halves and is correct in any theme. Text with no
  /// colour is only a defect when the surface above it is pinned.
  group('Dark-mode surface/colourless-text invariant (F210, Sprint 69)', () {
    /// A pinned surface, in EITHER spelling: `Colors.grey.shade200` (F197's
    /// form) or `Colors.grey[200]` (the form F210 found in the wild).
    ///
    /// Excludes the same non-text shapes F197 excludes, for the same reasons:
    /// an icon tint and a border are decoration, and a hardcoded TEXT colour
    /// pins its own foreground and belongs to the F133 gate.
    bool isPinnedSurface(String line) {
      final hasShade = RegExp(
        r'(?:^|[\s(,])(?:color|backgroundColor):\s*Colors\.[a-zA-Z]+'
        r'(?:\.shade\d+|\[\d+\])',
      ).hasMatch(line);
      if (!hasShade) return false;
      if (line.contains('TextStyle')) return false;
      if (line.contains('Icon(')) return false;
      if (line.contains('BorderSide') || line.contains('border:')) return false;
      return true;
    }

    /// Is line [i] a colour inside an `Icon(...)` that opened on an earlier
    /// line?
    ///
    /// The same `dart format` wrapping problem the F197 group hit with
    /// `TextStyle`, and it bit here for the identical reason. When the call
    /// grows past the line limit the tint lands on its own line, carrying no
    /// `Icon(` token for the single-line exclusion to see:
    ///
    /// ```dart
    /// Icon(Icons.check_circle_outline,
    ///   color: Colors.green.shade600, size: 16),   // <- read as a SURFACE
    /// ```
    ///
    /// Both real occurrences (`account_setup_screen.dart:546`,
    /// `safe_senders_management_screen.dart:689`) are icon tints, which WCAG
    /// 1.4.3 does not hold to the text minimum. Without this the gate reports
    /// two false positives -- and a gate that blocks correct work trains
    /// bypass, which is the failure mode the F197 group doc names explicitly.
    bool insideMultiLineIcon(List<String> lines, int i) {
      var depth = 0;
      for (var k = i - 1; k >= 0; k--) {
        depth +=
            ')'.allMatches(lines[k]).length - '('.allMatches(lines[k]).length;
        if (depth < 0) {
          // Same rule as the TextStyle walk: the opener decides. The previous
          // version used a 4-line window, which a five-argument wrapped Icon
          // stepped straight past -- a false positive that would have blocked
          // correct work, the exact failure mode the group doc warns about.
          return RegExp(r'\bIcon\(').hasMatch(lines[k]);
        }
      }
      return false;
    }

    /// Reuses F197's bracket walk: a colour inside a `TextStyle(` that opened
    /// on an earlier line is TEXT, not a surface, however `dart format` wrapped
    /// it. Duplicated rather than shared because the two groups are read
    /// independently and a silent change to one must not alter the other.
    bool insideMultiLineTextStyle(List<String> lines, int i) {
      var depth = 0;
      for (var k = i - 1; k >= 0; k--) {
        depth +=
            ')'.allMatches(lines[k]).length - '('.allMatches(lines[k]).length;
        if (depth < 0) {
          // The line that opened the bracket we sit inside DECIDES. The
          // previous version returned true whenever a TextStyle( appeared
          // anywhere in a 6-line window while depth was negative -- but depth
          // goes negative on the Container( the surface itself lives in, so a
          // CLOSED TextStyle above an unrelated Container made the gate skip
          // a genuine pinned surface. Verified by probe against the real
          // Export-dialog defect.
          return lines[k].contains('TextStyle(');
        }
      }
      return false;
    }

    /// Does the `TextStyle(...)` opening at [start] declare a colour?
    ///
    /// Scans forward to the matching close bracket, so a multi-line style is
    /// read whole. `color:` ANYWHERE inside it -- hardcoded, theme-derived, or
    /// a conditional -- means the foreground is deliberate and out of scope.
    /// Only a style that never mentions colour inherits from the theme.
    bool textStyleDeclaresColour(List<String> lines, int start) {
      // Decide the OPENING line on its own terms first. A single-line
      // `TextStyle(fontSize: 12),` closes here, so the loop below must never
      // run -- the previous version fell through to the NEXT line and read a
      // sibling widget's `color:`, suppressing a real violation.
      if (lines[start].contains('color:')) return true;
      var depth = '('.allMatches(lines[start]).length -
          ')'.allMatches(lines[start]).length;
      if (depth <= 0) return false;

      // Multi-line: walk to the matching close. Terminated by DEPTH, not by a
      // line count -- a fixed cap reported a long style as colourless, which
      // is a false positive that blocks correct work.
      for (var k = start + 1; k < lines.length; k++) {
        if (lines[k].contains('color:')) return true;
        depth +=
            '('.allMatches(lines[k]).length - ')'.allMatches(lines[k]).length;
        if (depth <= 0) return false;
      }
      return false;
    }

    /// Same window as F197, and for the same reason: far enough to cross a
    /// Container + padding + child into its text, not so far as to reach the
    /// next widget. Verified against all four real F210 instances.
    const windowLines = 12;

    test('the matcher self-checks: colourless text on a pinned surface only',
        () {
      // THE DEFECT (Export Successful dialog, results_display_screen.dart).
      const defect = [
        'decoration: BoxDecoration(color: Colors.grey[200]),',
        'child: SelectableText(',
        '  filePath,',
        "  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),",
        '),',
      ];
      expect(isPinnedSurface(defect[0]), isTrue,
          reason: 'Colors.grey[200] is a pinned surface -- the bracket form '
              'F197 could not match at all');
      expect(textStyleDeclaresColour(defect, 3), isFalse,
          reason: 'no colour: in the style means Flutter resolves it from the '
              'theme, which is the whole defect');

      // NOT a defect: a fully hardcoded card pins BOTH halves (Default
      // Folders, 7.56:1). This is the false positive that would make the gate
      // block correct work.
      const hardcoded = [
        'color: Colors.blue.shade50,',
        'child: Text("Default folders",',
        '  style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),',
      ];
      expect(textStyleDeclaresColour(hardcoded, 2), isTrue,
          reason: 'the foreground is pinned, so the card holds in any theme');

      // NOT a defect: a multi-line style that declares a colour further down.
      const multiLineWithColour = [
        'style: TextStyle(',
        '  fontSize: 12,',
        '  fontFamily: "monospace",',
        '  color: Colors.blue.shade900,',
        '),',
      ];
      expect(textStyleDeclaresColour(multiLineWithColour, 0), isTrue,
          reason: 'the colour is declared, just not on the opening line');

      // The F197 exclusions still hold in this group.
      expect(isPinnedSurface('Icon(Icons.info, color: Colors.blue[700])'),
          isFalse);
      expect(
          isPinnedSurface('border: Border.all(color: Colors.grey[300]!),'),
          isFalse);
      expect(
          isPinnedSurface(
              'style: TextStyle(color: Colors.grey[600], fontSize: 12),'),
          isFalse);

      // The bracket walk must not treat a wrapped TEXT colour as a surface.
      const splitTextStyle = [
        'style: TextStyle(',
        '  color: Colors.blue[900],',
        '),',
      ];
      expect(insideMultiLineTextStyle(splitTextStyle, 1), isTrue);

      // ---------------------------------------------------------------------
      // THE THREE REGRESSIONS CODE REVIEW FOUND IN THIS GROUP'S OWN
      // HEURISTICS. Each one made the gate pass on code it was written to
      // catch, or fail on code it was written to allow. They are pinned here
      // because "the gate is green" was true in every case.
      // ---------------------------------------------------------------------

      // FALSE NEGATIVE, the worst of the three: a CLOSED TextStyle above an
      // unrelated Container made the walk skip a genuine pinned surface,
      // because depth goes negative on the `Container(` itself. This is the
      // real Export-dialog defect with a labelled Text above it -- the single
      // most common layout in the codebase.
      const closedStyleThenRealSurface = [
        "Text('Exported to:', style: TextStyle(fontSize: 12)),",
        'const SizedBox(height: 8),',
        'Container(',
        'decoration: BoxDecoration(color: Colors.grey[200]),',
      ];
      expect(isPinnedSurface(closedStyleThenRealSurface[3]), isTrue);
      expect(insideMultiLineTextStyle(closedStyleThenRealSurface, 3), isFalse,
          reason: 'the Container( opened the bracket, not the TextStyle -- '
              'treating this as text is how the gate passed vacuously on the '
              'defect it exists to catch');

      // FALSE POSITIVE: a five-argument wrapped Icon stepped past the old
      // 4-line window, so its tint was read as a surface and any themed text
      // below it failed the build. A gate that blocks correct work trains
      // bypass, which this group's doc warns about explicitly.
      const wideIcon = [
        'Icon(',
        '  Icons.check_circle_outline,',
        '  size: 16,',
        "  semanticLabel: 'ok',",
        '  weight: 2,',
        '  color: Colors.green.shade600,',
        '),',
      ];
      expect(insideMultiLineIcon(wideIcon, 5), isTrue,
          reason: 'an icon tint is decoration however many arguments precede '
              'it -- the walk must terminate on DEPTH, never on a line count');

      // SUPPRESSED VIOLATION: for a single-line TextStyle the colour check ran
      // before any bracket bookkeeping, so it read the NEXT widget's colour
      // and dropped a real violation.
      const styleThenSiblingColour = [
        'style: TextStyle(fontSize: 12),',
        'color: Colors.blue,',
      ];
      expect(textStyleDeclaresColour(styleThenSiblingColour, 0), isFalse,
          reason: 'the style on line 0 closes on line 0; the colour below it '
              'belongs to a SIBLING widget and must not count as this text '
              'declaring its own colour');

      // And the inverse: a long style that declares its colour late is NOT
      // colourless. The old 12-line cap reported it as such.
      const longStyle = [
        'style: TextStyle(',
        '  fontSize: 12,',
        '  height: 1.2,',
        '  letterSpacing: 0.5,',
        '  wordSpacing: 1,',
        '  fontWeight: FontWeight.w600,',
        '  fontStyle: FontStyle.italic,',
        '  decorationThickness: 1,',
        '  fontFamily: "monospace",',
        '  overflow: TextOverflow.ellipsis,',
        '  backgroundColor: Colors.transparent,',
        '  decorationStyle: TextDecorationStyle.solid,',
        '  textBaseline: TextBaseline.alphabetic,',
        '  color: Colors.blue.shade900,',
        '),',
      ];
      expect(textStyleDeclaresColour(longStyle, 0), isTrue,
          reason: 'a declared colour is declared however far down it sits');

      // Nor a wrapped ICON tint -- the real shape from
      // account_setup_screen.dart:546, where dart format pushed the tint onto
      // its own line and the single-line `Icon(` exclusion could not see it.
      const splitIcon = [
        'Icon(Icons.check_circle_outline,',
        '  color: Colors.green.shade600, size: 16),',
      ];
      expect(isPinnedSurface(splitIcon[1]), isTrue,
          reason: 'the single-line check cannot see the Icon( above it -- '
              'this is why insideMultiLineIcon exists');
      expect(insideMultiLineIcon(splitIcon, 1), isTrue,
          reason: 'an icon tint is decoration, not text (WCAG 1.4.3)');

      // The icon walk must not over-reach past a CLOSED Icon().
      const closedIconThenSurface = [
        'Icon(Icons.info, size: 16),',
        'color: Colors.grey[100],',
      ];
      expect(insideMultiLineIcon(closedIconThenSurface, 1), isFalse,
          reason: 'the Icon on the previous line is CLOSED; the surface below '
              'it is a genuine surface');
    });

    test('no pinned surface wraps text that omits its colour', () {
      final uiDir = Directory('lib/ui');
      expect(uiDir.existsSync(), isTrue,
          reason: 'run this test from the mobile-app/ directory');

      final violations = <String>[];

      for (final entity in uiDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final fileName = entity.uri.pathSegments.last;
        final lines = entity.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          if (!isPinnedSurface(lines[i])) continue;
          if (insideMultiLineTextStyle(lines, i)) continue;
          if (insideMultiLineIcon(lines, i)) continue;

          final end = i + windowLines >= lines.length
              ? lines.length
              : i + windowLines + 1;
          for (var j = i + 1; j < end; j++) {
            if (!lines[j].contains('TextStyle(')) continue;
            if (textStyleDeclaresColour(lines, j)) continue;

            violations.add(
              '$fileName:${i + 1} pins a surface -- ${lines[i].trim()}\n'
              '    but $fileName:${j + 1} styles text with NO colour -- '
              '${lines[j].trim()}\n'
              '    Flutter resolves an omitted colour from the THEME, so the '
              'text flips with the theme while this surface does not. In dark '
              'mode that is near-white on near-white. This is the F197 defect '
              'with no textTheme token to match on -- which is exactly how it '
              'reached a shipped build one day after the F197 gate. Fix by '
              'making the surface theme-derived '
              '(`colorScheme.surfaceContainerHighest`), which is what F210 '
              'did, or by pinning the text colour if the surface must stay '
              'fixed.',
            );
            break;
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'A pinned surface wrapping text that inherits its colour from '
            'the theme is unreadable in one of the two themes (ADR-0037, '
            'WCAG 2.1 AA 4.5:1). See docs/ACCESSIBILITY_STANDARDS.md '
            'section 4.\n\n${violations.join('\n\n')}',
      );
    });
  });
}
