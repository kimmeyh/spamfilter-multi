// Sprint 79 Task 1 R-8: an IMAP command that never gets a reply must END,
// not hang the scan.
//
// Sprint 79 7.7.1 C-1 / H-1: enough_mail 2.1.7 applies the client's
// `defaultResponseTimeout` to LOGIN, SELECT, LIST, STORE, NOOP and EXPUNGE,
// but NOT to UID SEARCH or UID FETCH (each takes its own `responseTimeout`)
// and to nothing for UID MOVE. The adapter therefore passes the limit per
// call through `_uidSearch` / `_uidFetch`, and a timeout in them now reaches
// the scanner instead of reading as an empty folder.
//
// What this does NOT catch: a hang OUTSIDE an IMAP command (a Dart await on
// something else), a process the OS freezes or kills (the Fold rows whose
// heartbeat never ran), a server that trickles bytes slowly enough to keep
// one command alive past the limit in pieces. UID MOVE has no limit in the
// library; the adapter adds one (7.7.1 Q1), tested on a fake clock below.
// It proves the library behavior the fix relies on, with a real socket, that
// both client constructors pass the default, and that the adapter passes the
// limit to every SEARCH and FETCH and lets a timeout through.
import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';

/// Records the per-call `responseTimeout` the adapter passes; can be told to
/// fail SELECT, SEARCH, FETCH or STORE the way a stalled server does.
class _RecordingImapClient extends ImapClient {
  _RecordingImapClient(
      {this.searchError,
      this.selectError,
      this.fetchError,
      this.storeError,
      this.listError,
      this.moveError})
      : super(isLogEnabled: false);

  final Object? listError;
  final Object? moveError;

  /// When true, UID MOVE never answers (enough_mail sends it with no limit).
  bool hangOnMove = false;
  int moves = 0;

  @override
  Future<GenericImapResult> uidMove(
    MessageSequence sequence, {
    Mailbox? targetMailbox,
    String? targetMailboxPath,
  }) async {
    moves++;
    if (moveError != null) throw moveError!;
    if (hangOnMove) return Completer<GenericImapResult>().future;
    return GenericImapResult();
  }
  final Object? searchError;
  final Object? selectError;
  final Object? fetchError;
  final Object? storeError;
  final List<Duration?> searchTimeouts = [];
  final List<Duration?> fetchTimeouts = [];
  int disconnects = 0;

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async {
    if (selectError != null) throw selectError!;
    return Mailbox(
        encodedName: path, encodedPath: path, pathSeparator: '/', flags: []);
  }

  @override
  Future<StoreImapResult> uidStore(
    MessageSequence sequence,
    List<String> flags, {
    StoreAction? action,
    bool? silent,
    int? unchangedSinceModSequence,
  }) async {
    if (storeError != null) throw storeError!;
    return StoreImapResult();
  }

  @override
  Future<List<Mailbox>> listMailboxes({
    String path = '""',
    bool recursive = false,
    List<String>? mailboxPatterns,
    List<String>? selectionOptions,
    List<ReturnOption>? returnOptions,
  }) async {
    if (listError != null) throw listError!;
    return [];
  }

  /// When true, closing the socket never finishes (a peer that stopped
  /// answering).
  bool hangOnDisconnect = false;

  @override
  Future<void> disconnect() {
    disconnects++;
    return hangOnDisconnect ? Completer<void>().future : Future.value();
  }

  @override
  Future<SearchImapResult> uidSearchMessages({
    String searchCriteria = 'UNSEEN',
    List<ReturnOption>? returnOptions,
    Duration? responseTimeout,
  }) async {
    searchTimeouts.add(responseTimeout);
    if (searchError != null) throw searchError!;
    return SearchImapResult()
      ..matchingSequence = MessageSequence.fromIds([1, 2], isUid: true);
  }

  @override
  Future<FetchImapResult> uidFetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    fetchTimeouts.add(responseTimeout);
    if (fetchError != null) throw fetchError!;
    return FetchImapResult([
      for (final uid in sequence.toList())
        MimeMessage()
          ..uid = uid
          ..addHeader('From', 'sender$uid@example.com')
          ..addHeader('Subject', 'Message $uid'),
    ], null);
  }
}

GenericIMAPAdapter _adapterWith(ImapClient client) =>
    GenericIMAPAdapter(imapHost: 'imap.example.com', platformId: 'aol')
      ..debugSetImapClient(client);

