/// R76-4 (Sprint 78, ADR-0047): plain text from an email body, for the
/// dev-only content history.
///
/// Pure functions, so both adapters share ONE copy and tests need no network:
/// - [htmlToText]: a readable text version of an HTML-only body (the IMAP and
///   Gmail rule paths keep text/plain only and drop HTML-only bodies, which is
///   NOT changed -- rule matching is out of scope for R76-4).
/// - [gmailPartText]: walks a Gmail payload's NESTED multipart tree (the rule
///   path looks one level deep only).
/// - [capContentText]: the 64 KB cap (ADR-0047 item 5), cut on a character
///   boundary.
library;

import 'dart:convert';

import 'package:googleapis/gmail/v1.dart' as gmail;

/// ADR-0047 item 5: a stored body is capped at 64 KB of UTF-8.
const int kContentHistoryMaxBodyBytes = 64 * 1024;

/// A readable text version of [html]: script/style/head removed, line breaks
/// at block elements, tags dropped, the common entities decoded, runs of blank
/// lines collapsed. Not a full HTML renderer -- enough for a training corpus.
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(
      RegExp(r'<(script|style|head)\b[^>]*>.*?</\1\s*>',
          caseSensitive: false, dotAll: true),
      ' ');
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(
      RegExp(r'</(p|div|li|tr|h[1-6]|table|ul|ol|blockquote)\s*>',
          caseSensitive: false),
      '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = _decodeEntities(s);
  final lines = s
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .toList();
  final out = <String>[];
  for (final line in lines) {
    if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(line);
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

String _decodeEntities(String s) {
  const named = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };
  var out = s;
  named.forEach((k, v) => out = out.replaceAll(k, v));
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m[1]!);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m[1]!, radix: 16);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  return out;
}

/// [text] cut to at most [maxBytes] bytes of UTF-8 on a character boundary.
/// Returns the text and whether it was cut.
({String text, bool truncated}) capContentText(String text,
    {int maxBytes = kContentHistoryMaxBodyBytes}) {
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return (text: text, truncated: false);
  var end = maxBytes;
  // Step back off a UTF-8 continuation byte (10xxxxxx).
  while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
    end--;
  }
  return (
    text: utf8.decode(bytes.sublist(0, end), allowMalformed: true),
    truncated: true,
  );
}

/// Gmail body data is base64url; decoded leniently (padding optional).
String _decodeGmailData(String data) {
  var normalized = data.replaceAll('-', '+').replaceAll('_', '/');
  final pad = normalized.length % 4;
  if (pad != 0) normalized = normalized.padRight(normalized.length + 4 - pad, '=');
  return utf8.decode(base64.decode(normalized), allowMalformed: true);
}

/// The text of a Gmail payload: the first text/plain part anywhere in the
/// (nested) multipart tree; else the first text/html part, converted with
/// [htmlToText]; else null. Attachments (parts with a filename) are skipped.
String? gmailPartText(gmail.MessagePart? part) {
  if (part == null) return null;
  String? find(gmail.MessagePart p, String mime) {
    final isAttachment = (p.filename ?? '').isNotEmpty;
    if (!isAttachment && p.mimeType == mime && p.body?.data != null) {
      return _decodeGmailData(p.body!.data!);
    }
    for (final child in p.parts ?? const <gmail.MessagePart>[]) {
      final found = find(child, mime);
      if (found != null) return found;
    }
    return null;
  }

  final plain = find(part, 'text/plain');
  if (plain != null && plain.trim().isNotEmpty) return plain;
  final html = find(part, 'text/html');
  if (html != null) return htmlToText(html);
  return plain;
}
