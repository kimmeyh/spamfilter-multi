/// SEC-8 (Sprint 33), corrected by SEC-8b (Sprint 77, ADR-0046): issuing
/// authority pinning for the Google OAuth endpoints.
///
/// ## What is enforced
///
/// A request to a pinned host goes through a dart:io `HttpClient` whose
/// `SecurityContext` trusts ONLY the Google Trust Services root certificates
/// below (`SecurityContext(withTrustedRoots: false)` plus those roots). The
/// TLS library then validates EVERY handshake to that host, on the normal
/// path, against those roots and nothing else: a certificate chain that does
/// not lead to a Google root is rejected even when the device would have
/// trusted it (for example a certificate issued by another public CA, or by a
/// traffic-inspection proxy whose CA was installed on the device). The host
/// name check is unchanged. A rejection throws
/// [CertificatePinMismatchException] naming the host and the presented
/// certificate; it never falls back to a connection.
///
/// ## Why roots, not the leaf or SPKI hashes
///
/// dart:io exposes only the server's LEAF certificate to Dart code
/// (`HttpClientResponse.certificate`, `SecureSocket.peerCertificate`); the
/// intermediate certificates are never handed over, so an "intermediate SPKI
/// hash" cannot be computed from Dart. Google rotates leaf certificates
/// often, so a leaf pin would break sign-in. Restricting the trust anchors is
/// the strongest check dart:io can actually perform, and it is performed by
/// the TLS library on the full chain.
///
/// The Sprint 33 version of this file claimed SPKI pinning but enforced
/// nothing on the normal path: its `badCertificateCallback` ran only when the
/// device already distrusted the certificate, `send()` checked only the URL
/// scheme, and `fingerprint()` hashed the whole certificate while the pins
/// were documented as SPKI hashes. (The two hashes it carried did not match
/// any current Google root either.)
///
/// ## The pinned roots (primary source, verified 2026-10-07)
///
/// Google Trust Services repository, https://pki.goog/repository/ (data file
/// https://pki.goog/repo/repo.json), "root" entries: GTS Root R1, R2, R3, R4
/// and GlobalSign ECC Root CA - R4. Each PEM below was downloaded from the
/// repository's own link (https://i.pki.goog/r1.pem, r2.pem, r3.pem, r4.pem,
/// gsr4.pem) and its DER SHA-256 compared with the repository's published
/// fingerprint ([googleRootSha256]); `certificate_pinner_test.dart` re-checks
/// that equality on every run. All five are valid until 2036 or later.
/// On 2026-10-07 all four pinned hosts served leaf -> WR2 -> GTS Root R1.
///
/// ## Kill switch
///
/// [CertificatePinner.setEnabled] (Settings > General, "Pin Google OAuth
/// certificates"; persisted and applied at start-up in `main.dart`) turns the
/// restriction off: pinned hosts then use normal device validation. It does
/// not affect Custom IMAP certificate trust (`imap_certificate_trust.dart`),
/// which is a separate rule with its own user confirmation.
///
/// ## Scope
///
/// Only the hosts in the pin map. Callers: `gmail_windows_oauth_handler.dart`
/// (token exchange, desktop token refresh, userinfo). Android's native Google
/// sign-in and its AppAuth refresh use the platform HTTP stack and are not
/// routed through this client (unchanged by SEC-8b). IMAP is not handled here:
/// known IMAP providers use normal platform validation, and Custom IMAP
/// servers use trust-on-first-use (ADR-0046).
///
/// ## Platforms (ADR-0042, parity)
///
/// Shared Dart. On Windows and Android a dart:io `HttpClient` with an
/// explicit `SecurityContext` validates the chain inside BoringSSL in the
/// Dart runtime against only that context's roots; the OS trust store is not
/// consulted for these hosts. Verified live on the Windows host 2026-10-07
/// (Google hosts pass, a DigiCert-issued site fails); the same dart:io code
/// runs on Android.
///
/// ## Rotation procedure
///
/// Pins change only if Google moves these hosts to a root outside the list
/// (the repository lists any new root before it is used). To update: add the
/// new root's PEM from https://pki.goog/repository/ to [_googleTrustServicesRootsPem]
/// and its published SHA-256 to [googleRootSha256], ship, and remove a root
/// only after it has expired. The kill switch is the field release valve.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logger/logger.dart';

