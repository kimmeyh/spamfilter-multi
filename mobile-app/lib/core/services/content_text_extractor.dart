/// R76-4 (Sprint 78, ADR-0047): plain text from an email body. First written
/// for the dev-only content history; since Sprint 83 7.7.1 (Harold Q1 = 1) it
/// is also the text body rules match against, so a Block Body rule made from
/// the pop-up matches the text the pop-up read.
///
/// Pure functions, so both adapters share ONE copy and tests need no network:
/// - [selectBodyText]: the one rule for which part is "the text": text/plain
///   when it has content, else the HTML part converted with [htmlToText].
/// - [htmlToText]: a readable text version of an HTML-only body.
/// - [gmailPartText]: walks a Gmail payload's NESTED multipart tree.
/// - [capContentText]: the 64 KB cap (ADR-0047 item 5), cut on a character
///   boundary.
library;

import 'dart:convert';

import 'package:googleapis/gmail/v1.dart' as gmail;

/// ADR-0047 item 5: a stored body is capped at 64 KB of UTF-8.
const int kContentHistoryMaxBodyBytes = 64 * 1024;

/// A readable text version of [html]: script/style/head removed, line breaks
/// at block elements, tags dropped, the common entities decoded, runs of blank
/// lines collapsed. Not a full HTML renderer.
///
/// A link keeps its web address: `<a href="https://x.example/p">Click</a>`
/// becomes `Click (https://x.example/p)`; when the link text already contains
/// the address it is not repeated. Sprint 83 7.7.1 improvement review (Harold
/// Q5 = 1): this text is what body rules match (see [selectBodyText]); before
/// Q1 a Gmail HTML-only message gave rules the raw HTML, so a rule on a domain
/// that appears only in an href matched it. Dropping the address here would
/// silently stop that rule. Only http(s) and www addresses are kept; mailto,
/// `#` anchors and javascript are dropped as before.
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(
      RegExp(r'<(script|style|head)\b[^>]*>.*?</\1\s*>',
          caseSensitive: false, dotAll: true),
      ' ');
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  s = s.replaceAllMapped(_anchorPattern, (m) {
    final url = (m.group(2) ?? '').trim();
    final inner = m.group(3) ?? '';
    final isWeb = RegExp(r'^(https?://|www\.)', caseSensitive: false)
        .hasMatch(url);
    if (!isWeb || inner.contains(url)) return ' $inner ';
    return ' $inner ($url) ';
  });
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

/// An `<a ... href="URL" ...>TEXT</a>` element: group 2 is URL, group 3 is
/// TEXT (which may still hold tags; they are removed after).
final RegExp _anchorPattern = RegExp(
    r'''<a\b[^>]*?\bhref\s*=\s*(["'])(.*?)\1[^>]*>(.*?)</a\s*>''',
    caseSensitive: false,
    dotAll: true);

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
/// F185 (Sprint 63) contract: input that is not base64url comes back as the
/// raw string (never throws, so one bad part cannot drop a message from a
/// scan); malformed UTF-8 is replaced. Sprint 83 7.7.1: the ONE Gmail decoder
/// (`GmailApiAdapter.decodeGmailBodyData` calls it).
String decodeGmailData(String data) {
  try {
    return utf8.decode(base64Url.decode(base64Url.normalize(data)),
        allowMalformed: true);
  } catch (_) {
    return data;
  }
}

/// The text of a Gmail payload: the first text/plain part anywhere in the
/// (nested) multipart tree; else the first text/html part, converted with
/// [htmlToText]; else null. Attachments (parts with a filename) are skipped.
String? gmailPartText(gmail.MessagePart? part) {
  if (part == null) return null;
  String? find(gmail.MessagePart p, String mime) {
    final isAttachment = (p.filename ?? '').isNotEmpty;
    if (!isAttachment && p.mimeType == mime && p.body?.data != null) {
      return decodeGmailData(p.body!.data!);
    }
    for (final child in p.parts ?? const <gmail.MessagePart>[]) {
      final found = find(child, mime);
      if (found != null) return found;
    }
    return null;
  }

  return selectBodyText(
      plain: find(part, 'text/plain'), html: find(part, 'text/html'));
}

/// The text of a message from its decoded parts: [plain] when it has content;
/// else [html] converted with [htmlToText]; else [plain] (null or blank).
/// Sprint 83 7.7.1 (Harold Q1 = 1): the ONE selection used by the pop-up read
/// (`fetchContentText`) and the rule path (IMAP `_convertMimeMessage`, Gmail
/// `_convertGmailMessage` via [gmailPartText]), so the two cannot differ.
String? selectBodyText({String? plain, String? html}) {
  if (plain != null && plain.trim().isNotEmpty) return plain;
  if (html != null) return htmlToText(html);
  return plain;
}
