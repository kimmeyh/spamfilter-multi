/// [CertificatePinner] / [PinnedHttpClient] (SEC-8 Sprint 33, corrected by
/// SEC-8b Sprint 77, ADR-0046).
///
/// The Sprint 33 tests checked only the registry and the kill-switch flag; no
/// test ever pushed a certificate through the pinner, which is how a pin
/// layer that enforced nothing survived 44 sprints. These tests prove the
/// check on REAL TLS handshakes:
///
/// 1. Loopback HTTPS (fixture certificates, no network): a pinned host is
///    accepted only when its chain leads to a pinned root -- even when the
///    DEVICE trusts the presented certificate (the interception-proxy case);
///    the failure is a named [CertificatePinMismatchException] and the
///    server receives no request; the kill switch restores device validation.
/// 2. The shipped roots: each bundled PEM hashes to the fingerprint Google
///    publishes at https://pki.goog/repo/repo.json (copied 2026-10-07).
/// 3. Google's real chain, RECORDED 2026-10-07 from accounts.google.com
///    (`test/fixtures/tls/google_accounts_chain_20261007.pem`): its
///    intermediate names a pinned root as issuer, and the root certificate the
///    server sends carries the SAME public key as the pinned GTS Root R1.
/// 4. LIVE (network): the shipped pins accept today's Google endpoints and
///    reject a non-Google site. Skipped, with a printed reason, only when the
///    host cannot be resolved (no network); a TLS failure is a test failure,
///    because a wrong pin would break Gmail sign-in for every user.
///
/// Platforms (ADR-0042): shared dart:io code; an `HttpClient` with an explicit
/// `SecurityContext` validates inside BoringSSL in the Dart runtime on Windows
/// and Android alike. These tests run on the Windows host.
///
/// What these tests do NOT catch: signature verification of the RECORDED
/// chain (only the live test performs a real validation of Google's chain),
/// an Android device's behavior (same Dart code, not run on a device here),
/// and requests that bypass [PinnedHttpClient] (only the three
/// `gmail_windows_oauth_handler.dart` call sites use it).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/security/certificate_pinner.dart';

import '../../helpers/der_certificate.dart';

const _fixtures = 'test/fixtures/tls';

SecurityContext _serverContext(int n) {
  final suffix = n == 1 ? '' : '$n';
  return SecurityContext()
    ..useCertificateChain('$_fixtures/cert$suffix.pem')
    ..usePrivateKey('$_fixtures/key$suffix.pem');
}

String _pem(int n) =>
    File('$_fixtures/cert${n == 1 ? '' : '$n'}.pem').readAsStringSync();

/// A loopback HTTPS server presenting fixture certificate [n]; counts requests.
class _HttpsServer {
  _HttpsServer(this.server);
  final HttpServer server;
  int requests = 0;

  static Future<_HttpsServer> start(int n) async {
    final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4, 0, _serverContext(n));
    final wrapper = _HttpsServer(server);
    server.listen((request) {
      wrapper.requests++;
      request.response
        ..statusCode = 200
        ..write('ok');
      request.response.close();
    }, onError: (_) {});
    return wrapper;
  }

  Uri get uri => Uri.parse('https://localhost:${server.port}/token');
}

