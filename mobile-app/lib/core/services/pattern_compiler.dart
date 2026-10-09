import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:logger/logger.dart';

/// Where a compiled pattern came from.
///
/// SEC-1b (Sprint 33): the evaluator needs to know whether a regex was
/// shipped with the app (trusted) or supplied by the user (untrusted) so it
/// can apply ReDoS protection only where it is needed -- bundled patterns
/// stay on the fast path, user patterns get rejected at compile time if
/// they match the ReDoS heuristics in [PatternCompiler.detectReDoS].
enum PatternProvenance {
  /// Pattern originated from bundled assets (rules.yaml / safe senders).
  /// Trusted: direct [RegExp.hasMatch] with no timeout.
  bundled,

  /// Pattern came from a user action (manual rule entry, YAML import,
  /// clipboard paste). Untrusted: rejected at compile time if dangerous.
  user,
}

/// Precompiles and caches regex patterns for performance
///
/// Includes ReDoS (Regular Expression Denial of Service) protection:
/// - Pattern validation detects nested quantifiers and dangerous constructs
/// - [compileWithProvenance] rejects ReDoS-vulnerable user patterns at the
///   compile boundary so the hot path never sees them (SEC-1b)
/// - Timeout-protected matching via [safeHasMatch] remains available for
///   code that wants defense-in-depth even for bundled patterns
///
/// ## SEC-1b design note (Sprint 33)
///
/// The evaluator hot path iterates thousands of patterns per email. Wrapping
/// every match in an isolate timeout adds per-match overhead (~ms) that
/// multiplies with the pattern count and user inbox size. Instead, SEC-1b
/// rejects dangerous user patterns at the compile boundary. Bundled
/// patterns in `assets/rules/rules.yaml` are curated and tested, so they
/// continue to run with a direct `regex.hasMatch()` (Option C in the sprint
/// plan). See `docs/sprints/SPRINT_33_PLAN.md` for the full trade-off
/// discussion.
class PatternCompiler {
  final Logger _logger = Logger();
  final Map<String, RegExp> _cache = HashMap();
  final Map<String, String> _failures = HashMap();
  // SEC-1b: track which patterns came from user input so callers can decide
  // whether to warn / reject / sandbox.
  final Map<String, PatternProvenance> _provenance = HashMap();
  // SEC-1b: patterns rejected at compile time because they matched the
  // ReDoS heuristics. Stored so the UI can surface the reason to the user.
  final Map<String, String> _rejectedUserPatterns = HashMap();
  int _hits = 0;
  int _misses = 0;

  /// Default timeout for regex matching operations (SEC-1)
  static const Duration defaultMatchTimeout = Duration(seconds: 2);

  /// Compile a pattern and cache it.
  ///
  /// Backwards-compatible entry point; treats the pattern as
  /// [PatternProvenance.bundled] (the fast path). Call sites that load
  /// user-supplied patterns should use [compileWithProvenance] so the
  /// ReDoS guard can kick in.
  RegExp compile(String pattern) =>
      compileWithProvenance(pattern, PatternProvenance.bundled);

