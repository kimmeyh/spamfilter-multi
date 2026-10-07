/// Per-account server settings for the Custom IMAP provider (F192, Sprint 77).
///
/// ONE place defines how a custom server is described, so the form, the secure
/// store and the adapter cannot disagree about a key name or a value:
///
/// - the form builds [CustomImapSettings] and calls [toParams];
/// - `SecureCredentialsStore` persists exactly [paramKeys] as side keys and
///   returns them in `Credentials.additionalParams` (no call-site edits: every
///   reconnect path already loads credentials from the store);
/// - `GenericIMAPAdapter` reads them back with [tryFromParams].
///
/// Encryption is a closed set with NO plaintext member (Sprint 77 Q3). A value
/// that is missing or unrecognized parses to `null`, never to a default, so a
/// corrupted or hand-edited setting can never turn into a cleartext login.
library;

/// How the connection to a custom server is protected.
///
/// There is deliberately no "none". Adding one would reopen the cleartext
/// LOGIN path that Sprint 77 closed.
enum ImapEncryption {
  /// TLS from the first byte (implicit TLS, conventionally port 993).
  sslTls('sslTls', 993, 'SSL/TLS'),

  /// Plain connect, then the STARTTLS command upgrades the connection before
  /// any credential is sent (conventionally port 143).
  startTls('startTls', 143, 'STARTTLS');

  const ImapEncryption(this.wireValue, this.defaultPort, this.label);

  /// Value stored in secure storage. Never change an existing value.
  final String wireValue;

  /// Port the form pre-fills when this mode is chosen.
  final int defaultPort;

  /// Text shown to the user.
  final String label;

  /// Parse a stored value. Returns null for anything unrecognized.
  static ImapEncryption? fromWireValue(String? value) {
    for (final mode in ImapEncryption.values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }
}

/// Validated server settings for one custom IMAP account.
class CustomImapSettings {
  /// Key for the server host in `Credentials.additionalParams`.
  static const String keyHost = 'imapHost';

  /// Key for the server port.
  static const String keyPort = 'imapPort';

  /// Key for the [ImapEncryption.wireValue].
  static const String keyEncryption = 'imapEncryption';

  /// Key for the login name (may differ from the email address).
  static const String keyUsername = 'imapUsername';

  /// SEC-8b (Sprint 77, ADR-0046): SHA-256 (64 lower-case hex characters) of
  /// the server certificate trusted for this account -- one the user accepted
  /// in the "Trust this server?" dialog, or one the device already trusted.
  /// Optional: absent until the first successful certificate check.
  static const String keyTrustedCertSha256 = 'imapTrustedCertSha256';

  /// Every key, in a fixed order. The secure store saves, reads and deletes
  /// exactly this list, so a new key cannot be saved and forgotten on delete.
  static const List<String> paramKeys = <String>[
    keyHost,
    keyPort,
    keyEncryption,
    keyUsername,
    keyTrustedCertSha256,
  ];

  const CustomImapSettings({
    required this.host,
    required this.port,
    required this.encryption,
    this.username = '',
    this.trustedCertificateSha256,
  });

  /// Server host name or address, trimmed.
  final String host;

  /// Server port, 1 to 65535.
  final int port;

  /// Connection protection. Never plaintext.
  final ImapEncryption encryption;

  /// Login name. Empty means "use the email address".
  final String username;

  /// Fingerprint of the trusted server certificate, or null when none is
  /// recorded. Never a default: null means "ask the user" in the foreground
  /// and "fail" in the background (ADR-0046).
  final String? trustedCertificateSha256;

  /// A copy with [trustedCertificateSha256] replaced.
  CustomImapSettings withTrustedCertificate(String? sha256Hex) =>
      CustomImapSettings(
        host: host,
        port: port,
        encryption: encryption,
        username: username,
        trustedCertificateSha256: sha256Hex,
      );

  /// The login name to send, falling back to [email] when none was entered.
  String loginName(String email) => username.trim().isEmpty ? email : username;

  /// Serialize for `Credentials.additionalParams` and secure storage.
  Map<String, String> toParams() => <String, String>{
        keyHost: host,
        keyPort: port.toString(),
        keyEncryption: encryption.wireValue,
        keyUsername: username,
        if (trustedCertificateSha256 != null)
          keyTrustedCertSha256: trustedCertificateSha256!,
      };

  /// Rebuild from stored params.
  ///
  /// Returns null when the host is blank, the port is not 1 to 65535, or the
  /// encryption value is missing or unrecognized. The adapter treats null as
  /// "server not configured" and opens no socket.
  static CustomImapSettings? tryFromParams(Map<String, String>? params) {
    if (params == null) return null;
    final host = (params[keyHost] ?? '').trim();
    if (host.isEmpty) return null;
    final port = int.tryParse((params[keyPort] ?? '').trim());
    if (port == null || port < 1 || port > 65535) return null;
    final encryption = ImapEncryption.fromWireValue(params[keyEncryption]);
    if (encryption == null) return null;
    return CustomImapSettings(
      host: host,
      port: port,
      encryption: encryption,
      username: params[keyUsername] ?? '',
      // A malformed stored fingerprint is treated as NO trust (the user is
      // asked again), never as a reason to skip the check.
      trustedCertificateSha256: isSha256Hex(params[keyTrustedCertSha256])
          ? params[keyTrustedCertSha256]
          : null,
    );
  }

  /// True for 64 lower-case hex characters (a stored SHA-256 fingerprint).
  /// The ONE format check; imap_certificate_trust.dart uses it too.
  static bool isSha256Hex(String? value) =>
      value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}
