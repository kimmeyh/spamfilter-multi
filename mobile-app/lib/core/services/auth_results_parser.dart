/// F89 (Sprint 39): parse email authentication headers (SPF, DKIM, DMARC)
/// into a structured result and classify the overall trustworthiness.
///
/// Source headers, in priority order:
///   1. `Authentication-Results` (RFC 8601) -- the receiving MTA's verdict.
///   2. `ARC-Authentication-Results` (RFC 8617) -- preserved verdict from an
///      intermediary; used as a fallback when `Authentication-Results` is
///      absent (common when a forwarder rewrote the path).
///   3. `Received-SPF` (RFC 7208) -- standalone SPF result, used to fill in
///      an SPF verdict the `Authentication-Results` header did not carry.
///
/// The parser is deliberately tolerant of provider variations. AOL, Yahoo,
/// Gmail, and Outlook all emit slightly different `Authentication-Results`
/// strings (ordering, extra `(comment)` blocks, `header.from=` vs
/// `smtp.mailfrom=` tags). We extract only the `method=result` tokens we
/// care about and ignore the rest.
library;

/// The result of a single authentication method (SPF, DKIM, or DMARC).
///
/// Values follow RFC 8601 section 2.7 result keywords. Not every method
/// emits every value (for example SPF uses `softfail`; DKIM does not), so
/// the enum is the union of the relevant keywords across all three methods.
enum AuthMethodResult {
  /// The method passed.
  pass,

  /// The method failed (SPF hardfail, DKIM signature did not verify, DMARC
  /// disposition fail/reject).
  fail,

  /// SPF soft failure (`~all`): the domain discourages but does not forbid.
  softfail,

  /// The method returned a neutral verdict (`?all` for SPF).
  neutral,

  /// No policy / no record published, or the method was simply not present.
  none,

  /// A temporary error occurred during evaluation (DNS timeout, etc.).
  temperror,

  /// A permanent error occurred (malformed record, etc.).
  permerror,
}

/// Overall classification of an email's authentication state, used to drive
/// the badge color and whether a quick-add prompt warns the user.
enum AuthClassification {
  /// All present methods passed. Safe to whitelist.
  green,

  /// Mixed results (some pass, some softfail/neutral/none), but not a clear
  /// spoof signal. Non-blocking caution.
  yellow,

  /// Strong spoof signal: (SPF fail OR DKIM fail) AND DMARC fail. Warn
  /// before whitelisting.
  red,

  /// No authentication headers were present at all. Cannot assess.
  grey,
}

/// Structured authentication result parsed from an email's headers.
class EmailAuthResult {
  /// SPF verdict (sender IP authorized by the envelope-from domain).
  final AuthMethodResult spf;

  /// DKIM verdict (cryptographic signature verified against the signing
  /// domain). When multiple DKIM signatures are present, the strongest
  /// result is reported (pass beats fail beats none).
  final AuthMethodResult dkim;

  /// DMARC verdict (alignment of SPF/DKIM identifiers with the
  /// `From:` header domain plus the published DMARC policy).
  final AuthMethodResult dmarc;

  /// The raw header text the verdicts were parsed from, joined across all
  /// source headers. Shown to the user in the "technical details" section
  /// so they can inspect the original MTA output.
  final String raw;

  const EmailAuthResult({
    required this.spf,
    required this.dkim,
    required this.dmarc,
    required this.raw,
  });

  /// True when none of the three methods produced a usable verdict and no
  /// source header was found.
  bool get isEmpty =>
      raw.isEmpty &&
      spf == AuthMethodResult.none &&
      dkim == AuthMethodResult.none &&
      dmarc == AuthMethodResult.none;

  @override
  String toString() =>
      'EmailAuthResult(spf: $spf, dkim: $dkim, dmarc: $dmarc)';
}

