/// F323 R-1 (Sprint 83): the body read behind the Block Body choice.
///
/// Checks the order (lease, claim, connect, fetch) and, on EVERY exit path,
/// that the session is closed, the claim row is gone and the lease is free.
///
/// What these tests do NOT catch (one line each):
///   - a real IMAP or Gmail fetch (the platform is a fake; the real
///     fetchContentText throws on a failed fetch, and a fake that throws
///     stands in for it);
///   - a background scan in ANOTHER process holding the account (the busy
///     case is simulated by a claim seam that throws);
///   - the default seams (PlatformRegistry, SecureCredentialsStore): tests
///     pass their own.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/email_provider.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/services/popup_body_fetcher.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';

import '../../helpers/database_test_helper.dart';

class _FakePlatform implements SpamFilterPlatform {
  _FakePlatform({
    this.body = 'see https://x.example',
    this.throwOnFetch,
    this.contentText,
    this.throwOnContent,
  });
  final String body;
  final Object? throwOnFetch;

  /// What fetchContentText returns; null = the named no-op (demo, mock) or a
  /// message with no text.
  final String? contentText;
  final Object? throwOnContent;
  final List<String> calls = [];

  @override
  Future<void> loadCredentials(Credentials credentials) async =>
      calls.add('load');

  @override
  Future<String?> fetchContentText(EmailMessage message) async {
    calls.add('content');
    if (throwOnContent != null) throw throwOnContent!;
    return contentText;
  }

  @override
  Future<EmailMessage> fetchFullBody(EmailMessage message) async {
    calls.add('fetch');
    if (throwOnFetch != null) throw throwOnFetch!;
    return EmailMessage(
      id: message.id,
      from: message.from,
      subject: message.subject,
      body: body,
      headers: message.headers,
      receivedDate: message.receivedDate,
      folderName: message.folderName,
    );
  }

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EmailMessage _msg() => EmailMessage(
      id: '42',
      from: 'a@b.example',
      subject: 's',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 11, 1),
      folderName: 'INBOX',
    );

