/// What the app SHOULD do on the host platform (ADR-0049, F294).
///
/// A policy is a choice (a design preference, a control users of a platform
/// expect, a store rule), not an OS limit; limits live in
/// [PlatformCapabilities]. Each getter's doc comment states its answer on
/// Windows, Android and iOS.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'host_platform.dart';

export 'host_platform.dart' show HostPlatform;

class PlatformPolicy {
  /// Builds the policy for [host]. Tests may subclass to change one answer and
  /// install it with [debugOverride].
  const PlatformPolicy(this.host);

  final HostPlatform host;

  static PlatformPolicy? _override;

  /// The policy for the running host, or the test override.
  static PlatformPolicy get current =>
      _override ?? PlatformPolicy(detectHostPlatform());

  /// Test seam: set to a fixed host or a subclass; set back to null in
  /// tearDown.
  @visibleForTesting
  static set debugOverride(PlatformPolicy? value) => _override = value;

  /// Flat, Fluent-style surfaces: lower card and dialog elevation, smaller
  /// corner radii. Windows: true. Android: false (Material 3). iOS: false.
  bool get prefersFlatSurfaces => host == HostPlatform.windows;

  /// An Exit button in the app bar. Windows: true. Android: false (users do
  /// not exit Android apps; the system manages them). iOS: false.
  bool get showsExitButton => host == HostPlatform.windows;
}
