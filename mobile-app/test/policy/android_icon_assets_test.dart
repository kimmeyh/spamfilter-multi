import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-7 policy gates (Sprint 65, Issue #382).
///
/// Adaptive icons for Android require:
/// - A 512x512 Play listing icon (32-bit PNG, no alpha channel per Play Store requirements).
/// - Icon assets at all five Android densities: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi.
/// - Foreground layer assets at all five densities.
/// - Adaptive configuration XML referencing both layers.
///
/// Source gates (T-1 and T-2) verify the files exist and have correct shape,
/// not that the artwork renders correctly -- that is verified on-device (AC-3).
/// Play rejects alpha channel at upload, which is a slow feedback loop; a local
/// gate catches the defect early.
///
/// A partial regeneration (e.g. only xxhdpi updated) would be caught by T-2
/// asserting that EVERY declared density is present.
void main() {
  // Test runs from mobile-app/ directory
  final androidResBase =
      Directory('android/app/src/main/res');
  final storeAssetsBase =
      Directory('../docs/store-assets/android');

  // T-1 (verifies AC-2): the 512x512 listing icon exists, is 512x512, and has no alpha.
  test(
      'Play listing icon (512x512) exists at correct path with no alpha channel',
      () {
    final listingIconFile = File('${storeAssetsBase.path}/play_listing_icon_512.png');
    expect(listingIconFile.existsSync(), isTrue,
        reason: 'GP-7 AC-2: 512x512 Play listing icon must exist at '
            'docs/store-assets/android/play_listing_icon_512.png');

    // Read PNG and verify dimensions via IHDR chunk.
    final bytes = listingIconFile.readAsBytesSync();
    expect(bytes.length, greaterThanOrEqualTo(24),
        reason: 'PNG file too small to contain valid IHDR');

    // PNG signature: 8 bytes. IHDR chunk: length (4) + type (4) + data (13) + crc (4) = 25 bytes.
    // Width is at offset 16 (big-endian uint32).
    // Height is at offset 20 (big-endian uint32).
    // Color type is at offset 25 (uint8): 2=RGB, 6=RGBA.
    final width = (bytes[16] << 24) |
        (bytes[17] << 16) |
        (bytes[18] << 8) |
        bytes[19];
    final height = (bytes[20] << 24) |
        (bytes[21] << 16) |
        (bytes[22] << 8) |
        bytes[23];
    final colorType = bytes[25];

    expect(width, equals(512),
        reason: 'GP-7 AC-2: listing icon width must be exactly 512px');
    expect(height, equals(512),
        reason: 'GP-7 AC-2: listing icon height must be exactly 512px');
    expect(colorType, equals(2),
        reason: 'GP-7 AC-2: listing icon must be RGB (color type 2), '
            'not RGBA (color type 6). Play rejects alpha channel.');
  });

  // T-2 (verifies AC-1): every declared density has both ic_launcher.png
  // and ic_launcher_foreground.png, and the adaptive XML exists and references
  // both layers.
  test(
      'All five densities have launcher icon and foreground layer, '
      'and adaptive XML exists', () {
    final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

    // Verify adaptive configuration exists and references the foreground layer.
    final adaptiveXml = File(
        '${androidResBase.path}/mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptiveXml.existsSync(), isTrue,
        reason: 'GP-7 AC-1: adaptive icon config must exist at '
            'mipmap-anydpi-v26/ic_launcher.xml');

    final xmlContent = adaptiveXml.readAsStringSync();
    expect(xmlContent, contains('ic_launcher_foreground'),
        reason: 'GP-7 AC-1: adaptive XML must reference '
            'drawable/ic_launcher_foreground');
    expect(xmlContent, contains('ic_launcher_background'),
        reason: 'GP-7 AC-1: adaptive XML must reference the background color');

    // Verify every density has both ic_launcher.png and ic_launcher_foreground.png.
    for (final density in densities) {
      final launcherIcon = File(
          '${androidResBase.path}/mipmap-$density/ic_launcher.png');
      expect(launcherIcon.existsSync(), isTrue,
          reason: 'GP-7 AC-1: mipmap-$density/ic_launcher.png must exist. '
              'A partial regeneration is incomplete.');

      final foregroundIcon = File(
          '${androidResBase.path}/drawable-$density/ic_launcher_foreground.png');
      expect(foregroundIcon.existsSync(), isTrue,
          reason: 'GP-7 AC-1: drawable-$density/ic_launcher_foreground.png '
              'must exist at all five densities.');
    }
  });

  // Verify background color resource exists.
  test('Background color resource exists', () {
    final colorsFile = File('${androidResBase.path}/values/colors.xml');
    expect(colorsFile.existsSync(), isTrue,
        reason: 'GP-7 AC-1: values/colors.xml must define ic_launcher_background');

    final colorsContent = colorsFile.readAsStringSync();
    expect(colorsContent, contains('ic_launcher_background'),
        reason: 'GP-7 AC-1: colors.xml must define the ic_launcher_background '
            'color used by the adaptive XML');
  });
}
