/// Sprint 38 F88 (Issue #255): tests for the multipart/mixed response
/// parser helpers in GmailApiAdapter.
///
/// The batchGet HTTP call itself requires a real Gmail account, so
/// orchestration is verified in Phase 5.3 manual testing. The parser
/// helpers (boundary extraction, multipart splitting, JSON extraction
/// from each sub-response) are pure-Dart and can be tested directly
/// against the documented Google batch response shape.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';

void main() {
  group('Sprint 38 F88 -- batchGet multipart parser', () {
    group('extractBoundary', () {
      test('extracts unquoted boundary', () {
        expect(
          GmailApiAdapter.extractBoundaryForTesting(
              'multipart/mixed; boundary=batch_xxx'),
          'batch_xxx',
        );
      });

      test('extracts quoted boundary', () {
        expect(
          GmailApiAdapter.extractBoundaryForTesting(
              'multipart/mixed; boundary="batch_xxx"'),
          'batch_xxx',
        );
      });

      test('returns null when no boundary parameter', () {
        expect(
          GmailApiAdapter.extractBoundaryForTesting('multipart/mixed'),
          isNull,
        );
        expect(
          GmailApiAdapter.extractBoundaryForTesting('application/json'),
          isNull,
        );
        expect(GmailApiAdapter.extractBoundaryForTesting(''), isNull);
      });

      test('handles boundary at end without trailing semicolon', () {
        expect(
          GmailApiAdapter.extractBoundaryForTesting(
              'multipart/mixed; charset=utf-8; boundary=foo_123'),
          'foo_123',
        );
      });
    });

    group('parseMultipartMixed', () {
      test('returns empty list for body containing only the closing marker',
          () {
        final parts = GmailApiAdapter.parseMultipartMixedForTesting(
            '--b--\r\n', 'b');
        expect(parts, isEmpty);
      });

      test('splits two sub-responses', () {
        // Construct a minimal multipart body with two sub-responses.
        final body = StringBuffer()
          ..write('--b\r\n')
          ..write('Content-Type: application/http\r\n')
          ..write('Content-ID: <response-item-0>\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n')
          ..write('\r\n')
          ..write('{"id":"msg-1"}\r\n')
          ..write('--b\r\n')
          ..write('Content-Type: application/http\r\n')
          ..write('Content-ID: <response-item-1>\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n')
          ..write('\r\n')
          ..write('{"id":"msg-2"}\r\n')
          ..write('--b--\r\n');

        final parts = GmailApiAdapter.parseMultipartMixedForTesting(
            body.toString(), 'b');
        expect(parts.length, 2);
        expect(parts[0], contains('msg-1'));
        expect(parts[1], contains('msg-2'));
      });

      test('handles preamble (leading whitespace before first boundary)', () {
        final body = StringBuffer()
          ..write('preamble line\r\n')
          ..write('--b\r\n')
          ..write('Content-Type: application/http\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('\r\n')
          ..write('{"id":"only"}\r\n')
          ..write('--b--\r\n');

        final parts = GmailApiAdapter.parseMultipartMixedForTesting(
            body.toString(), 'b');
        expect(parts.length, 1);
        expect(parts[0], contains('only'));
        // Preamble line must not leak into the parsed parts.
        expect(parts[0], isNot(contains('preamble')));
      });
    });

    group('extractJson', () {
      test('extracts JSON body from sub-response with HTTP/1.1 200 OK', () {
        final subResponse = StringBuffer()
          ..write('Content-Type: application/http\r\n')
          ..write('Content-ID: <response-item-0>\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n')
          ..write('\r\n')
          ..write('{"id":"msg-1","subject":"test"}');

        final json = GmailApiAdapter.extractJsonForTesting(subResponse.toString());
        expect(json, isNotNull);
        expect(json, contains('"id":"msg-1"'));
        expect(json, contains('"subject":"test"'));
      });

      test('returns null when first blank-line boundary missing', () {
        // No \r\n\r\n at all.
        expect(GmailApiAdapter.extractJsonForTesting('garbage'), isNull);
      });

      test('returns null when second blank-line boundary missing', () {
        // Has the part headers blank line but no http body.
        expect(
          GmailApiAdapter.extractJsonForTesting(
              'Content-Type: application/http\r\n\r\nHTTP/1.1 204 No Content\r\n'),
          isNull,
        );
      });

      test('handles trailing whitespace', () {
        final sub = StringBuffer()
          ..write('Content-Type: application/http\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 200 OK\r\n')
          ..write('\r\n')
          ..write('{"k":"v"}\r\n  \r\n');
        expect(
          GmailApiAdapter.extractJsonForTesting(sub.toString()),
          '{"k":"v"}',
        );
      });

      test('extracts error JSON the same way as success', () {
        // Gmail returns 4xx with a JSON error body for failed sub-requests.
        // The parser must still return the JSON; the caller (batchGet) is
        // responsible for checking the {error: ...} shape.
        final sub = StringBuffer()
          ..write('Content-Type: application/http\r\n')
          ..write('\r\n')
          ..write('HTTP/1.1 404 Not Found\r\n')
          ..write('Content-Type: application/json\r\n')
          ..write('\r\n')
          ..write('{"error":{"code":404,"message":"Not Found"}}');
        final json = GmailApiAdapter.extractJsonForTesting(sub.toString());
        expect(json, contains('"error"'));
      });
    });
  });
}
