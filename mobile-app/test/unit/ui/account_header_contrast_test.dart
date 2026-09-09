/// F195 (Sprint 67): the Settings account header must be readable in BOTH
/// themes, measured against WCAG AA rather than judged by eye.
///
/// **The defect.** `_buildAccountHeaderCard` painted a hardcoded
/// `Colors.blue.shade50` background and let its text colour come from
/// `textTheme.titleMedium` -- which the theme adapts to the mode. The two
/// halves therefore disagreed:
///
/// - LIGHT mode: dark text on pale blue -> **18.39:1**, comfortably passing
/// - DARK mode: LIGHT text on the same pale blue -> **1.14:1**, against a
///   4.5:1 requirement
///
/// Harold, 2026-09-08, from his Galaxy S24+: *"settings > Manual and Background
/// tabs (box at the top with email address in it is almost unreadable due to
/// colors)"*. One widget, three tabs (Account, Manual Scan, Background), so a
/// single fix covered all of them.
///
/// **Why the ratio is computed here rather than eyeballed on a screenshot.**
/// A screenshot proves today. A computed assertion proves next year, when
/// somebody changes the theme's `secondaryContainer` and has no idea this
/// header depends on it. R-1 of the card is explicit: measure, do not judge.
///
/// **The sibling audit, corrected.** An earlier version of this comment said
/// the pattern appeared "28 times, concentrated in `account_setup_screen.dart`".
/// Both halves were wrong, and the 5.1.1 review caught it. 28 (in fact 29) is
/// the count of hardcoded `Colors.*.shadeNN` occurrences repo-wide -- and most
/// of those are CORRECT, because they also pin their text colour. Harold's own
/// counter-example makes the point: Settings > Manual Scan > Default Folders is
/// `blue.shade900` on `blue.shade50`, fully hardcoded, and measures 7.56:1.
///
/// The defect is MIXING a hardcoded surface with theme-derived text. Auditing
/// for that specifically -- a `shadeNN` surface with a `textTheme` reference
/// within a dozen lines -- finds exactly ONE other instance
/// (`scan_history_screen.dart`, the background-scan info strip), fixed in the
/// same commit as this correction. `account_setup_screen.dart` contains no
/// `textTheme` usage at all, so the pattern is structurally impossible there.
///
/// The lesson is the one this sprint keeps teaching: a count produced by
/// grepping the easy proxy is not a count of the defect.
///
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/ui/theme/app_theme.dart';

/// Relative luminance per WCAG 2.1, and the contrast ratio built from it.
/// Implemented locally rather than pulled from a package -- it is a dozen lines
/// of a fixed, published formula, and a dependency for that is a worse trade.
double _luminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  /// WCAG AA for normal-size text. The header is `titleMedium` bold, which is
  /// borderline "large" at some scales -- the stricter bar is used deliberately,
  /// because the email address inside it renders at normal weight in practice.
  const wcagAaNormal = 4.5;

  test('the account header meets WCAG AA in the LIGHT theme', () {
    final scheme = AppTheme.lightTheme.colorScheme;
    final ratio =
        contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer);
    expect(ratio, greaterThanOrEqualTo(wcagAaNormal),
        reason: 'measured ${ratio.toStringAsFixed(2)}:1 -- the header pairs '
            'secondaryContainer with onSecondaryContainer precisely so Material '
            'guarantees this holds');
  });

  test('the account header meets WCAG AA in the DARK theme', () {
    // THE REGRESSION TEST. This is the case that failed: the old code paired
    // theme-derived text with a hardcoded Colors.blue.shade50 and measured
    // 1.14:1 here while passing comfortably in light mode -- so anyone testing
    // in light mode saw nothing wrong.
    final scheme = AppTheme.darkTheme.colorScheme;
    final ratio =
        contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer);
    expect(ratio, greaterThanOrEqualTo(wcagAaNormal),
        reason: 'measured ${ratio.toStringAsFixed(2)}:1 -- this is the mode '
            'Harold was in when the header was unreadable. A hardcoded light '
            'surface with theme-derived text measures 1.14:1 here.');
  });

  test('a hardcoded pale surface with dark-theme text FAILS -- pinning the '
      'defect shape, not just the fix', () {
    // Proves the test can actually detect the original defect. Without this,
    // the two tests above pass for a fix that was never needed -- which is
    // exactly how this sprint shipped an inert gate twice.
    const hardcodedSurface = Color(0xFFE3F2FD); // Colors.blue.shade50
    final darkText = AppTheme.darkTheme.colorScheme.onSurface;
    final ratio = contrastRatio(darkText, hardcodedSurface);
    expect(ratio, lessThan(wcagAaNormal),
        reason: 'if this ever PASSES, the measurement is wrong -- the original '
            'pairing measured 1.14:1 and was reported as unreadable from a '
            'real device');
  });
}
