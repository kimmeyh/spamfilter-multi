/// F192 (Sprint 77): [CustomImapSettings] parsing and the closed encryption set.
///
/// The security property: encryption has NO plaintext member, and a missing or
/// unrecognized stored value parses to null instead of a default, so a corrupt
/// setting can never become a cleartext login.
///
/// What this does NOT catch: whether the adapter treats null as "stop" (the
/// adapter test with real sockets covers that), or whether the store persists
/// the keys (secure_credentials_store_custom_imap_test.dart).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/custom_imap_settings.dart';

void main() {
  group('ImapEncryption', () {
    test('offers exactly SSL/TLS and STARTTLS -- no plaintext member', () {
      expect(ImapEncryption.values, [ImapEncryption.sslTls, ImapEncryption.startTls]);
      expect(ImapEncryption.values.map((m) => m.wireValue),
          ['sslTls', 'startTls']);
    });

    test('default ports are 993 and 143', () {
      expect(ImapEncryption.sslTls.defaultPort, 993);
      expect(ImapEncryption.startTls.defaultPort, 143);
    });

    test('fromWireValue returns null, never a default, for anything unknown',
        () {
      for (final bad in [null, '', 'none', 'plain', 'false', 'SSLTLS', ' sslTls']) {
        expect(ImapEncryption.fromWireValue(bad), isNull, reason: '"$bad"');
      }
      expect(ImapEncryption.fromWireValue('sslTls'), ImapEncryption.sslTls);
      expect(ImapEncryption.fromWireValue('startTls'), ImapEncryption.startTls);
    });
  });

  group('CustomImapSettings params', () {
    test('round trip keeps every field', () {
      const settings = CustomImapSettings(
        host: 'imap.example.com',
        port: 143,
        encryption: ImapEncryption.startTls,
        username: 'me',
      );
      final back = CustomImapSettings.tryFromParams(settings.toParams())!;
      expect(back.host, 'imap.example.com');
      expect(back.port, 143);
      expect(back.encryption, ImapEncryption.startTls);
      expect(back.username, 'me');
    });

    test('paramKeys lists exactly the five keys toParams can write '
        '(the certificate key only once a certificate is trusted)', () {
      const settings = CustomImapSettings(
          host: 'h.example.com', port: 993, encryption: ImapEncryption.sslTls);
      expect(settings.toParams().keys.toSet(),
          CustomImapSettings.paramKeys.toSet()
            ..remove(CustomImapSettings.keyTrustedCertSha256));
      final trusted = settings.withTrustedCertificate('a' * 64);
      expect(trusted.toParams().keys.toSet(),
          CustomImapSettings.paramKeys.toSet());
      expect(CustomImapSettings.paramKeys.length, 5);
    });

    test('SEC-8b: the trusted fingerprint round-trips; a malformed one reads '
        'as NO trust, never as a setting that skips the check', () {
      final good = 'ab' * 32;
      final back = CustomImapSettings.tryFromParams(const CustomImapSettings(
              host: 'h', port: 993, encryption: ImapEncryption.sslTls)
          .withTrustedCertificate(good)
          .toParams())!;
      expect(back.trustedCertificateSha256, good);
      for (final bad in ['', 'AB' * 32, 'ab' * 31, 'zz' * 32, '${'ab' * 32} ']) {
        final params = <String, String>{
          CustomImapSettings.keyHost: 'h',
          CustomImapSettings.keyPort: '993',
          CustomImapSettings.keyEncryption: 'sslTls',
          CustomImapSettings.keyTrustedCertSha256: bad,
        };
        final parsed = CustomImapSettings.tryFromParams(params);
        expect(parsed, isNotNull, reason: 'a bad fingerprint is not a bad server');
        expect(parsed!.trustedCertificateSha256, isNull, reason: '"$bad"');
      }
    });

    test('null, empty, blank host, bad port or bad encryption parse to null',
        () {
      Map<String, String> ok() => {
            CustomImapSettings.keyHost: 'imap.example.com',
            CustomImapSettings.keyPort: '993',
            CustomImapSettings.keyEncryption: 'sslTls',
            CustomImapSettings.keyUsername: '',
          };
      expect(CustomImapSettings.tryFromParams(ok()), isNotNull);
      expect(CustomImapSettings.tryFromParams(null), isNull);
      expect(CustomImapSettings.tryFromParams({}), isNull);
      for (final entry in {
        CustomImapSettings.keyHost: '   ',
        CustomImapSettings.keyPort: '0',
        CustomImapSettings.keyEncryption: 'none',
      }.entries) {
        final params = ok()..[entry.key] = entry.value;
        expect(CustomImapSettings.tryFromParams(params), isNull,
            reason: '${entry.key}=${entry.value}');
      }
      for (final missing in CustomImapSettings.paramKeys.where((k) =>
          k != CustomImapSettings.keyUsername &&
          k != CustomImapSettings.keyTrustedCertSha256)) {
        final params = ok()..remove(missing);
        expect(CustomImapSettings.tryFromParams(params), isNull,
            reason: 'missing $missing');
      }
    });

    test('port bounds: 1 and 65535 pass, 0 and 65536 fail', () {
      Map<String, String> withPort(String p) => {
            CustomImapSettings.keyHost: 'h.example.com',
            CustomImapSettings.keyPort: p,
            CustomImapSettings.keyEncryption: 'sslTls',
          };
      expect(CustomImapSettings.tryFromParams(withPort('1')), isNotNull);
      expect(CustomImapSettings.tryFromParams(withPort('65535')), isNotNull);
      expect(CustomImapSettings.tryFromParams(withPort('0')), isNull);
      expect(CustomImapSettings.tryFromParams(withPort('65536')), isNull);
    });

    test('loginName falls back to the email when the username is blank', () {
      const named = CustomImapSettings(
          host: 'h', port: 993, encryption: ImapEncryption.sslTls, username: 'u');
      const blank = CustomImapSettings(
          host: 'h', port: 993, encryption: ImapEncryption.sslTls, username: '  ');
      expect(named.loginName('a@b.test'), 'u');
      expect(blank.loginName('a@b.test'), 'a@b.test');
    });
  });
}
