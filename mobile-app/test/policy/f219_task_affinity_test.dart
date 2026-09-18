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

  test('the OAuth redirect intent filter is still present', () {
    // The paired assertion. Removing taskAffinity is only meaningful while this
    // activity is still the redirect target; if the filter moved, the fix above
    // would be guarding nothing and this gate would pass vacuously.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final code = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    expect(code.contains(r'${appAuthRedirectScheme}'), isTrue,
        reason: 'the redirect scheme placeholder is what makes MainActivity '
            'the OAuth return target');
  });
}