void main() {
  setUpAll(() {
    // The DEVICE trusts cert3 in this process (it plays a certificate the
    // device accepts but that is NOT under the pinned roots). cert2 is
    // trusted by nobody except the pin.
    SecurityContext.defaultContext
        .setTrustedCertificates('$_fixtures/cert3.pem');
  });

  tearDown(() {
    CertificatePinner.resetPinsForTesting();
    CertificatePinner.setEnabled(true);
  });

  group('enforcement on real handshakes (loopback)', () {
    test('a chain to a pinned root is accepted even though the device does '
        'NOT trust it -- proves the pinned context, not device trust, decides',
        () async {
      final server = await _HttpsServer.start(2);
      addTearDown(() => server.server.close(force: true));
      CertificatePinner.setPinsForTesting({'localhost': _pem(2)});

      final client = PinnedHttpClient();
      addTearDown(client.close);
      final response = await client.post(server.uri, body: 'code=x');

      expect(response.statusCode, 200);
      expect(server.requests, 1);
    });

    test('a certificate the DEVICE trusts but that is not under the pinned '
        'roots is refused with a named error, and no request reaches the '
        'server', () async {
      final server = await _HttpsServer.start(3); // device-trusted
      addTearDown(() => server.server.close(force: true));
      CertificatePinner.setPinsForTesting({'localhost': _pem(2)});

      final client = PinnedHttpClient();
      addTearDown(client.close);
      Object? error;
      try {
        await client.post(server.uri, body: 'code=secret-auth-code');
      } catch (e) {
        error = e;
      }

      expect(error, isA<CertificatePinMismatchException>());
      final e = error! as CertificatePinMismatchException;
      expect(e.host, 'localhost');
      expect(e.actual, contains('Third Test Certificate'));
      expect(server.requests, 0, reason: 'the auth code must never be sent');
    });

    test('kill switch OFF: the same device-trusted certificate is accepted '
        '(device validation only)', () async {
      final server = await _HttpsServer.start(3);
      addTearDown(() => server.server.close(force: true));
      CertificatePinner.setPinsForTesting({'localhost': _pem(2)});
      CertificatePinner.setEnabled(false);

      final client = PinnedHttpClient();
      addTearDown(client.close);
      final response = await client.post(server.uri, body: 'code=x');

      expect(response.statusCode, 200);
    });

    test('kill switch OFF does not accept what the DEVICE rejects', () async {
      final server = await _HttpsServer.start(2); // trusted only by the pin
      addTearDown(() => server.server.close(force: true));
      CertificatePinner.setPinsForTesting({'localhost': _pem(2)});
      CertificatePinner.setEnabled(false);

      final client = PinnedHttpClient();
      addTearDown(client.close);
      await expectLater(
          client.post(server.uri, body: 'code=x'), throwsA(isA<Exception>()));
      expect(server.requests, 0);
    });

    test('an unpinned host uses device validation', () async {
      final server = await _HttpsServer.start(3);
      addTearDown(() => server.server.close(force: true));
      CertificatePinner.setPinsForTesting({'pinned.example': _pem(2)});

      final client = PinnedHttpClient();
      addTearDown(client.close);
      final response = await client.post(server.uri, body: 'code=x');
      expect(response.statusCode, 200);
    });

    test('a pinned host requested over plain http is refused', () async {
      CertificatePinner.setPinsForTesting({'localhost': _pem(2)});
      final client = PinnedHttpClient();
      addTearDown(client.close);
      await expectLater(client.get(Uri.parse('http://localhost:9/')),
          throwsA(isA<CertificatePinMismatchException>()));
    });
  });

  group('shipped Google roots', () {
    test('pins cover exactly the four Google OAuth hosts, all with the GTS '
        'root bundle', () {
      expect(CertificatePinner.pins.keys.toSet(),
          CertificatePinner.googlePinnedHosts.toSet());
      for (final pem in CertificatePinner.pins.values) {
        expect(pem, CertificatePinner.googleTrustServicesRootsPem);
      }
      expect(() => (CertificatePinner.pins as Map)['evil.example'] = 'x',
          throwsUnsupportedError);
    });

    test('each bundled root hashes to the fingerprint pki.goog publishes',
        () {
      final roots = DerCertificate.parsePemBundle(
          CertificatePinner.googleTrustServicesRootsPem);
      final hashes = [for (final r in roots) sha256.convert(r.der).toString()];
      expect(hashes, CertificatePinner.googleRootSha256.values.toList());
      // Self-signed roots: issuer == subject.
      for (final r in roots) {
        expect(r.issuer, r.subject);
      }
    });

    test('the RECORDED accounts.google.com chain (2026-10-07) leads to a '
        'pinned root by name and by key', () {
      final chain = DerCertificate.parsePemBundle(File(
              '$_fixtures/google_accounts_chain_20261007.pem')
          .readAsStringSync());
      expect(chain, hasLength(3));
      final roots = DerCertificate.parsePemBundle(
          CertificatePinner.googleTrustServicesRootsPem);
      final gtsR1 = roots.first;

      // leaf -> WR2: names chain.
      expect(chain[0].issuer, chain[1].subject);
      // WR2 is issued by GTS Root R1 (a pinned root), byte for byte.
      expect(chain[1].issuer, gtsR1.subject);
      // The server also sends GTS Root R1 cross-signed by an older root; it
      // carries the SAME key as the pinned self-signed R1, so chain building
      // ends at the pinned anchor.
      expect(chain[2].subject, gtsR1.subject);
      expect(chain[2].spki, gtsR1.spki);
    });

    test('a wrong root bundle would NOT match the recorded chain (the check '
        'above can fail)', () {
      final chain = DerCertificate.parsePemBundle(File(
              '$_fixtures/google_accounts_chain_20261007.pem')
          .readAsStringSync());
      final notGoogle = DerCertificate.parsePemBundle(_pem(2)).single;
      expect(chain[1].issuer, isNot(notGoogle.subject));
      expect(chain[2].spki, isNot(notGoogle.spki));
    });
  });

  group('LIVE: today\'s Google endpoints with the shipped pins', () {
    Future<bool> online(String host) async {
      try {
        return (await InternetAddress.lookup(host)).isNotEmpty;
      } on SocketException {
        return false;
      }
    }

    for (final host in CertificatePinner.googlePinnedHosts) {
      test('$host passes the pin', () async {
        if (!await online(host)) {
          markTestSkipped('no network: cannot resolve $host');
          return;
        }
        final client = PinnedHttpClient();
        addTearDown(client.close);
        // Any HTTP status proves the TLS handshake passed the pin.
        final response = await client.get(Uri.parse('https://$host/'));
        expect(response.statusCode, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 30)));
    }

    test('a non-Google site pinned to the Google roots is refused', () async {
      const host = 'www.digicert.com';
      if (!await online(host)) {
        markTestSkipped('no network: cannot resolve $host');
        return;
      }
      CertificatePinner.setPinsForTesting(
          {host: CertificatePinner.googleTrustServicesRootsPem});
      final client = PinnedHttpClient();
      addTearDown(client.close);
      await expectLater(client.get(Uri.parse('https://$host/')),
          throwsA(isA<CertificatePinMismatchException>()));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  test('CertificatePinMismatchException names host, expectation and the '
      'presented certificate; its user message names the Settings switch', () {
    final ex = CertificatePinMismatchException(
        host: 'example.com', expected: 'roots A, B', actual: 'subject /CN=x');
    expect(ex.toString(), allOf(contains('example.com'), contains('roots A, B'),
        contains('/CN=x')));
    expect(CertificatePinMismatchException.userMessage,
        contains('Settings > General'));
  });

  test('utf8 PEM bundle loads into a SecurityContext (no format error)', () {
    expect(CertificatePinner.securityContextFor('accounts.google.com'),
        isNotNull);
    expect(CertificatePinner.securityContextFor('unpinned.example'), isNull);
    expect(utf8.encode(CertificatePinner.googleTrustServicesRootsPem),
        isNotEmpty);
  });
}