  /// Compile a pattern and cache it, tracking where it came from.
  ///
  /// For [PatternProvenance.user] inputs this runs [detectReDoS] first
  /// and, if any warnings fire, caches a never-matches regex and records
  /// the rejection in [rejectedUserPatterns]. Bundled patterns skip the
  /// ReDoS check since they are reviewed and tested before ship.
  RegExp compileWithProvenance(String pattern, PatternProvenance provenance) {
    if (_cache.containsKey(pattern)) {
      _hits++;
      return _cache[pattern]!;
    }

    _misses++;

    // SEC-1b: reject dangerous user patterns before they enter the hot path.
    if (provenance == PatternProvenance.user) {
      final redosWarnings = detectReDoS(pattern);
      if (redosWarnings.isNotEmpty) {
        final reason = redosWarnings.first;
        _logger.w('Rejecting ReDoS-vulnerable user pattern: "$pattern" '
            '($reason)');
        _rejectedUserPatterns[pattern] = reason;
        _provenance[pattern] = provenance;
        final fallback = RegExp(r'(?!)'); // Never matches
        _cache[pattern] = fallback;
        return fallback;
      }
    }

    try {
      // Strip Python-style inline flags (?i), (?m), (?s), (?x) or combinations like (?im)
      // Dart RegExp doesn't support inline flags but we already use caseSensitive: false
      // Only a leading inline-flag block is removed; other (?...) constructs like (?:...) or (?=...)
      // are preserved because they don't match the following regex.
      String cleanPattern = pattern;
      if (pattern.startsWith('(?') && pattern.contains(')')) {
        final flagMatch = RegExp(r'^\(\?[imsx]+\)').firstMatch(pattern);
        if (flagMatch != null) {
          cleanPattern = pattern.substring(flagMatch.end);
          _logger.d('Stripped inline flags from pattern: "$pattern" -> "$cleanPattern"');
        }
      }

      final regex = RegExp(cleanPattern, caseSensitive: false);
      _cache[pattern] = regex;
      _provenance[pattern] = provenance;
      return regex;
    } catch (e) {
      // Invalid regex - log error, track failure, cache a pattern that never matches
      final errorMsg = e.toString();
      _logger.e('Invalid regex pattern: "$pattern" - Error: $errorMsg');
      _failures[pattern] = errorMsg;
      _provenance[pattern] = provenance;

      final fallback = RegExp(r'(?!)'); // Never matches
      _cache[pattern] = fallback;
      return fallback;
    }
  }

  /// Match a pattern against input with timeout protection (SEC-1).
  ///
  /// Runs the regex match in a separate isolate with a timeout.
  /// Returns false if the match times out (pattern is treated as non-matching).
  ///
  /// Use this for user-provided patterns or untrusted input.
  /// For trusted internal patterns, direct [RegExp.hasMatch] is acceptable.
  static Future<bool> safeHasMatch(
    RegExp regex,
    String input, {
    Duration timeout = defaultMatchTimeout,
  }) async {
    try {
      return await Isolate.run(() => regex.hasMatch(input))
          .timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }

  /// Precompile a list of patterns
  void precompile(List<String> patterns) {
    for (final pattern in patterns) {
      compile(pattern);
    }
  }

  /// Clear the cache
  void clear() {
    _cache.clear();
    _failures.clear();
    _provenance.clear();
    _rejectedUserPatterns.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'cached_patterns': _cache.length,
      'cache_hits': _hits,
      'cache_misses': _misses,
      'failed_patterns': _failures.length,
    };
  }

  /// Get all compilation failures (pattern -> error message)
  Map<String, String> get compilationFailures => Map.unmodifiable(_failures);

  /// SEC-1b: user patterns rejected at compile time because they matched
  /// the ReDoS heuristics. Key = original pattern, value = warning message
  /// suitable for surfacing in rule-management UI.
  Map<String, String> get rejectedUserPatterns =>
      Map.unmodifiable(_rejectedUserPatterns);

  /// SEC-1b: lookup the recorded provenance of a pattern, or `null` if the
  /// pattern has not been compiled through this instance.
  PatternProvenance? provenanceOf(String pattern) => _provenance[pattern];

  /// Check if a pattern is valid (compiled successfully)
  bool isPatternValid(String pattern) => !_failures.containsKey(pattern);

