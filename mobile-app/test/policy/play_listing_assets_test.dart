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
      // Play: each side 320-3840px, aspect ratio between 16:9 and 9:16.
      expect(h.width, inInclusiveRange(320, 3840),
          reason: '$path width ${h.width} is outside Play\'s 320-3840 range');
      expect(h.height, inInclusiveRange(320, 3840),
          reason: '$path height ${h.height} is outside Play\'s 320-3840 range');
      final ratio = h.width / h.height;
      expect(ratio, inInclusiveRange(9 / 16, 16 / 9),
          reason: '$path aspect ratio must be between 9:16 and 16:9');
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
}
