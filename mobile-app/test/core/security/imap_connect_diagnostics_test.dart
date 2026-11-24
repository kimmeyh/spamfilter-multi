// F347 (Sprint 86): the connect-failure diagnostic line names the phase and
// the network type, and never changes the exception the adapter maps.
import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';
import 'package:my_email_spam_filter/core/security/imap_connect_diagnostics.dart';

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    ImapConnectDiagnostics.resetForTest();
    ImapConnectDiagnostics.logEnabled = () async => true;
    ImapConnectDiagnostics.sink = (d) async => lines.add(d);
    ImapConnectDiagnostics.networkTypeReader = () async => 'wifi';
    ImapConnectDiagnostics.dnsLookup =
        (h) async => [InternetAddress.loopbackIPv4];
  });
  tearDown(ImapConnectDiagnostics.resetForTest);

  // 10.255.255.1 is unroutable on most networks: the connect either hangs
  // (TimeoutException) or fails at once (SocketException). Both are tcp.
  Future<Object> tcpFailure(
      [ImapEncryption encryption = ImapEncryption.sslTls]) async {
    try {
      await ImapTlsConnector.connect(
        host: '10.255.255.1',
        port: 993,
        encryption: encryption,
        timeout: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // The report runs in the background; wait for it before the test reads.
      await ImapConnectDiagnostics.settleForTest();
      return e;
    }
    fail('connect should not succeed');
  }

  group('Custom IMAP path (ImapTlsConnector)', () {
    test('SSL/TLS stall: names the inferred phase tcp+tls and the network',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add); // accepts, never answers the handshake
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });

      Object? error;
      try {
        await ImapTlsConnector.connect(
          host: '127.0.0.1',
          port: server.port,
          encryption: ImapEncryption.sslTls,
          timeout: const Duration(milliseconds: 400),
        );
      } catch (e) {
        error = e;
      }

      await ImapConnectDiagnostics.settleForTest();
      // R-3: same type, same message shape as before the diagnostic.
      expect(error, isA<TimeoutException>());
      expect(error.toString(), contains('Future not completed'));
      expect(lines, hasLength(1));
      expect(lines.single, contains('phase=tcp+tls'));
      expect(lines.single, contains('phase-inferred'));
      expect(lines.single, contains('network=wifi'));
      expect(lines.single, contains('error=TimeoutException'));
      expect(lines.single, contains('host=127.0.0.1:${server.port}'));
    }); // What this does NOT catch: whether TCP or TLS stalled on the SSL/TLS
    // path (one call covers both); the STARTTLS tests below separate them.

    test('STARTTLS then silence in the handshake: phase=tls with tcp and '
        'starttls finished', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen((c) {
        held.add(c);
        c.write('* OK ready\r\n');
        c.listen((data) {
          if (String.fromCharCodes(data).contains('STARTTLS')) {
            c.write('S1 OK Begin TLS\r\n'); // then never answers the hello
          }
        });
      });
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });
      await expectLater(
        ImapTlsConnector.connect(
          host: '127.0.0.1',
          port: server.port,
          encryption: ImapEncryption.startTls,
          timeout: const Duration(milliseconds: 600),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('phase=tls'));
      expect(lines.single, contains('tcp='));
      expect(lines.single, contains('starttls='));
      expect(lines.single, isNot(contains('phase-inferred')));
    }); // What this does NOT catch: a real server's STARTTLS timing.

    test('TCP stall (STARTTLS path): names phase=tcp and the network',
        () async {
      final error = await tcpFailure(ImapEncryption.startTls);
      expect(error is TimeoutException || error is SocketException, isTrue);
      expect(lines, hasLength(1));
      expect(lines.single, contains('phase=tcp '));
      expect(lines.single, contains('network=wifi'));
      expect(lines.single, isNot(contains('tcp=')));
    }); // What this does NOT catch: an address that accepts and then resets;
    // and whether the machine routes 10.255.255.1 at all (either failure type
    // counts as the tcp phase here).

    test('DNS failure: names phase=dns; the exception is a network type',
        () async {
      ImapConnectDiagnostics.dnsLookup =
          (h) async => throw const SocketException('no such host');
      final error = await tcpFailure();
      expect(error is TimeoutException || error is SocketException, isTrue);
      expect(lines.single, contains('phase=dns'));
      expect(lines.single, contains('dns-recheck=SocketException'));
    }); // What this does NOT catch: a lookup failure where the real connect
    // then succeeds (no line is written, by design); exception identity (the
    // identity test below covers it).

    test('DNS that never answers: phase stays in-flight, dns-recheck=timeout',
        () async {
      ImapConnectDiagnostics.dnsTimeout = const Duration(milliseconds: 50);
      ImapConnectDiagnostics.dnsLookup =
          (h) => Completer<List<InternetAddress>>().future;
      await tcpFailure();
      expect(lines.single, contains('phase=tcp+tls'));
      expect(lines.single, isNot(contains('phase=dns')));
      expect(lines.single, contains('dns-recheck=timeout'));
    }); // What this does NOT catch: a lookup slower than dnsTimeout that would
    // still have finished before the connect timeout.

    test('log OFF: no lookup, no connectivity read, no line; error arrives '
        'at once', () async {
      var lookups = 0;
      var reads = 0;
      ImapConnectDiagnostics.logEnabled = () async => false;
      ImapConnectDiagnostics.dnsLookup = (h) async {
        lookups++;
        return [InternetAddress.loopbackIPv4];
      };
      ImapConnectDiagnostics.networkTypeReader = () async {
        reads++;
        return 'wifi';
      };
      final original = TimeoutException('connect');
      final sw = Stopwatch()..start();
      await expectLater(
        ImapConnectDiagnostics.traceConnect<void>(
          host: 'h',
          port: 993,
          providerPath: true,
          body: (_) async => throw original,
        ),
        throwsA(same(original)),
      );
      expect(sw.elapsedMilliseconds, lessThan(500));
      await ImapConnectDiagnostics.settleForTest();
      expect(lookups, 0);
      expect(reads, 0);
      expect(lines, isEmpty);
    }); // What this does NOT catch: the real DiagnosticLogger.isEnabled reading
    // the database (replaced by the seam here).

    test('log ON with a slow lookup: the caller error is not delayed',
        () async {
      ImapConnectDiagnostics.dnsTimeout = const Duration(seconds: 5);
      final gate = Completer<List<InternetAddress>>();
      ImapConnectDiagnostics.dnsLookup = (h) => gate.future;
      final original = TimeoutException('connect');
      final sw = Stopwatch()..start();
      await expectLater(
        ImapConnectDiagnostics.traceConnect<void>(
          host: 'h',
          port: 993,
          providerPath: true,
          body: (_) async => throw original,
        ),
        throwsA(same(original)),
      );
      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(lines, isEmpty); // the report is still waiting on the lookup
      gate.complete([InternetAddress.loopbackIPv4]);
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('dns-recheck=ok'));
    }); // What this does NOT catch: a platform where the 500 ms bound is too
    // tight under heavy load (the lookup itself is a never-completing fake).

    test('a lookup that fails fast with a refused connect is still phase=dns',
        () async {
      // The recheck runs after the failure and must be awaited.
      ImapConnectDiagnostics.dnsLookup = (h) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        throw const SocketException('no such host');
      };
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = probe.port;
      await probe.close();
      try {
        await ImapTlsConnector.connect(
          host: '127.0.0.1',
          port: closedPort,
          encryption: ImapEncryption.sslTls,
          timeout: const Duration(milliseconds: 2500),
        );
        fail('connect should not succeed');
      } on SocketException {
        // expected, unchanged type (Windows may take over 1 s to refuse)
      } on TimeoutException {
        // the same failure when the refusal is slower than the limit
      }
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('phase=dns'));
      expect(lines.single, contains('dns-recheck=SocketException'));
    }); // What this does NOT catch: a lookup slower than dnsTimeout.

    test('a failing lookup is not run, and is not blamed, once TLS was reached',
        () async {
      ImapConnectDiagnostics.dnsLookup =
          (h) async => throw const SocketException('no such host');
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen((c) {
        held.add(c);
        c.write('* OK ready\r\n');
        c.listen((data) {
          if (String.fromCharCodes(data).contains('STARTTLS')) {
            c.write('S1 OK Begin TLS\r\n');
          }
        });
      });
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });
      await expectLater(
        ImapTlsConnector.connect(
          host: '127.0.0.1',
          port: server.port,
          encryption: ImapEncryption.startTls,
          timeout: const Duration(milliseconds: 600),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('phase=tls'));
      expect(lines.single, contains('tcp='));
      expect(lines.single, contains('dns=passed'));
      expect(lines.single, isNot(contains('dns-recheck')));
    }); // What this does NOT catch: the wording of the dns note.

    test('STARTTLS stall: logs phase=starttls and keeps the refusal', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add); // accepts, sends no greeting
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });
      await expectLater(
        ImapTlsConnector.connect(
          host: '127.0.0.1',
          port: server.port,
          encryption: ImapEncryption.startTls,
          timeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<UserFacingConnectionException>()),
      );
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('phase=starttls'));
      expect(lines.single, contains('tcp='));
      expect(lines.single, contains('error=TimeoutException'));
    }); // What this does NOT catch: a STARTTLS refusal that is not a network
    // failure (deliberately unlogged).

    test('network read that hangs is reported as unknown', () async {
      ImapConnectDiagnostics.networkReadTimeout =
          const Duration(milliseconds: 50);
      ImapConnectDiagnostics.networkTypeReader =
          () => Completer<String>().future;
      await tcpFailure();
      expect(lines.single, contains('network=unknown'));
    }); // What this does NOT catch: the real connectivity_plus plugin (it is
    // replaced here); a read that throws is covered by the same catch.

    test('a failing sink does not replace the connect failure', () async {
      ImapConnectDiagnostics.sink = (d) async => throw StateError('log down');
      final error = await tcpFailure();
      expect(error is TimeoutException || error is SocketException, isTrue);
    }); // What this does NOT catch: a sink that hangs forever.
  });

  group('provider path (ImapClient.connectToServer)', () {
    test('timeout is reported as the inferred phase tcp+tls, exception intact',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add);
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });
      final client = ImapClient(isLogEnabled: false);

      Object? error;
      try {
        await ImapConnectDiagnostics.traceConnect<Object?>(
          host: '127.0.0.1',
          port: server.port,
          providerPath: true,
          body: (_) => client.connectToServer('127.0.0.1', server.port,
              isSecure: true, timeout: const Duration(milliseconds: 400)),
        );
      } catch (e) {
        error = e;
      }
      await ImapConnectDiagnostics.settleForTest();
      expect(error, isA<TimeoutException>());
      expect(lines.single, contains('phase=tcp+tls'));
      expect(lines.single, contains('phase-inferred'));
      expect(lines.single, contains('network=wifi'));
    }); // What this does NOT catch: that generic_imap_adapter.dart calls
    // traceConnect (the adapter has no seam for a server); see the source gate.

    test('a non-network exception passes through with no line', () async {
      final boom = StateError('not a network error');
      await expectLater(
        ImapConnectDiagnostics.traceConnect<void>(
          host: 'h',
          port: 1,
          body: (_) async => throw boom,
        ),
        throwsA(same(boom)),
      );
      expect(lines, isEmpty);
    }); // What this does NOT catch: HandshakeException (deliberately unlogged).

    test('the rethrown exception is the SAME object (type, message, identity)',
        () async {
      const original = SocketException('Connection refused', port: 993);
      await expectLater(
        ImapConnectDiagnostics.traceConnect<void>(
          host: 'h',
          port: 993,
          providerPath: true,
          body: (_) async => throw original,
        ),
        throwsA(same(original)),
      );
      await ImapConnectDiagnostics.settleForTest();
      expect(lines.single, contains('error=SocketException'));
      expect(lines.single, isNot(contains('Connection refused')));
    }); // What this does NOT catch: the adapter's own mapping to
    // ConnectionException (unchanged code, covered by adapter tests).
  });

  test('the adapter source routes the provider connect through the trace', () {
    final src = File('lib/adapters/email_providers/generic_imap_adapter.dart')
        .readAsStringSync();
    expect(
      src,
      matches(RegExp(
          r'ImapConnectDiagnostics\.traceConnect[\s\S]{0,400}?'
          r'client\.connectToServer\(_imapHost, _imapPort')),
    );
  }); // What this does NOT catch: a call that is present but unreachable.
}