  /// Validate a pattern and return warnings for common mistakes.
  ///
  /// Unlike [compile], this does not cache the pattern. It checks for
  /// structural issues that indicate the pattern may not work as intended.
  /// Returns an empty list if no warnings are found.
  ///
  /// Warnings do not prevent pattern compilation; they help users write
  /// better patterns.
  ///
  /// Set [addressField] to true when the pattern is matched against a single
  /// email address (safe senders, rule `from`). It adds the F266
  /// [detectUnmatchable] check, which is wrong for subject and body patterns.
  List<String> validatePattern(String pattern, {bool addressField = false}) {
    final warnings = <String>[];

    if (addressField) {
      warnings.addAll(detectUnmatchable(pattern));
    }

    // SEC-1: Check for ReDoS-vulnerable patterns (nested quantifiers)
    final redosWarnings = detectReDoS(pattern);
    warnings.addAll(redosWarnings);

    // Check for unescaped dots in domain-like patterns
    // e.g. "@spam.com$" should be "@spam\.com$"
    final domainLike = RegExp(r'@[a-z0-9-]+\.[a-z]+\$?$');
    if (domainLike.hasMatch(pattern) && !pattern.contains(r'\.')) {
      warnings.add('Pattern contains unescaped dot in what appears to be a domain. '
          'Use "\\." for literal dot (e.g., "@spam\\.com\$").');
    }

    // Check for redundant leading wildcards like ".*.*"
    if (pattern.contains('.*.*')) {
      warnings.add('Pattern contains redundant ".*.*". '
          'A single ".*" already matches everything.');
    }

    // Check for empty alternation branches like "(foo|)" or "(|bar)"
    if (RegExp(r'\(\||\|\)|\|\|').hasMatch(pattern)) {
      warnings.add('Pattern contains empty alternation branch. '
          'Empty branches match everything, which is likely unintended.');
    }

    // Check for patterns with 3+ repeated literal characters that will
    // not match after body normalization reduces them
    final repeatedChars = RegExp(r'(.)\1{2,}');
    if (repeatedChars.hasMatch(pattern)) {
      final match = repeatedChars.firstMatch(pattern)!;
      final char = match.group(1);
      // Only warn for non-regex metacharacters
      if (char != null && !r'.*+?{}[]()|\^$'.contains(char)) {
        warnings.add('Pattern contains 3+ repeated "$char" characters. '
            'Body normalization reduces these to 1 character. '
            'Match the normalized form instead.');
      }
    }

    return warnings;
  }

  /// Detect an UNMATCHABLE address pattern (F266, Sprint 77).
  ///
  /// An email address contains exactly one `@`. A pattern whose every match
  /// path needs at least two literal `@` characters outside a character
  /// class can therefore never match any address. The shipped defect was
  /// `^[^@\s]+@(?:[a-z0-9-]+\.)*@banking\.jpmchase\.com$`: a stray second
  /// `@` after the subdomain wildcard, present in 23 bundled safe senders.
  /// Those senders looked protected and were not.
  ///
  /// Returns a one-element list with a user-facing message, or an empty list.
  /// Same contract as [detectReDoS], and it is called from the same places.
  ///
  /// Apply it ONLY to patterns matched against a single address: safe
  /// senders, rule `from` conditions and exceptions. Do NOT apply it to
  /// subject, body or non-From header patterns, where two `@` can be legal.
  ///
  /// Method: count the MINIMUM number of literal `@` any match must contain.
  /// `|` takes the cheapest branch, `*` `?` `{0,n}` make a part optional (0),
  /// `+` and `{n,m}` repeat it n times, lookarounds count 0, and a character
  /// class counts 0, so `[^@\s]` is not a literal `@`. An escaped `\@` is a
  /// literal `@`.
  ///
  /// What this does NOT catch: other impossible shapes (an anchor in the
  /// wrong place, a class that excludes what the pattern requires, a
  /// contradictory lookahead), a missing `@` (a domain-only pattern is legal
  /// for non-address header text), and patterns whose regex does not parse.
  static List<String> detectUnmatchable(String pattern) {
    final count = _AtSignCounter(pattern).minimumLiteralAtSigns();
    if (count > 1) {
      return const [
        'Pattern requires more than one "@" character, but an email address '
            'contains exactly one, so it can never match. Remove the extra '
            '"@" (for example after the subdomain wildcard).'
      ];
    }
    return const [];
  }

  /// The domain wildcard group every bundled entire-domain pattern uses.
  static const String _domainWildcard = r'(?:[a-z0-9-]+\.)*';