/// A server that answers the greeting, LOGIN and SELECT, then reads every
/// later command and never answers -- the stalled socket mid-scan.
Future<ServerSocket> _serverSilentAfterSelect(List<Socket> sockets) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((s) {
    sockets.add(s);
    s.write('* OK [CAPABILITY IMAP4rev1] ready\r\n');
    var buffer = '';
    s.listen((data) {
      buffer += String.fromCharCodes(data);
      while (buffer.contains('\r\n')) {
        final i = buffer.indexOf('\r\n');
        final line = buffer.substring(0, i);
        buffer = buffer.substring(i + 2);
        final parts = line.split(' ');
        if (parts.length < 2) continue;
        final tag = parts[0];
        final cmd = parts[1].toUpperCase();
        if (cmd == 'UID') {
          // UID SEARCH / UID FETCH: never answered -- the stall.
        } else if (cmd == 'SELECT' || cmd == 'EXAMINE') {
          s.write('* FLAGS (\\Seen)\r\n* 2 EXISTS\r\n* 0 RECENT\r\n'
              '* OK [UIDVALIDITY 1] ok\r\n'
              '$tag OK [READ-WRITE] SELECT completed\r\n');
        } else if (cmd == 'CAPABILITY') {
          s.write('* CAPABILITY IMAP4rev1\r\n$tag OK done\r\n');
        } else {
          // LOGIN and anything else the client sends on its own.
          s.write('$tag OK done\r\n');
        }
      }
    });
  });
  return server;
}

