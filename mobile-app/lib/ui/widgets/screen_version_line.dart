import 'package:flutter/material.dart';

import '../../core/services/app_version.dart';
import '../../core/services/app_environment.dart';

/// F229 (Sprint 73): the app version, visible on the first page of every
/// screen at phone width.
///
/// **Harold's requirement**: *"need to do a deep dive because we need to find a
/// place somewhere on the first page of every screen (V<n>.<n>.<n>)."* Every
/// screenshot then identifies the build it came from, which Sprint 72 proved
/// the release process depends on.
///
/// ## Why the AppBar cannot hold it, measured rather than argued
///
/// [AppBarVersionLabel] renders the version in the action row above 600px and
/// hides below it. Sprint 72 tried the obvious fix -- a shorter string, a
/// smaller max width -- and it still overflowed by 18px. The deep dive measured
/// why, at 411px:
///
/// - screen 411 - back button ~56 - minimum title ~72 = **283px for actions**;
/// - the six icons need **288px**, so the row is 5px over BEFORE any text;
/// - removing "Select Account" frees 43px;
/// - `V0.0.0` at 10pt needs 60px, and with the `[DEV]` suffix **120px**.
///
/// So even deleting a control buys less than half of what the string needs.
/// Shrinking the font is 17px short after that deletion; wrapping does not
/// create horizontal room inside a fixed-height AppBar; and a strip under the
/// AppBar collides with the existing `TabBar` on two screens. **Arithmetic, not
/// preference** -- which is why the trade Harold offered (give up an icon to
/// buy space) was recommended AGAINST and not spent.
///
/// This line sits in the screen BODY instead, where it is full-width and has no
/// competition at all: measured at 16 logical pixels of height, versus the
/// 120px of horizontal room it could never win upstairs.
///
/// ## Why per screen, and not once at `MaterialApp.builder`
///
/// This mirrors [SystemInsetWrapper] deliberately, and for the reason that
/// widget documents at length: F209's first implementation applied itself once
/// above the `Navigator` and broke three things, including re-breaking the F178
/// action popup, because a widget above the Navigator also wraps dialog routes,
/// modal sheets and the `ScaffoldMessenger` overlay.
///
/// A version line above the Navigator would additionally paint over dialogs and
/// bottom sheets, which are not "screens" and must not carry it. So the cost is
/// the same as F209's -- a wiring gate to keep coverage honest -- and it is
/// paid for the same reason.
///
/// ## Platform parity (ADR-0042): SAME on both, no exception
///
/// Verified per IMP-5: no OS behavior is involved. The only variable is WINDOW
/// WIDTH, which both platforms span -- a narrow Windows window enters the same
/// regime as a phone and gets the same treatment, which is the point rather
/// than an accident. The 600px threshold is shared with [AppBarVersionLabel] so
/// the app keeps ONE notion of "compact", and the two are complementary by
/// construction: exactly one of them renders at any width.
class ScreenVersionLine extends StatefulWidget {
  const ScreenVersionLine({super.key, this.debugWidth});

  /// Overrides the measured width. Tests only, so both sides of the 600px
  /// threshold can be exercised without resizing the test view.
  @visibleForTesting
  final double? debugWidth;

  /// Does this width get the BODY line rather than the AppBar label?
  ///
  /// Exposed so the complementarity with [AppBarVersionLabel] can be asserted
  /// directly: that label hides below 600, this one shows below 600, and the
  /// pair must never both render or both vanish.
  @visibleForTesting
  static bool appliesTo({required double width}) => width < 600;

  @override
  State<ScreenVersionLine> createState() => _ScreenVersionLineState();
}

class _ScreenVersionLineState extends State<ScreenVersionLine> {
  String? _version;

  @override
  void initState() {
    super.initState();
    AppVersion.get().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width =
        widget.debugWidth ?? MediaQuery.of(context).size.width;
    if (!ScreenVersionLine.appliesTo(width: width)) {
      // Wide enough for the AppBar label, which is where reviewers already
      // look. Rendering both would be noise, not redundancy.
      return const SizedBox.shrink();
    }

    final version = _version;
    if (version == null) return const SizedBox.shrink();

    // `V0.16.0` rather than `Version 0.16.0`: the short form is what Harold
    // asked for, and this line has no title competing for the reader's eye.
    // The runtime value, never a literal -- version_consistency_test and
    // stale_footer_test both police that.
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 2, bottom: 2),
      child: Text(
        'V$version${AppEnvironment.displaySuffix}',
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              // Deliberately NOT a faded grey. `text_contrast_test` enforces
              // WCAG ratios whose thresholds depend on font size, and 11pt is
              // below the large-text exemption -- so this takes the theme's
              // own secondary colour, which is already inside the contrast
              // budget, rather than an alpha that would sit outside it.
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
    );
  }
}
