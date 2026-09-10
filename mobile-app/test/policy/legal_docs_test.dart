import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-5 publication gate (Sprint 64, Issue #368).
///
/// The legal documents under docs/legal/ are PUBLISHED LIVE at
/// https://myemailspamfilter.com/legal/ directly from main:/docs via GitHub
/// Pages. After the 2026-08-28 publication (effective date + contact email
/// set, Harold-approved), no editorial placeholder may ever reappear -- a
/// placeholder that reaches main is immediately visible to the public.
void main() {
  test('published legal documents contain no editorial placeholders', () {
    final legalDir = Directory('../docs/legal');
    expect(legalDir.existsSync(), isTrue,
        reason: 'docs/legal must exist (published site content)');

    final offenders = <String>[];
    for (final entity in legalDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final content = entity.readAsStringSync();
      for (final marker in ['[SET AT PUBLICATION', '[CONTACT EMAIL']) {
        if (content.contains(marker)) {
          offenders.add('${entity.path}: $marker');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'placeholders in published legal docs: ${offenders.join('; ')}');
  });

  test('legal documents carry an effective date and canonical URL', () {
    for (final name in ['PRIVACY_POLICY.md', 'TERMS.md']) {
      final content = File('../docs/legal/$name').readAsStringSync();
      expect(content, contains('**Effective date**:'),
          reason: '$name must state its effective date');
      expect(content, contains('https://myemailspamfilter.com/legal/'),
          reason: '$name must state its canonical published URL');
    }
  });

  /// F200 (Sprint 68): the SERVED SITE must not contradict the privacy policy.
  ///
  /// **Why this gate did not exist and needed to.** The legal documents are
  /// Markdown that GitHub Pages renders, so they track their source
  /// automatically -- correcting `PRIVACY_POLICY.md` corrects what the public
  /// reads. The landing page is HAND-WRITTEN HTML that nothing regenerates and,
  /// until now, nothing inspected.
  ///
  /// That asymmetry ran for about six months. Sprint 63 deliberately corrected
  /// the privacy policy to disclose that scan history stores sender, subject,
  /// folder, action and a 100-character body preview -- the ADR's older
  /// "in-memory only" description predated `unmatched_emails`/`email_actions`
  /// persistence. The correction landed in the legal document. The landing page
  /// kept telling users that email content "is never persisted to disk", on the
  /// same domain, one click away, and on the page cited as the privacy-policy
  /// host in the Google Play listing.
  ///
  /// A stale marketing page is untidy. A page that makes a FALSE PRIVACY CLAIM
  /// is a different category, which is why this is a build-failing gate and not
  /// a review checklist item.
  group('Served site does not contradict the privacy policy (F200)', () {
    /// Claims that are false for this app because the local database exists.
    /// Each is a phrase a well-meaning author might write while summarising
    /// "your data stays on your device" -- the failure mode here was never
    /// dishonesty, it was a summary that outlived the code it described.
    const forbiddenClaims = <String, String>{
      'never persisted to disk':
          'scan history IS written to a local database (sender, subject, '
          'folder, action, and a <=100-char preview for messages awaiting '
          'review). This exact sentence shipped on the landing page for ~6 '
          'months after PRIVACY_POLICY.md was corrected.',
      'in-memory only':
          'message EVALUATION is header-first and bodies are discarded after '
          'evaluation, but the scan RESULT is stored. "In-memory only" reads '
          'as a claim about all data.',
      'nothing is stored':
          'rules, credentials, settings and scan history are all stored '
          'locally. The true claim is that nothing leaves the DEVICE.',
      'no data is stored':
          'same as above -- the honest distinction is device-local storage '
          'versus transmission off the device.',
    };

    /// Every hand-written page served under the domain. Markdown under
    /// docs/legal/ is deliberately NOT listed: it is the source of truth these
    /// pages must agree with, and it is checked by the tests above.
    const servedPages = <String>[
      '../docs/index.html',
      '../docs/delete/index.html',
    ];

    test('the matcher self-checks: it catches the sentence that shipped', () {
      const regression =
          'Email content is processed in-memory only and is never persisted to disk.';
      final caught = forbiddenClaims.keys
          .where((c) => regression.toLowerCase().contains(c))
          .toList();
      expect(caught, isNotEmpty,
          reason: 'the gate must catch the exact wording that was live on '
              'myemailspamfilter.com -- if this fails, the claim list has '
              'drifted away from the defect it exists for');
    });

    test('no served page contradicts PRIVACY_POLICY.md', () {
      final offenders = <String>[];

      for (final path in servedPages) {
        final f = File(path);
        if (!f.existsSync()) continue; // a deleted page cannot lie
        final text = f.readAsStringSync().toLowerCase();
        for (final entry in forbiddenClaims.entries) {
          if (text.contains(entry.key)) {
            offenders.add('$path claims "${entry.key}" -- ${entry.value}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'A page served at myemailspamfilter.com contradicts '
              'docs/legal/PRIVACY_POLICY.md. The policy is authoritative; fix '
              'the page, not the policy.\n\n${offenders.join('\n\n')}');
    });

    test('exactly one privacy policy is reachable', () {
      // Two were live at once: /privacy (March 20, 2026, hand-written HTML from
      // Sprint 24) and /legal/PRIVACY_POLICY.html (August 28, 2026). The
      // landing page linked the STALE one while the Play listing cited the
      // CURRENT one, so which document a user read depended on where they
      // arrived from. F200 deleted the old page; this keeps it deleted.
      expect(File('../docs/privacy/index.html').existsSync(), isFalse,
          reason: 'docs/privacy/index.html is the superseded March 2026 policy. '
              'One canonical policy only: docs/legal/PRIVACY_POLICY.md.');
      expect(Directory('../docs/website').existsSync(), isFalse,
          reason: 'docs/website/ was the pre-cc47bd3 location of the site and '
              'was left behind as a byte-identical duplicate when the files '
              'moved to docs/ root. Two copies is how one gets fixed and the '
              'other does not.');
    });

    test('served pages link only to pages that exist', () {
      final broken = <String>[];
      final linkPattern = RegExp('href="(/[^"]*)"');

      for (final path in servedPages) {
        final f = File(path);
        if (!f.existsSync()) continue;
        for (final m in linkPattern.allMatches(f.readAsStringSync())) {
          final href = m.group(1)!;
          if (href == '/') continue; // the site root
          // GitHub Pages serves `/foo` from `docs/foo/index.html`, `/foo.html`
          // from `docs/foo.html`, AND `/foo.html` from `docs/foo.md` -- Jekyll
          // renders Markdown to HTML at that path. That last mapping is why the
          // legal documents can be Markdown in the repo and .html on the web,
          // and missing it made this check's first run report the CORRECT links
          // as broken (verified live: myemailspamfilter.com/legal/
          // PRIVACY_POLICY.html resolves and serves the August 2026 policy).
          final asFile = File('../docs$href');
          final asDir = File('../docs$href/index.html');
          final asMarkdown = href.endsWith('.html')
              ? File('../docs${href.substring(0, href.length - 5)}.md')
              : File('../docs$href.md');
          if (!asFile.existsSync() &&
              !asDir.existsSync() &&
              !asMarkdown.existsSync()) {
            broken.add('$path links to $href, which is not served');
          }
        }
      }

      expect(broken, isEmpty,
          reason: 'Deleting a page without repointing its inbound links is how '
              'a site develops dead ends.\n\n${broken.join('\n')}');
    });
  });
}
