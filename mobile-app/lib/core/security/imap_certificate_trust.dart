/// SEC-8b (Sprint 77, ADR-0046): certificate trust for Custom IMAP servers.
///
/// ## The rule (Sprint 77 Q4 = 1, trust-on-first-use)
///
/// 1. If the device (the platform trust store) trusts the server certificate,
///    the connection goes ahead, and its SHA-256 fingerprint is recorded so a
///    later switch to an untrusted certificate is reported as a CHANGE.
/// 2. If the device does NOT trust it, the connection goes ahead ONLY when
///    the presented certificate's SHA-256 fingerprint equals the one the user
///    accepted for this account. Anything else stops the TLS handshake before
///    a single IMAP command is sent, so the password never leaves the device,
///    and [ServerCertificateNotTrustedException] carries the certificate for
///    the "Trust this server?" dialog.
/// 3. Nothing here ever accepts a certificate silently: acceptance of an
///    untrusted certificate needs a stored fingerprint, and a stored
///    fingerprint is written only after the user said Yes in the dialog
///    (or for a certificate the device already trusted).
///
/// Known providers (AOL, Yahoo, Gmail IMAP, iCloud) do NOT use this file. They
/// keep normal platform validation only (Q4 option 4, leaf pinning, was
/// rejected because leaf certificates rotate).
///
/// ## How the socket reaches enough_mail
///
/// enough_mail 2.1.7 verifies certificates with dart:io, and `ImapClient`
/// does accept `onBadCertificate`. But its STARTTLS upgrade
/// (`ClientBase.upgradeToSslSocket`) calls `SecureSocket.secure(socket)` with
/// NO callback, and neither path exposes the peer certificate. So this file
/// opens the TLS socket itself (both modes), inspects the certificate, then
/// hands the finished socket to the client with the public
/// `ClientBase.connect(socket, connectionInformation:)`.
///
/// Two library constraints, proven by the R-0 spike against imap.aol.com on
/// 2026-10-07 and by `imap_certificate_trust_test.dart`:
/// - A command queued before the server greeting fails (the library completes
///   queued tasks with `'reconnect'`, or hits an uninitialized field), so the
///   connector WAITS for the greeting before returning. That is what
///   [GreetingAwareImapClient] exists for.
/// - After STARTTLS the server sends no new greeting, so the connector
///   supplies a fixed one ([startTlsGreeting]) ahead of the TLS stream. It
///   carries no capabilities: capabilities seen before TLS are untrusted
///   (RFC 3501 section 6.2.1), so they are fetched again over TLS.
///
/// ## Platforms (ADR-0042 parity, no exception)
///
/// Shared Dart on Windows and Android. `Socket` / `SecureSocket` are dart:io
/// on both, and the TLS handshake is BoringSSL inside the Dart runtime on
/// both. The behavior assumed identical: `onBadCertificate` runs exactly when
/// the platform trust store rejects the chain or the host name, and
/// `peerCertificate` returns the server's leaf certificate. The trust store
/// itself differs by OS (Windows root store versus Android system CAs), which
/// only changes WHICH servers land in branch 1 versus branch 2 above; the
/// rule is the same.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:enough_mail/enough_mail.dart';
// `ConnectionInfo` is not exported by enough_mail, but `ClientBase.connect`
// (public, documented "mainly useful for testing") requires it to accept a
// pre-built socket. The package is pinned (`^2.1.7`); a breaking change here
// fails compilation and `imap_certificate_trust_test.dart`, not silently.
// ignore: implementation_imports
import 'package:enough_mail/src/private/util/client_base.dart'
    show ConnectionInfo;
import 'package:logger/logger.dart';

import '../../adapters/email_providers/custom_imap_settings.dart';
import '../../adapters/email_providers/spam_filter_platform.dart'
    show UserFacingConnectionException;

/// The account setup form's Save button label. ONE constant, used by the
/// button (`account_setup_screen.dart`) and by the "how to confirm" sentence
/// in [ServerCertificateNotTrustedException], so the instruction always names
/// the control that actually stores trust.
const String kSaveAccountButtonLabel = 'Save Credentials & Continue';

