/// TLD data-quality audit and ccTLD gap-fill tool (BUG-S37-2, Sprint 39).
///
/// This script operates on the bundled rule asset
/// `assets/rules/rules.yaml`, which is the authoritative source for default
/// (bundled) rules. It performs two independent jobs:
///
///   (a) DATA-QUALITY AUDIT (report only, never mutates):
///       Scans every `patternSubType: top_level_domain` rule and flags
///       candidates that look like typos (single-character TLDs, malformed
///       `xn-*` punycode, known junk strings) or second-level domains
///       masquerading as TLDs (for example `de.com`, `us.kg`). The flagged
///       items are written to a Markdown report for Harold to review and
///       decide upon manually. NOTHING is deleted or modified by the audit.
///
///   (b) ccTLD GAP ANALYSIS (report only here; application is a separate
///       deliberate step in the source code -- see VERIFY in the task and the
///       `_postSeedTldBlockPatterns` list in default_rule_set_service.dart):
///       Diffs the bundled top_level_domain set against the canonical ISO
///       3166-1 alpha-2 country-code list (embedded below, no network), and
///       reports which ccTLDs are MISSING (present in ISO, absent from the
///       bundled rules), excluding `.us`, `.uk`, and `.ca` which remain
///       allowed by Harold's decision (2026-05-25).
///
/// Usage:
///   cd mobile-app
///   dart run scripts/tld_audit_and_gapfill.dart
///
/// Output:
///   - Writes the audit + gap report to docs/sprints/SPRINT_39_TLD_AUDIT.md
///   - Prints a summary to stdout.
///
/// This script intentionally does NOT mutate rules.yaml or any database. It is
/// an analysis tool. The actual gap-fill (adding bundled rules) is applied in
/// the source so it covers both fresh installs (rules.yaml asset) and existing
/// installs (DefaultRuleSetService._postSeedTldBlockPatterns migration).

import 'dart:io';

/// Canonical ISO 3166-1 alpha-2 country codes (the two-letter ccTLD basis).
/// Embedded so the script never touches the network. This is the officially
/// assigned set (251 entries) including the exceptionally-reserved `uk` and
/// `eu` aliases that function as ccTLDs in DNS. `eu` is a supranational ccTLD
/// and is treated as a ccTLD here because it is already bundled.
const List<String> _isoCcTlds = <String>[
  'ad', 'ae', 'af', 'ag', 'ai', 'al', 'am', 'ao', 'aq', 'ar', 'as', 'at',
  'au', 'aw', 'ax', 'az', 'ba', 'bb', 'bd', 'be', 'bf', 'bg', 'bh', 'bi',
  'bj', 'bl', 'bm', 'bn', 'bo', 'bq', 'br', 'bs', 'bt', 'bv', 'bw', 'by',
  'bz', 'ca', 'cc', 'cd', 'cf', 'cg', 'ch', 'ci', 'ck', 'cl', 'cm', 'cn',
  'co', 'cr', 'cu', 'cv', 'cw', 'cx', 'cy', 'cz', 'de', 'dj', 'dk', 'dm',
  'do', 'dz', 'ec', 'ee', 'eg', 'eh', 'er', 'es', 'et', 'fi', 'fj', 'fk',
  'fm', 'fo', 'fr', 'ga', 'gb', 'gd', 'ge', 'gf', 'gg', 'gh', 'gi', 'gl',
  'gm', 'gn', 'gp', 'gq', 'gr', 'gs', 'gt', 'gu', 'gw', 'gy', 'hk', 'hm',
  'hn', 'hr', 'ht', 'hu', 'id', 'ie', 'il', 'im', 'in', 'io', 'iq', 'ir',
  'is', 'it', 'je', 'jm', 'jo', 'jp', 'ke', 'kg', 'kh', 'ki', 'km', 'kn',
  'kp', 'kr', 'kw', 'ky', 'kz', 'la', 'lb', 'lc', 'li', 'lk', 'lr', 'ls',
  'lt', 'lu', 'lv', 'ly', 'ma', 'mc', 'md', 'me', 'mf', 'mg', 'mh', 'mk',
  'ml', 'mm', 'mn', 'mo', 'mp', 'mq', 'mr', 'ms', 'mt', 'mu', 'mv', 'mw',
  'mx', 'my', 'mz', 'na', 'nc', 'ne', 'nf', 'ng', 'ni', 'nl', 'no', 'np',
  'nr', 'nu', 'nz', 'om', 'pa', 'pe', 'pf', 'pg', 'ph', 'pk', 'pl', 'pm',
  'pn', 'pr', 'ps', 'pt', 'pw', 'py', 'qa', 're', 'ro', 'rs', 'ru', 'rw',
  'sa', 'sb', 'sc', 'sd', 'se', 'sg', 'sh', 'si', 'sj', 'sk', 'sl', 'sm',
  'sn', 'so', 'sr', 'ss', 'st', 'sv', 'sx', 'sy', 'sz', 'tc', 'td', 'tf',
  'tg', 'th', 'tj', 'tk', 'tl', 'tm', 'tn', 'to', 'tr', 'tt', 'tv', 'tw',
  'tz', 'ua', 'ug', 'uk', 'um', 'us', 'uy', 'uz', 'va', 'vc', 've', 'vg',
  'vi', 'vn', 'vu', 'wf', 'ws', 'ye', 'yt', 'za', 'zm', 'zw', 'eu',
];

