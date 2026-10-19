/// The one place in `lib/` that reads `dart:io` `Platform.isX` (ADR-0049, F294).
///
/// Every platform difference in the app is answered by [PlatformCapabilities]
/// (what the code CAN do) or [PlatformPolicy] (what the app SHOULD do), and
/// both are built from the [HostPlatform] detected here.
/// `test/policy/platform_check_seam_test.dart` fails on any `Platform.isX`
/// in `lib/` outside `lib/core/platform/`.
library;

import 'dart:io' show Platform;

/// The operating system the app is running on.
enum HostPlatform { windows, android, ios, macos, linux, other }

/// Reads the host operating system once per call. Not cached: tests that
/// need another host use the `debugOverride` seams on the two classes.
HostPlatform detectHostPlatform() {
  if (Platform.isWindows) return HostPlatform.windows;
  if (Platform.isAndroid) return HostPlatform.android;
  if (Platform.isIOS) return HostPlatform.ios;
  if (Platform.isMacOS) return HostPlatform.macos;
  if (Platform.isLinux) return HostPlatform.linux;
  return HostPlatform.other;
}
