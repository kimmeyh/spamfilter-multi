// Sprint 80 (Harold Q4 = 2): the Windows startup reconciliation moved after
// runApp, so it shares WindowsTaskSchedulerService.runExclusive with Settings'
// schedule and cancel. These tests pin the lock's three promises (order,
// reentrancy, release after an error) and that the adapter takes it.
//
// What these tests do NOT catch: whether main.dart actually wraps the
// reconciliation in the lock and starts it after runApp (that is checked by
// reading main.dart and by the measured window time on a release build), and
// a second PROCESS changing tasks (the lock is in-process by design; the
// background-scan process never changes tasks).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/services/windows_task_scheduler_service.dart';

void main() {
  group('WindowsTaskSchedulerService.runExclusive', () {
    test('a later section waits until the earlier one finishes', () async {
      final release = Completer<void>();
      final events = <String>[];

      final first = WindowsTaskSchedulerService.runExclusive(() async {
        events.add('first start');
        await release.future;
        events.add('first end');
      });
      final second = WindowsTaskSchedulerService.runExclusive(() async {
        events.add('second');
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, ['first start'],
          reason: 'second must not run while first holds the lock');

      release.complete();
      await Future.wait([first, second]);
      expect(events, ['first start', 'first end', 'second']);
    });

    test('a nested section runs at once instead of deadlocking', () async {
      final result = await WindowsTaskSchedulerService.runExclusive(() async {
        return WindowsTaskSchedulerService.runExclusive(() async => 42);
      }).timeout(const Duration(seconds: 2));
      expect(result, 42);
    });

    test('an error reaches its caller and does not block later sections',
        () async {
      final failing = WindowsTaskSchedulerService.runExclusive<void>(
          () async => throw StateError('boom'));
      await expectLater(failing, throwsA(isA<StateError>()));

      final after = await WindowsTaskSchedulerService.runExclusive(
          () async => 'ran').timeout(const Duration(seconds: 2));
      expect(after, 'ran');
    });
  });

  // PR #490 7.7.1 (code-reviewer finding 6). SOURCE-TEXT check: the Settings
  // screen needs a database and an account to pump. What this does NOT catch:
  // a third Background-tab control added later that writes outside the helper.
  test('Settings writes each Background-tab value under the lock', () {
    final src =
        File('lib/ui/screens/settings_screen.dart').readAsStringSync();
    expect(src,
        contains('WindowsTaskSchedulerService.runExclusive(change)'));
    for (final write in [
      'setAccountBackgroundEnabled(_requireAccountId, value)',
      'setAccountBackgroundFrequency(\n                      _requireAccountId, minutes)',
    ]) {
      final at = src.replaceAll('\r\n', '\n').indexOf(write);
      expect(at, greaterThan(0), reason: write);
      final helper = src
          .replaceAll('\r\n', '\n')
          .lastIndexOf('await _changeBackgroundSettingExclusive(() async {', at);
      expect(helper, greaterThan(0),
          reason: '$write must sit inside _changeBackgroundSettingExclusive');
      expect(at - helper, lessThan(400),
          reason: '$write must be the helper\'s own body, not a later one');
    }
  });

  group('WindowsSchedulerAdapter takes the lock', () {
    test('schedule waits while a reconciliation holds the lock', () async {
      final release = Completer<void>();
      final held = WindowsTaskSchedulerService.runExclusive(
          () => release.future);

      var finished = false;
      // intervalMinutes 0 returns false before any PowerShell call, so the
      // only thing that can delay it is the lock.
      final scheduled = const WindowsSchedulerAdapter()
          .schedule(accountId: 'lock-probe', intervalMinutes: 0,
              caller: 'test')
          .then((ok) {
        finished = true;
        return ok;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(finished, isFalse,
          reason: 'a Settings schedule must wait for the reconciliation');

      release.complete();
      await held;
      expect(await scheduled, isFalse);
      expect(finished, isTrue);
    });
  });
}
