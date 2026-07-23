import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

/// F-VERSION-DERIVE (Sprint 49): the single runtime source for the app
/// version string.
///
/// `pubspec.yaml` is the single source of truth for the version; this class
/// reads the COMPILED version at runtime via `package_info_plus` (already the
/// F117 Help-footer mechanism), so version-bearing strings -- the scan-log
/// filenames and the Settings About text -- can never drift from pubspec.
/// Before this, the version was hardcoded at 6+ production sites and every
/// release required a multi-file bump (missed twice: F105 shipped a stale
/// main.cpp literal; F118 broke two tests).
///
/// Works in the foreground app, the headless `--background-scan` mode (the
/// full engine + plugin registrants run there), and the MSIX sandbox. The
/// value is cached after the first read. In pure-Dart test contexts without
/// the platform channel, use [overrideForTest] (or
/// `PackageInfo.setMockInitialValues`); the 'unknown' fallback exists only so
/// best-effort logging can never crash on a missing channel.
class AppVersion {
  AppVersion._();

  static String? _cached;

  /// The app version, e.g. `0.5.7` (no build suffix).
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      _cached = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _cached = 'unknown';
    }
    return _cached!;
  }

  @visibleForTesting
  static void overrideForTest(String? version) => _cached = version;
}
