/// IMP-2 (Sprint 61 retrospective, approved by Harold 2026-08-21): when a
/// platform factory replaces inline platform checks, the former call sites
/// must be verified platform-free -- verification is part of introducing the
/// factory, not optional cleanup. See ADR-0042 "Platform factories" section.
///
/// The escape this pins: F161 shipped `BackgroundScanSchedulerFactory` with 9
/// mutation-verified adapter tests, but BOTH `settings_screen` call sites of
/// `_updateScheduledScan` kept their `if (Platform.isWindows)` guards from the
/// pre-factory code. The setting persisted, no work was ever scheduled, and
/// Android's enable toggle LIED -- found live by Harold in Manual Validation
/// round 1, one file away from the fully-tested factory.
///
/// This is a SOURCE-TEXT gate (like msix_config_test): it proves the guard is
/// absent, not that scheduling works -- the behavior side is covered by
/// background_scan_scheduler_test.dart and the on-device MV record. Scope is
/// deliberately narrow: only the call sites of factory-routed methods are
/// checked. `Platform.isWindows` elsewhere in the file is legitimate (e.g. the
/// Windows-only deferral status line is a real platform difference, declared).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IMP-2: factory call sites are platform-free (ADR-0042)', () {
    test(
        '_updateScheduledScan call sites in settings_screen carry no '
        'platform guard', () {
      final source =
          File('lib/ui/screens/settings_screen.dart').readAsLinesSync();

      // Strip comment-only lines so explanatory comments that NAME the old
      // guard (the F161 fix comments do) cannot mask or trip the check.
      final code = <String>[];
      for (final line in source) {
        if (line.trimLeft().startsWith('//')) continue;
        code.add(line);
      }

      final callSites = <int>[];
      for (var i = 0; i < code.length; i++) {
        final line = code[i];
        // Call sites only -- skip the method's own declaration.
        if (line.contains('_updateScheduledScan(') &&
            !line.contains('Future<void> _updateScheduledScan')) {
          callSites.add(i);
        }
      }

      expect(callSites, hasLength(2),
          reason: 'settings_screen has exactly two _updateScheduledScan call '
              'sites (enable toggle + frequency change). If one was added or '
              'removed, re-verify each is platform-free and update this '
              'count deliberately.');

      for (final i in callSites) {
        final start = i >= 3 ? i - 3 : 0;
        final window = code.sublist(start, i + 1).join('\n');
        expect(window.contains('Platform.is'), isFalse,
            reason: 'A platform guard within 3 code lines of a '
                '_updateScheduledScan call site re-creates the F161 escape: '
                'the factory owns the platform decision (isSupported / the '
                'UnsupportedPlatformScheduler no-op), so the call site must '
                'be unconditional. Offending window:\n$window');
      }
    });
  });
}
