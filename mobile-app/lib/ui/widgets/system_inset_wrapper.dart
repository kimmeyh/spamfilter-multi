import 'dart:io';

import 'package:flutter/material.dart';

/// F209 (Sprint 69): keeps screen content clear of the Android system
/// navigation bar.
///
/// **The defect.** Harold, on a Galaxy S24+: *"didn't you find that almost all
/// the pages had the bottom bit covered by the android 3 buttons"*. He was
/// right, and the audit at sprint planning showed how far it went -- only **2
/// of 23 screens** used `SafeArea` at all. This was not a handful of missed
/// insets; it was the app-wide default.
///
/// **Not cosmetic.** The clearest case is the Import/Export screen, where a
/// failure message is cut off mid-sentence by the navigation buttons: the user
/// cannot read the diagnostic that explains what went wrong. On scrollable
/// screens it can also hide the last list row or a bottom action.
///
/// **Why here and not in 21 screens.** Every one of the 23 screens builds its
/// own `Scaffold`; there is no shared body container to fix, and no shared
/// wrapper existed (`AppBarWithExit` is top-of-screen only and cannot address a
/// bottom inset). Applying this through `MaterialApp.builder` covers every
/// route -- including ones added later, which is the part that matters. A gate
/// alone would only catch the next screen after someone had already written it.
///
/// **DECLARED PLATFORM EXCEPTION (ADR-0042).** Windows has no system
/// navigation bar, so this is a no-op there and desktop layout is unchanged.
/// The fork is `Platform.isAndroid`, at the narrowest possible point -- one
/// widget, one condition -- rather than a forked layout per screen. The
/// exception is necessary, not a choice: there is no cross-platform way to
/// express "inset for a thing that only one platform has".
///
/// **Why `viewPadding` and not `SafeArea`.** `SafeArea` consumes
/// `MediaQuery.padding`, which a scrolling body can zero out; `viewPadding`
/// reports the physical inset regardless. Android 15 and later enforce
/// edge-to-edge rendering by default, so this grows worse on newer devices
/// rather than better, and the reported padding is the only reliable source.
///
/// Applied as bottom padding on the whole subtree, so the inset is added once
/// and every screen inherits it.
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

  /// The bottom inset to add, given the window's [viewPaddingBottom].
  ///
  /// Returns 0 on every non-Android platform and whenever the platform reports
  /// no inset -- a device using gesture navigation reports a much smaller
  /// value, and a keyboard-covered screen is handled by Flutter separately.
  @visibleForTesting
  static double bottomInset({
    required bool isAndroid,
    required double viewPaddingBottom,
  }) {
    if (!appliesTo(isAndroid: isAndroid)) return 0;
    return viewPaddingBottom;
  }

  @override
  Widget build(BuildContext context) {
    final inset = bottomInset(
      isAndroid: debugIsAndroid ?? Platform.isAndroid,
      viewPaddingBottom: MediaQuery.of(context).viewPadding.bottom,
    );

    if (inset == 0) return child;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: child,
    );
  }
}
