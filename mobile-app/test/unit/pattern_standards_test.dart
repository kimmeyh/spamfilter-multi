import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';
import 'package:spam_filter_mobile/core/utils/pattern_normalization.dart';

/// Tests for subject and body content pattern standards (Issue #141).
///
/// Validates that pattern normalization, compilation, and matching work
/// correctly for subject and body rule patterns as documented in
/// docs/RULE_FORMAT.md.
void main() {
  late PatternCompiler compiler;

  setUp(() {
    compiler = PatternCompiler();
  });

  group('Subject Pattern Standards', () {
    group('S1: Contains Keyword', () {
      test('matches keyword anywhere in subject', () {
        final regex = compiler.compile('viagra');
        final normalized = PatternNormalization.normalizeSubject(
            'Buy Viagra Now');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('does not match unrelated subject', () {
        final regex = compiler.compile('viagra');
        final normalized = PatternNormalization.normalizeSubject(
            'Your monthly invoice');
        expect(regex.hasMatch(normalized), isFalse);
      });
    });

    group('S2: Starts With', () {
      test('matches subject starting with pattern', () {
        final regex = compiler.compile('^urgent');
        final normalized = PatternNormalization.normalizeSubject(
            'URGENT: Action Required');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('does not match when keyword is not at start', () {
        final regex = compiler.compile('^urgent');
        final normalized = PatternNormalization.normalizeSubject(
            'This is not urgent');
        expect(regex.hasMatch(normalized), isFalse);
      });
    });

    group('S3: Ends With', () {
      test('matches subject ending with pattern', () {
        final regex = compiler.compile(r'click here$');
        final normalized = PatternNormalization.normalizeSubject(
            'Please click here');
        expect(regex.hasMatch(normalized), isTrue);
      });
    });

    group('S4: Exact Match', () {
      test('matches exact subject text', () {
        final regex = compiler.compile('^you have won\$');
        final normalized = PatternNormalization.normalizeSubject(
            'You Have Won');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('does not match partial subject', () {
        final regex = compiler.compile('^you have won\$');
        final normalized = PatternNormalization.normalizeSubject(
            'You Have Won a Prize');
        expect(regex.hasMatch(normalized), isFalse);
      });
    });

    group('S5: Keyword + Context', () {
      test('matches keywords in order with flexible spacing', () {
        final regex = compiler.compile('urgent.*action.*required');
        final normalized = PatternNormalization.normalizeSubject(
            'URGENT: Immediate Action Required');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('does not match when keywords are in wrong order', () {
        final regex = compiler.compile('urgent.*action.*required');
        final normalized = PatternNormalization.normalizeSubject(
            'Required: Take Action, Not Urgent');
        expect(regex.hasMatch(normalized), isFalse);
      });
    });

    group('S6: Alternation', () {
      test('matches any keyword in alternation', () {
        final regex = compiler.compile('(viagra|cialis|levitra)');
        expect(regex.hasMatch(
            PatternNormalization.normalizeSubject('Buy Viagra')), isTrue);
        expect(regex.hasMatch(
            PatternNormalization.normalizeSubject('Cheap Cialis')), isTrue);
        expect(regex.hasMatch(
            PatternNormalization.normalizeSubject('Get Levitra')), isTrue);
      });

      test('does not match unrelated text', () {
        final regex = compiler.compile('(viagra|cialis|levitra)');
        expect(regex.hasMatch(
            PatternNormalization.normalizeSubject('Invoice for services')),
            isFalse);
      });
    });

    group('Subject normalization edge cases', () {
      test('normalizes tabs and newlines to spaces', () {
        final normalized = PatternNormalization.normalizeSubject(
            'Subject\twith\ttabs\nand\nnewlines');
        expect(normalized, 'subject with tabs and newlines');
      });

      test('collapses multiple spaces between words', () {
        final normalized = PatternNormalization.normalizeSubject(
            'Multiple    Spaces     Between     Words');
        expect(normalized, 'multiple spaces between words');
      });

      test('preserves colons in Re:/Fwd: prefixes', () {
        final normalized = PatternNormalization.normalizeSubject(
            'Re: Fwd: Original Subject');
        expect(normalized, 're: fwd: original subject');
      });

      test('preserves numbers and special characters', () {
        final normalized = PatternNormalization.normalizeSubject(
            'Invoice #12345 - Amount Due: \$99.99');
        expect(normalized, 'invoice #12345 - amount due: \$99.99');
      });

      test('case-insensitive pattern matches normalized subject', () {
        final regex = compiler.compile('action required');
        final normalized = PatternNormalization.normalizeSubject(
            'ACTION REQUIRED: Verify Your Account');
        expect(regex.hasMatch(normalized), isTrue);
      });
    });

    group('Subject pattern real-world examples', () {
      test('phishing urgency pattern', () {
        final regex = compiler.compile(
            '(?:verify|confirm).*(?:your|the) account');
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Verify Your Account Immediately')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Please Confirm the Account')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Your Account Statement')), isFalse);
      });

      test('prize scam pattern', () {
        final regex = compiler.compile(
            '(?:claim|collect).*(?:prize|reward|winnings)');
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Claim Your Prize Now!')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Collect Your Reward Today')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Employee Reward Program')), isFalse);
      });

      test('lottery scam pattern', () {
        final regex = compiler.compile(
            r'^(?:re: )?(?:congratulations|you (?:have )?won)');
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Congratulations! You Won!')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Re: You Have Won a Prize')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeSubject(
            'Meeting Congratulations to the Team')), isFalse);
      });
    });
  });

  group('Body Content Pattern Standards', () {
    group('B1: Contains Phrase', () {
      test('matches phrase in body text', () {
        final regex = compiler.compile('verify your account');
        final normalized = PatternNormalization.normalizeBodyText(
            'Please verify your account by clicking the link below.');
        expect(regex.hasMatch(normalized), isTrue);
      });
    });

    group('B2: Keyword Sequence', () {
      test('matches keywords in order with flexible spacing', () {
        final regex = compiler.compile('verify.*account.*click');
        final normalized = PatternNormalization.normalizeBodyText(
            'We need to verify your account. Please click here.');
        expect(regex.hasMatch(normalized), isTrue);
      });
    });

    group('B3: URL Domain', () {
      test('matches URL shortener domain in body', () {
        final regex = compiler.compile(r'https?://[^/]*bit\.ly');
        final normalized = PatternNormalization.normalizeBodyText(
            'Click here: https://bit.ly/abc123 for more info');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('matches URL with subdomain', () {
        final regex = compiler.compile(r'https?://[^/]*tinyurl\.com');
        final normalized = PatternNormalization.normalizeBodyText(
            'Visit http://tinyurl.com/xyz789 today');
        expect(regex.hasMatch(normalized), isTrue);
      });
    });

    group('B4: Alternation', () {
      test('matches any phrase in alternation', () {
        final regex = compiler.compile('(unsubscribe|opt.out)');
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Click to unsubscribe from this list')), isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Opt-out of future emails')), isTrue);
      });
    });

    group('Body normalization edge cases', () {
      test('repeated characters normalized to single', () {
        final normalized = PatternNormalization.normalizeBodyText(
            'Click!!!!! here NOW!!!!');
        expect(normalized, 'click! here now!');
      });

      test('two repeated characters are preserved', () {
        final normalized = PatternNormalization.normalizeBodyText(
            'See!! this!! now!!');
        expect(normalized, 'see!! this!! now!!');
      });

      test('repeated letters normalized', () {
        final normalized = PatternNormalization.normalizeBodyText(
            'Freeeeee money');
        // 7 consecutive 'e' chars become 1
        expect(normalized, 'fre money');
      });

      test('pattern matches after normalization of exclamation marks', () {
        final regex = compiler.compile('click.*here');
        final normalized = PatternNormalization.normalizeBodyText(
            'CLICK!!!!! HERE!!!!!');
        expect(regex.hasMatch(normalized), isTrue);
      });

      test('URL extraction from body text', () {
        final urls = PatternNormalization.extractUrls(
            'Visit https://example.com and http://spam.xyz/page');
        expect(urls, hasLength(2));
        expect(urls[0], contains('example.com'));
        expect(urls[1], contains('spam.xyz'));
      });

      test('domain extraction from URL', () {
        expect(PatternNormalization.extractDomain(
            'https://www.example.com/path?q=1'), 'example.com');
        expect(PatternNormalization.extractDomain(
            'http://mail.google.com:8080'), 'mail.google.com');
      });
    });

    group('Body pattern real-world examples', () {
      test('credential phishing pattern', () {
        final regex = compiler.compile(
            '(?:verify|confirm).*(?:your|the) (?:account|identity).*(?:click|link|immediately)');
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Please verify your account by clicking the link immediately')),
            isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Confirm the identity of your profile. Click here.')),
            isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Please verify that you received the package')),
            isFalse);
      });

      test('account lockout phishing pattern', () {
        final regex = compiler.compile(
            '(?:account|password).*(?:suspended|locked|disabled).*(?:verify|click|restore)');
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Your account has been suspended. Click here to restore access.')),
            isTrue);
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'Password locked. Verify your identity to unlock.')),
            isTrue);
      });

      test('prize scam pattern in body', () {
        final regex = compiler.compile(
            '(?:won|winner|selected).*(?:claim|collect).*(?:prize|reward|gift)');
        expect(regex.hasMatch(PatternNormalization.normalizeBodyText(
            'You have been selected as a winner! Claim your prize now!')),
            isTrue);
      });
    });
  });

  group('PatternCompiler.validatePattern', () {
    test('warns about unescaped dot in domain pattern', () {
      final warnings = compiler.validatePattern(r'@spam.com$');
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('unescaped dot'));
    });

    test('no warning for escaped dot in domain pattern', () {
      final warnings = compiler.validatePattern(r'@spam\.com$');
      expect(warnings, isEmpty);
    });

    test('warns about redundant leading wildcards', () {
      final warnings = compiler.validatePattern('.*.*text');
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('redundant'));
    });

    test('no warning for single wildcard', () {
      final warnings = compiler.validatePattern('.*text');
      expect(warnings, isEmpty);
    });

    test('warns about empty alternation branch', () {
      final warnings = compiler.validatePattern('(foo|)');
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('empty alternation'));
    });

    test('no warning for valid alternation', () {
      final warnings = compiler.validatePattern('(foo|bar)');
      expect(warnings, isEmpty);
    });

    test('warns about repeated characters in pattern', () {
      final warnings = compiler.validatePattern('click!!! here');
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('repeated'));
    });

    test('no warning for 2 repeated characters', () {
      final warnings = compiler.validatePattern('click!! here');
      expect(warnings, isEmpty);
    });

    test('no warning for repeated regex metacharacters', () {
      // .* contains repeated meta chars, should not warn
      final warnings = compiler.validatePattern('test.*pattern');
      expect(warnings, isEmpty);
    });

    test('returns multiple warnings for multiple issues', () {
      final warnings = compiler.validatePattern('.*.*@spam.com\$');
      expect(warnings.length, greaterThanOrEqualTo(2));
    });

    test('returns empty list for valid simple pattern', () {
      final warnings = compiler.validatePattern('urgent');
      expect(warnings, isEmpty);
    });

    test('returns empty list for valid complex pattern', () {
      final warnings = compiler.validatePattern(
          r'(?:verify|confirm).*(?:your|the) account');
      expect(warnings, isEmpty);
    });
  });

  group('Cross-condition pattern matching', () {
    test('same pattern works for both subject and body', () {
      final regex = compiler.compile('verify.*account');

      final subjectNormalized = PatternNormalization.normalizeSubject(
          'Verify Your Account');
      final bodyNormalized = PatternNormalization.normalizeBodyText(
          'Please verify your account immediately.');

      expect(regex.hasMatch(subjectNormalized), isTrue);
      expect(regex.hasMatch(bodyNormalized), isTrue);
    });

    test('body normalization differs from subject normalization for repeats', () {
      // Subject preserves repeats, body reduces them
      final subjectNorm = PatternNormalization.normalizeSubject(
          'URGENT!!! Action Required!!!');
      final bodyNorm = PatternNormalization.normalizeBodyText(
          'URGENT!!! Action Required!!!');

      expect(subjectNorm, 'urgent!!! action required!!!');
      expect(bodyNorm, 'urgent! action required!');
    });

    test('word boundary prevents partial matches', () {
      final regex = compiler.compile(r'\bfree\b');
      final normalized = PatternNormalization.normalizeSubject(
          'Freedom of Expression');
      expect(regex.hasMatch(normalized), isFalse);

      final spamNormalized = PatternNormalization.normalizeSubject(
          'Get Your Free Gift');
      expect(regex.hasMatch(spamNormalized), isTrue);
    });
  });
}
