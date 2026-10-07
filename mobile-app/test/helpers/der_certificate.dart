/// Minimal X.509 DER reader for TESTS (SEC-8b, Sprint 77).
///
/// Reads only what the pinning tests compare: the raw encoded issuer name,
/// subject name and SubjectPublicKeyInfo of a certificate. It does NOT verify
/// signatures; a test that needs "this chain validates" uses a real TLS
/// handshake instead.
library;

import 'dart:convert';
import 'dart:typed_data';

class DerCertificate {
  DerCertificate._(this.der, this.issuer, this.subject, this.spki);

  final Uint8List der;

  /// Full TLV bytes of the issuer Name.
  final Uint8List issuer;

  /// Full TLV bytes of the subject Name.
  final Uint8List subject;

  /// Full TLV bytes of SubjectPublicKeyInfo.
  final Uint8List spki;

  static DerCertificate parse(Uint8List der) {
    final cert = _Tlv.read(der, 0);
    final tbs = _Tlv.read(der, cert.contentStart);
    var offset = tbs.contentStart;
    var field = _Tlv.read(der, offset);
    if (field.tag == 0xA0) {
      // explicit [0] version
      offset = field.end;
      field = _Tlv.read(der, offset);
    }
    // serialNumber, signature, issuer, validity, subject, subjectPublicKeyInfo
    final fields = <_Tlv>[];
    for (var i = 0; i < 6; i++) {
      field = _Tlv.read(der, offset);
      fields.add(field);
      offset = field.end;
    }
    Uint8List bytes(_Tlv t) => Uint8List.sublistView(der, t.start, t.end);
    return DerCertificate._(der, bytes(fields[2]), bytes(fields[4]), bytes(fields[5]));
  }

  /// Every certificate in a PEM bundle, in order.
  static List<DerCertificate> parsePemBundle(String pem) {
    final matches = RegExp(
            r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----')
        .allMatches(pem);
    return [
      for (final m in matches)
        parse(base64.decode(m.group(1)!.replaceAll(RegExp(r'\s'), ''))),
    ];
  }
}

class _Tlv {
  _Tlv(this.tag, this.start, this.contentStart, this.end);

  final int tag;
  final int start;
  final int contentStart;
  final int end;

  static _Tlv read(Uint8List b, int start) {
    final tag = b[start];
    var i = start + 1;
    var length = b[i++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      length = 0;
      for (var k = 0; k < count; k++) {
        length = (length << 8) | b[i++];
      }
    }
    return _Tlv(tag, start, i, i + length);
  }
}