  /// Repair the one shipped F266 defect shape: a stray literal `@` directly
  /// after the domain wildcard, as in
  /// `^[^@\s]+@(?:[a-z0-9-]+\.)*@banking\.jpmchase\.com$`.
  ///
  /// Returns the repaired pattern (the second `@` removed), or `null` when
  /// the pattern is not of this shape or the repair would not fix it. The
  /// result is only returned when [detectUnmatchable] is clean for it, so a
  /// legitimate pattern is never touched. Deterministic and pure: the v13
  /// database migration and the seed test both use it.
  static String? repairStrayAtAfterDomainWildcard(String pattern) {
    if (detectUnmatchable(pattern).isEmpty) return null;
    const needle = '$_domainWildcard@';
    final at = pattern.indexOf(needle);
    if (at < 0) return null;
    final repaired = pattern.substring(0, at + _domainWildcard.length) +
        pattern.substring(at + needle.length);
    return detectUnmatchable(repaired).isEmpty ? repaired : null;
  }

  /// True when [pattern] is exactly the shipped F266 defect shape that
  /// [repairStrayAtAfterDomainWildcard] can fix. This is the NARROW check for
  /// header patterns, which hold `key:value` text where the general
  /// [detectUnmatchable] could misfire; the import sanitizer, the store
  /// backstop and the v13 migration all use it so they agree.
  static bool hasStrayAtAfterDomainWildcard(String pattern) =>
      repairStrayAtAfterDomainWildcard(pattern) != null;

  /// Detect ReDoS-vulnerable patterns (SEC-1).
  ///
  /// Checks for nested quantifiers and overlapping alternation that can
  /// cause catastrophic backtracking. Returns a list of warnings.
  ///
  /// Detected patterns:
  /// - Nested quantifiers: `(a+)+`, `(a*)*`, `(.*)+`, `(a+)*`
  /// - Overlapping alternation with quantifiers: `(a|a)+`
  /// - Star-of-star: `.*.*` in groups with quantifiers
  static List<String> detectReDoS(String pattern) {
    final warnings = <String>[];

    // Pattern 1: Nested quantifiers - group with quantifier containing inner quantifier
    // Matches: (a+)+, (a*)+, (a+)*, (a{2,})*, ([^@]+)+, (.*)+
    // Uses a simplified heuristic: find groups that have a quantifier both
    // inside and outside.
    //
    // SAFE exception: If the inner quantified part is followed by a fixed
    // literal before the group closes, backtracking is bounded.
    // Example: (?:[a-z0-9-]+\.)* is safe -- the \. anchors each iteration.
    //
    // We scan for groups (...) where the inner quantifier (+/*) is the LAST
    // significant token before the closing paren (no anchoring literal after it).
    final nestedQuantifierPattern = RegExp(
      r'\('           // Opening paren
      r'(?:\?:)?'     // Optional non-capturing prefix
      r'[^)]*'        // Group content
      r'[+*]'         // Inner quantifier (+ or *)
      r'\)'           // Closing paren immediately after quantifier
      r'[+*?]'        // Outer quantifier
    );
    if (nestedQuantifierPattern.hasMatch(pattern)) {
      final match = nestedQuantifierPattern.firstMatch(pattern)!;
      warnings.add(
        'Pattern contains nested quantifiers "${match.group(0)}" which can cause '
        'catastrophic backtracking (ReDoS). Simplify the pattern to use a '
        'single quantifier level.',
      );
    }

    // Pattern 2: Repetition with curly brace quantifiers
    // Matches: (a{2,})+, (a{1,10})*
    final curlyNestedPattern = RegExp(
      r'\('
      r'[^)]*'
      r'\{[0-9]+,[0-9]*\}'  // {n,m} or {n,}
      r'[^)]*'
      r'\)'
      r'[+*?]'
    );
    if (curlyNestedPattern.hasMatch(pattern)) {
      final match = curlyNestedPattern.firstMatch(pattern)!;
      warnings.add(
        'Pattern contains nested quantifiers "${match.group(0)}" with '
        'repetition bounds which can cause catastrophic backtracking (ReDoS).',
      );
    }

    // Pattern 3: Overlapping alternation with quantifier
    // Matches: (a|a)+, (ab|a)+, (\s|\s)+
    // Simplified: look for alternation groups followed by quantifier
    // where branches share a common prefix
    final altWithQuantifier = RegExp(
      r'\('
      r'([^)|]+)'     // First branch
      r'\|'           // Alternation
      r'\1'           // Same as first branch (backreference pattern check)
      r'[^)]*'
      r'\)'
      r'[+*]'
    );
    if (altWithQuantifier.hasMatch(pattern)) {
      warnings.add(
        'Pattern contains overlapping alternation with quantifier which '
        'can cause catastrophic backtracking (ReDoS). Ensure alternation '
        'branches are mutually exclusive.',
      );
    }

    return warnings;
  }
}

