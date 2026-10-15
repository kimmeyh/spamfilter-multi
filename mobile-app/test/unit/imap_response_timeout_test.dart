// Sprint 79 Task 1 R-8: an IMAP command that never gets a reply must END,
// not hang the scan.
//
// What this does NOT catch: a hang OUTSIDE an IMAP command (a Dart await on
// something else), a process the OS freezes or kills (the Fold rows whose
// heartbeat never ran), or a server that trickles bytes slowly enough to keep
// one command alive past the limit in pieces. It proves the library behavior
// the fix relies on, with a real socket, and that both client constructors
// pass the limit.
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/core/security/imap_certificate_trust.dart';

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
}
