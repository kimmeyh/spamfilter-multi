import 'dart:io';

import 'package:flutter/material.dart';

/// F209 (Sprint 69): keeps screen content clear of the Android system
/// navigation bar.
///
/// **The defect.** Harold, on a Galaxy S24+: *"didn't you find that almost all
/// the pages had the bottom bit covered by the android 3 buttons"*. The audit
/// at sprint planning showed how far it went -- only **2 of 23 screens** used
/// `SafeArea` at all. This was not a handful of missed insets; it was the
/// app-wide default.
///
/// **Not cosmetic.** On the Import/Export screen a failure message is cut off
/// mid-sentence by the navigation buttons, so the user cannot read the
/// diagnostic that explains what went wrong. On scrollable screens it can also
/// hide the last list row or a bottom action.
///
/// ## Why this applies `SafeArea`, and why that choice is load-bearing
///
/// The first implementation added raw `Padding` at `MaterialApp.builder`. Code
/// review found three defects in that approach, all of which come from the
/// same root cause: **padding shrinks the subtree without telling anything
/// inside that the inset has been handled.** Every descendant still read
/// `viewPadding.bottom == 48` and inset a second time.
///
/// 1. **Double-inset.** A `SafeArea`-wrapped bottom sheet ended 48 logical
///    pixels above the navigation bar rather than flush against it -- a dead
///    strip where content used to be.
/// 2. **The F178 popup regressed.** `results_display_screen.dart` reads insets
///    from the ROOT VIEW (`MediaQueryData.fromView`) on purpose, because
///    inherited MediaQuery gets consumed and silently degenerated its
///    safe-area math on a real phone (Sprint 62, found by Harold from a
///    screenshot showing "Block Subject" clipped). `fromView` cannot be
///    consumed -- so it still reported the full screen height while the Stack
///    it positions inside had been shrunk by 48. The popup would have been
///    clipped again, re-breaking a fix that already cost a sprint.
/// 3. **Keyboard handling broke.** `viewPadding` reports the physical inset
///    regardless of the keyboard; `padding` reports what is *not already
///    consumed by something else*, and Flutter correctly zeroes it when the
///    keyboard covers the navigation bar. Using `viewPadding` pushed every
///    text-entry screen 48 pixels too high while typing.
///
/// `SafeArea` avoids all three: it reads `padding` (so the keyboard case is
/// correct by construction) and it CONSUMES what it applies (so nothing
/// downstream insets twice).
///
/// ## Why it wraps the Scaffold BODY, not the whole app
///
/// Applying this above the `Navigator` would also wrap dialog routes, modal
/// sheets and the `ScaffoldMessenger` overlay -- which is how defects 1 and 2
/// above happened. Those surfaces already manage their own insets, correctly
/// and deliberately. So this widget is applied per screen, around the body
/// only, leaving app bars, bottom sheets, dialogs and snackbars untouched.
///
/// **DECLARED PLATFORM EXCEPTION (ADR-0042).** Windows has no system
/// navigation bar, so this is a no-op there and desktop layout is unchanged.
/// The fork is `Platform.isAndroid` at the narrowest possible point -- one
/// widget, one condition -- rather than a forked layout per screen. The
/// exception is necessary, not chosen: there is no cross-platform way to
/// express "inset for a thing that only one platform has".
class SystemInsetWrapper extends StatelessWidget {
  const SystemInsetWrapper({
    super.key,
    required this.child,
    this.debugIsAndroid,
  });

  final Widget child;

  /// Overrides the platform check. Tests only.
  ///
  /// Flutter widget tests run on the HOST, so [Platform.isAndroid] is false in
  /// CI and on this machine -- which would leave the Android branch, the one
  /// that actually ships, never rendered by any test. This seam lets both
  /// branches be exercised for real instead of asserted by proxy.
  @visibleForTesting
  final bool? debugIsAndroid;

  /// Is the system navigation inset ours to handle?
  ///
  /// Android only. Exposed so the ADR-0042 both-branches test can assert the
  /// desktop branch is a genuine no-op rather than inferring it.
  @visibleForTesting
  static bool appliesTo({required bool isAndroid}) => isAndroid;

  @override
  Widget build(BuildContext context) {
    if (!appliesTo(isAndroid: debugIsAndroid ?? Platform.isAndroid)) {
      return child;
    }

    // bottom only: the app bar owns the top inset, and horizontal insets
    // belong to cutouts this app has no reason to fight.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: child,
    );
  }
}
