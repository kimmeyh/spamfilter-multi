import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F219 (Sprint 70): `android:taskAffinity=""` must not return to MainActivity.
///
/// **What it broke.** MainActivity carries the OAuth redirect intent filter.
/// An EMPTY task affinity means the activity belongs to no task, so when the
/// browser fired the redirect Android had no task to route it into. The intent
/// never arrived and flutter_appauth surfaced it as `null_intent` -- Google
/// Sign-In failed for every tester on Android.
///
/// **Why a gate and not just a comment.** The attribute is the Flutter Android
/// template default. Any future `flutter create`-style rescaffold, or a
/// copy-paste from template docs, reintroduces it silently, and the symptom
/// appears only on a real device during an OAuth round trip -- the single most
/// expensive place to rediscover it.
void main() {
  test('MainActivity declares no empty android:taskAffinity', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // Strip XML comments first. The F219 rationale comment QUOTES the attribute
    // it removed, and a naive search would match that and pass/fail on prose.
    // (Same trap the F210 gate hit in Sprint 69: a text gate matching something
    // other than the thing it checks.)
    final code = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    expect(code.contains('taskAffinity'), isFalse,
        reason: 'android:taskAffinity on MainActivity breaks the OAuth '
            'redirect (F219, null_intent). If a future change genuinely needs '
            'an explicit affinity, it must NOT be the empty string, and it '
            'must not be hardcoded -- applicationIdSuffix ".dev" means dev and '
            'prod are separate apps that must stay in separate tasks.');
  });

  test('F227: MainActivity does NOT re-register the OAuth redirect scheme', () {
    // UPDATED BY F227 (Sprint 70). This test previously asserted the OPPOSITE --
    // that MainActivity still carried the redirect filter -- as a paired check
    // so the taskAffinity fix could not guard a filter that had moved away.
    //
    // Emulator probing showed that pairing was wrong. flutter_appauth declares
    // its own net.openid.appauth.RedirectUriReceiverActivity with the same
    // filter, so MainActivity carrying one meant TWO activities claimed the
    // scheme and Android showed a chooser instead of delivering the callback --
    // which is what produced null_intent. Verified on an Android 14 emulator:
    // `pm query-activities` returned 2 activities before the fix and 1 after,
    // and the redirect now lands in the app's own task rather than
    // ResolverActivity.
    //
    // So the invariant inverted: MainActivity must NOT declare this filter.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final code = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    expect(code.contains(r'${appAuthRedirectScheme}'), isFalse,
        reason: "F227: the redirect scheme belongs to AppAuth's own "
            "RedirectUriReceiverActivity, which flutter_appauth declares. "
            "Re-adding it here makes TWO activities claim the scheme, Android "
            "shows a chooser, AppAuth's receiver never runs, and the flow "
            "fails with null_intent.");
  });

  test('F227: the scheme is still WIRED, just not here', () {
    // The paired assertion, corrected. Removing the filter must not silently
    // unregister the scheme -- the gradle placeholder that feeds AppAuth's
    // receiver has to survive, or the redirect resolves to nothing at all.
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('appAuthRedirectScheme'), isTrue,
        reason: "the manifestPlaceholder in build.gradle.kts is what supplies "
            "the scheme to AppAuth's receiver (SEC-9, Sprint 64). Without it "
            "nothing registers the redirect.");
  });
}