/// Lower-case hex SHA-256 of a certificate's DER encoding (64 characters).
///
/// This is the whole-certificate fingerprint that browsers and
/// `openssl x509 -fingerprint -sha256` show (without the colons), so a user
/// can compare it with what their server administrator gives them.
String certificateSha256(List<int> der) =>
    crypto.sha256.convert(der).toString();

/// True for a well-formed stored fingerprint (64 lower-case hex characters).
bool isCertificateSha256(String? value) => CustomImapSettings.isSha256Hex(value);

/// What the user sees about a server certificate.
class ServerCertificateInfo {
  const ServerCertificateInfo({
    required this.sha256Hex,
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
  });

  factory ServerCertificateInfo.fromCertificate(X509Certificate certificate) =>
      ServerCertificateInfo(
        sha256Hex: certificateSha256(certificate.der),
        subject: certificate.subject,
        issuer: certificate.issuer,
        validFrom: certificate.startValidity,
        validTo: certificate.endValidity,
      );

  /// 64 lower-case hex characters; the value stored per account.
  final String sha256Hex;

  /// Certificate subject, as dart:io formats it (for example `/CN=mail.x`).
  final String subject;

  /// Certificate issuer. Equal to [subject] for a self-signed certificate.
  final String issuer;

  final DateTime validFrom;
  final DateTime validTo;

  /// `AB:CD:...` (32 pairs), the form certificate viewers display.
  String get displayFingerprint {
    final upper = sha256Hex.toUpperCase();
    final pairs = <String>[
      for (var i = 0; i < upper.length; i += 2) upper.substring(i, i + 2),
    ];
    return pairs.join(':');
  }

  /// First 8 characters, the only part ever written to a log.
  String get shortFingerprint => sha256Hex.substring(0, 8);

  /// True when the certificate signed itself.
  bool get isSelfSigned => subject == issuer;
}

/// Why a certificate was not accepted.
enum CertificateTrustProblem {
  /// The device does not trust it and the user has not accepted it.
  notTrusted,

  /// The user (or the device) trusted a DIFFERENT certificate for this
  /// account before; the server now presents this one.
  changed,
}

/// A Custom IMAP server presented a certificate that is neither trusted by
/// the device nor the one the user accepted. The TLS handshake was aborted;
/// no IMAP command, and so no password, was sent.
///
/// A [UserFacingConnectionException], so every existing path shows
/// [userMessage] unchanged: `GenericIMAPAdapter.loadCredentials` rethrows it,
/// `ErrorMessages.humanize` returns [userMessage], and a background scan
/// records it as the scan's failure reason (no dialog is possible there).
/// The setup form catches this exact type and shows the trust dialog instead.
class ServerCertificateNotTrustedException
    extends UserFacingConnectionException {
  ServerCertificateNotTrustedException({
    required this.host,
    required this.port,
    required this.certificate,
    required this.problem,
    Object? originalError,
  }) : super(
          'Server certificate ${problem == CertificateTrustProblem.changed ? "changed" : "not trusted"} '
              'for $host:$port (sha256 ${certificate.shortFingerprint}...)',
          problem == CertificateTrustProblem.changed
              ? changedMessage
              : notTrustedMessage,
          originalError,
        );

  final String host;
  final int port;
  final ServerCertificateInfo certificate;
  final CertificateTrustProblem problem;

  /// Where the user confirms a server. Only SAVE stores trust: the form's
  /// Save checks the certificate, asks "Trust this server?", and stores the
  /// fingerprint with the account (`account_setup_screen.dart`
  /// `_checkCertificateBeforeSave`); saving the same email address again
  /// replaces the stored settings. Test Connection does NOT store it: the
  /// form has no account id yet, so the adapter's recorder returns early
  /// (`generic_imap_adapter.dart` `_rememberDeviceTrustedCertificate`) and a
  /// "Trust" there only sets form state (Sprint 77 Phase 5.1.2 F-PRECHECK:
  /// this text used to say "choose Test Connection"). The button name is
  /// [kSaveAccountButtonLabel], the same constant the button shows.
  static const String _howToConfirm =
      'To review it, open Accounts, choose Add Account, pick Custom IMAP '
      'Server, enter this account again and choose '
      '"$kSaveAccountButtonLabel"; the app then asks whether to trust the '
      'server.';

  /// Named reason for a changed certificate (Sprint 77 Q4 wording).
  static const String changedMessage =
      'Server certificate changed -- open the app and confirm the server. '
      'The app did not send your password. $_howToConfirm';

  /// Named reason for a certificate nobody has accepted yet.
  static const String notTrustedMessage =
      'Server certificate not trusted -- open the app and confirm the server. '
      'The app did not send your password. $_howToConfirm';
}

