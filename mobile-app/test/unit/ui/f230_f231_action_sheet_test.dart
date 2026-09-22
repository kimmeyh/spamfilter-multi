/// F230 + F231 (Sprint 72): the No-rule action sheet must be readable, and what
/// it did must survive being missed.
///
/// Planned and tested as ONE unit because both change the same geometry --
/// moving Skip and surfacing the outcome touch the same widget tree, and doing
/// them separately means solving that layout twice.
///
/// **F230, from Harold on the 0.15.2 Play build**: the subtitle and date rows
/// were too small on Android, and *"Skip button often overlays the domain on
/// this same page"*. The second is a WIDTH problem, not a font problem: the
/// sender is `Expanded` with ellipsis and shared its Row with Skip, so every
/// pixel Skip took came out of the address. At 411px it rendered
/// `kimmeyharold@help.ramirezo...`; the IDENTICAL code on Windows at ~993px
/// showed it in full.
///
/// **F231**: Harold TIMED the toasts at about one second each, not the nominal
/// three -- the duration includes animation and each action REPLACES the
/// current SnackBar rather than queueing. And acting from the top of the list
/// auto-advances into the next item's dialog, which covers the toast
/// completely: *"you don't see any of them."*
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they pin the SOURCE
/// structure -- that Skip left the sender row, that the domain is bounded, that
/// theme styles replaced hardcoded sizes, that outcomes are recorded. They
/// cannot prove the result is COMFORTABLE to read on real hardware, and they do
/// not render the sheet at a given width. Harold's judgement at manual
/// validation on both a phone and Windows is the real acceptance.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source =
        File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
  });

  group('F230: Skip no longer eats the sender', () {
    test('THE BUG: Skip is out of the sender Row', () {
      // The sender Text is Expanded + ellipsis. Anything sharing that Row takes
      // width directly from the address.
      final senderRowStart = source.indexOf('displaySenderEmail,');
      expect(senderRowStart, greaterThan(-1));
      // Look at the window right after the sender widget, where Skip used to
      // sit; it must not be there any more.
      final window = source.substring(
          senderRowStart, senderRowStart + 1400);
      expect(window.contains('_buildSkipButton('), isFalse,
          reason: 'THE ASSERTION THAT WAS MISSING: Skip immediately after the '
              'Expanded sender is what truncated the address at 411px');
    });

    test('Skip is still present, just relocated', () {
      expect(source.contains('_buildSkipButton('), isTrue,
          reason: 'moved, not removed');
      expect(
          RegExp(r'_buildSkipButton\(').allMatches(source).length,
          greaterThanOrEqualTo(1));
    });

    test('Skip keeps its filter gate and its existing behavior', () {
      expect(source.contains('if (_filter == EmailActionType.none) ...['),
          isTrue,
          reason: 'still only under the No-rule filter, where an unaddressed '
              'sequence exists to advance through');
      expect(source.contains('_quickActionThenAdvance'), isTrue,
          reason: 'the widget MOVED; it must not be reimplemented, or "next '
              'unaddressed item" drifts from every other button (F136)');
    });

    test('the domain is BOUNDED so the overflow did not just relocate', () {
      // The date/domain row had no Expanded. Dropping a button into it
      // unbounded would move the overflow rather than fix it -- the same shape
      // as the ~81px AppBar overflow F172 hit at 411px.
      final domainIdx = source.indexOf('displaySenderDomain,');
      expect(domainIdx, greaterThan(-1));
      final before = source.substring(domainIdx - 400, domainIdx);
      expect(before.contains('Flexible('), isTrue,
          reason: 'a long domain must yield rather than break the row');
    });
  });

  group('F230: sizes come from the theme, not from literals', () {
    test('the subtitle no longer hardcodes fontSize 12', () {
      expect(
          source.contains('style: TextStyle(\n'
              '                                    fontSize: 12, color: Colors.grey[600]),'),
          isFalse);
      expect(source.contains('.textTheme\n'
              '                                    .bodyMedium'), isTrue,
          reason: 'theme styles honour the OS font-size accessibility setting, '
              'which a hardcoded number cannot (ADR-0037)');
    });

    test('the date and domain no longer hardcode fontSize 11', () {
      expect(
          source.contains('fontSize: 11,\n'
              '                                        color: Colors.grey.shade600'),
          isFalse,
          reason: 'this was the smallest text on the sheet');
      expect(source.contains('.bodySmall'), isTrue);
    });

    test('the change is UNCONDITIONAL -- no platform branch', () {
      // Harold chose to accept the larger text on Windows rather than branch:
      // "It would be OK if it was bigger on Windows in order to match Android
      // and not cause an unnecessary exception." One shared change, no
      // ADR-0042 exception to maintain.
      final subtitleIdx = source.indexOf('bodyMedium');
      final window = source.substring(subtitleIdx - 600, subtitleIdx);
      expect(window.contains('Platform.isAndroid'), isFalse,
          reason: 'a platform branch here would be exactly the unnecessary '
              'exception Harold declined');
    });
  });

  group('F231: outcomes survive being missed', () {
    test('THE FIX: every outcome is recorded, not just shown', () {
      expect(source.contains('_sessionActivity'), isTrue);
      expect(source.contains('_sessionActivity.add('), isTrue,
          reason: 'the toast was the ONLY place the per-action outcome existed '
              '-- not in a log, not in the CSV, and the footer carries only '
              'aggregate counts');
    });

    test('the record is made inside setState', () {
      // The history control renders conditionally on this list being non-empty.
      // Without a rebuild the first action records silently and the control
      // never appears -- a durable record that cannot be reached is the same
      // shape as the defect it fixes.
      final idx = source.indexOf('_sessionActivity.add(');
      final before = source.substring(idx - 300, idx);
      expect(before.contains('setState('), isTrue);
    });

    test('there is a way to VIEW the record', () {
      expect(source.contains('_showSessionActivity'), isTrue);
      expect(source.contains("tooltip: 'What happened in this session'"), isTrue,
          reason: 'Harold had to open Scan History to reconstruct what had '
              'happened; the answer belongs on this screen');
    });

    test('the control is hidden until it has something to show', () {
      expect(source.contains('if (_sessionActivity.isNotEmpty)'), isTrue,
          reason: 'this action row is the one F172 measured at ~81px of '
              'overflow at 411px -- it must not gain a permanent dead control');
    });

    test('recording happens BEFORE the toast is shown', () {
      final recordIdx = source.indexOf('_sessionActivity.add(');
      final toastIdx = source.indexOf(
          'ScaffoldMessenger.of(context).showSnackBar(', recordIdx);
      expect(recordIdx, lessThan(toastIdx),
          reason: 'the record must not depend on the toast succeeding');
    });
  });
}