/// A pinned host presented a certificate chain that does not lead to one of
/// its pinned roots (or was requested without TLS). The request was not sent.
class CertificatePinMismatchException implements Exception {
  final String host;
  final String expected;
  final String actual;

  CertificatePinMismatchException({
    required this.host,
    required this.expected,
    required this.actual,
  });

  /// Plain sentence for the screen.
  static const String userMessage =
      'The Google sign-in server presented a certificate that was not issued '
      'by Google, so the app stopped before sending anything. This can happen '
      'on a network that inspects secure connections. Try another network; if '
      'you trust this one, you can turn off "Pin Google OAuth certificates" in '
      'Settings > General.';

  @override
  String toString() =>
      'CertificatePinMismatchException(host: $host, '
      'expected: $expected, actual: $actual)';
}

/// Registry of pinned hosts and their trusted root certificates.
class CertificatePinner {
  static final Logger _logger = Logger();

  /// Published DER SHA-256 of each pinned root, copied from
  /// https://pki.goog/repo/repo.json on 2026-10-07 (lower-case hex).
  static const Map<String, String> googleRootSha256 = {
    'GTS Root R1':
        'd947432abde7b7fa90fc2e6b59101b1280e0e1c7e4e40fa3c6887fff57a7f4cf',
    'GTS Root R2':
        '8d25cd97229dbf70356bda4eb3cc734031e24cf00fafcfd32dc76eb5841c7ea8',
    'GTS Root R3':
        '34d8a73ee208d9bcdb0d956520934b4e40e69482596e8b6f73c8426b010a6f48',
    'GTS Root R4':
        '349dfa4058c5e263123b398ae795573c4e1313c83fe68f93556cd5e8031b3c7d',
    'GlobalSign ECC Root CA - R4':
        'b085d70b964f191a73e4af0d54ae7a0e07aafdaf9b71dd0862138ab7325a24a2',
  };

