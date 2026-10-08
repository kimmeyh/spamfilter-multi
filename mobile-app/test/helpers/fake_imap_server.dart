/// An in-process IMAP server over loopback that records every byte it
/// receives (F192 + SEC-8b, Sprint 77). Shared by the Custom IMAP adapter test
/// and the certificate-trust test so both prove their claims against REAL
/// sockets and a REAL TLS handshake.
///
/// TEST ONLY. Binds 127.0.0.1 on an ephemeral port; no network access.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// How the server answers STARTTLS.
enum StartTlsBehavior {
  /// Reply "NO" to STARTTLS.
  refuse,

  /// Reply "OK" and then close the socket, so the TLS handshake cannot finish.
  okThenClose,

  /// Reply "OK" and complete a real TLS handshake with [FakeImapServer.context].
  accept,

  /// Reply "OK" followed by an injected plaintext line in the SAME write,
  /// before the handshake (the STARTTLS command-injection shape).
  okWithInjection,

  /// Answer STARTTLS with 64 KB and no line end (a hostile server growing
  /// the client's pre-TLS buffer).
  oversizedLine,

  /// Answer STARTTLS with an endless run of untagged lines and never the
  /// tagged reply.
  untaggedFlood,
}

/// Fixture paths under `test/fixtures/tls/` (see its README.txt).
const String tlsFixtureDir = 'test/fixtures/tls';

/// A server [SecurityContext] for fixture certificate number [n] (1, 2 or 3;
/// 1 is `cert.pem`/`key.pem`).
SecurityContext fixtureServerContext(int n) {
  final suffix = n == 1 ? '' : '$n';
  return SecurityContext()
    ..useCertificateChain('$tlsFixtureDir/cert$suffix.pem')
    ..usePrivateKey('$tlsFixtureDir/key$suffix.pem');
}

class FakeImapServer {
  FakeImapServer._(this._plain, this._secure, this._behavior, this.context);

  final ServerSocket? _plain;
  final SecureServerSocket? _secure;
  final StartTlsBehavior _behavior;

  /// Context used for a STARTTLS handshake. Mutable so a test can make the
  /// server present a DIFFERENT certificate on its next connection.
  SecurityContext context;

  /// Number of TCP connections accepted.
  int connections = 0;

  /// When true, LOGIN is refused with `NO [AUTHENTICATIONFAILED]` (a wrong
  /// password), as a real server does (Sprint 77 MV step 3a).
  bool rejectLogin = false;

  /// Every byte received on any connection, decoded as Latin-1 (so a binary
  /// TLS ClientHello cannot throw).
  final StringBuffer rawReceived = StringBuffer();

  /// IMAP command lines received IN CLEARTEXT (before any TLS).
  final List<String> plaintextCommands = [];

  /// IMAP command lines received over TLS.
  final List<String> tlsCommands = [];

  int get port => _plain?.port ?? _secure!.port;

  /// All text the server ever saw, to assert a secret never appeared.
  String get everything => rawReceived.toString();

  /// Server that speaks TLS from the first byte (port-993 style).
  static Future<FakeImapServer> implicitTls(SecurityContext context) async {
    final secure = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4, 0, context);
    final server =
        FakeImapServer._(null, secure, StartTlsBehavior.refuse, context);
    secure.listen((socket) => server._serve(socket, tls: true),
        onError: (_) {});
    return server;
  }

  /// Server that starts in cleartext and offers STARTTLS (port-143 style).
  static Future<FakeImapServer> startTls(
      StartTlsBehavior behavior, SecurityContext context) async {
    final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final server = FakeImapServer._(plain, null, behavior, context);
    plain.listen((socket) => server._serve(socket, tls: false));
    return server;
  }

  void _serve(Socket socket, {required bool tls}) {
    connections++;
    socket.write('* OK [CAPABILITY IMAP4rev1 STARTTLS] fake server ready\r\n');
    _listen(socket, tls: tls);
  }

  void _listen(Socket socket, {required bool tls}) {
    final buffer = StringBuffer();
    late StreamSubscription<List<int>> sub;
    sub = socket.listen((data) async {
      rawReceived.write(latin1.decode(data));
      buffer.write(latin1.decode(data));
      var text = buffer.toString();
      int index;
      while ((index = text.indexOf('\r\n')) >= 0) {
        final line = text.substring(0, index);
        text = text.substring(index + 2);
        buffer
          ..clear()
          ..write(text);
        (tls ? tlsCommands : plaintextCommands).add(line);
        final parts = line.split(' ');
        final tag = parts.first;
        final command = parts.length > 1 ? parts[1].toUpperCase() : '';
        switch (command) {
          case 'STARTTLS':
            if (tls || _behavior == StartTlsBehavior.refuse) {
              socket.write('$tag NO STARTTLS not available\r\n');
            } else if (_behavior == StartTlsBehavior.oversizedLine) {
              socket.write('* ${'x' * (64 * 1024)}');
            } else if (_behavior == StartTlsBehavior.untaggedFlood) {
              // One write; the client is expected to hang up part way, so a
              // failed write is the expected outcome, not a test error.
              socket.done.then((_) {}, onError: (_) {});
              socket.write(List.generate(200, (i) => '* $i still thinking\r\n')
                  .join());
            } else if (_behavior == StartTlsBehavior.okThenClose) {
              socket.write('$tag OK Begin TLS negotiation\r\n');
              await socket.flush();
              await sub.cancel();
              socket.destroy();
            } else {
              socket.write(_behavior == StartTlsBehavior.okWithInjection
                  ? '$tag OK Begin TLS negotiation\r\n* OK injected\r\n'
                  : '$tag OK Begin TLS negotiation\r\n');
              await socket.flush();
              sub.pause();
              try {
                final secured = await SecureSocket.secureServer(socket, context);
                _listen(secured, tls: true);
              } on Object {
                // The client rejected our certificate (or gave up) and
                // aborted the handshake. That is the point of those tests.
                socket.destroy();
              }
            }
            return;
          case 'CAPABILITY':
            socket.write('* CAPABILITY IMAP4rev1 STARTTLS\r\n$tag OK done\r\n');
          case 'LOGIN':
            socket.write(rejectLogin
                ? '$tag NO [AUTHENTICATIONFAILED] Invalid credentials\r\n'
                : '$tag OK [CAPABILITY IMAP4rev1] logged in\r\n');
          case 'LOGOUT':
            socket.write('* BYE bye\r\n$tag OK logout done\r\n');
          default:
            socket.write('$tag OK\r\n');
        }
      }
    }, onError: (_) {}, onDone: () {});
  }

  Future<void> close() async {
    await _plain?.close();
    await _secure?.close();
  }
}
