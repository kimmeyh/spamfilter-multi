// Sprint 83 7.7.1 (code-reviewer M-1, silent-failure-hunter M-2): the one
// path that turns background scanning on.
//
// What these tests do NOT catch: the real Android permission dialog (the
// request is replaced by a seam), the real Windows Task Scheduler call, and
// the Windows lock's ordering against the start-up reconciliation (that lock
// is tested in the windows_task_scheduler_service tests).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/background_scan_enabler.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';

class _FakeScheduler implements BackgroundScanScheduler {
  _FakeScheduler({this.supported = true, this.result = true});
  final bool supported;
  final bool result;
  final calls = <String>[];

  @override
  bool get isSupported => supported;

  @override
  String get mechanismLabel => 'fake';

  @override
  Future<bool> isScheduled(String accountId) async => false;

  @override
  Future<bool> schedule({
    required String accountId,
    required int intervalMinutes,
    required String caller,
  }) async {
    calls.add('$accountId/$intervalMinutes/$caller');
    return result;
  }

  @override
  Future<bool> cancel(String accountId, {required String caller}) async =>
      true;
}

void main() {
  var permissionRequests = 0;
  setUp(() {
    permissionRequests = 0;
    BackgroundScanEnabler.permissionRequestOverride =
        () async => permissionRequests++;
  });
  tearDown(() => BackgroundScanEnabler.permissionRequestOverride = null);

  Future<BackgroundEnableResult> run(_FakeScheduler s, {int minutes = 15}) =>
      BackgroundScanEnabler.schedule(
          accountId: 'aol-a@x.com',
          minutes: minutes,
          caller: 'test',
          scheduler: s);

  test('scheduled: permission asked, then scheduled; no message', () async {
    final s = _FakeScheduler();
    expect(await run(s), BackgroundEnableResult.scheduled);
    expect(permissionRequests, 1);
    expect(s.calls, ['aol-a@x.com/15/test']);
    expect(BackgroundScanEnabler.messageFor(BackgroundEnableResult.scheduled),
        isNull);
  });

  test('unsupported platform: nothing scheduled, the user is told', () async {
    final s = _FakeScheduler(supported: false);
    final r = await run(s);
    expect(r, BackgroundEnableResult.unsupported);
    expect(s.calls, isEmpty);
    expect(permissionRequests, 0);
    expect(BackgroundScanEnabler.messageFor(r), contains('cannot run'));
  });

  test('invalid interval: nothing scheduled, the user is told', () async {
    final s = _FakeScheduler();
    final r = await run(s, minutes: 0);
    expect(r, BackgroundEnableResult.invalidInterval);
    expect(s.calls, isEmpty);
    expect(BackgroundScanEnabler.messageFor(r), contains('not valid'));
  });

  test('scheduler returns false: the user is told', () async {
    final r = await run(_FakeScheduler(result: false));
    expect(r, BackgroundEnableResult.scheduleFailed);
    expect(BackgroundScanEnabler.messageFor(r), contains('could not be'));
  });

  // Prevention: both controls that turn background scanning on go through
  // the enabler, so a step added to it reaches both.
  test('source gate: both controls call the shared enabler', () {
    final list =
        File('lib/ui/screens/account_selection_screen.dart').readAsStringSync();
    final settings = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
    expect(list, contains('BackgroundScanEnabler.turnOn('));
    expect(list, isNot(contains('.schedule(')),
        reason: 'the account list must not schedule directly');
    expect(settings, contains('BackgroundScanEnabler.schedule('));
    expect(
        RegExp(r'scheduler\.schedule\(').hasMatch(settings), isFalse,
        reason: 'Settings must not schedule directly');
  });
}
