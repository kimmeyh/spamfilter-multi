/// Sprint 83 7.7.1 (Harold Q1 = 1): the rule path's body is the same text the
/// No Rule pop-up reads -- text/plain, else the HTML part as text. Before, the
/// rule path kept text/plain only, so a Block Body rule saved from an
/// HTML-only message (the pop-up read its HTML as text) could never match it.
///
/// These tests go through the adapters' CONVERSION (the code `fetchFullBody`
/// and the scan fetch run), not only through `selectBodyText`, so a call site
/// that goes back to text/plain only fails here (Sprint 73 IMP-3: correct
/// helper, wrong wiring).
///
/// Q5 = 1 (improvement review): an HTML link keeps its address in the text,
/// so a body rule on a domain that appears only in an href still matches a
/// Gmail single-part HTML message (before Q1 those rules saw the raw HTML).
///
/// Would NOT catch: a link address that is not http(s) or www (for example an
/// unquoted href or a relative URL); htmlToText keeps quoted http(s)/www only.
library;

import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/services/content_text_extractor.dart';

String _b64(String s) => base64Url.encode(utf8.encode(s));

void main() {
  group('IMAP rule-path body (_convertMimeMessage)', () {
    MimeMessage parse(String raw) =>
        MimeMessage.parseFromText(raw.replaceAll('\n', '\r\n'));

    test('an HTML-only message has the HTML as text in its body', () {
      final mime = parse('From: promo@shop.example\n'
          'Subject: Sale\n'
          'MIME-Version: 1.0\n'
          'Content-Type: text/html; charset=utf-8\n'
          '\n'
          '<html><body><p>Visit spamlink.example today</p></body></html>\n');
      final msg = GenericIMAPAdapter.custom()
          .debugConvertMimeMessage(mime, 'INBOX');
      expect(msg.body, contains('Visit spamlink.example today'));
      expect(msg.body, isNot(contains('<p>')),
          reason: 'the rule sees the text the pop-up showed, not markup');
    });

    test('a message with a text/plain part keeps the plain part', () {
      final mime = parse('From: a@b.example\n'
          'Subject: Hi\n'
          'MIME-Version: 1.0\n'
          'Content-Type: multipart/alternative; boundary="XX"\n'
          '\n'
          '--XX\n'
          'Content-Type: text/plain; charset=utf-8\n'
          '\n'
          'plain words\n'
          '--XX\n'
          'Content-Type: text/html; charset=utf-8\n'
          '\n'
          '<p>html words</p>\n'
          '--XX--\n');
      final msg = GenericIMAPAdapter.custom()
          .debugConvertMimeMessage(mime, 'INBOX');
      expect(msg.body, contains('plain words'));
      expect(msg.body, isNot(contains('html words')));
    });
  });

  group('htmlToText link addresses (Q5 = 1)', () {
    test('a web link keeps its address after the link text', () {
      expect(htmlToText('<a class="b" HREF=\'http://x.example/p\'>Go <b>now</b></a>'),
          'Go now (http://x.example/p)');
      expect(htmlToText('<a href="www.y.example">Shop</a>'),
          'Shop (www.y.example)');
    });

    test('an address already in the link text is not repeated', () {
      expect(htmlToText('<a href="https://z.example">https://z.example</a>'),
          'https://z.example');
    });

    test('mailto, anchors and javascript links keep only their text', () {
      expect(
          htmlToText('<a href="mailto:a@b.example">Mail</a> '
              '<a href="#top">Top</a> <a href="javascript:void(0)">X</a>'),
          'Mail Top X');
    });
  });

  group('Gmail rule-path body (_convertGmailMessage)', () {
    gmail.MessagePartHeader h(String n, String v) =>
        gmail.MessagePartHeader(name: n, value: v);

    test('an HTML-only nested message has the HTML as text in its body', () {
      final msg = gmail.Message(
        id: 'm1',
        payload: gmail.MessagePart(
          mimeType: 'multipart/mixed',
          headers: [h('From', 'promo@shop.example'), h('Subject', 'Sale')],
          parts: [
            gmail.MessagePart(mimeType: 'multipart/alternative', parts: [
              gmail.MessagePart(
                mimeType: 'text/html',
                body: gmail.MessagePartBody(
                    data: _b64('<p>Visit spamlink.example today</p>')),
              ),
            ]),
          ],
        ),
      );
      final converted = GmailApiAdapter().debugConvertGmailMessage(msg, 'INBOX');
      expect(converted, isNotNull);
      expect(converted!.body, 'Visit spamlink.example today');
    });

    test('a nested text/plain part is used (before: top level only)', () {
      final msg = gmail.Message(
        id: 'm2',
        payload: gmail.MessagePart(
          mimeType: 'multipart/mixed',
          headers: [h('From', 'a@b.example')],
          parts: [
            gmail.MessagePart(mimeType: 'multipart/alternative', parts: [
              gmail.MessagePart(
                  mimeType: 'text/plain',
                  body: gmail.MessagePartBody(data: _b64('nested plain'))),
              gmail.MessagePart(
                  mimeType: 'text/html',
                  body: gmail.MessagePartBody(data: _b64('<p>html</p>'))),
            ]),
          ],
        ),
      );
      final converted = GmailApiAdapter().debugConvertGmailMessage(msg, 'INBOX');
      expect(converted!.body, 'nested plain');
    });

    test('a single-part HTML message keeps an href-only link address', () {
      // Q5 = 1: before Q1 this shape gave rules the raw HTML, so a body rule
      // on spam-only-in-href.example matched it. It must still match.
      final msg = gmail.Message(
        id: 'm4',
        payload: gmail.MessagePart(
          mimeType: 'text/html',
          headers: [h('From', 'promo@shop.example')],
          body: gmail.MessagePartBody(
              data: _b64('<p><a href="https://spam-only-in-href.example/x?a=1'
                  '&amp;b=2">Click here</a></p>')),
        ),
      );
      final converted = GmailApiAdapter().debugConvertGmailMessage(msg, 'INBOX');
      expect(converted!.body,
          'Click here (https://spam-only-in-href.example/x?a=1&b=2)');
      expect(RegExp(r'spam-only-in-href\.example').hasMatch(converted.body),
          isTrue,
          reason: 'a body rule on the href-only domain still matches');
    });

    test('a metadata-only message has an empty body', () {
      final msg = gmail.Message(
        id: 'm3',
        payload: gmail.MessagePart(
            mimeType: 'text/html', headers: [h('From', 'a@b.example')]),
      );
      final converted = GmailApiAdapter().debugConvertGmailMessage(msg, 'INBOX');
      expect(converted!.body, '');
    });
  });
}