/// An `ImapClient` whose greeting can be awaited.
///
/// `ClientBase.connect(socket, ...)` returns nothing to await, and a command
/// sent before the greeting fails. This completes [greetingReceived] after the
/// library has processed the greeting, or with an error if the connection
/// drops first.
class GreetingAwareImapClient extends ImapClient {
  GreetingAwareImapClient() : super(isLogEnabled: false);

  final Completer<void> _greeting = Completer<void>();

  /// Completes once the server greeting has been processed.
  Future<void> get greetingReceived => _greeting.future;

  @override
  FutureOr<void> onConnectionEstablished(
    ConnectionInfo connectionInfo,
    String serverGreeting,
  ) async {
    await super.onConnectionEstablished(connectionInfo, serverGreeting);
    if (!_greeting.isCompleted) _greeting.complete();
  }

  @override
  void onConnectionError(dynamic error) {
    super.onConnectionError(error);
    if (!_greeting.isCompleted) {
      _greeting.completeError(
          const SocketException('IMAP connection closed before the greeting'));
    }
  }
}

/// The result of [ImapTlsConnector.connect]: a client ready for LOGIN.
class ImapTlsConnection {
  const ImapTlsConnection({
    required this.client,
    required this.certificate,
    required this.platformTrusted,
  });

  final ImapClient client;

  /// The certificate the server presented.
  final ServerCertificateInfo certificate;

  /// True when the device trust store accepted the certificate; false when
  /// it was accepted only because it matches the stored fingerprint.
  final bool platformTrusted;
}

/// Decides, inside the synchronous `onBadCertificate` callback, whether an
/// untrusted certificate is the one the user accepted.
class _TrustDecision {
  _TrustDecision(this.trustedFingerprint);

  final String? trustedFingerprint;
  X509Certificate? rejected;
  bool acceptedByFingerprint = false;

  bool onBadCertificate(X509Certificate certificate) {
    final presented = certificateSha256(certificate.der);
    if (isCertificateSha256(trustedFingerprint) &&
        presented == trustedFingerprint) {
      acceptedByFingerprint = true;
      return true;
    }
    rejected = certificate;
    return false;
  }

  /// The named failure for a handshake this decision aborted, or null when
  /// the handshake failed for some other reason (protocol, network).
  ServerCertificateNotTrustedException? failure(
      String host, int port, Object error) {
    final cert = rejected;
    if (cert == null) return null;
    return ServerCertificateNotTrustedException(
      host: host,
      port: port,
      certificate: ServerCertificateInfo.fromCertificate(cert),
      problem: isCertificateSha256(trustedFingerprint)
          ? CertificateTrustProblem.changed
          : CertificateTrustProblem.notTrusted,
      originalError: error,
    );
  }
}

/// Opens the TLS connection to a Custom IMAP server and applies the trust
/// rule in the library dartdoc. The ONLY socket opener for platform 'imap'.
class ImapTlsConnector {
  static final Logger _logger = Logger();

  /// Greeting supplied after STARTTLS (the server sends none). Deliberately
  /// without capabilities; see the library dartdoc.
  static const String startTlsGreeting = '* OK TLS established\r\n';

  /// Tag used for the STARTTLS command this connector sends itself.
  static const String _startTlsTag = 'S1';

  /// Most bytes the pre-TLS reader holds at once. A greeting and a STARTTLS
  /// reply are well under 1 KB; a server that sends more without a line end
  /// is refused instead of growing memory without limit (F-PRECHECK).
  static const int maxPreTlsBufferedBytes = 16 * 1024;

  /// Most untagged lines accepted before the tagged STARTTLS reply.
  static const int maxPreTlsUntaggedLines = 50;