/// ccTLDs that remain ALLOWED (not blocked) by Harold's decision 2026-05-25.
const Set<String> _excludedCcTlds = <String>{'us', 'uk', 'ca'};

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  // scripts/ lives under mobile-app/. Resolve repo root two levels up.
  final mobileAppDir = Directory(scriptDir).parent.path;
  final repoRoot = Directory(mobileAppDir).parent.path;

  final rulesYamlPath = '$mobileAppDir/assets/rules/rules.yaml';
  final reportPath = '$repoRoot/docs/sprints/SPRINT_39_TLD_AUDIT.md';

  final rulesFile = File(rulesYamlPath);
  if (!rulesFile.existsSync()) {
    stderr.writeln('[FAIL] rules.yaml not found at $rulesYamlPath');
    exit(1);
  }

  final lines = rulesFile.readAsLinesSync();

  // Parse the bundled top_level_domain TLDs by walking the simple, regular
  // structure of the rebuilt rules.yaml. Each rule is a `- name:` block; a
  // rule is a top_level_domain TLD rule when it carries
  // `patternSubType: top_level_domain` and a header pattern of the shape
  // '@.*\.<tld>$'. We capture the <tld> token for each such rule.
  final headerPatternRe = RegExp(r"^\s*-\s*'@\.\*\\\.([a-z0-9.-]+)\$'\s*$");

  // Collect (tld, ruleName) for every top_level_domain rule.
  final bundledTlds = <String>{};
  final bundledTldOccurrences = <String>[]; // includes duplicates for audit
  // Any header pattern of the TLD shape (regardless of patternSubType). This
  // catches dotted second-level domains that the rebuild misclassified as
  // exact_domain (for example `qzz.io`), which the audit must still flag.
  final allTldShapedTokens = <String, String>{}; // token -> ruleName
  String? pendingHeaderTld;
  String? currentRuleName;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final nameMatch = RegExp(r'^\-\s*name:\s*(.+)\s*$').firstMatch(line);
    if (nameMatch != null) {
      currentRuleName = nameMatch.group(1)!.trim();
      pendingHeaderTld = null;
      continue;
    }
    final hMatch = headerPatternRe.firstMatch(line);
    if (hMatch != null) {
      pendingHeaderTld = hMatch.group(1);
      allTldShapedTokens[hMatch.group(1)!] = currentRuleName ?? 'unknown';
      continue;
    }
    if (line.trim() == 'patternSubType: top_level_domain') {
      final tld = pendingHeaderTld;
      if (tld != null) {
        bundledTlds.add(tld);
        bundledTldOccurrences.add('$tld\t($currentRuleName)');
      }
    }
  }

  // -------------------------------------------------------------------------
  // SUB-TASK (a): data-quality audit (candidates only, no auto-apply).
  // -------------------------------------------------------------------------
  final singleCharCandidates = <String>[];
  final junkCandidates = <String>[];
  final malformedPunycodeCandidates = <String>[];
  final secondLevelCandidates = <String>[];

  // Known junk strings observed in the bundled set (from BUG-S37-2 brief).
  const knownJunk = <String>{
    'giw', 'nwm', 'sweepss', 'xd',
  };

  // Second-level masquerade check scans ALL TLD-shaped header patterns,
  // because the rebuild script classifies dotted forms (for example
  // `qzz.io`) as exact_domain rather than top_level_domain.
  for (final token in allTldShapedTokens.keys.toList()..sort()) {
    if (token.contains('.')) {
      secondLevelCandidates.add(token);
    }
  }

  for (final tld in bundledTlds.toList()..sort()) {
    if (tld.contains('.')) {
      // Already handled by the all-tokens scan above.
      continue;
    }
    if (tld.length == 1) {
      singleCharCandidates.add(tld);
      continue;
    }
    if (tld.startsWith('xn-') && !tld.startsWith('xn--')) {
      // Valid punycode TLDs use the `xn--` prefix (two hyphens). A single
      // hyphen is malformed.
      malformedPunycodeCandidates.add(tld);
      continue;
    }
    if (knownJunk.contains(tld)) {
      junkCandidates.add(tld);
      continue;
    }
  }

  // -------------------------------------------------------------------------
  // SUB-TASK (b): ccTLD gap analysis.
  // -------------------------------------------------------------------------
  final presentCcTlds = <String>[];
  final missingCcTlds = <String>[];
  for (final cc in _isoCcTlds) {
    if (_excludedCcTlds.contains(cc)) continue;
    if (bundledTlds.contains(cc)) {
      presentCcTlds.add(cc);
    } else {
      missingCcTlds.add(cc);
    }
  }
  presentCcTlds.sort();
  missingCcTlds.sort();

  // -------------------------------------------------------------------------
  // Build the report.
  // -------------------------------------------------------------------------
  final buf = StringBuffer();
  buf.writeln('# Sprint 39 -- TLD Data-Quality Audit and ccTLD Gap Analysis');
  buf.writeln();
  buf.writeln('Generated by `mobile-app/scripts/tld_audit_and_gapfill.dart` '
      '(BUG-S37-2).');
  buf.writeln();
  buf.writeln('Source: `mobile-app/assets/rules/rules.yaml` '
      '(authoritative bundled rule set).');
  buf.writeln();
  buf.writeln('This report is ANALYSIS ONLY. The audit section never mutates '
      'rules. Review the candidates and decide manually via the Manage Rules '
      'screen.');
  buf.writeln();
  buf.writeln('## Summary');
  buf.writeln();
  buf.writeln('- Bundled `top_level_domain` rules: '
      '${bundledTldOccurrences.length}');
  buf.writeln('- Distinct bundled TLDs: ${bundledTlds.length}');
  buf.writeln('- ISO 3166-1 alpha-2 ccTLDs considered: ${_isoCcTlds.length}');
  buf.writeln('- ccTLDs excluded (stay allowed): '
      '${_excludedCcTlds.join(', ')}');
  buf.writeln('- ccTLDs already present (excl. allowed): '
      '${presentCcTlds.length}');
  buf.writeln('- ccTLDs MISSING (excl. allowed): ${missingCcTlds.length}');
  buf.writeln('- Audit candidates total: '
      '${singleCharCandidates.length + junkCandidates.length + malformedPunycodeCandidates.length + secondLevelCandidates.length}');
  buf.writeln();

  buf.writeln('## Sub-task (a): Data-Quality Audit Candidates (review only)');
  buf.writeln();
  buf.writeln('### Single-character TLDs (likely typos)');
  buf.writeln();
  if (singleCharCandidates.isEmpty) {
    buf.writeln('- None.');
  } else {
    for (final t in singleCharCandidates) {
      buf.writeln('- `.$t`');
    }
  }
  buf.writeln();
  buf.writeln('### Known junk strings');
  buf.writeln();
  if (junkCandidates.isEmpty) {
    buf.writeln('- None.');
  } else {
    for (final t in junkCandidates) {
      buf.writeln('- `.$t`');
    }
  }
  buf.writeln();
  buf.writeln('### Malformed punycode (xn- with single hyphen)');
  buf.writeln();
  if (malformedPunycodeCandidates.isEmpty) {
    buf.writeln('- None.');
  } else {
    for (final t in malformedPunycodeCandidates) {
      buf.writeln('- `.$t`');
    }
  }
  buf.writeln();
  buf.writeln('### Second-level domains masquerading as TLDs');
  buf.writeln();
  if (secondLevelCandidates.isEmpty) {
    buf.writeln('- None.');
  } else {
    for (final t in secondLevelCandidates) {
      buf.writeln('- `.$t`');
    }
  }
  buf.writeln();

  buf.writeln('## Sub-task (b): ccTLD Gap Analysis');
  buf.writeln();
  buf.writeln('### ccTLDs MISSING from bundled rules (excl. us/uk/ca)');
  buf.writeln();
  buf.writeln('Count: ${missingCcTlds.length}');
  buf.writeln();
  if (missingCcTlds.isEmpty) {
    buf.writeln('- None. Bundled set already covers every ISO ccTLD '
        '(except the three allowed).');
  } else {
    buf.writeln(missingCcTlds.map((t) => '`.$t`').join(', '));
  }
  buf.writeln();
  buf.writeln('### ccTLDs already present (excl. us/uk/ca)');
  buf.writeln();
  buf.writeln('Count: ${presentCcTlds.length}');
  buf.writeln();
  buf.writeln(presentCcTlds.map((t) => '`.$t`').join(', '));
  buf.writeln();

  final reportFile = File(reportPath);
  reportFile.parent.createSync(recursive: true);
  reportFile.writeAsStringSync(buf.toString());

  // -------------------------------------------------------------------------
  // stdout summary.
  // -------------------------------------------------------------------------
  stdout.writeln('=== TLD Audit + ccTLD Gap Analysis (BUG-S37-2) ===');
  stdout.writeln('Bundled top_level_domain rules : '
      '${bundledTldOccurrences.length}');
  stdout.writeln('Distinct bundled TLDs          : ${bundledTlds.length}');
  stdout.writeln('ISO ccTLDs considered          : ${_isoCcTlds.length}');
  stdout.writeln('ccTLDs present (excl us/uk/ca) : ${presentCcTlds.length}');
  stdout.writeln('ccTLDs MISSING (excl us/uk/ca) : ${missingCcTlds.length}');
  stdout.writeln('Audit candidates               : '
      '${singleCharCandidates.length + junkCandidates.length + malformedPunycodeCandidates.length + secondLevelCandidates.length}');
  stdout.writeln('  single-char  : ${singleCharCandidates.join(', ')}');
  stdout.writeln('  junk         : ${junkCandidates.join(', ')}');
  stdout.writeln('  malformed xn : ${malformedPunycodeCandidates.join(', ')}');
  stdout.writeln('  second-level : ${secondLevelCandidates.join(', ')}');
  stdout.writeln('Report written to: $reportPath');
  stdout.writeln();
  if (missingCcTlds.length > 30) {
    stdout.writeln('[WARNING] Missing ccTLD count is large '
        '(${missingCcTlds.length}). The bundled set is mostly gTLDs, not '
        'ccTLDs. Surface this to Harold before bulk-adding.');
  }
  stdout.writeln('Missing list: ${missingCcTlds.join(' ')}');
}
