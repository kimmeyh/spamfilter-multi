// F102 (Sprint 43) -- Logging redaction enforcement gate, as a Dart test.
//
// Codifies the ADR-0030 "Logging & Redaction" invariant in the standard test
// suite (`flutter test`), so a new un-redacted PII log line FAILS the build --
// not just the standalone scripts/check-log-redaction.ps1 CLI. Mirrors that
// script's logic so both lanes agree.
//
// FAILS when a log call in lib/ interpolates a raw account id / email / token
// without a Redact.* wrapper. Excludes non-PII identifiers (emailId row ids,
// counts, *Ids lists).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A log-sink call on the line: _logger.i/d/w/e(, Logger().i/d/w/e(,
/// _bgLog(, or bgLog(.
final _logCall = RegExp(
    r'(_logger\.(i|d|w|e)|Logger\(\)\.(i|d|w|e)|_bgLog|[^A-Za-z]bgLog)\s*\(');

/// Raw PII interpolations. Negative lookaheads keep emailId/emails/accountIds/
/// accountCount from matching.
final _pii = RegExp(
    r'\$\{?(email(?!Id|Ids|Count|s\b)|emailAddress|fromEmail|senderEmail|userEmail|toEmail|accountId(?!s)|bgAccountId|_backgroundAccountId|account(?!Id|Ids|Count|s\b)|accessToken|refreshToken|token|appPassword|clientSecret)\b');

bool _isViolation(String line) {
  if (!_logCall.hasMatch(line)) return false; // not a log call
  if (line.contains('Redact.')) return false; // redacted inline
  return _pii.hasMatch(line); // raw PII in a log call
}

void main() {
  group('F102 logging-redaction invariant (ADR-0030)', () {
    test('self-check: the matcher flags raw PII and ignores safe forms', () {
      expect(_isViolation(r"_logger.d('x $emailAddress y')"), isTrue);
      expect(_isViolation(r"_logger.i('for account $accountId')"), isTrue);
      expect(_isViolation(r"await _bgLog('account $accountId missing')"), isTrue);
      expect(_isViolation(r"_logger.d('${Redact.email(emailAddress)}')"), isFalse);
      expect(_isViolation(r"_logger.i('${Redact.accountId(accountId)}')"), isFalse);
      expect(_isViolation(r"_logger.d('Deleted email $emailId')"), isFalse);
      expect(_isViolation(r"_logger.i('scans=$scans emails=$emails')"), isFalse);
      expect(_isViolation(r"final accountId = $accountId;"), isFalse);
    });

    test('no lib/ log call leaks a raw account id / email / token', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'run from the mobile-app directory');

      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isViolation(lines[i])) {
            violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Un-redacted PII in log calls (wrap with Redact.accountId/'
              'email/token):\n${violations.join('\n')}');
    });
  });
}
