/// F33 (Sprint 46): Body-rules cleanup script.
///
/// One-time DB cleanup for user-created "body" condition rules. Body rules
/// live ONLY in the user's DB (the bundled asset rules.yaml has zero
/// non-empty body arrays -- verified 2026-07-07), so this is a DB-only
/// tool modelled on scripts/fix_tld_rules.dart, NOT an asset editor.
///
/// GROUP-FIRST approach (Harold 2026-07-02): classify every body rule into
/// a group, report the counts, and (only with --apply) transform per group.
/// Ambiguous rules are reported and left untouched, never guessed.
///
/// Groups:
///   G1 -- ALL domain-shaped body rules with a full `domain\.tld` (Option B,
///         Harold 2026-07-02): leading-slash `/domain\.tld`, leading-dot
///         `\.domain\.tld`, or bare `domain\.tld`. CONVERTED to a
///         URL-anchored regex:
///             (?:://|[/.])domain\.tld
///         which matches the domain as a URL host -- apex directly after
///         `://` (http://domain.tld), subdomain after `.`
///         (http://a.a.a.domain.tld), or in a path after `/` -- while
///         rejecting bare-text mentions, email addresses (bob@domain.tld),
///         and substrings (mydomain.tld).
///   G2 -- KEYWORD/PHRASE rules misclassified as domains: patternSubType
///         'entire_domain' but the body is a spaced phrase (e.g.
///         "camp lejeune"), with a mangled source_domain like
///         `camp\ lejeunecom`. The condition_body regex already matches
///         correctly; only the METADATA is wrong. RECLASSIFIED: set
///         patternSubType='keyword', clear the bogus source_domain. Body
///         regex unchanged.
///   G4 -- adamshetzner special-case removals (Harold 2026-07-02): every
///         rule whose body targets `adamshetzner` WITHOUT a full `.tld`
///         (i.e. `/adamshetzner\.` and `\.adamshetzner\.`) is REMOVED --
///         all should have included the .tld.
///   G5 -- orphan/degenerate rows: empty or missing condition_body on a
///         body-category rule. REMOVED (Harold 2026-07-02: "yes on the ~3
///         orphan rows").
///   G6 -- truncated / bare /-prefixed patterns with NO full `.tld`:
///         `/acslogeg\.` (trailing dot, no tld) or `/auenwind` (bare label,
///         no dot). REMOVED (Harold 2026-07-07: "these types can be removed
///         from the rules DB") -- too loose to be useful and cannot be
///         safely URL-anchored.
///   DUP -- exact source_domain collisions and near-duplicate roots
///         (e.g. `/adianeos\.com` and `\.adianeos\.com` both target
///         adianeos.com): keep one canonical rule per domain root, REMOVE
///         the rest. Runs AFTER classification so the surviving rule still
///         gets the G1 URL-anchored conversion.
///
/// Usage (dry-run report, NO writes -- default):
///   cd mobile-app
///   dart run scripts/cleanup_body_rules.dart              # dev DB
///   dart run scripts/cleanup_body_rules.dart --env prod   # prod DB
///
/// Usage (apply the cleanup -- backs up the DB first):
///   dart run scripts/cleanup_body_rules.dart --apply
///   dart run scripts/cleanup_body_rules.dart --env prod --apply
///
/// The report is written to docs/sprints/SPRINT_46_F33_BODY_RULES_REPORT.md
/// and printed to stdout.
library;

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final apply = args.contains('--apply');
  final envIndex = args.indexOf('--env');
  final env = (envIndex >= 0 && envIndex + 1 < args.length)
      ? args[envIndex + 1]
      : 'dev';

  final appDataPath = Platform.environment['APPDATA'];
  if (appDataPath == null) {
    stderr.writeln('[FAIL] APPDATA environment variable not found');
    exit(1);
  }
  final dataDir = env == 'prod'
      ? 'MyEmailSpamFilter'
      : 'MyEmailSpamFilter_Dev';
  final dbPath = '$appDataPath\\MyEmailSpamFilter\\$dataDir\\spam_filter.db';

  print('=== F33 Body-Rules Cleanup (${apply ? "APPLY" : "DRY-RUN"}) ===');
  print('Environment: $env');
  print('Database: $dbPath');
  print('');

  if (!File(dbPath).existsSync()) {
    stderr.writeln('[FAIL] Database not found at $dbPath');
    exit(1);
  }

  final db = await openDatabase(dbPath);

  // Load every body-condition rule.
  final rows = await db.query(
    'rules',
    columns: [
      'id',
      'name',
      'condition_body',
      'pattern_category',
      'pattern_sub_type',
      'source_domain',
    ],
    // Copilot review (Sprint 46), two rounds: the selection must be
    // (a) ALL body-category rows, INCLUDING those with a NULL/empty
    //     condition_body, so G5 (orphan removal) can see them -- the
    //     original filter excluded exactly the rows G5 exists for; and
    // (b) ONLY body-category rows -- a rule categorized under
    //     header_from/subject that also carries a body condition must NOT
    //     be reclassified/converted/removed by this body-cleanup script.
    // Legacy uncategorized rows (NULL/empty pattern_category) with a
    // non-empty body condition are still included, since pre-categorization
    // body rules had no pattern_category. (Dev-run evidence: every
    // body-condition rule carried pattern_category='body', so (b) is
    // defensive, not corrective.)
    where: "pattern_category = 'body' "
        "OR ((pattern_category IS NULL OR pattern_category = '') "
        "AND condition_body IS NOT NULL AND condition_body != '')",
  );

  final analysis = analyzeBodyRules(rows);
  final report = buildReport(analysis, env: env, apply: apply);

  // Resolve repo root: scripts/ lives under mobile-app/.
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final mobileAppDir = Directory(scriptDir).parent.path;
  final repoRoot = Directory(mobileAppDir).parent.path;
  final reportPath =
      '$repoRoot/docs/sprints/SPRINT_46_F33_BODY_RULES_REPORT.md';
  File(reportPath).writeAsStringSync(report);
  print(report);
  print('[OK] Report written to $reportPath');

  if (!apply) {
    print('');
    print('DRY-RUN only -- no changes made. Re-run with --apply to execute.');
    await db.close();
    return;
  }

  // --- APPLY path ---
  final backupPath = '$dbPath.backup_pre_f33_${env}_'
      '${DateTime.now().toIso8601String().replaceAll(RegExp(r"[:.]"), "-")}';
  print('');
  print('Backing up DB to: $backupPath');
  await db.close();
  File(dbPath).copySync(backupPath);
  final wdb = await openDatabase(dbPath);

  int reclassified = 0, removed = 0, converted = 0;
  await wdb.transaction((txn) async {
    // G2: reclassify keyword/phrase rules (metadata only).
    for (final r in analysis.keyword) {
      await txn.update(
        'rules',
        {'pattern_sub_type': 'keyword', 'source_domain': null},
        where: 'id = ?',
        whereArgs: [r.id],
      );
      reclassified++;
    }
    // G4 + G5 + DUP: removals.
    for (final r in analysis.toRemove) {
      await txn.delete('rules', where: 'id = ?', whereArgs: [r.id]);
      removed++;
    }
    // G1 + SPECIAL: rewrite condition_body (URL-anchored domains + the
    // hand-decided phone-number regex).
    for (final entry in analysis.allConversions.entries) {
      await txn.update(
        'rules',
        {'condition_body': jsonEncode([entry.value])},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
      converted++;
    }
  });

  print('[OK] Reclassified: $reclassified');
  print('[OK] Removed: $removed');
  print('[OK] Converted (G1 URL-anchored): $converted');
  print('[OK] Backup retained at: $backupPath');
  await wdb.close();
}