/// Parses email authentication headers and classifies the overall state.
class AuthResultsParser {
  /// Parse the authentication headers out of [headers].
  ///
  /// [headers] is expected to be the `EmailMessage.headers` map (raw header
  /// names to values). Lookup is case-insensitive because providers vary
  /// (`Authentication-Results`, `authentication-results`, etc.).
  ///
  /// Returns an [EmailAuthResult]. When no relevant header is present, all
  /// three methods are [AuthMethodResult.none] and [EmailAuthResult.raw] is
  /// empty -- classify() will map this to [AuthClassification.grey].
  static EmailAuthResult parse(Map<String, String> headers) {
    final authResults = _lookup(headers, 'authentication-results');
    final arcResults = _lookup(headers, 'arc-authentication-results');
    final receivedSpf = _lookup(headers, 'received-spf');

    // Build the raw display string from whatever was present.
    final rawParts = <String>[];
    if (authResults != null) rawParts.add(authResults);
    if (arcResults != null) rawParts.add(arcResults);
    if (receivedSpf != null) rawParts.add('Received-SPF: $receivedSpf');
    final raw = rawParts.join('\n');

    // Prefer Authentication-Results; fall back to ARC when absent.
    final primary = authResults ?? arcResults ?? '';

    var spf = _extractMethod(primary, 'spf');
    var dkim = _extractMethod(primary, 'dkim');
    final dmarc = _extractMethod(primary, 'dmarc');

    // Received-SPF fills an SPF verdict that the primary header did not carry.
    if (spf == AuthMethodResult.none && receivedSpf != null) {
      spf = _parseReceivedSpf(receivedSpf);
    }

    return EmailAuthResult(spf: spf, dkim: dkim, dmarc: dmarc, raw: raw);
  }

  /// Classify [result] into a badge state.
  ///
  /// Rules (in order):
  ///   - GREY: no authentication headers were present at all.
  ///   - RED: (SPF fail OR DKIM fail) AND DMARC fail/reject. A confident
  ///     spoof signal -- the From-domain published a policy and the message
  ///     failed it on the relevant identifier.
  ///   - GREEN: every method that has a verdict passed, and at least one did.
  ///   - YELLOW: anything else (mixed pass/softfail/neutral/none, or a single
  ///     failure that DMARC did not corroborate).
  static AuthClassification classify(EmailAuthResult result) {
    if (result.isEmpty) {
      return AuthClassification.grey;
    }

    final spfFail = result.spf == AuthMethodResult.fail;
    final dkimFail = result.dkim == AuthMethodResult.fail;
    final dmarcFail = result.dmarc == AuthMethodResult.fail;

    // RED: a clear, DMARC-corroborated spoof signal.
    if ((spfFail || dkimFail) && dmarcFail) {
      return AuthClassification.red;
    }

    // GREEN: every present verdict passed (none == "not present" for that
    // method and does not disqualify), and at least one method passed.
    final verdicts = [result.spf, result.dkim, result.dmarc];
    final present = verdicts.where((v) => v != AuthMethodResult.none);
    final anyPass = present.any((v) => v == AuthMethodResult.pass);
    final allPresentPass =
        present.isNotEmpty && present.every((v) => v == AuthMethodResult.pass);
    if (allPresentPass && anyPass) {
      return AuthClassification.green;
    }

    // Everything else is a non-blocking caution.
    return AuthClassification.yellow;
  }

  /// Convenience: parse [headers] and classify in one step.
  static AuthClassification classifyHeaders(Map<String, String> headers) =>
      classify(parse(headers));

  /// F110 (Sprint 43): the list of authentication checks that FAILED in
  /// [result], in SPF, DKIM, DMARC order. Used for the debug-CSV
  /// "Phishing SPF/DKIM/DMARC" column and the per-account scan-log
  /// phishing line. A check is "failed" only on an explicit
  /// [AuthMethodResult.fail] (a hard fail) -- softfail / neutral / none /
  /// temperror / permerror are NOT counted as failures (they are not a
  /// confident spoof signal and would create noise on legitimately-forwarded
  /// mail). Returns an empty list when nothing hard-failed.
  static List<String> failedChecks(EmailAuthResult result) {
    final failed = <String>[];
    if (result.spf == AuthMethodResult.fail) failed.add('SPF');
    if (result.dkim == AuthMethodResult.fail) failed.add('DKIM');
    if (result.dmarc == AuthMethodResult.fail) failed.add('DMARC');
    return failed;
  }

  /// Convenience: [failedChecks] computed straight from raw [headers].
  static List<String> failedChecksFromHeaders(Map<String, String> headers) =>
      failedChecks(parse(headers));

  /// Map an [AuthClassification] back to its persisted string name
  /// (`green`/`yellow`/`red`/`grey`). Inverse of [classificationFromName].
  static String classificationToName(AuthClassification c) => c.name;