void main() {
  test('the limits are the documented values', () {
    expect(kImapResponseTimeout, const Duration(seconds: 120));
    expect(kImapWriteTimeout, const Duration(seconds: 60));
  });

  test('GreetingAwareImapClient carries the response and write limits', () {
    final client = GreetingAwareImapClient();
    expect(client.defaultResponseTimeout, kImapResponseTimeout);
    expect(client.defaultWriteTimeout, kImapWriteTimeout);
  });

  test('source gate: the adapter builds its plain client with the limits', () {
    final src = File('lib/adapters/email_providers/generic_imap_adapter.dart')
        .readAsStringSync();
    final ctor = RegExp(
        r'ImapClient\(\s*isLogEnabled: false,\s*defaultResponseTimeout: kImapResponseTimeout,\s*defaultWriteTimeout: kImapWriteTimeout,\s*\)');
    expect(ctor.hasMatch(src), isTrue);
    // No client built anywhere in lib/ without a response limit.
    final bare = RegExp(r'ImapClient\(isLogEnabled: false\)');
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(bare.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('a silent server: the command fails with "timeout" instead of hanging',
      () async {
    // Greets, then reads every command and never answers -- the stalled
    // socket of the Fold rows.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    server.listen((s) {
      sockets.add(s);
      s.write('* OK [CAPABILITY IMAP4rev1] ready\r\n');
      s.listen((_) {});
    });
    final client = ImapClient(
      isLogEnabled: false,
      defaultResponseTimeout: const Duration(milliseconds: 400),
    );
    try {
      await client.connectToServer('127.0.0.1', server.port, isSecure: false);
      Object? error;
      final sw = Stopwatch()..start();
      try {
        await client
            .login('user', 'pass')
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        error = e;
      }
      expect(error, isA<ImapException>(),
          reason: 'got $error -- a TimeoutException here would mean the '
              'library never timed the command out (the hang)');
      expect((error as ImapException).message, 'timeout');
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      // And the adapter reads it as "server unavailable", never a password
      // refusal, so it cannot move the account toward lockout.
      expect(GenericIMAPAdapter.classifyLoginRefusal(error.message),
          LoginRefusal.serverUnavailable);
    } finally {
      for (final s in sockets) {
        s.destroy();
      }
      await server.close();
    }
  });

  group('7.7.1 C-1: UID SEARCH needs the limit passed per call', () {
    test(
        'library: the client default does NOT limit UID SEARCH; a per-call '
        'responseTimeout does', () async {
      final sockets = <Socket>[];
      final server = await _serverSilentAfterSelect(sockets);
      final client = ImapClient(
        isLogEnabled: false,
        // 1 s, not less: LOGIN and SELECT must fit inside it on a cold JIT
        // run (300 ms timed LOGIN out).
        defaultResponseTimeout: const Duration(seconds: 1),
      );
      try {
        await client.connectToServer('127.0.0.1', server.port,
            isSecure: false);
        await client.login('user', 'pass');
        await client.selectMailboxByPath('INBOX');

        // Default only: still waiting after 5 s (five times the default).
        // If a library upgrade starts applying the default, this goes red and
        // the per-call wrappers can be revisited.
        Object? defaultOnly;
        try {
          await client
              .uidSearchMessages(searchCriteria: 'ALL')
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          defaultOnly = e;
        }
        expect(defaultOnly, isNot(isA<ImapException>()),
            reason: 'the client default timed out UID SEARCH: got '
                '$defaultOnly');
      } finally {
        for (final s in sockets) {
          s.destroy();
        }
        await server.close();
      }

      // Per call, on a fresh connection (the first one has a command queued).
      final sockets2 = <Socket>[];
      final server2 = await _serverSilentAfterSelect(sockets2);
      final client2 = ImapClient(isLogEnabled: false);
      try {
        await client2.connectToServer('127.0.0.1', server2.port,
            isSecure: false);
        await client2.login('user', 'pass');
        await client2.selectMailboxByPath('INBOX');
        Object? perCall;
        try {
          await client2
              .uidSearchMessages(
                  searchCriteria: 'ALL',
                  responseTimeout: const Duration(milliseconds: 300))
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          perCall = e;
        }
        expect(perCall, isA<ImapException>(), reason: 'got $perCall');
        expect((perCall as ImapException).message, 'timeout');
      } finally {
        for (final s in sockets2) {
          s.destroy();
        }
        await server2.close();
      }
    });

    test('adapter: every SEARCH and FETCH passes kImapResponseTimeout',
        () async {
      final client = _RecordingImapClient();
      final messages = await _adapterWith(client)
          .fetchMessages(daysBack: 0, folderNames: ['Inbox']);
      expect(messages, hasLength(2));
      expect(client.searchTimeouts, [kImapResponseTimeout]);
      expect(client.fetchTimeouts, [kImapResponseTimeout]);
    });

    test('source gate: no SEARCH or FETCH call bypasses the wrappers', () {
      final adapter =
          File('lib/adapters/email_providers/generic_imap_adapter.dart')
              .readAsStringSync();
      // Exactly one direct call of each: inside `_uidSearch` / `_uidFetch`.
      expect('.uidSearchMessages('.allMatchesIn(adapter), 1);
      expect('.uidFetchMessages('.allMatchesIn(adapter), 1);
      expect(adapter, contains('responseTimeout: kImapResponseTimeout'));
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('generic_imap_adapter.dart'))) {
        final src = f.readAsStringSync();
        expect(src.contains('.uidSearchMessages(') ||
            src.contains('.uidFetchMessages('), isFalse, reason: f.path);
      }
    });
  });

  test(
      '7.7.1 H-1: a SEARCH timeout on the full-fetch path reaches the caller '
      '(it used to read as an empty folder with errors=0)', () async {
    final client = _RecordingImapClient(
        searchError: ImapException(ImapClient(isLogEnabled: false), 'timeout'));
    Object? error;
    try {
      await _adapterWith(client)
          .fetchMessages(daysBack: 0, folderNames: ['Inbox']);
    } catch (e) {
      error = e;
    }
    expect(error, isA<ImapServerNotRespondingException>(),
        reason: 'the adapter swallowed the timeout and returned a list');
  });

  // Sprint 79 7.7.1 Q2 (Harold, "q2 1"): ONE timeout ends the session, so no
  // later command waits its own full limit on the same dead connection.
  //
  // What this does NOT catch: a real 2-minute stall (the library test above
  // proves the exception type with a real socket; these use a scripted
  // client), and the scanner's own handling (it rethrows every `isSessionFatal` error and
  // fails the scan at its outer catch -- pinned by its own tests).
  group('7.7.1 Q2: a timeout ends the session', () {
    ImapException timeout() =>
        ImapException(ImapClient(isLogEnabled: false), 'timeout');

    test('SEARCH timeout: session-fatal, client dropped, no later command sent',
        () async {
      final client = _RecordingImapClient(searchError: timeout());
      final adapter = _adapterWith(client);
      Object? first;
      try {
        await adapter.fetchMessages(daysBack: 0, folderNames: ['Inbox']);
      } catch (e) {
        first = e;
      }
      expect(first, isA<ImapServerNotRespondingException>());
      expect(isSessionFatal(first!), isTrue,
          reason: 'every per-item catch rethrows only session-fatal errors');
      expect(adapter.debugHasClient, isFalse);
      expect(client.disconnects, 1, reason: 'the socket is closed');

      // The next folder fails at once: nothing is sent to the dead client.
      await expectLater(
          adapter.fetchMessages(daysBack: 0, folderNames: ['Spam']),
          throwsA(isA<ConnectionException>()));
      expect(client.searchTimeouts, hasLength(1),
          reason: 'a second SEARCH would wait another full limit');
    });

    test('a socket close that never finishes does not hang the scan',
        () async {
      final client = _RecordingImapClient(searchError: timeout())
        ..hangOnDisconnect = true;
      final sw = Stopwatch()..start();
      await expectLater(
          _adapterWith(client)
              .fetchMessages(daysBack: 0, folderNames: ['Inbox'])
              .timeout(const Duration(seconds: 30)),
          throwsA(isA<ImapServerNotRespondingException>()));
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)),
          reason: 'the close is bounded at 10 s');
    });

    test('SELECT timeout keeps its type (not wrapped as FetchException)',
        () async {
      final client = _RecordingImapClient(selectError: timeout());
      final adapter = _adapterWith(client);
      await expectLater(
          adapter.fetchMessages(daysBack: 0, folderNames: ['Inbox']),
          throwsA(isA<ImapServerNotRespondingException>()));
      expect(adapter.debugHasClient, isFalse);
    });

    test('FETCH timeout keeps its type through the batch fetch', () async {
      final client = _RecordingImapClient(fetchError: timeout());
      await expectLater(
          _adapterWith(client)
              .fetchMessages(daysBack: 0, folderNames: ['Inbox']),
          throwsA(isA<ImapServerNotRespondingException>()));
    });

    test('a body fetch timeout ends the scan, not a header-only fallback',
        () async {
      final client = _RecordingImapClient(fetchError: timeout());
      final message = EmailMessage(
        id: '7',
        from: 'a@example.com',
        subject: 's',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 10, 18),
        folderName: 'Inbox',
      );
      await expectLater(_adapterWith(client).fetchFullBody(message),
          throwsA(isA<ImapServerNotRespondingException>()));
    });

    test('cursor lookups rethrow it instead of answering null', () async {
      await expectLater(
          _adapterWith(_RecordingImapClient(searchError: timeout()))
              .getCurrentMaxUid('Inbox'),
          throwsA(isA<ImapServerNotRespondingException>()));
      await expectLater(
          _adapterWith(_RecordingImapClient(searchError: timeout()))
              .firstUidSince('Inbox', DateTime(2026, 10, 1)),
          throwsA(isA<ImapServerNotRespondingException>()));
    });

    test('a STORE timeout is not reported as flagged', () async {
      final client = _RecordingImapClient(storeError: timeout());
      final message = EmailMessage(
        id: '7',
        from: 'a@example.com',
        subject: 's',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 10, 18),
        folderName: 'Inbox',
      );
      await expectLater(
          _adapterWith(client).applyFlagBatch([message], 'Rule'),
          throwsA(isA<ImapServerNotRespondingException>()),
          reason: 'this catch used to mark the batch succeeded');
    });

    test('the other action paths rethrow it too (no per-message fallback)',
        () async {
      final message = EmailMessage(
        id: '7',
        from: 'a@example.com',
        subject: 's',
        body: '',
        headers: const {},
        receivedDate: DateTime(2026, 10, 18),
        folderName: 'Inbox',
      );
      final notResponding = throwsA(isA<ImapServerNotRespondingException>());
      await expectLater(
          _adapterWith(_RecordingImapClient(storeError: timeout()))
              .applyFlag(message: message, flagName: 'Rule'),
          notResponding,
          reason: 'applyFlag swallowed every error');
      await expectLater(
          _adapterWith(_RecordingImapClient(storeError: timeout()))
              .markAsReadBatch([message]),
          notResponding,
          reason: 'the per-message fallback would send more commands');
      await expectLater(
          _adapterWith(_RecordingImapClient(storeError: timeout()))
              .takeActionBatch([message], FilterAction.markAsSpam),
          notResponding);
      await expectLater(
          _adapterWith(_RecordingImapClient(listError: timeout()))
              .listFolders(),
          notResponding);
    });

    test('a write timeout counts as no response; other errors do not', () {
      expect(GenericIMAPAdapter.isNoResponse(timeout()), isTrue);
      expect(GenericIMAPAdapter.isNoResponse(TimeoutException('flush')),
          isTrue);
      expect(
          GenericIMAPAdapter.isNoResponse(
              ImapException(ImapClient(isLogEnabled: false), 'NO denied')),
          isFalse);
      expect(GenericIMAPAdapter.isNoResponse(const SocketException('x')),
          isFalse);
    });

    test('the user sentence names what happened and what happens next', () {
      final e = ImapServerNotRespondingException('UID SEARCH');
      expect(e.userMessage, ImapServerNotRespondingException.userText);
      expect(e.userMessage, contains('stopped responding'));
      expect(e.message, contains('UID SEARCH'));
    });

    test('source gate: every timed command goes through the session check',
        () {
      final adapter =
          File('lib/adapters/email_providers/generic_imap_adapter.dart')
              .readAsStringSync();
      for (final direct in [
        '_imapClient!.uidStore(',
        '_imapClient!.selectMailboxByPath(',
        '_imapClient!.listMailboxes(',
        '_imapClient!.uidSearchMessages(',
        '_imapClient!.uidFetchMessages(',
        '_imapClient!.uidMove(',
      ]) {
        expect(adapter.contains(direct), isFalse, reason: direct);
      }
      expect('client.uidStore('.allMatchesIn(adapter), 1);
      expect('.uidMove('.allMatchesIn(adapter), 1,
          reason: 'only _uidMove may send UID MOVE');
    });
  });

  // Sprint 79 7.7.1 Q1 (Harold, "q1 1"): UID MOVE gets the 2-minute limit and
  // the same session end. enough_mail sends MOVE with no limit, so the
  // adapter adds a Dart `.timeout`.
  //
  // What this does NOT catch: a server that finishes the MOVE after the app
  // stopped waiting (the message is moved but counted failed; the next scan
  // sees it in its new folder), and a MOVE sent by a path that does not use
  // GenericIMAPAdapter (Gmail uses its own API).
  group('7.7.1 Q1: a UID MOVE that never answers ends the session', () {
    EmailMessage message() => EmailMessage(
          id: '7',
          from: 'a@example.com',
          subject: 's',
          body: '',
          headers: const {},
          receivedDate: DateTime(2026, 10, 18),
          folderName: 'Inbox',
        );

    // testWidgets runs on a fake clock, so the 120 s limit elapses in pump().
    testWidgets('a hung MOVE waits the full limit, then closes the session',
        (tester) async {
      final client = _RecordingImapClient()..hangOnMove = true;
      final adapter = _adapterWith(client);
      Object? error;
      var done = false;
      unawaited(adapter
          .moveToFolder(message: message(), targetFolder: 'Trash')
          .then((_) => done = true, onError: (Object e) {
        error = e;
        done = true;
      }));
      await tester.pump(kImapResponseTimeout - const Duration(seconds: 1));
      expect(done, isFalse, reason: 'it must not give up before the limit');
      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue, reason: 'a hung MOVE used to wait forever');
      expect(error, isA<ImapServerNotRespondingException>());
      expect((error! as ImapServerNotRespondingException).command, 'UID MOVE');
      expect(adapter.debugHasClient, isFalse);
      expect(client.disconnects, 1);
    });

    test('a MOVE timeout in the batch path stops the batch, not one chunk',
        () async {
      final client = _RecordingImapClient(moveError: TimeoutException('move'));
      final adapter = _adapterWith(client);
      await expectLater(
          adapter.takeActionBatch([message()], FilterAction.delete),
          throwsA(isA<ImapServerNotRespondingException>()),
          reason: 'the chunk catch would retry it for 6 passes');
      expect(client.moves, 1, reason: 'no second MOVE on the dead session');
      expect(adapter.debugHasClient, isFalse);
    });

    test('the single-message paths rethrow it too', () async {
      final notResponding = throwsA(isA<ImapServerNotRespondingException>());
      for (final action in [
        FilterAction.delete,
        FilterAction.moveToJunk,
        FilterAction.moveToFolder,
      ]) {
        await expectLater(
            _adapterWith(
                    _RecordingImapClient(moveError: TimeoutException('move')))
                .takeAction(message: message(), action: action),
            notResponding,
            reason: '$action');
      }
      await expectLater(
          _adapterWith(_RecordingImapClient(moveError: TimeoutException('m')))
              .moveToFolder(message: message(), targetFolder: 'Trash'),
          notResponding);
    });

    test('a MOVE refused by the server is not a session end', () async {
      final client = _RecordingImapClient(
          moveError:
              ImapException(ImapClient(isLogEnabled: false), 'NO no such box'));
      final adapter = _adapterWith(client);
      await expectLater(
          adapter.moveToFolder(message: message(), targetFolder: 'Nowhere'),
          throwsA(isA<ActionException>()));
      expect(adapter.debugHasClient, isTrue);
      expect(client.disconnects, 0);
    });
  });
}

extension on String {
  int allMatchesIn(String s) => RegExp(RegExp.escape(this)).allMatches(s).length;
}