/// A single body-rule row, decoded.
class BodyRule {
  final int id;
  final String name;
  final String rawBody;
  final List<String> patterns;
  final String? subType;
  final String? sourceDomain;

  BodyRule({
    required this.id,
    required this.name,
    required this.rawBody,
    required this.patterns,
    required this.subType,
    required this.sourceDomain,
  });
}

class BodyRuleAnalysis {
  final List<BodyRule> all;
  final List<BodyRule> keyword; // G2 -- reclassify metadata
  final List<BodyRule> g1; // all domain-shaped w/ full .tld -- convert (Option B)
  final List<BodyRule> adamshetznerRemovals; // G4
  final List<BodyRule> orphans; // G5
  final List<BodyRule> truncated; // G6 -- truncated/bare /-prefixed, no tld
  final List<BodyRule> duplicateRemovals; // DUP
  final List<BodyRule> specialRemovals; // SPECIAL -- Harold hand-decided removals
  final List<BodyRule> ambiguous; // reported, untouched
  final Map<int, String> g1Conversions; // rule id -> new URL-anchored regex
  final Map<int, String> specialConversions; // SPECIAL -- hand-decided rewrites

  /// Everything to delete (G4 + G5 + G6 + DUP + SPECIAL), deduplicated by id.
  List<BodyRule> get toRemove {
    final seen = <int>{};
    final out = <BodyRule>[];
    for (final r in [
      ...adamshetznerRemovals,
      ...orphans,
      ...truncated,
      ...duplicateRemovals,
      ...specialRemovals,
    ]) {
      if (seen.add(r.id)) out.add(r);
    }
    return out;
  }