  /// Connect, verify the certificate, and return a client whose greeting has
  /// been processed. Sends NO credential. Throws:
  /// - [ServerCertificateNotTrustedException] for an untrusted certificate
  ///   that is not the stored one;
  /// - [UserFacingConnectionException] when the server refuses STARTTLS or
  ///   breaks the IMAP exchange before TLS;
  /// - `SocketException` / `TimeoutException` / `HandshakeException` for
  ///   network and protocol failures (the adapter maps these).
  static Future<ImapTlsConnection> connect({
    required String host,
    required int port,
    required ImapEncryption encryption,
    String? trustedFingerprint,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final decision = _TrustDecision(trustedFingerprint);
    final SecureSocket secure;
    try {
      secure = encryption == ImapEncryption.sslTls
          ? await SecureSocket.connect(host, port,
                  onBadCertificate: decision.onBadCertificate)
              .timeout(timeout)
          : await _startTls(host, port, decision, timeout);
    } on HandshakeException catch (e) {
      final named = decision.failure(host, port, e);
      if (named != null) {
        _logger.w('[IMAP] Certificate for $host:$port not accepted '
            '(${named.problem.name}, sha256 '
            '${named.certificate.shortFingerprint}...); password not sent');
        throw named;
      }
      rethrow;
    }

    final peer = secure.peerCertificate;
    if (peer == null) {
      secure.destroy();
      throw HandshakeException('Server presented no certificate');
    }
    final info = ServerCertificateInfo.fromCertificate(peer);

    final client = GreetingAwareImapClient();
    final Socket socket = encryption == ImapEncryption.startTls
        ? PrefixedSocket(secure, utf8.encode(startTlsGreeting))
        : secure;
    client.connect(socket,
        connectionInformation: ConnectionInfo(host, port, isSecure: true));
    try {
      await client.greetingReceived.timeout(timeout);
      if (encryption == ImapEncryption.startTls) {
        // RFC 3501 6.2.1: discard pre-TLS capabilities, ask again over TLS.
        await client.capability();
      }
    } catch (_) {
      try {
        await client.disconnect();
      } catch (_) {
        // Abandoning the socket; the original error is what matters.
      }
      rethrow;
    }

    return ImapTlsConnection(
      client: client,
      certificate: info,
      platformTrusted: !decision.acceptedByFingerprint,
    );
  }

  /// Plain connect, the STARTTLS exchange, then the TLS handshake with the
  /// trust callback. Refuses (and sends nothing further) unless the server
  /// greets with `* OK` and answers STARTTLS with a tagged OK, and refuses if
  /// the server sent ANY byte after that OK and before the handshake (a
  /// plaintext injection that would otherwise be read as if it came over TLS).
  static Future<SecureSocket> _startTls(
    String host,
    int port,
    _TrustDecision decision,
    Duration timeout,
  ) async {
    final plain = await Socket.connect(host, port).timeout(timeout);
    final reader = _LineReader(plain);
    try {
      final greeting = await reader.nextLine().timeout(timeout);
      if (!greeting.toUpperCase().startsWith('* OK')) {
        throw _refused('the server greeting was "${_clip(greeting)}"');
      }
      plain.write('$_startTlsTag STARTTLS\r\n');
      await plain.flush();
      var untagged = 0;
      while (true) {
        final line = await reader.nextLine().timeout(timeout);
        if (line.startsWith('* ')) {
          // Untagged data, ignored -- but bounded, so a server that never
          // sends the tagged reply cannot keep the connection open forever
          // (each line resets only the per-line timeout).
          if (++untagged > maxPreTlsUntaggedLines) {
            throw _refused('the server sent more than '
                '$maxPreTlsUntaggedLines lines before answering STARTTLS');
          }
          continue;
        }
        if (line.toUpperCase().startsWith('$_startTlsTag OK')) break;
        throw _refused('the server answered "${_clip(line)}"');
      }
      if (reader.hasBufferedData) {
        throw _refused('the server sent data before the TLS handshake');
      }
    } catch (e) {
      await reader.cancel();
      plain.destroy();
      if (e is TimeoutException || e is SocketException) {
        throw _refused('$e');
      }
      rethrow;
    }

    // Same order as enough_mail's own upgrade: pause, secure, cancel.
    reader.pause();
    try {
      return await SecureSocket.secure(
        plain,
        host: host,
        onBadCertificate: decision.onBadCertificate,
      ).timeout(timeout);
    } finally {
      await reader.cancel();
    }
  }

  static String _clip(String s) => s.length > 80 ? '${s.substring(0, 80)}...' : s;

  static UserFacingConnectionException _refused(String detail) =>
      UserFacingConnectionException(
        'STARTTLS upgrade failed: $detail',
        'The server did not accept a secure (STARTTLS) connection, so the '
        'app did not send your password. Check the encryption setting or '
        'use SSL/TLS.',
      );
}

/// Reads CRLF-terminated lines from a plain socket before STARTTLS.
///
/// Bounded: once more than [ImapTlsConnector.maxPreTlsBufferedBytes] are
/// held (one over-long line, or a flood), the reader fails with a STARTTLS
/// refusal, stops reading, and drops what it held.
class _LineReader {
  _LineReader(Socket socket) {
    _subscription = socket.listen(
      (data) {
        if (_error != null) return;
        _buffer.addAll(data);
        _drain();
        if (_buffer.length > ImapTlsConnector.maxPreTlsBufferedBytes) {
          _buffer.clear();
          _subscription.pause();
          _fail(ImapTlsConnector._refused('the server sent more than '
              '${ImapTlsConnector.maxPreTlsBufferedBytes} bytes without a '
              'line end before TLS'));
        }
      },
      onError: (Object e) => _fail(e),
      onDone: () => _fail(const SocketException('connection closed')),
    );
  }