  /// Parse a persisted classification name back into an [AuthClassification].
  ///
  /// F96 (Sprint 43): used on the off-scan quick-add paths to re-hydrate the
  /// classification snapshot stored at scan time (`email_actions` /
  /// `unmatched_emails` `auth_classification` column). Returns null when
  /// [name] is null, empty, or unrecognized -- callers treat that as "no
  /// snapshot available; fall back to parsing the live headers".
  static AuthClassification? classificationFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final c in AuthClassification.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Synthesize a minimal [EmailAuthResult] consistent with a re-hydrated
  /// [classification], for paths that persisted only the classification enum
  /// (Sprint 43 Class-1 decision -- the raw `Authentication-Results` header is
  /// NOT stored). The result has no raw text and approximates per-protocol
  /// verdicts so the RED warning dialog renders coherently:
  ///   - RED:    spf/dkim/dmarc = fail (the dialog explains "what failed").
  ///   - others: all `none` (the dialog is only shown for RED).
  ///
  /// This is intentionally lossy: a re-hydrated RED warning fires (the
  /// anti-phishing goal) but cannot reproduce the original header breakdown.
  static EmailAuthResult syntheticResultFor(AuthClassification classification) {
    final failed = classification == AuthClassification.red;
    final verdict =
        failed ? AuthMethodResult.fail : AuthMethodResult.none;
    return EmailAuthResult(
      spf: verdict,
      dkim: verdict,
      dmarc: verdict,
      raw: '',
    );
  }

  // --- Internal helpers ---

  /// Case-insensitive header lookup. Returns null when absent or blank.
  static String? _lookup(Map<String, String> headers, String lowerName) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        final value = entry.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// Extract the result keyword for [method] (spf|dkim|dmarc) out of an
  /// `Authentication-Results` header value.
  ///
  /// The header is a sequence of `method=result` tokens, each optionally
  /// followed by `(comment)` and `tag=value` pairs, separated by `;`. For
  /// DKIM there may be multiple entries; we return the strongest verdict
  /// (pass beats fail beats softer results).
  static AuthMethodResult _extractMethod(String headerValue, String method) {
    if (headerValue.isEmpty) return AuthMethodResult.none;

    // Match `method = keyword`, tolerating whitespace and a leading `=`.
    // Word boundary on the method name avoids matching e.g. `dkim-adsp`.
    final pattern = RegExp(
      r'\b' + RegExp.escape(method) + r'\s*=\s*([a-zA-Z]+)',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(headerValue);
    if (matches.isEmpty) return AuthMethodResult.none;

    // Reduce to the strongest verdict across all occurrences.
    var best = AuthMethodResult.none;
    for (final m in matches) {
      final keyword = m.group(1)!.toLowerCase();
      final parsed = _keywordToResult(keyword);
      if (_strength(parsed) > _strength(best)) {
        best = parsed;
      }
    }
    return best;
  }

  /// Parse a standalone `Received-SPF` header value. The result keyword is
  /// the first token (RFC 7208 section 9.1: `Received-SPF: pass (...)`).
  static AuthMethodResult _parseReceivedSpf(String value) {
    final match = RegExp(r'^\s*([a-zA-Z]+)').firstMatch(value);
    if (match == null) return AuthMethodResult.none;
    return _keywordToResult(match.group(1)!.toLowerCase());
  }

  /// Map an RFC 8601 / RFC 7208 result keyword to [AuthMethodResult].
  static AuthMethodResult _keywordToResult(String keyword) {
    switch (keyword) {
      case 'pass':
        return AuthMethodResult.pass;
      case 'fail':
      case 'hardfail':
      case 'reject': // DMARC disposition seen as `dmarc=fail` but some MTAs
      case 'quarantine': // surface disposition keywords; treat as failure.
        return AuthMethodResult.fail;
      case 'softfail':
        return AuthMethodResult.softfail;
      case 'neutral':
        return AuthMethodResult.neutral;
      case 'none':
        return AuthMethodResult.none;
      case 'temperror':
      case 'error':
        return AuthMethodResult.temperror;
      case 'permerror':
        return AuthMethodResult.permerror;
      default:
        return AuthMethodResult.none;
    }
  }

  /// Ordering used to pick the "strongest" verdict when a method appears
  /// more than once (multiple DKIM signatures). Higher wins. Pass is the
  /// strongest positive signal; a fail should not be hidden by a later
  /// `none`, but a `pass` should win over a `fail` (at least one valid
  /// signature is enough for DKIM).
  static int _strength(AuthMethodResult r) {
    switch (r) {
      case AuthMethodResult.pass:
        return 6;
      case AuthMethodResult.fail:
        return 5;
      case AuthMethodResult.softfail:
        return 4;
      case AuthMethodResult.neutral:
        return 3;
      case AuthMethodResult.temperror:
        return 2;
      case AuthMethodResult.permerror:
        return 1;
      case AuthMethodResult.none:
        return 0;
    }
  }
}