  /// All condition_body rewrites (G1 URL-anchoring + SPECIAL hand-decided).
  Map<int, String> get allConversions => {...g1Conversions, ...specialConversions};

  BodyRuleAnalysis({
    required this.all,
    required this.keyword,
    required this.g1,
    required this.adamshetznerRemovals,
    required this.orphans,
    required this.truncated,
    required this.duplicateRemovals,
    required this.specialRemovals,
    required this.ambiguous,
    required this.g1Conversions,
    required this.specialConversions,
  });
}

/// Extracts the domain root (`domain\.tld` unescaped -> `domain.tld`) from a
/// domain-shaped body pattern. Handles both families (Option B, Harold
/// 2026-07-02 -- convert ALL domain-shaped body rules, not just /-prefixed):
///   - URL-fragment / leading-slash: `/adianeos\.com`
///   - leading-dot "anywhere":       `\.adianeos\.com`
///   - bare:                          `adianeos\.com`
/// Requires a FULL `domain\.tld` (at least one escaped-dot segment after the
/// label). Returns null for patterns without a complete `.tld` (e.g.
/// `/adamshetzner\.`, bare `adamshetzner\.`) -- those are NOT convertible
/// and fall through to the G4/ambiguous handling upstream.
String? extractDomainRoot(String pattern) {
  var body = pattern;
  // Strip a single leading URL-path slash if present.
  if (body.startsWith('/')) body = body.substring(1);
  // Strip a single leading escaped-dot ("\." -> the "anywhere" anchor).
  if (body.startsWith(r'\.')) body = body.substring(2);
  // Strip a single trailing URL-path slash if present.
  if (body.endsWith('/')) body = body.substring(0, body.length - 1);
  // A label char is a letter/digit or an ESCAPED hyphen (`\-`); domains in
  // these patterns store hyphens escaped (e.g. `pic\-time\.net`). Require at
  // least one full `\.tld` segment.
  final m = RegExp(r'^((?:[a-z0-9]|\\-)+(?:\\\.(?:[a-z0-9]|\\-)+)+)$')
      .firstMatch(body);
  if (m == null) return null; // no full tld (trailing `\.` etc.)
  return m.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
}

/// Builds the F33 URL-anchored target regex for a domain root (dotted,
/// unescaped, e.g. "adianeos.com"). Matches the domain as a URL host:
/// apex directly after `://`, subdomain after `.`, or in a path after `/`.
///
/// Rejects bare-text mentions, substrings (`mydomain.tld`), and APEX-form
/// email addresses (`bob@domain.tld`). NOTE (Copilot review, Sprint 46): an
/// address at a SUBDOMAIN of the target (`bob@mail.domain.tld`) still
/// matches, because `.domain.tld` appears after a dot -- an accepted
/// tradeoff of Harold's approved `://*[/ or .]domain.tld` spec: mail sent
/// from a subdomain of a blocked spam domain is itself a block-worthy
/// signal.
String buildUrlAnchoredRegex(String domainRoot) {
  final escaped = domainRoot.replaceAll('.', r'\.');
  return '(?:://|[/.])$escaped';
}