  late final StreamSubscription<Uint8List> _subscription;
  final List<int> _buffer = <int>[];
  Completer<String>? _waiting;
  Object? _error;

  bool get hasBufferedData => _buffer.isNotEmpty;

  Future<String> nextLine() {
    final completer = Completer<String>();
    _waiting = completer;
    if (_error != null) {
      completer.completeError(_error!);
    } else {
      _drain();
    }
    return completer.future;
  }

  void _drain() {
    final waiting = _waiting;
    if (waiting == null || waiting.isCompleted) return;
    for (var i = 0; i + 1 < _buffer.length; i++) {
      if (_buffer[i] == 13 && _buffer[i + 1] == 10) {
        final line = latin1.decode(_buffer.sublist(0, i));
        _buffer.removeRange(0, i + 2);
        _waiting = null;
        waiting.complete(line);
        return;
      }
    }
  }

  void _fail(Object error) {
    _error = error;
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) {
      _waiting = null;
      waiting.completeError(error);
    }
  }

  void pause() => _subscription.pause();

  Future<void> cancel() async {
    try {
      await _subscription.cancel();
    } catch (_) {
      // Already cancelled or closed.
    }
  }
}

/// A [Socket] that delivers [prefix] before the bytes of [inner].
///
/// Used once: to hand enough_mail the greeting it waits for after STARTTLS.
/// Writes, options and lifecycle all go straight to [inner].
class PrefixedSocket extends StreamView<Uint8List> implements Socket {
  PrefixedSocket(this.inner, List<int> prefix)
      : super(_prefixed(Uint8List.fromList(prefix), inner));

  final Socket inner;

  static Stream<Uint8List> _prefixed(Uint8List first, Stream<Uint8List> rest) async* {
    yield first;
    yield* rest;
  }

  @override
  Encoding get encoding => inner.encoding;

  @override
  set encoding(Encoding value) => inner.encoding = value;

  @override
  void add(List<int> data) => inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => inner.addStream(stream);

  @override
  Future<void> flush() => inner.flush();

  @override
  Future<void> close() => inner.close();

  @override
  Future<void> get done => inner.done;

  @override
  void write(Object? object) => inner.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => inner.writeln(object);

  @override
  InternetAddress get address => inner.address;

  @override
  InternetAddress get remoteAddress => inner.remoteAddress;

  @override
  int get port => inner.port;

  @override
  int get remotePort => inner.remotePort;

  @override
  bool setOption(SocketOption option, bool enabled) =>
      inner.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) => inner.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => inner.setRawOption(option);

  @override
  void destroy() => inner.destroy();
}
