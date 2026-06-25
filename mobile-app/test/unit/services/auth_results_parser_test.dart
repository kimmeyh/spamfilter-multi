/// F89 (Sprint 39) Phase 1 tests: AuthResultsParser parses provider-specific
/// Authentication-Results / ARC-Authentication-Results / Received-SPF headers
/// into an EmailAuthResult and classifies it GREEN/YELLOW/RED/GREY.
///
/// Fixtures cover AOL, Yahoo, Gmail, and Outlook header shapes plus the
/// Sprint 38 Amazon phishing scenario (SPF fail + DKIM fail + DMARC fail).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/auth_results_parser.dart';

void main() {
  group('AuthResultsParser.parse -- per-provider fixtures', () {
    test('Gmail all-pass header parses to spf/dkim/dmarc pass', () {
      final headers = {
        'Authentication-Results': 'mx.google.com; '
            'dkim=pass header.i=@example.com header.s=sel header.b=abc; '
            'spf=pass (google.com: domain of bounce@example.com designates '
            '10.0.0.1 as permitted sender) smtp.mailfrom=bounce@example.com; '
            'dmarc=pass (p=REJECT sp=REJECT dis=NONE) header.from=example.com',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.pass);
      expect(result.dkim, AuthMethodResult.pass);
      expect(result.dmarc, AuthMethodResult.pass);
      expect(AuthResultsParser.classify(result), AuthClassification.green);
    });

    test('AOL header with mixed spf=softfail, dkim=pass parses correctly', () {
      final headers = {
        'authentication-results': 'mx.aol.com; '
            'dkim=pass header.d=newsletter.com; '
            'spf=softfail smtp.mailfrom=newsletter.com; '
            'dmarc=none header.from=newsletter.com',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.softfail);
      expect(result.dkim, AuthMethodResult.pass);
      expect(result.dmarc, AuthMethodResult.none);
      // Mixed: not all-pass, not a spoof signal -> YELLOW.
      expect(AuthResultsParser.classify(result), AuthClassification.yellow);
    });

    test('Yahoo header parses spf=pass dkim=fail (mixed -> yellow)', () {
      final headers = {
        'Authentication-Results': 'atlas.yahoo.com; '
            'dkim=fail reason="signature verification failed" '
            'header.d=promo.example; '
            'spf=pass smtp.mailfrom=promo.example; '
            'dmarc=pass header.from=promo.example',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.pass);
      expect(result.dkim, AuthMethodResult.fail);
      expect(result.dmarc, AuthMethodResult.pass);
      // DKIM failed but DMARC passed -> not a confident spoof -> YELLOW.
      expect(AuthResultsParser.classify(result), AuthClassification.yellow);
    });

    test('Outlook-style header with temperror parses to temperror', () {
      final headers = {
        'Authentication-Results': 'spf=temperror (sender IP is 1.2.3.4) '
            'smtp.mailfrom=example.com; dkim=none; dmarc=none',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.temperror);
      expect(result.dkim, AuthMethodResult.none);
      expect(result.dmarc, AuthMethodResult.none);
      expect(AuthResultsParser.classify(result), AuthClassification.yellow);
    });

    test('Received-SPF fallback fills SPF when AR header omits it', () {
      final headers = {
        'Authentication-Results': 'mx.example.com; dkim=pass header.d=x.com; '
            'dmarc=pass header.from=x.com',
        'Received-SPF': 'pass (example.com: domain of x.com designates 1.1.1.1 '
            'as permitted sender) client-ip=1.1.1.1;',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.pass,
          reason: 'SPF verdict should be filled from Received-SPF.');
      expect(result.dkim, AuthMethodResult.pass);
      expect(AuthResultsParser.classify(result), AuthClassification.green);
    });

    test('ARC-Authentication-Results used when Authentication-Results absent',
        () {
      final headers = {
        'ARC-Authentication-Results': 'i=1; mx.example.com; '
            'spf=pass smtp.mailfrom=x.com; dkim=pass header.d=x.com; '
            'dmarc=pass header.from=x.com',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.pass);
      expect(result.dkim, AuthMethodResult.pass);
      expect(result.dmarc, AuthMethodResult.pass);
      // The ARC header value (used as the fallback source) is preserved in raw.
      expect(result.raw, contains('i=1'));
      expect(AuthResultsParser.classify(result), AuthClassification.green);
    });

    test('multiple DKIM signatures: pass wins over fail (strongest verdict)',
        () {
      final headers = {
        'Authentication-Results': 'mx.example.com; '
            'dkim=fail header.d=marketing.example; '
            'dkim=pass header.d=example.com; '
            'spf=pass smtp.mailfrom=example.com; '
            'dmarc=pass header.from=example.com',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.dkim, AuthMethodResult.pass,
          reason: 'At least one valid DKIM signature should count as pass.');
    });
  });

  group('AuthResultsParser.classify -- classification states', () {
    test('GREEN when all present checks pass', () {
      const result = EmailAuthResult(
        spf: AuthMethodResult.pass,
        dkim: AuthMethodResult.pass,
        dmarc: AuthMethodResult.pass,
        raw: 'x',
      );
      expect(AuthResultsParser.classify(result), AuthClassification.green);
    });

    test('RED -- Sprint 38 Amazon phishing: SPF fail + DKIM fail + DMARC fail',
        () {
      // From: account_update@amazon.com, all three checks fail. This is the
      // canonical spoof scenario the feature exists to catch.
      final headers = {
        'Authentication-Results': 'mx.aol.com; '
            'spf=fail smtp.mailfrom=account_update@amazon.com; '
            'dkim=fail header.d=amazon.com; '
            'dmarc=fail (p=REJECT) header.from=amazon.com',
      };
      final result = AuthResultsParser.parse(headers);
      expect(result.spf, AuthMethodResult.fail);
      expect(result.dkim, AuthMethodResult.fail);
      expect(result.dmarc, AuthMethodResult.fail);
      expect(AuthResultsParser.classify(result), AuthClassification.red,
          reason: 'SPF fail AND DKIM fail AND DMARC fail must be RED.');
    });

    test('RED when SPF fail AND DMARC fail (DKIM pass does not rescue)', () {
      const result = EmailAuthResult(
        spf: AuthMethodResult.fail,
        dkim: AuthMethodResult.pass,
        dmarc: AuthMethodResult.fail,
        raw: 'x',
      );
      expect(AuthResultsParser.classify(result), AuthClassification.red);
    });

    test('YELLOW when DKIM fails but DMARC does not (no corroboration)', () {
      const result = EmailAuthResult(
        spf: AuthMethodResult.pass,
        dkim: AuthMethodResult.fail,
        dmarc: AuthMethodResult.none,
        raw: 'x',
      );
      expect(AuthResultsParser.classify(result), AuthClassification.yellow);
    });

    test('GREY when no authentication headers were present at all', () {
      final result = AuthResultsParser.parse({'From': 'a@b.com'});
      expect(result.isEmpty, isTrue);
      expect(AuthResultsParser.classify(result), AuthClassification.grey);
    });

    test('classifyHeaders convenience matches parse+classify', () {
      final headers = {
        'Authentication-Results':
            'spf=fail; dkim=fail; dmarc=fail header.from=x.com',
      };
      expect(
        AuthResultsParser.classifyHeaders(headers),
        AuthClassification.red,
      );
    });
  });

  // F96 (Sprint 43): re-hydration helpers used by the off-scan quick-add paths.
  group('F96 -- classification name round-trip', () {
    test('classificationToName / classificationFromName round-trip', () {
      for (final c in AuthClassification.values) {
        final name = AuthResultsParser.classificationToName(c);
        expect(AuthResultsParser.classificationFromName(name), c);
      }
    });

    test('classificationFromName returns null for null/empty/unknown', () {
      expect(AuthResultsParser.classificationFromName(null), isNull);
      expect(AuthResultsParser.classificationFromName(''), isNull);
      expect(AuthResultsParser.classificationFromName('purple'), isNull);
    });
  });

  group('F96 -- syntheticResultFor', () {
    test('RED synthesizes failing verdicts so the warning renders', () {
      final r = AuthResultsParser.syntheticResultFor(AuthClassification.red);
      expect(r.spf, AuthMethodResult.fail);
      expect(r.dkim, AuthMethodResult.fail);
      expect(r.dmarc, AuthMethodResult.fail);
      expect(r.raw, isEmpty);
      // A synthetic RED must itself re-classify as RED for consistency.
      expect(AuthResultsParser.classify(r), AuthClassification.red);
    });

    test('non-RED synthesizes neutral verdicts (no warning is shown)', () {
      for (final c in [
        AuthClassification.green,
        AuthClassification.yellow,
        AuthClassification.grey,
      ]) {
        final r = AuthResultsParser.syntheticResultFor(c);
        expect(r.spf, AuthMethodResult.none);
        expect(r.dkim, AuthMethodResult.none);
        expect(r.dmarc, AuthMethodResult.none);
        expect(r.raw, isEmpty);
      }
    });
  });
}