/// SPECIAL cases (Harold hand-decided 2026-07-07) for the 3 rows the generic
/// classifier flagged ambiguous. Keys are the decoded condition_body pattern.
///
/// The phone-number rule `800\-571\-7438` is rewritten to a
/// format-tolerant regex matching 800-571-7438, (800) 571-7438,
/// 800.571.7438, (800)571-7438, "800 571 7438", and 8005717438.
const Map<String, String> kSpecialConversions = {
  r'800\-571\-7438': r'\(?800\)?[-. ]?571[-. ]?7438',
};

/// SPECIAL removals (Harold 2026-07-07): a bare-TLD rule and a
/// domain-with-path rule he chose to delete rather than convert.
const Set<String> kSpecialRemovals = {
  r'\.nl/',
  r'sys\-confg\.co\.uk/cl/',
};


BodyRuleAnalysis analyzeBodyRules(List<Map<String, Object?>> rows) {
  final all = <BodyRule>[];
  final keyword = <BodyRule>[];
  final g1 = <BodyRule>[];
  final adamshetzner = <BodyRule>[];
  final orphans = <BodyRule>[];
  final truncated = <BodyRule>[];
  final specialRemovals = <BodyRule>[];
  final specialConversions = <int, String>{};
  final ambiguous = <BodyRule>[];
  final g1Conversions = <int, String>{};

  for (final row in rows) {
    final id = row['id'] as int;
    final name = row['name'] as String? ?? '';
    final raw = row['condition_body'] as String? ?? '';
    final subType = row['pattern_sub_type'] as String?;
    final sourceDomain = row['source_domain'] as String?;

    List<String> patterns;
    try {
      final decoded = jsonDecode(raw);
      patterns =
          decoded is List ? decoded.map((e) => e.toString()).toList() : <String>[];
    } catch (_) {
      patterns = <String>[];
    }

    final rule = BodyRule(
      id: id,
      name: name,
      rawBody: raw,
      patterns: patterns,
      subType: subType,
      sourceDomain: sourceDomain,
    );
    all.add(rule);

    // G5: orphan/degenerate -- no usable pattern.
    if (patterns.isEmpty || patterns.every((p) => p.trim().isEmpty)) {
      orphans.add(rule);
      continue;
    }

    final single = patterns.length == 1 ? patterns.first : null;

    // SPECIAL: the 3 ambiguous rows Harold hand-decided (2026-07-07).
    if (single != null && kSpecialConversions.containsKey(single)) {
      specialConversions[id] = kSpecialConversions[single]!;
      continue;
    }
    if (single != null && kSpecialRemovals.contains(single)) {
      specialRemovals.add(rule);
      continue;
    }

    // G4: adamshetzner without a full .tld -> remove.
    if (patterns.any((p) =>
        p.contains('adamshetzner') && !RegExp(r'adamshetzner\\\.[a-z]').hasMatch(p))) {
      adamshetzner.add(rule);
      continue;
    }

    // G2: keyword/phrase misclassified as domain (spaced phrase in body).
    if (single != null && RegExp(r'\\ ').hasMatch(single)) {
      keyword.add(rule);
      continue;
    }

    // G1 (Option B): any domain-shaped body pattern with a full .tld
    // (leading-slash `/domain\.tld`, leading-dot `\.domain\.tld`, or bare
    // `domain\.tld`) -> convert to the URL-anchored regex. Harold
    // 2026-07-02: convert ALL domain-shaped body rules, so the .net/.com
    // "anywhere" family is included, not just the /-prefixed one.
    if (single != null) {
      final root = extractDomainRoot(single);
      if (root != null) {
        g1.add(rule);
        g1Conversions[id] = buildUrlAnchoredRegex(root);
        continue;
      }
      // G6 (Harold 2026-07-07, surfaced during dry-run): domain-LABEL-shaped
      // patterns with NO full `.tld` -> REMOVE. Reached only after the G1
      // full-`.tld` conversion above failed, so by construction these lack a
      // complete tld. Covers every anchor variant of the truncated/bare
      // family Harold approved removing:
      //   - leading-slash trailing-dot:  `/acslogeg\.`     (was G6 v1)
      //   - leading-slash bare label:    `/auenwind`
      //   - leading-dot trailing-dot:    `\.aalbody\.`     (non-slash sibling)
      //   - leading-@ trailing-dot:      `@jacksodoy\.`
      //   - bare label trailing-dot:     `18birdies\.`
      // The label test requires the core token to be domain-name-shaped
      // (letters/digits/hyphens/escaped-dots) so genuine non-domain bodies
      // (e.g. a phone number `800\-571\-7438`, keyword phrases) are NOT
      // swept in -- those stay ambiguous for separate review.
      final core = single
          .replaceFirst(RegExp(r'^[/@]'), '') // strip a leading / or @
          .replaceFirst(RegExp(r'^\\\.'), '') // strip a leading escaped dot
          .replaceFirst(RegExp(r'\\\.$'), ''); // strip a trailing escaped dot
      // Domain-label-shaped: letters/digits, escaped hyphens (`\-`), and
      // escaped-dot separators. MUST contain at least one letter so that
      // pure digit/hyphen bodies -- phone numbers like `800\-571\-7438`,
      // IP-ish fragments -- are NOT swept in; those stay ambiguous for
      // separate review. A pure escaped-dot label (`domain\.sub\.`) with
      // letters also qualifies.
      final labelChar = r'(?:[a-z0-9]|\\-)';
      final isDomainLabelShaped =
          RegExp('^$labelChar+(?:\\\\\\.$labelChar+)*\$').hasMatch(core) &&
              RegExp('[a-z]').hasMatch(core);
      if (isDomainLabelShaped) {
        truncated.add(rule);
        continue;
      }
    }

    // Anything else that does not cleanly fit -> ambiguous, report only
    // (e.g. phone numbers, punctuation-heavy bodies, multi-pattern arrays).
    ambiguous.add(rule);
  }

  // DUP: remove duplicates that target the same domain root. Canonical key
  // = normalized source_domain (lowercased, trailing junk trimmed) OR the
  // extracted G1 root. Keep the lowest-id rule per key; remove the rest.
  final byKey = <String, List<BodyRule>>{};
  String? keyFor(BodyRule r) {
    if (r.sourceDomain != null && r.sourceDomain!.trim().isNotEmpty) {
      return r.sourceDomain!.toLowerCase().trim();
    }
    if (r.patterns.length == 1) {
      return extractDomainRoot(r.patterns.first);
    }
    return null;
  }

  // Only consider dedup among rules NOT already slated for removal/keyword.
  // Excludes G4/G5/G6/SPECIAL removals so a valid G1 rule is never dropped
  // as a "duplicate" of an already-removed row sharing a source_domain, and
  // excludes G2 keyword rules (Copilot round 4): their source_domain is a
  // known-bogus artifact (e.g. `camp\ lejeunecom`), so letting them into
  // the dedup candidate set could silently drop a keyword rule whose bogus
  // source_domain happens to collide.
  final removalIds = {
    ...adamshetzner.map((r) => r.id),
    ...orphans.map((r) => r.id),
    ...truncated.map((r) => r.id),
    ...specialRemovals.map((r) => r.id),
    ...keyword.map((r) => r.id),
  };
  for (final r in all) {
    if (removalIds.contains(r.id)) continue;
    final key = keyFor(r);
    if (key == null) continue;
    byKey.putIfAbsent(key, () => []).add(r);
  }
  final duplicateRemovals = <BodyRule>[];
  for (final group in byKey.values) {
    if (group.length < 2) continue;
    group.sort((a, b) => a.id.compareTo(b.id));
    duplicateRemovals.addAll(group.skip(1)); // keep first, remove rest
  }
  // If a rule is being removed as a duplicate, drop any G1 conversion for it
  // AND remove it from the g1 list so the report group counts reconcile to
  // the total (a duplicate that is also domain-shaped must be counted once,
  // as a removal, not also as a conversion).
  final dupIds = duplicateRemovals.map((r) => r.id).toSet();
  for (final id in dupIds) {
    g1Conversions.remove(id);
  }
  g1.removeWhere((r) => dupIds.contains(r.id));

  return BodyRuleAnalysis(
    all: all,
    keyword: keyword,
    g1: g1,
    adamshetznerRemovals: adamshetzner,
    orphans: orphans,
    truncated: truncated,
    duplicateRemovals: duplicateRemovals,
    specialRemovals: specialRemovals,
    ambiguous: ambiguous,
    g1Conversions: g1Conversions,
    specialConversions: specialConversions,
  );
}

