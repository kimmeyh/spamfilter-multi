import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gmail OAuth scope parity gate (GP-4, Sprint 66, Issue #388).
///
/// **What this protects, and why it is an ADR-0042 concern.** The requested
/// Gmail scopes are declared in TWO independent places:
///
/// - `lib/adapters/auth/google_auth_service.dart` -- `GmailScopes.defaultScopes`
/// - `lib/adapters/email_providers/gmail_windows_oauth_handler.dart` -- a
///   private `_scopes` list
///
/// They agree today, but nothing made them agree. They are separate literals,
/// so a scope added to one and not the other produces a silent per-platform
/// divergence in what the app asks a user to consent to. That is precisely the
/// class ADR-0042 exists to prevent: same behaviour everywhere unless a
/// platform exception is declared, and this is not one.
///
/// **Why it matters more than usual right now.** GP-4 submits these scopes to
/// Google for OAuth verification. A reviewer assesses the scopes the app
/// declares. If the two lists drift after submission, one platform is
/// requesting something the verification did not cover.
///
/// **Declared-but-unrequested scopes are also a finding.** Sprint 66 removed
/// `gmail.readonly` and `gmail.send` because nothing requested them -- a send
/// scope declared on a spam filter invites a question a reviewer should never
/// have to ask. This gate keeps that surface narrow.
void main() {
  final authService = File('lib/adapters/auth/google_auth_service.dart');
  final windowsHandler =
      File('lib/adapters/email_providers/gmail_windows_oauth_handler.dart');

  /// Every Google API scope URL appearing as a string literal in [source].
  Set<String> scopeUrlsIn(String source) => RegExp(
        r"'(https://www\.googleapis\.com/auth/[a-zA-Z0-9._-]+)'",
      ).allMatches(source).map((m) => m.group(1)!).toSet();

  test('both scope declarations exist where this gate expects them', () {
    // If a refactor moves either declaration, this fails FIRST with a clear
    // reason -- rather than the parity check below silently comparing two
    // empty sets and passing.
    expect(authService.existsSync(), isTrue);
    expect(windowsHandler.existsSync(), isTrue);

    expect(scopeUrlsIn(authService.readAsStringSync()), isNotEmpty,
        reason: 'no Google API scope literals found in google_auth_service.dart '
            '-- the declaration moved, so this gate is comparing nothing. '
            'Update the gate rather than deleting it.');
    expect(scopeUrlsIn(windowsHandler.readAsStringSync()), isNotEmpty,
        reason: 'no Google API scope literals found in '
            'gmail_windows_oauth_handler.dart -- see above.');
  });

  test('the Windows and shared scope sets are IDENTICAL', () {
    final shared = scopeUrlsIn(authService.readAsStringSync());
    final windows = scopeUrlsIn(windowsHandler.readAsStringSync());

    final onlyShared = shared.difference(windows).toList()..sort();
    final onlyWindows = windows.difference(shared).toList()..sort();

    expect(onlyShared, isEmpty,
        reason: 'scope(s) declared in google_auth_service.dart but NOT in the '
            'Windows handler: $onlyShared. The two platforms would ask users '
            'to consent to different things -- an undeclared ADR-0042 '
            'divergence. Add it to both, or declare an explicit platform '
            'exception with its reason.');
    expect(onlyWindows, isEmpty,
        reason: 'scope(s) declared in the Windows handler but NOT in '
            'google_auth_service.dart: $onlyWindows. Same divergence, other '
            'direction -- and this one also means Windows requests something '
            "the OAuth verification submission may not have covered.");
  });

  test('no restricted scope is declared without being requested', () {
    // GP-4 R-3: a reviewer assesses what is DECLARED. Constants left behind
    // "in case we need them later" widen the verification surface for free.
    // gmail.send is called out by name because it is the one whose presence on
    // a spam filter is actively misleading.
    final source = authService.readAsStringSync();
    final declared = scopeUrlsIn(source);

    const neverRequested = <String>[
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.readonly',
    ];

    for (final scope in neverRequested) {
      expect(declared.contains(scope), isFalse,
          reason: 'the scope "$scope" is declared but no code path requests '
              'it. Removed in Sprint 66 to narrow the OAuth verification '
              'surface. If a feature genuinely needs it now, add the code '
              'path FIRST, then re-declare it here and update the Google '
              'verification submission -- the submitted scope set and the '
              'requested scope set must match.');
    }
  });
}
