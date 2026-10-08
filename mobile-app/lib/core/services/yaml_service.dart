import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import 'pattern_compiler.dart';

/// Handles YAML import/export for rules and safe senders
class YamlService {
  /// Maximum file size for YAML imports (10 MB)
  static const int maxImportFileSize = 10 * 1024 * 1024;

  /// Validate file size before reading
  Future<void> _validateFileSize(File file) async {
    final size = await file.length();
    if (size > maxImportFileSize) {
      throw FileSystemException(
        'File too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum allowed size is ${maxImportFileSize ~/ 1024 ~/ 1024} MB.',
        file.path,
      );
    }
  }

  /// Load rules from YAML file
  Future<RuleSet> loadRules(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Rules file not found', filePath);
    }
    await _validateFileSize(file);
    final content = await file.readAsString();
    final yaml = loadYaml(content);
    final converted = _convertYamlToMap(yaml);
    return RuleSet.fromMap(converted as Map<String, dynamic>);
  }
  
  /// Recursively convert YamlMap/YamlList to regular Map/List
  dynamic _convertYamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _convertYamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((item) => _convertYamlToMap(item)).toList();
    } else {
      return yaml;
    }
  }

  /// Parse rules from a YAML string (no file I/O)
  RuleSet parseRulesFromString(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    final converted = _convertYamlToMap(yaml);
    return RuleSet.fromMap(converted as Map<String, dynamic>);
  }

  /// Parse safe senders from a YAML string (no file I/O)
  SafeSenderList parseSafeSendersFromString(String yamlContent) {
    final yaml = loadYaml(yamlContent) as Map;
    return SafeSenderList.fromMap(Map<String, dynamic>.from(yaml));
  }

  /// Load safe senders from YAML file
  Future<SafeSenderList> loadSafeSenders(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Safe senders file not found', filePath);
    }
    await _validateFileSize(file);
    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map;
    return SafeSenderList.fromMap(Map<String, dynamic>.from(yaml));
  }

  /// F266 (Sprint 77): drop safe-sender patterns that can never match an
  /// address (see [PatternCompiler.detectUnmatchable]) from an imported list.
  /// Returns the cleaned list and one human-readable line per skipped entry,
  /// for the import screen to report. The persistence layer rejects the same
  /// patterns, so this filter only turns a hard failure into a reported skip.
  ///
  /// `droppedPatterns` is the number of entries removed (one per `skipped`
  /// line here); the import screen words its message from the counts, not
  /// from `skipped.length` (final review, finding 9).
  static ({SafeSenderList list, List<String> skipped, int droppedPatterns})
      sanitizeSafeSenders(SafeSenderList imported) {
    final kept = <String>[];
    final skipped = <String>[];
    for (final pattern in imported.safeSenders) {
      if (PatternCompiler.detectUnmatchable(pattern).isEmpty) {
        kept.add(pattern);
      } else {
        skipped.add('Safe sender "$pattern": requires more than one "@", '
            'can never match');
      }
    }
    return (
      list: SafeSenderList(safeSenders: kept),
      skipped: skipped,
      droppedPatterns: skipped.length,
    );
  }

  /// The import message for what the sanitizers removed, worded from the
  /// separate counts: `1 pattern`, `2 rules`, `1 rule and 3 patterns`.
  /// Empty when nothing was removed. One AND rule with one bad pattern is
  /// `1 rule`, not "2 entries", even though it writes two detail lines.
  static String describeDropped(
      {required int droppedRules, required int droppedPatterns}) {
    final parts = <String>[
      if (droppedRules > 0)
        '$droppedRules ${droppedRules == 1 ? 'rule' : 'rules'}',
      if (droppedPatterns > 0)
        '$droppedPatterns ${droppedPatterns == 1 ? 'pattern' : 'patterns'}',
    ];
    return parts.join(' and ');
  }

  /// F266 (Sprint 77): rules counterpart of [sanitizeSafeSenders]. The
  /// `from` lists get the full check ([PatternCompiler.detectUnmatchable]);
  /// subject and body are not checked.
  ///
  /// An OR rule loses just the unmatchable `from` pattern (it never matched,
  /// so behavior is unchanged), and the rule is skipped if that leaves it
  /// with no conditions. An AND rule is skipped whole: dropping one of its
  /// conditions would WIDEN what the rule matches. An unmatchable `from`
  /// exception is dropped (it never matched, so behavior is unchanged).
  ///
  /// `header` lists get ONLY the narrow stray-@ check
  /// ([PatternCompiler.hasStrayAtAfterDomainWildcard]): they hold `key:value`
  /// text for non-From headers, but the app stores its own From rules there.
  ///
  /// `droppedRules` counts rules removed whole; `droppedPatterns` counts bad
  /// patterns removed from rules that were KEPT. A pattern inside a dropped
  /// rule is not counted again. `skipped` is the per-line detail (a dropped
  /// rule writes one line per bad pattern plus a `skipped` line), so its
  /// length is not a count of anything.
  static ({
    RuleSet ruleSet,
    List<String> skipped,
    int droppedRules,
    int droppedPatterns,
  }) sanitizeRules(RuleSet imported) {
    final kept = <Rule>[];
    final skipped = <String>[];
    var droppedRules = 0;
    var droppedPatterns = 0;
    bool bad(String p) => PatternCompiler.detectUnmatchable(p).isNotEmpty;
    bool badHeader(String p) =>
        PatternCompiler.hasStrayAtAfterDomainWildcard(p);

    for (final rule in imported.rules) {
      final c = rule.conditions;
      final e = rule.exceptions;
      final badFrom = c.from.where(bad).toList();
      final badHeaders = c.header.where(badHeader).toList();
      final badExceptionFrom = (e?.from ?? const <String>[]).where(bad).toList();
      final badExceptionHeaders =
          (e?.header ?? const <String>[]).where(badHeader).toList();
      if (badFrom.isEmpty &&
          badHeaders.isEmpty &&
          badExceptionFrom.isEmpty &&
          badExceptionHeaders.isEmpty) {
        kept.add(rule);
        continue;
      }
      final allBad = [
        ...badFrom,
        ...badHeaders,
        ...badExceptionFrom,
        ...badExceptionHeaders,
      ];
      for (final p in allBad) {
        skipped.add('Rule "${rule.name}": pattern "$p" requires more than '
            'one "@", can never match');
      }
      final remainingFrom = c.from.where((p) => !bad(p)).toList();
      final remainingHeader = c.header.where((p) => !badHeader(p)).toList();
      final noConditionsLeft = remainingFrom.isEmpty &&
          remainingHeader.isEmpty &&
          c.subject.isEmpty &&
          c.body.isEmpty;
      if ((badFrom.isNotEmpty || badHeaders.isNotEmpty) &&
          (c.type == 'AND' || noConditionsLeft)) {
        skipped.add('Rule "${rule.name}": skipped');
        droppedRules++;
        continue;
      }
      droppedPatterns += allBad.length;
      kept.add(Rule(
        name: rule.name,
        enabled: rule.enabled,
        isLocal: rule.isLocal,
        executionOrder: rule.executionOrder,
        conditions: RuleConditions(
          type: c.type,
          from: remainingFrom,
          header: remainingHeader,
          subject: c.subject,
          body: c.body,
        ),
        actions: rule.actions,
        exceptions: e == null
            ? null
            : RuleExceptions(
                from: e.from.where((p) => !bad(p)).toList(),
                header: e.header.where((p) => !badHeader(p)).toList(),
                subject: e.subject,
                body: e.body,
              ),
        metadata: rule.metadata,
        patternCategory: rule.patternCategory,
        patternSubType: rule.patternSubType,
        sourceDomain: rule.sourceDomain,
      ));
    }
    return (
      ruleSet: RuleSet(
        version: imported.version,
        settings: imported.settings,
        rules: kept,
      ),
      skipped: skipped,
      droppedRules: droppedRules,
      droppedPatterns: droppedPatterns,
    );
  }

  /// The rules export text (normalized, sorted, single-quoted patterns),
  /// without touching any file. Sprint 74 MV: Android and iOS hand these
  /// bytes to the system save dialog, which writes the file itself.
  ///
  /// If [appVersion] is provided, the export will start with a comment line
  /// containing the version and export date. This is optional to keep the
  /// pure render function testable without version dependencies.
  String renderRules(RuleSet ruleSet, {String? appVersion}) =>
      _convertToYaml(_normalizeRuleSet(ruleSet).toMap(), appVersion: appVersion);

  /// The safe senders export text, without touching any file (see
  /// [renderRules]).
  String renderSafeSenders(SafeSenderList safeSenders, {String? appVersion}) =>
      _convertToYaml(_normalizeSafeSenders(safeSenders).toMap(), appVersion: appVersion);

  /// Export rules to YAML file with backup
  Future<void> exportRules(RuleSet ruleSet, String filePath,
      {String? appVersion}) async {
    // Create backup if file exists
    final file = File(filePath);
    if (await file.exists()) {
      await _createBackup(filePath);
    }
    await file.writeAsString(renderRules(ruleSet, appVersion: appVersion));
  }

  /// Export safe senders to YAML file with backup
  Future<void> exportSafeSenders(SafeSenderList safeSenders, String filePath,
      {String? appVersion}) async {
    // Create backup if file exists
    final file = File(filePath);
    if (await file.exists()) {
      await _createBackup(filePath);
    }
    await file.writeAsString(
        renderSafeSenders(safeSenders, appVersion: appVersion));
  }

  Future<void> _createBackup(String filePath) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final backupDir = '${_getDirectory(filePath)}/Archive';
    await Directory(backupDir).create(recursive: true);
    
    final fileName = _getFileName(filePath);
    final backupPath = '$backupDir/${fileName}_backup_$timestamp';
    await File(filePath).copy(backupPath);
  }

  RuleSet _normalizeRuleSet(RuleSet ruleSet) {
    final normalizedRules = ruleSet.rules.map((rule) {
      return Rule(
        name: rule.name,
        enabled: rule.enabled,
        isLocal: rule.isLocal,
        executionOrder: rule.executionOrder,
        conditions: RuleConditions(
          type: rule.conditions.type,
          from: _normalizeList(rule.conditions.from),
          header: _normalizeList(rule.conditions.header),
          subject: _normalizeList(rule.conditions.subject),
          body: _normalizeList(rule.conditions.body),
        ),
        actions: rule.actions,
        exceptions: rule.exceptions != null
            ? RuleExceptions(
                from: _normalizeList(rule.exceptions!.from),
                header: _normalizeList(rule.exceptions!.header),
                subject: _normalizeList(rule.exceptions!.subject),
                body: _normalizeList(rule.exceptions!.body),
              )
            : null,
        metadata: rule.metadata,
        patternCategory: rule.patternCategory,
        patternSubType: rule.patternSubType,
        sourceDomain: rule.sourceDomain,
      );
    }).toList();

    return RuleSet(
      version: ruleSet.version,
      settings: ruleSet.settings,
      rules: normalizedRules,
    );
  }

  SafeSenderList _normalizeSafeSenders(SafeSenderList safeSenders) {
    return SafeSenderList(
      safeSenders: _normalizeList(safeSenders.safeSenders),
    );
  }

  List<String> _normalizeList(List<String> items) {
    return items
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _convertToYaml(Map<String, dynamic> data, {String? appVersion}) {
    // Simple YAML conversion - for production use a proper YAML encoder
    final buffer = StringBuffer();

    // Prepend version and export date comment if version is provided
    if (appVersion != null) {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      buffer.writeln('# Exported by MyEmailSpamFilter $appVersion on $dateStr');
    }

    _writeYaml(buffer, data, 0);
    return buffer.toString();
  }

  void _writeYaml(StringBuffer buffer, dynamic value, int indent) {
    final spaces = '  ' * indent;
    
    if (value is Map) {
      value.forEach((key, val) {
        if (val is Map || val is List) {
          buffer.writeln('$spaces$key:');
          _writeYaml(buffer, val, indent + 1);
        } else {
          buffer.writeln('$spaces$key: ${_formatValue(val)}');
        }
      });
    } else if (value is List) {
      for (final item in value) {
        if (item is Map) {
          buffer.writeln('$spaces-');
          _writeYaml(buffer, item, indent + 1);
        } else {
          buffer.writeln('$spaces- ${_formatValue(item)}');
        }
      }
    }
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      final escaped = value.replaceAll("'", "''");
      return "'$escaped'";
    }
    return value.toString();
  }

  String _getDirectory(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    return lastSeparator >= 0 ? path.substring(0, lastSeparator) : '.';
  }

  String _getFileName(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    final nameWithExtension = lastSeparator >= 0 ? path.substring(lastSeparator + 1) : path;
    return nameWithExtension;
  }
}
