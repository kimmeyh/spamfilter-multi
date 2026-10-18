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
// one command alive past the limit in pieces, and a stalled UID MOVE (no
// per-call limit exists in the library; decision pending, Sprint 79 7.7.1).
// It proves the library behavior the fix relies on, with a real socket, that
// both client constructors pass the default, and that the adapter passes the
// limit to every SEARCH and FETCH and lets a timeout through.
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';

/// Records the per-call `responseTimeout` the adapter passes; can be told to
/// fail SEARCH the way a stalled server does.
class _RecordingImapClient extends ImapClient {
  _RecordingImapClient({this.searchError}) : super(isLogEnabled: false);

  final Object? searchError;
  final List<Duration?> searchTimeouts = [];
  final List<Duration?> fetchTimeouts = [];

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async =>
      Mailbox(
          encodedName: path, encodedPath: path, pathSeparator: '/', flags: []);

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
    expect(error, isA<ImapException>(),
        reason: 'the adapter swallowed the timeout and returned a list');
  });
}

extension on String {
  int allMatchesIn(String s) => RegExp(RegExp.escape(this)).allMatches(s).length;
}