void main() {
  late DatabaseTestHelper testHelper;
  late ScanResultStore store;
  const account = 'aol-acct-a';

  setUpAll(DatabaseTestHelper.initializeFfi);

  setUp(() async {
    PopupBodyFetcher.debugDisabled = false; // flutter_test_config.dart sets it
    ScanCoordinator.resetForTest();
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    await testHelper.createTestAccount(account);
    store = ScanResultStore(testHelper.dbHelper);
  });

  tearDown(() async {
    ScanCoordinator.resetForTest();
    await testHelper.tearDown();
  });

  PopupBodyFetcher fetcher(_FakePlatform? platform,
      {Future<ScanLease> Function(String)? lease,
      Future<InteractiveScanClaim> Function(String)? claim,
      bool credentials = true,
      Future<bool> Function(String)? signInRequired}) {
    return PopupBodyFetcher(
      signInRequiredReader: signInRequired ?? (_) async => false,
      platformFactory: (_) => platform,
      credentialsLoader: (_) async =>
          credentials ? Credentials(email: 'a@b.example', password: 'x') : null,
      leaseAcquirer: lease ??
          (id) => ScanCoordinator.instance
              .acquire(scanType: 'reprocess', accountId: id),
      claimer: claim ?? (id) => store.claimInteractive(id),
    );
  }

  Future<void> expectNothingHeld() async {
    expect(ScanCoordinator.instance.active, isNull, reason: 'lease released');
    final db = await testHelper.dbHelper.database;
    final rows = await db.query('scan_results',
        where: "status = 'in_progress'");
    expect(rows, isEmpty, reason: 'claim row removed');
  }

  test('the test switch makes fetch throw before any lease or claim', () async {
    PopupBodyFetcher.debugDisabled = true;
    final p = _FakePlatform();
    await expectLater(
        fetcher(p)
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<PopupBodyUnavailable>()));
    expect(p.calls, isEmpty);
    expect(ScanCoordinator.instance.active, isNull);
  });

  test('success: connect, fetch, return the body, then release everything',
      () async {
    final p = _FakePlatform();
    final body = await fetcher(p)
        .fetch(platformId: 'aol', accountId: account, message: _msg());
    expect(body, 'see https://x.example');
    expect(p.calls, ['load', 'content', 'fetch', 'disconnect']);
    await expectNothingHeld();
  });

  // 5.1.9 rehearsal: the rule-path body is text/plain only, so an HTML-only
  // message read as empty. What this does NOT catch: the real adapters' HTML
  // conversion (generic_imap_adapter / gmail_api_adapter fetchContentText).
  test('content text (an HTML-only message as text) is used first', () async {
    final p = _FakePlatform(body: '', contentText: 'html as text https://y.example');
    final body = await fetcher(p)
        .fetch(platformId: 'aol', accountId: account, message: _msg());
    expect(body, 'html as text https://y.example');
    expect(p.calls, ['load', 'content', 'disconnect']);
    await expectNothingHeld();
  });

  test('a failed content fetch is rethrown, not read as "no text"', () async {
    final p = _FakePlatform(throwOnContent: StateError('fetch failed'));
    await expectLater(
        fetcher(p)
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<StateError>()));
    expect(p.calls, ['load', 'content', 'disconnect']);
    await expectNothingHeld();
  });

  test('no text anywhere throws and releases', () async {
    final p = _FakePlatform(body: '  ', contentText: ' ');
    await expectLater(
        fetcher(p)
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<PopupBodyUnavailable>()));
    expect(p.calls, ['load', 'content', 'fetch', 'disconnect']);
    await expectNothingHeld();
  });

  test('a fetch that throws is rethrown and everything is released', () async {
    final p = _FakePlatform(throwOnFetch: StateError('boom'));
    await expectLater(
        fetcher(p)
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<StateError>()));
    expect(p.calls.last, 'disconnect');
    await expectNothingHeld();
  });

  test('a busy account (claim refused) connects nothing and frees the lease',
      () async {
    final p = _FakePlatform();
    await expectLater(
        fetcher(p, claim: (_) async {
          throw ScanAccountBusyException.unverifiable('busy');
        }).fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<ScanAccountBusyException>()));
    expect(p.calls, isEmpty);
    expect(ScanCoordinator.instance.active, isNull);
  });

  test('a running scan in this process: the wait times out, nothing connects',
      () async {
    final held = await ScanCoordinator.instance
        .acquire(scanType: 'manual', accountId: account);
    final p = _FakePlatform();
    var claimed = false;
    await expectLater(
        fetcher(p,
            lease: (id) => ScanCoordinator.instance.acquire(
                scanType: 'reprocess',
                accountId: id,
                waitLimit: const Duration(milliseconds: 50)),
            claim: (id) {
              claimed = true;
              return store.claimInteractive(id);
            }).fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<TimeoutException>()));
    expect(claimed, isFalse);
    expect(p.calls, isEmpty);
    // The holder is unchanged and no queue entry is left behind.
    expect(ScanCoordinator.instance.active, isNotNull);
    ScanCoordinator.instance.release(held);
    expect(ScanCoordinator.instance.active, isNull);
  });

  test('no saved credentials throws and releases', () async {
    final p = _FakePlatform();
    await expectLater(
        fetcher(p, credentials: false)
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<PopupBodyUnavailable>()));
    expect(p.calls, ['disconnect']);
    await expectNothingHeld();
  });

  // Sprint 83 7.7.1 (Harold Q2 = 1). Would NOT catch: the background skip
  // (f324_imap_sign_in_skip_test) or a flag that was never set.
  test('a flagged IMAP account: no lease, no claim, no login', () async {
    final p = _FakePlatform();
    var leased = false;
    await expectLater(
        fetcher(p,
                signInRequired: (_) async => true,
                lease: (id) async {
                  leased = true;
                  return ScanCoordinator.instance
                      .acquire(scanType: 'reprocess', accountId: id);
                })
            .fetch(platformId: 'aol', accountId: account, message: _msg()),
        throwsA(isA<PopupBodyUnavailable>()
            .having((e) => e.why, 'why', 'sign-in required')));
    expect(p.calls, isEmpty, reason: 'no login sent to the provider');
    expect(leased, isFalse);
    await expectNothingHeld();
  });

  test('an unreadable flag lets the read go ahead', () async {
    final p = _FakePlatform();
    final body = await fetcher(p,
            signInRequired: (_) async => throw StateError('damaged'))
        .fetch(platformId: 'aol', accountId: account, message: _msg());
    expect(body, 'see https://x.example');
  });

  test('the flag is not read for a non-IMAP platform (Gmail)', () async {
    final p = _FakePlatform();
    final body = await fetcher(p, signInRequired: (_) async => true)
        .fetch(platformId: 'gmail', accountId: account, message: _msg());
    expect(body, 'see https://x.example');
  });

  test('an unknown platform throws and releases', () async {
    await expectLater(
        fetcher(null)
            .fetch(platformId: 'nope', accountId: account, message: _msg()),
        throwsA(isA<PopupBodyUnavailable>()));
    await expectNothingHeld();
  });
}