  /// The five Google Trust Services roots, in [googleRootSha256] order.
  /// Public certificates (no secret); see the library dartdoc for the source.
  static const String _googleTrustServicesRootsPem = '''
-----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw
MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp
Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo
27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w
Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw
TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl
qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH
szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8
Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk
MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92
wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p
aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN
VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID
AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb
C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe
QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy
h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4
7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J
ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef
MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/
Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT
6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ
0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm
2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb
bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlrsWNBCUaqxElqjANBgkqhkiG9w0BAQwFADBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjIwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw
MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp
Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjIwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQDO3v2m++zsFDQ8BwZabFn3GTXd98GdVarTzTukk3LvCvpt
nfbwhYBboUhSnznFt+4orO/LdmgUud+tAWyZH8QiHZ/+cnfgLFuv5AS/T3KgGjSY
6Dlo7JUle3ah5mm5hRm9iYz+re026nO8/4Piy33B0s5Ks40FnotJk9/BW9BuXvAu
MC6C/Pq8tBcKSOWIm8Wba96wyrQD8Nr0kLhlZPdcTK3ofmZemde4wj7I0BOdre7k
RXuJVfeKH2JShBKzwkCX44ofR5GmdFrS+LFjKBC4swm4VndAoiaYecb+3yXuPuWg
f9RhD1FLPD+M2uFwdNjCaKH5wQzpoeJ/u1U8dgbuak7MkogwTZq9TwtImoS1mKPV
+3PBV2HdKFZ1E66HjucMUQkQdYhMvI35ezzUIkgfKtzra7tEscszcTJGr61K8Yzo
dDqs5xoic4DSMPclQsciOzsSrZYuxsN2B6ogtzVJV+mSSeh2FnIxZyuWfoqjx5RW
Ir9qS34BIbIjMt/kmkRtWVtd9QCgHJvGeJeNkP+byKq0rxFROV7Z+2et1VsRnTKa
G73VululycslaVNVJ1zgyjbLiGH7HrfQy+4W+9OmTN6SpdTi3/UGVN4unUu0kzCq
gc7dGtxRcw1PcOnlthYhGXmy5okLdWTK1au8CcEYof/UVKGFPP0UJAOyh9OktwID
AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQUu//KjiOfT5nK2+JopqUVJxce2Q4wDQYJKoZIhvcNAQEMBQADggIBAB/Kzt3H
vqGf2SdMC9wXmBFqiN495nFWcrKeGk6c1SuYJF2ba3uwM4IJvd8lRuqYnrYb/oM8
0mJhwQTtzuDFycgTE1XnqGOtjHsB/ncw4c5omwX4Eu55MaBBRTUoCnGkJE+M3DyC
B19m3H0Q/gxhswWV7uGugQ+o+MePTagjAiZrHYNSVc61LwDKgEDg4XSsYPWHgJ2u
NmSRXbBoGOqKYcl3qJfEycel/FVL8/B/uWU9J2jQzGv6U53hkRrJXRqWbTKH7QMg
yALOWr7Z6v2yTcQvG99fevX4i8buMTolUVVnjWQye+mew4K6Ki3pHrTgSAai/Gev
HyICc/sgCq+dVEuhzf9gR7A/Xe8bVr2XIZYtCtFenTgCR2y59PYjJbigapordwj6
xLEokCZYCDzifqrXPW+6MYgKBesntaFJ7qBFVHvmJ2WZICGoo7z7GJa7Um8M7YNR
TOlZ4iBgxcJlkoKM8xAfDoqXvneCbT+PHV28SSe9zE8P4c52hgQjxcCMElv924Sg
JPFI/2R80L5cFtHvma3AH/vLrrw4IgYmZNralw4/KBVEqE8AyvCazM90arQ+POuV
7LXTWtiBmelDGDfrs7vRWGJB82bSj6p4lVQgw1oudCvV0b4YacCs1aTPObpRhANl
6WLAYv7YTVWW4tAR+kg0Eeye7QUd5MjWHYbL
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPluILrIPglJ209ZjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjMwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjMwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AAQfTzOHMymKoYTey8chWEGJ6ladK0uFxh1MJ7x/JlFyb+Kf1qPKzEUURout736G
jOyxfi//qXGdGIRFBEFVbivqJn+7kAHjSxm65FSWRQmx1WyRRK2EE46ajA2ADDL2
4CejQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBTB8Sa6oC2uhYHP0/EqEr24Cmf9vDAKBggqhkjOPQQDAwNpADBmAjEA9uEglRR7
VKOQFhG/hMjqb2sXnh5GmCCbn9MN2azTL818+FsuVbu/3ZL3pAzcMeGiAjEA/Jdm
ZuVDFhOD3cffL74UOO0BzrEXGhF16b0DjyZ+hOXJYKaV11RZt+cRLInUue4X
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIB3DCCAYOgAwIBAgINAgPlfvU/k/2lCSGypjAKBggqhkjOPQQDAjBQMSQwIgYD
VQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0gUjQxEzARBgNVBAoTCkdsb2Jh
bFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTIxMTEzMDAwMDAwWhcNMzgw
MTE5MDMxNDA3WjBQMSQwIgYDVQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0g
UjQxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wWTAT
BgcqhkjOPQIBBggqhkjOPQMBBwNCAAS4xnnTj2wlDp8uORkcA6SumuU5BwkWymOx
uYb4ilfBV85C+nOh92VC/x7BALJucw7/xyHlGKSq2XE/qNS5zowdo0IwQDAOBgNV
HQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUVLB7rUW44kB/
+wpu+74zyTyjhNUwCgYIKoZIzj0EAwIDRwAwRAIgIk90crlgr/HmnKAWBVBfw147
bmF0774BxL4YSFlhgjICICadVGNA3jdgUM/I2O2dgq43mLyjj0xMqTQrbO/7lZsm
-----END CERTIFICATE-----
''';

  /// Hosts pinned to the Google Trust Services roots.
  static const List<String> googlePinnedHosts = <String>[
    'accounts.google.com',
    'oauth2.googleapis.com',
    'gmail.googleapis.com',
    'www.googleapis.com',
  ];

