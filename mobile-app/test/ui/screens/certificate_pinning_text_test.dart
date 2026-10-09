/// Sprint 77 Phase 5.1.2 F-PRECHECK (LOW): the "Pin Google OAuth certificates"
/// switch told Android users that Google sign-in connects only to Google Trust
/// Services certificates. Android does not use `PinnedHttpClient` (its sign-in
/// goes through google_sign_in / flutter_appauth), so that claim was false
/// there. The text is now per platform.
///
/// What this does NOT catch: a future Android code path that starts using
/// `PinnedHttpClient` (the Android text would then understate the switch);
/// the source check below only shows today's pinned callers are the desktop
/// handler.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/settings_screen.dart';

void main() {
  test('Windows text describes the pin; Android text says the switch does not '
      'apply', () {
    final windows = SettingsScreen.certificatePinningSubtitle(isAndroid: false);
    final android = SettingsScreen.certificatePinningSubtitle(isAndroid: true);
    expect(windows, contains('Google Trust Services'));
    expect(android, isNot(contains('Google Trust Services')));
    expect(android, contains('does not'));
  });

  test('the switch uses the per-platform text through the Android seam', () {
    final src = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
    expect(
        src.contains('subtitle: Text(SettingsScreen.certificatePinningSubtitle(\n'
            '              isAndroid: SettingsScreen.showsAndroidBackgroundRows)),'),
        isTrue);
  });

  test('only the desktop OAuth handler constructs PinnedHttpClient', () {
    final callers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll('\\', '/').endsWith(
            'core/security/certificate_pinner.dart'))
        .where((f) => f.readAsStringSync().contains('PinnedHttpClient('))
        .map((f) => f.path.replaceAll('\\', '/').split('/').last)
        .toSet();
    expect(callers, {'gmail_windows_oauth_handler.dart'},
        reason: 'a new caller may run on Android: revisit the Android text');
  });
}