/// Computes the minimum number of literal `@` characters any match of a regex
/// must contain (F266). Private helper of [PatternCompiler.detectUnmatchable].
///
/// This is a small recursive-descent walk, not a regex engine. It never
/// throws: on any parse surprise it reports 0, which means "do not flag".
/// A false negative is acceptable here; a false positive would reject a
/// legal pattern.
class _AtSignCounter {
  _AtSignCounter(this._p);

  final String _p;
  int _i = 0;

  int minimumLiteralAtSigns() {
    try {
      _i = 0;
      return _alternation();
    } catch (_) {
      return 0;
    }
  }

  /// Alternation: the cheapest branch decides the minimum.
  int _alternation() {
    var best = _sequence();
    while (_i < _p.length && _p[_i] == '|') {
      _i++;
      final branch = _sequence();
      if (branch < best) best = branch;
    }
    return best;
  }

  int _sequence() {
    var total = 0;
    while (_i < _p.length) {
      final c = _p[_i];
      if (c == '|' || c == ')') break;
      int atom;
      if (c == r'\') {
        // An escaped at sign is still one literal at sign.
        atom = (_i + 1 < _p.length && _p[_i + 1] == '@') ? 1 : 0;
        _i += 2;
      } else if (c == '[') {
        _skipCharacterClass();
        atom = 0;
      } else if (c == '(') {
        atom = _group();
      } else {
        atom = c == '@' ? 1 : 0;
        _i++;
      }
      total += atom * _quantifierMinimum();
    }
    return total;
  }

  int _group() {
    _i++; // past '('
    var zeroWidth = false;
    if (_i < _p.length && _p[_i] == '?') {
      final next = _i + 1 < _p.length ? _p[_i + 1] : '';
      if (next == ':') {
        _i += 2;
      } else if (next == '=' || next == '!') {
        zeroWidth = true;
        _i += 2;
      } else if (next == '<') {
        final after = _i + 2 < _p.length ? _p[_i + 2] : '';
        if (after == '=' || after == '!') {
          zeroWidth = true;
          _i += 3;
        } else {
          final close = _p.indexOf('>', _i);
          if (close < 0) return 0;
          _i = close + 1; // named capture group
        }
      }
    }
    final inner = _alternation();
    if (_i < _p.length && _p[_i] == ')') _i++;
    return zeroWidth ? 0 : inner;
  }

  void _skipCharacterClass() {
    _i++; // past '['
    if (_i < _p.length && _p[_i] == '^') _i++;
    while (_i < _p.length && _p[_i] != ']') {
      _i += _p[_i] == r'\' ? 2 : 1;
    }
    _i++; // past ']'
  }

  /// Minimum repeat count of the atom just read (1 when there is no
  /// quantifier). Also consumes a trailing lazy `?`.
  int _quantifierMinimum() {
    if (_i >= _p.length) return 1;
    var min = 1;
    final c = _p[_i];
    if (c == '*' || c == '?') {
      min = 0;
      _i++;
    } else if (c == '+') {
      _i++;
    } else if (c == '{') {
      final m = RegExp(r'\{(\d+)(?:,\d*)?\}').matchAsPrefix(_p, _i);
      if (m == null) return 1; // a literal brace, not a quantifier
      min = int.parse(m.group(1)!);
      _i = m.end;
    } else {
      return 1;
    }
    if (_i < _p.length && _p[_i] == '?') _i++; // lazy modifier
    return min;
  }
}