  static Map<String, String> _defaultPins() => {
        for (final host in googlePinnedHosts)
          host: _googleTrustServicesRootsPem,
      };

  /// Host -> PEM bundle of the ONLY roots trusted for that host.
  static Map<String, String> _pins = _defaultPins();

  /// Runtime kill switch. When `false`, pinned hosts use normal device
  /// validation. Defaults to `true` (pinning on).
  static bool _enabled = true;

  /// The default (shipped) root bundle, for tests and diagnostics.
  static String get googleTrustServicesRootsPem => _googleTrustServicesRootsPem;

  /// Snapshot of the pins (host -> PEM bundle), unmodifiable.
  static Map<String, String> get pins => Map.unmodifiable(_pins);

  /// Whether pinning is currently enforced.
  static bool get enabled => _enabled;

  /// True when a request to [host] must chain to its pinned roots right now.
  static bool isEnforcedFor(String host) => _enabled && _pins.containsKey(host);

  /// Toggle pinning at runtime (Settings toggle and start-up initializer).
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    _logger.i('Certificate pinning ${enabled ? "enabled" : "DISABLED"}');
  }

  /// Replace the pin map (host -> PEM bundle) for tests. Always pair with
  /// [resetPinsForTesting] in tearDown.
  static void setPinsForTesting(Map<String, String> pemBundleByHost) {
    _pins = Map.of(pemBundleByHost);
  }

  /// Restore the shipped pins. Call in tearDown after [setPinsForTesting].
  static void resetPinsForTesting() {
    _pins = _defaultPins();
  }

  /// A context that trusts ONLY [host]'s pinned roots. Null for an unpinned
  /// host.
  static SecurityContext? securityContextFor(String host) {
    final pem = _pins[host];
    if (pem == null) return null;
    return SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(pem));
  }
}

/// HTTP client that enforces [CertificatePinner] on every TLS handshake to a
/// pinned host. Unpinned hosts, and every host while the kill switch is off,
/// use a normal client with device validation.
class PinnedHttpClient extends http.BaseClient {
  PinnedHttpClient();

  /// One client per pinned host (each has its own trust context).
  final Map<String, http.Client> _pinnedClients = {};
  http.Client? _deviceTrustClient;

  /// The certificate the pinned context last rejected, per host. Read only to
  /// name the failure; it never changes a decision.
  final Map<String, X509Certificate> _rejected = {};

  http.Client _clientFor(String host) {
    if (!CertificatePinner.isEnforcedFor(host)) {
      return _deviceTrustClient ??= IOClient(HttpClient());
    }
    return _pinnedClients.putIfAbsent(host, () {
      final io = HttpClient(context: CertificatePinner.securityContextFor(host));
      // Runs only when the chain does NOT lead to a pinned root (or the name
      // does not match). Always refuse; remember what was presented.
      io.badCertificateCallback = (cert, callbackHost, port) {
        _rejected[callbackHost] = cert;
        return false;
      };
      return IOClient(io);
    });
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    if (!CertificatePinner.isEnforcedFor(host)) {
      return _clientFor(host).send(request);
    }
    if (request.url.scheme != 'https') {
      throw CertificatePinMismatchException(
        host: host,
        expected: 'https with a Google Trust Services certificate chain',
        actual: '(no TLS: scheme=${request.url.scheme})',
      );
    }
    _rejected.remove(host);
    try {
      return await _clientFor(host).send(request);
    } catch (e) {
      final cert = _rejected.remove(host);
      // Only a handshake the pinned context REJECTED (the callback saw the
      // certificate) is a pin failure; a network or protocol error keeps its
      // own type so it is not misreported as an attack.
      if (cert != null) {
        throw CertificatePinMismatchException(
          host: host,
          expected: 'a chain to a pinned root '
              '(${CertificatePinner.googleRootSha256.keys.join(", ")})',
          actual: 'subject ${cert.subject}, issuer ${cert.issuer}',
        );
      }
      rethrow;
    }
  }

  @override
  void close() {
    for (final client in _pinnedClients.values) {
      client.close();
    }
    _deviceTrustClient?.close();
    super.close();
  }
}
