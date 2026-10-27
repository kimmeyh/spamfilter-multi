/// F302 (Sprint 81) prevention gate: every consumer of an IMAP message id as a
/// UID goes through `parseImapUid` / `hasValidImapUid`
/// (`lib/core/services/imap_uid.dart`).
///
/// Why: a message the server sent without a UID holds the constant
/// `kNoValidImapUid`. The helper is the one place that refuses it AND writes
/// the diagnostic line naming the folder. A new `int.tryParse(message.id)` in
/// `lib/` would skip both: it would act on (or silently drop) the message with
/// no log line.
///
/// Sprint 81 retro IMP-4: the gate matches the OPERATION, not a list of
/// argument names (the first version matched id-like names and missed
/// `identifierValue`). Every `int.parse` / `int.tryParse` in `lib/` -- a call
/// or a tear-off such as `.map(int.parse)` -- is compared, by its exact call
/// text and count, with [_reviewed]: calls a person has read and judged not to
/// parse a message id. A new call anywhere, whatever its argument is named,
/// fails until it is reviewed: it goes through the helper, or its text, count
/// and reason are added here. Keying by call text (7.7.1 improvement review
/// M-2) means swapping a reviewed call for a new one in the same file also
/// fails; a per-file count alone did not.
///
/// What this does NOT catch: a UID consumer that never calls `int.parse` /
/// `int.tryParse` (`num.parse`, `BigInt.parse`, a `switch` on the id string,
/// an opaque map key); a new call whose text is IDENTICAL to a reviewed one
/// and replaces it (for example `int.tryParse(value)` where `value` now holds a
/// message id); and a call written inside a comment or string, which is
/// counted (strict on purpose). The behavior tests in
/// `test/unit/adapters/f302_no_valid_imap_uid_test.dart` cover the consumers
/// that exist today.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A call or a tear-off (7.7.1 improvement review L-1: `\(` missed
/// `.map(int.parse)`).
final RegExp _parse = RegExp(r'\bint\.(?:tryParse|parse)\b');

/// The helper itself parses the id once, after the refusal.
const String _helper = 'lib/core/services/imap_uid.dart';

/// path (from `lib/`, forward slashes) -> {call text (whitespace collapsed):
/// count}. Reviewed 2026-10-26; none parses a message id. The reason per file
/// is in the trailing comment.
const Map<String, Map<String, int>> _reviewed = {
  // OAuth expires_in.
  'lib/adapters/auth/google_auth_service.dart': {
    "int.tryParse(expiresInStr ?? '3600')": 1,
  },
  // IMAP port setting.
  'lib/adapters/email_providers/custom_imap_settings.dart': {
    "int.tryParse((params[keyPort] ?? '').trim())": 1,
  },
  // Gmail internalDate (ms).
  'lib/adapters/email_providers/gmail_api_adapter.dart': {
    "int.tryParse(internalDate ?? '')": 1,
  },
  // Gmail internalDate (ms).
  'lib/adapters/gmail/gmail_client.dart': {
    "int.parse(response['internalDate'] as String? ?? '0')": 1,
  },
  // YAML integer field.
  'lib/core/models/rule_set.dart': {'int.tryParse(value)': 1},
  // Epoch millis in a deferral record.
  'lib/core/services/background_deferral_ingest.dart': {
    'int.tryParse(parts[0].trim())': 1,
  },
  // HTML numeric character references.
  'lib/core/services/content_text_extractor.dart': {
    'int.tryParse(m[1]!)': 1,
    'int.tryParse(m[1]!, radix: 16)': 1,
  },
  // The stored oldest-no-rule cursor: written by the app from a UID that
  // already passed parseImapUid, never a message id.
  'lib/core/services/email_scanner.dart': {'int.tryParse(cursorStr)': 1},
  // Epoch millis in a trigger record.
  'lib/core/services/new_mail_trigger.dart': {
    'int.tryParse(raw.substring(0, bar))': 1,
    'int.tryParse(parts[0])': 1,
  },
  // Regex quantifier bound.
  'lib/core/services/pattern_compiler.dart': {'int.parse(m.group(1)!)': 1},
  // Stored setting values (intervals, days, times, counts).
  'lib/core/storage/settings_store.dart': {
    'int.tryParse(value)': 9,
    "int.tryParse(ownRows.first['setting_value'] as String? ?? '')": 1,
    "int.tryParse(r['setting_value'] as String? ?? '')": 1,
  },
  // IMAP port field.
  'lib/ui/screens/account_setup_screen.dart': {
    'int.tryParse(_portController.text.trim())': 2,
  },
  // OAuth expires_in.
  'lib/ui/screens/gmail_webview_oauth_screen.dart': {
    "int.tryParse(expiresInStr ?? '3600')": 1,
  },
  // Execution order field.
  'lib/ui/screens/rule_edit_screen.dart': {
    'int.tryParse(_executionOrderController.text.trim())': 1,
    'int.tryParse(value.trim())': 1,
  },
  // Days field.
  'lib/ui/screens/settings_screen.dart': {'int.tryParse(value)': 1},
  // Interval number field.
  'lib/ui/widgets/scan_interval_control.dart': {
    'int.tryParse(_number.text.trim())': 1,
  },
};