String buildReport(BodyRuleAnalysis a, {required String env, required bool apply}) {
  final b = StringBuffer();
  b.writeln('# Sprint 46 F33 -- Body Rules Cleanup Report');
  b.writeln();
  b.writeln('**Environment**: $env');
  b.writeln('**Mode**: ${apply ? "APPLY (changes written)" : "DRY-RUN (no changes)"}');
  b.writeln('**Total body-condition rules**: ${a.all.length}');
  b.writeln();
  b.writeln('## Group counts');
  b.writeln();
  b.writeln('| Group | Meaning | Action | Count |');
  b.writeln('|-------|---------|--------|-------|');
  b.writeln('| G1 | ALL domain-shaped w/ full `.tld` (Option B) | Convert to URL-anchored regex | ${a.g1.length} |');
  b.writeln('| G2 | keyword/phrase misclassified as domain | Reclassify metadata (body unchanged) | ${a.keyword.length} |');
  b.writeln('| G4 | adamshetzner without `.tld` | Remove | ${a.adamshetznerRemovals.length} |');
  b.writeln('| G5 | orphan / empty condition_body | Remove | ${a.orphans.length} |');
  b.writeln('| G6 | truncated/bare `/label\\.` or `/label`, no full tld | Remove | ${a.truncated.length} |');
  b.writeln('| DUP | same-domain-root duplicates | Remove all but first | ${a.duplicateRemovals.length} |');
  b.writeln('| SPECIAL | Harold hand-decided (phone-number rewrite + 2 removals) | Convert ${a.specialConversions.length} / Remove ${a.specialRemovals.length} | ${a.specialConversions.length + a.specialRemovals.length} |');
  b.writeln('| ? | ambiguous (does not fit) | Report only, untouched | ${a.ambiguous.length} |');
  b.writeln();
  b.writeln('**Net removals**: ${a.toRemove.length}. '
      '**Reclassified**: ${a.keyword.length}. '
      '**Converted**: ${a.allConversions.length} '
      '(G1 ${a.g1Conversions.length} + SPECIAL ${a.specialConversions.length}).');
  b.writeln();
  if (a.specialConversions.isNotEmpty || a.specialRemovals.isNotEmpty) {
    b.writeln('## SPECIAL (Harold hand-decided 2026-07-07)');
    b.writeln();
    final byId = {for (final r in a.all) r.id: r};
    for (final e in a.specialConversions.entries) {
      b.writeln('- CONVERT id=${e.key}: `${byId[e.key]?.rawBody}` -> `["${e.value}"]`');
    }
    for (final r in a.specialRemovals) {
      b.writeln('- REMOVE `${r.name}` body=`${r.rawBody}`');
    }
    b.writeln();
  }

  void sample(String title, List<BodyRule> rules, {int n = 15}) {
    b.writeln('## $title (${rules.length})');
    b.writeln();
    if (rules.isEmpty) {
      b.writeln('_None._');
      b.writeln();
      return;
    }
    for (final r in rules.take(n)) {
      b.writeln('- `${r.name}` body=`${r.rawBody}` subType=`${r.subType}` src=`${r.sourceDomain}`');
    }
    if (rules.length > n) b.writeln('- ... and ${rules.length - n} more');
    b.writeln();
  }

  b.writeln('## G1 conversions (sample)');
  b.writeln();
  final g1Sample = a.g1Conversions.entries.take(15).toList();
  if (g1Sample.isEmpty) {
    b.writeln('_None._');
  } else {
    final byId = {for (final r in a.all) r.id: r};
    for (final e in g1Sample) {
      final old = byId[e.key]?.rawBody ?? '?';
      b.writeln('- id=${e.key}: `$old` -> `["${e.value}"]`');
    }
    if (a.g1Conversions.length > 15) {
      b.writeln('- ... and ${a.g1Conversions.length - 15} more');
    }
  }
  b.writeln();

  sample('G2 keyword reclassifications', a.keyword);
  sample('G4 adamshetzner removals', a.adamshetznerRemovals);
  sample('G5 orphan removals', a.orphans);
  sample('G6 truncated/bare removals', a.truncated);
  sample('DUP duplicate removals', a.duplicateRemovals);
  sample('Ambiguous (untouched -- review)', a.ambiguous);

  return b.toString();
}
