/// F185 (Sprint 63): Gmail body data arrives base64url-encoded; the adapter
/// previously assigned it RAW, so body rules evaluated against base64 text
/// and could essentially never match on the Gmail path (pre-existing;
/// surfaced by the Sprint 63 review because F180 routes every Gmail
/// body-rule match through this conversion).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:googleapis/gmail/v1.dart' as gmail;

import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';

void main() {
  group('F185 GmailApiAdapter.decodeGmailBodyData', () {
    test('decodes base64url body text (the body-rule matching contract)', () {
      const plain = 'Limited offer: miracle cure inside! Unsubscribe below.';
      final encoded = base64Url.encode(utf8.encode(plain));
      expect(GmailApiAdapter.decodeGmailBodyData(encoded), plain,
          reason: 'a body rule for "miracle cure" must see the DECODED text');
    });

    test('handles unpadded base64url (Gmail omits padding)', () {
      const plain = 'ab';
      final encoded =
          base64Url.encode(utf8.encode(plain)).replaceAll('=', '');
      expect(GmailApiAdapter.decodeGmailBodyData(encoded), plain);
    });

    test('undecodable input degrades to the raw string, never throws', () {
      const garbage = 'not!!valid@@base64%%';
      expect(GmailApiAdapter.decodeGmailBodyData(garbage), garbage);
    });

    test('malformed UTF-8 inside valid base64 is replaced, not fatal', () {
      final encoded = base64Url.encode([0xC3, 0x28, 0x41]);
      final out = GmailApiAdapter.decodeGmailBodyData(encoded);
      expect(out, contains('A'),
          reason: 'allowMalformed keeps the decodable portion');
    });
  });

  group('F185 conversion call site decodes the body', () {
    test('a converted Gmail message carries DECODED body text', () {
      const plain = 'This message contains a miracle cure phrase.';
      final msg = gmail.Message(
        id: 'm1',
        payload: gmail.MessagePart(
          headers: [
            gmail.MessagePartHeader(name: 'From', value: 'x@ok.com'),
            gmail.MessagePartHeader(name: 'Subject', value: 's'),
          ],
          body: gmail.MessagePartBody(
              data: base64Url.encode(utf8.encode(plain))),
        ),
      );
      final adapter = GmailApiAdapter();
      final converted = adapter.debugConvertGmailMessage(msg, 'INBOX');
      expect(converted, isNotNull);
      expect(converted!.body, plain,
          reason: 'the fetch conversion must hand rule evaluation decoded '
              'text, not base64 (the F185 defect)');
    });
  });
}