String _rel(String path) {
  final p = path.replaceAll('\\', '/');
  final i = p.lastIndexOf('lib/');
  return i < 0 ? p : p.substring(i);
}

/// The call text at [m]: through the matching `)` for a call, or the bare
/// name for a tear-off. Whitespace collapsed so formatting does not matter.
String _callText(String text, RegExpMatch m) {
  var end = m.end;
  if (end < text.length && text[end] == '(') {
    var depth = 0;
    for (var j = end; j < text.length; j++) {
      if (text[j] == '(') depth++;
      if (text[j] == ')' && --depth == 0) {
        end = j + 1;
        break;
      }
    }
  }
  return text.substring(m.start, end).replaceAll(RegExp(r'\s+'), ' ');
}

/// Every call that is not reviewed, and every reviewed count that differs.
List<String> _violations(Iterable<File> files,
    {Map<String, Map<String, int>> reviewed = _reviewed}) {
  final out = <String>[];
  for (final f in files) {
    final rel = _rel(f.path);
    if (rel == _helper) continue;
    final text = f.readAsStringSync();
    final found = <String, List<int>>{};
    for (final m in _parse.allMatches(text)) {
      found
          .putIfAbsent(_callText(text, m), () => [])
          .add(text.substring(0, m.start).split('\n').length);
    }
    final allowed = reviewed[rel] ?? const <String, int>{};
    for (final call in {...found.keys, ...allowed.keys}) {
      final lines = found[call] ?? const <int>[];
      final want = allowed[call] ?? 0;
      if (lines.length != want) {
        out.add('$rel: "$call" found ${lines.length} time(s) at lines $lines, '
            '$want reviewed');
      }
    }
  }
  return out;
}

void main() {
  group('F302: no UID consumer bypasses the shared helper', () {
    test('every int.parse / int.tryParse in lib/ is a reviewed call', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(_violations(files), isEmpty,
          reason: 'A message id is parsed only by parseImapUid(id, '
              'folderName:, context:) from lib/core/services/imap_uid.dart '
              '(it refuses kNoValidImapUid and logs the folder, F302). If the '
              'new call is NOT a message id, add its text, count and reason '
              'to _reviewed.');
    });

    test('every reviewed file still exists (no stale entries)', () {
      for (final path in _reviewed.keys) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('the gate fails on probe consumers, whatever the argument is named',
        () {
      final probeDir = Directory.systemTemp.createTempSync('f302_probe_');
      addTearDown(() => probeDir.deleteSync(recursive: true));
      File probe(String name, String body) =>
          File('${probeDir.path}/lib/$name')
            ..createSync(recursive: true)
            ..writeAsStringSync(body);

      final direct = probe('direct.dart',
          'int? a(dynamic m) => int.tryParse(m.id);\n');
      final renamed = probe('renamed.dart',
          'int? b(String identifierValue) => int.parse(identifierValue);\n');
      final viaLocal = probe('via_local.dart',
          'int? c(dynamic m) { final x = m.id; return int.tryParse(x); }\n');
      final tearOff = probe('tear_off.dart',
          'List<int> d(List<String> ids) => ids.map(int.parse).toList();\n');
      for (final f in [direct, renamed, viaLocal, tearOff]) {
        expect(_violations([f]), hasLength(1), reason: f.path);
      }

      // A reviewed file that gains one more call fails.
      const reviewedProbe = {
        'lib/grown.dart': {'int.tryParse(s)': 1},
        'lib/swapped.dart': {'int.tryParse(s)': 1},
      };
      final grown = probe('grown.dart',
          'int? e(String s) => int.tryParse(s);\n'
          'int? f(dynamic m) => int.tryParse(m.id);\n');
      expect(_violations([grown], reviewed: reviewedProbe), hasLength(1));

      // M-2: the reviewed call removed and a new one added -- same count.
      final swapped = probe('swapped.dart',
          'int? g(dynamic m) => int.tryParse(m.id);\n');
      expect(_violations([swapped], reviewed: reviewedProbe), hasLength(2),
          reason: 'the new call is not reviewed, and the reviewed one is gone');

      final clean = probe('clean.dart', '''
import 'package:my_email_spam_filter/core/services/imap_uid.dart';
int? one(dynamic message) => parseImapUid(message.id,
    folderName: message.folderName, context: 'probe');
''');
      expect(_violations([clean]), isEmpty);
    });
  });
}
