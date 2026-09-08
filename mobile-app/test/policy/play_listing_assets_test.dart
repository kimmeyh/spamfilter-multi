import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-6 Play listing policy gate (Sprint 65, Issue #383).
///
/// **What this protects.** Play rejects a listing at UPLOAD for things that are
/// trivially checkable locally: a short description one character over the
/// limit, a feature graphic that is not exactly 1024x500, an alpha channel on
/// an image that may not have one. Each rejection is a slow round trip through
/// the console, and a rejection during the closed-test rollout delays the
/// 14-day clock that gates the entire Play launch.
///
/// **The character counts are MEASURED, not read.** The listing copy states a
/// count next to each description. This gate extracts the actual text and
/// counts it, because a stated count is a claim and a measured count is a
/// fact -- and the two drift the moment someone edits the copy without
/// updating the number beneath it.
///
/// **The asset checks are deliberately conditional.** The screenshots and
/// feature graphic are Harold's to capture (Sprint 65 plan, Task 4 scope
/// boundary), so failing on their absence would be noise for work that is not
/// yet due. But silently passing when they are missing is worse: that is how a
/// gap survives to upload day. So a missing asset prints an explicit PENDING
/// line naming it, and a PRESENT asset is checked strictly.
void main() {
  final listingCopy = File('../docs/store-assets/android/LISTING_COPY.md');
  final assetSpec = File('../docs/store-assets/android/ASSET_SPEC.md');
  const assetDir = '../docs/store-assets/android';

  /// Extract a blockquoted copy block that follows [header] and stops at
  /// [terminator], stripping the "> " markers. The copy is blockquoted in the
  /// master so the exact submitted text is unambiguous -- markdown prose
  /// around it is commentary, the blockquote is the artifact.
  String extractQuotedBlock(String source, String header, String terminator) {
    final start = source.indexOf(header);
    expect(start, greaterThan(-1),
        reason: 'LISTING_COPY.md must contain the section header "$header" -- '
            'if the section was renamed, update this gate rather than '
            'deleting it');
    final end = source.indexOf(terminator, start);
    expect(end, greaterThan(start),
        reason: 'could not find "$terminator" after "$header"');
    final body = source.substring(start + header.length, end);
    final quoted = body
        .split('\n')
        .where((l) => l.trimLeft().startsWith('>'))
        .map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), ''))
        .join('\n')
        .trim();
    expect(quoted, isNotEmpty,
        reason: 'the copy under "$header" must be blockquoted so the exact '
            'submitted text is unambiguous');
    return quoted;
  }

  /// Read a PNG's width, height and colour type straight from the IHDR chunk.
  /// Colour type 6 (RGBA) and 4 (grey+alpha) carry an alpha channel, which
  /// Play rejects on listing graphics.
  ({int width, int height, int colourType}) readPngHeader(File file) {
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(26),
        reason: '${file.path} is too small to be a valid PNG');
    final width = bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19];
    final height = bytes[20] << 24 | bytes[21] << 16 | bytes[22] << 8 | bytes[23];
    return (width: width, height: height, colourType: bytes[25]);
  }

  test('the listing copy and asset specification exist', () {
    expect(listingCopy.existsSync(), isTrue,
        reason: 'GP-6 records the submitted listing text in the repo so the '
            'next submission does not re-derive it from the console');
    expect(assetSpec.existsSync(), isTrue,
        reason: 'the asset specification is what Harold captures from, and '
            'what names the filenames this gate checks');
  });

  test('the short description is within Play\'s 80-character limit', () {
    final text = extractQuotedBlock(
      listingCopy.readAsStringSync(),
      '## Short description (80 character limit)',
      '**Character count',
    );
    expect(text.length, lessThanOrEqualTo(80),
        reason: 'Play truncates or rejects over-length short descriptions. '
            'Measured ${text.length} characters: "$text"');
  });

  test('the full description is within Play\'s 4000-character limit', () {
    final text = extractQuotedBlock(
      listingCopy.readAsStringSync(),
      '## Full description (4000 character limit)',
      '**Character count',
    );
    expect(text.length, lessThanOrEqualTo(4000),
        reason: 'Play rejects over-length full descriptions. Measured '
            '${text.length} characters.');
  });

  test('the cross-store claim comparison exists and is populated (AC-4)', () {
    final content = listingCopy.readAsStringSync();
    final start = content.indexOf('## Cross-store claim comparison');
    expect(start, greaterThan(-1),
        reason: 'AC-4 requires a recorded claim-by-claim comparison against '
            'the Microsoft Store listing -- same product, same claims, with '
            'any deliberate difference justified');

    final section = content.substring(start);
    // Table rows, not prose: the comparison is only useful if it actually
    // enumerates claims. A heading with an empty body would satisfy a
    // presence check and prove nothing.
    final rows = section
        .split('\n')
        .where((l) => l.trimLeft().startsWith('|') && l.contains('|'))
        .length;
    expect(rows, greaterThan(5),
        reason: 'the comparison must enumerate individual claims, not just '
            'assert that a comparison happened. Found $rows table lines.');
  });

  test('listing graphics are correct when present, and named when not', () {
    // Filenames come from ASSET_SPEC.md. Keep the two in step: if a filename
    // changes there, it changes here.
    const featureGraphic = '$assetDir/feature_graphic_1024x500.png';
    const phoneScreenshots = [
      '$assetDir/phone_01_choose_provider.png',
      '$assetDir/phone_02_scan_results.png',
      '$assetDir/phone_03_review_no_rule.png',
      '$assetDir/phone_04_manage_rules.png',
      '$assetDir/phone_05_background_scan.png',
    ];

    final pending = <String>[];

    final fg = File(featureGraphic);
    if (fg.existsSync()) {
      final h = readPngHeader(fg);
      expect(h.width, 1024,
          reason: 'Play requires the feature graphic to be exactly 1024x500');
      expect(h.height, 500,
          reason: 'Play requires the feature graphic to be exactly 1024x500');
      expect(h.colourType == 6 || h.colourType == 4, isFalse,
          reason: 'the feature graphic must not carry an alpha channel -- '
              'Play rejects it at upload');
    } else {
      pending.add(featureGraphic);
    }

    var presentScreenshots = 0;
    for (final path in phoneScreenshots) {
      final f = File(path);
      if (!f.existsSync()) {
        pending.add(path);
        continue;
      }
      presentScreenshots++;
      final h = readPngHeader(f);
      // Play: each side 320-3840px.
      expect(h.width, inInclusiveRange(320, 3840),
          reason: '$path width ${h.width} is outside Play\'s 320-3840 range');
      expect(h.height, inInclusiveRange(320, 3840),
          reason: '$path height ${h.height} is outside Play\'s 320-3840 range');

      // NO ASPECT-RATIO ASSERTION, deliberately.
      //
      // This test previously required the ratio to fall between 9:16 and 16:9.
      // That bound is not what Play enforces, and the assertion actively
      // obstructed correct work: on 2026-09-08 all five screenshots were
      // captured at 1080x2340 -- the `pixel34_updated` AVD's native resolution,
      // and the exact example the ASSET_SPEC row itself offered as satisfying
      // the rule -- uploaded to the Play Console without complaint, and then
      // failed this gate at 1:2.167, which exceeds 9:16 by 1.22x.
      //
      // A modern portrait phone is 20:9 or taller. A gate that rejects the
      // native resolution of the very emulator the spec names is not
      // protecting anything; it invites someone to crop real content off a
      // screenshot to satisfy a limit that does not exist, or to weaken the
      // gate under time pressure and take its other assertions down with it.
      //
      // The side-length bounds above ARE real and stay. If Play ever does
      // reject a tall capture, restore a ratio check with the console's own
      // error text quoted here as evidence -- not from a remembered rule.
    }

    // Only enforce the minimum count once capture has started. Enforcing it
    // from zero would fail every run until Harold does work that is not yet
    // due -- see this file's header for why the pending state is printed
    // rather than asserted.
    if (presentScreenshots > 0) {
      expect(presentScreenshots, greaterThanOrEqualTo(2),
          reason: 'Play requires at least 2 phone screenshots; capture has '
              'started but only $presentScreenshots are present');
    }

    if (pending.isNotEmpty) {
      // Visible, not silent. This is the line that stops a missing asset
      // surviving to upload day.
      // ignore: avoid_print
      print('PENDING Play assets (Harold captures these -- see '
          'docs/store-assets/android/ASSET_SPEC.md):');
      for (final p in pending) {
        // ignore: avoid_print
        print('  - $p');
      }
    }
  });

  test('the listing claims no email provider a user cannot actually connect',
      () {
    // WHY THIS EXISTS. Every other assertion in this file checks the SHAPE of
    // the copy -- how long it is, whether a section is present. None of them
    // checks whether the copy is TRUE, and on 2026-09-08 a false claim went
    // all the way to the Play Console with this gate green: the descriptions
    // advertised "Gmail, AOL, Yahoo, iCloud, and any other IMAP-based email
    // provider" while the shipped app offers exactly two connectable
    // providers. The contradiction was caught by eye, against a screenshot in
    // the same listing showing Yahoo marked "Coming Soon".
    //
    // The bad claim came from reading `platform_registry.dart`, which is a
    // catalogue of every provider the codebase knows about regardless of
    // whether the UI exposes it. The screen is the shipped truth:
    // `platform_selection_screen.dart` renders `phase == 1` as "Available Now"
    // and DISABLES `phase == 2` ("Coming Soon"), while phases 3+ are filtered
    // out before render. So this test derives the permitted names from the
    // registry's phase-1 entries and fails if the copy names anything else.
    //
    // Deliberately narrow: it checks provider NAMES, the specific class of
    // claim that broke. It cannot verify the copy's other factual claims, and
    // pretending otherwise would be the same over-trust that let this through.
    final registry = File(
            'lib/adapters/email_providers/platform_registry.dart')
        .readAsStringSync();

    // Parse `id: 'x'` / `displayName: 'Y'` / `phase: N` triples.
    final entries = RegExp(
      r"id:\s*'([^']+)',\s*displayName:\s*'([^']+)',\s*phase:\s*(\d+)",
      multiLine: true,
    ).allMatches(registry);
    expect(entries, isNotEmpty,
        reason: 'could not parse provider entries from platform_registry.dart '
            '-- if its shape changed, fix this gate rather than removing it');

    final connectable = <String>{};
    final notConnectable = <String>{};
    for (final m in entries) {
      final display = m.group(2)!;
      final phase = int.parse(m.group(3)!);
      if (phase == 1) {
        connectable.add(display);
      } else if (phase > 1) {
        notConnectable.add(display);
      }
    }
    expect(connectable, isNotEmpty,
        reason: 'no phase-1 (Available Now) providers found -- that would mean '
            'the app exposes nothing, so this gate is misreading the registry');

    final copy = listingCopy.readAsStringSync();
    final shortDesc =
        extractQuotedBlock(copy, '## Short description', '**Character count');
    final fullDesc =
        extractQuotedBlock(copy, '## Full description', '**Character count');
    final submitted = '$shortDesc\n$fullDesc';

    // A not-yet-connectable provider must not be NAMED in the submitted copy.
    // "Coming Soon" providers are the trap: they are visible in the app, which
    // makes them feel shipped when writing copy.
    //
    // Match the BRAND WORD, not the registry's full displayName. The first
    // version of this assertion did `submitted.contains(displayName)` and was
    // mutation-tested by reintroducing the exact false line that shipped --
    // it PASSED, catching nothing. The registry says "Yahoo Mail"; the copy
    // said "Yahoo". A substring test anchored on the longer string can never
    // see the shorter one, so the gate was decorative. (Same defect family as
    // the substring shadow in app_content_declarations_test.dart, inverted:
    // there the short string masked the long one, here the long string missed
    // the short one.)
    //
    // The brand word is the leading token of displayName with any parenthetical
    // dropped: "Yahoo Mail" -> "Yahoo", "iCloud Mail" -> "iCloud",
    // "Custom IMAP Server" -> "Custom" (so IMAP is checked explicitly below).
    String brandWord(String displayName) =>
        displayName.split(RegExp(r'[\s(]')).first;

    bool namesProvider(String word) =>
        RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false)
            .hasMatch(submitted);

    final wrongly = <String>[];
    for (final name in notConnectable) {
      // Demo Mode is phase 0 and is not a provider a user "connects" -- the
      // copy legitimately describes it as a feature, so it is exempt.
      if (name.startsWith('Demo Mode')) continue;
      final word = brandWord(name);
      // "Custom IMAP Server" -> guard the meaningful token, not "Custom".
      final probe = word == 'Custom' ? 'IMAP' : word;
      if (namesProvider(probe)) wrongly.add(name);
    }
    wrongly.sort();
    expect(wrongly, isEmpty,
        reason: 'the listing copy names provider(s) $wrongly, but they are not '
            'phase 1 in platform_registry.dart, so a user CANNOT connect them '
            '-- `platform_selection_screen.dart` either disables them ("Coming '
            'Soon", phase 2) or filters them out entirely (phase 3+). This is '
            'a false store claim. Either remove the name from the copy, or, if '
            'the provider genuinely shipped, move it to phase 1 first. '
            'Connectable today: ${connectable.toList()..sort()}');
  });
}
