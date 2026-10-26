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
/// argument names. The first version matched `int.tryParse(<id-like name>)`
/// and missed `identifierValue` (7.7.1 review). Now EVERY `int.parse(` /
/// `int.tryParse(` in `lib/` is counted per file against [_reviewed], a list
/// of parse sites a person has read and judged not to be a message-id parse.
/// A new parse anywhere -- whatever its argument is called, and including an
/// id copied into a local first -- fails until it is reviewed: either it goes
/// through the helper, or its file's count and reason are updated here.
///
/// What this does NOT catch: a UID consumer that never calls `int.parse` /
/// `int.tryParse` (`num.parse`, `BigInt.parse`, a `switch` on the id string, an
/// opaque map key), and a reviewed parse whose argument is later changed to a
/// message id without adding a parse. The behavior tests in
/// `test/unit/adapters/f302_no_valid_imap_uid_test.dart` cover the consumers
/// that exist today.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _parse = RegExp(r'\bint\.(?:tryParse|parse)\(');

/// The helper itself parses the id once, after the refusal.
const String _helper = 'lib/core/services/imap_uid.dart';

/// path (from `lib/`, forward slashes) -> (count, reason). Each count is the
/// number of `int.parse(` / `int.tryParse(` calls in that file, all reviewed
/// 2026-10-26 as NOT parsing a message id.
const Map<String, (int, String)> _reviewed = {
  'lib/adapters/gmail/gmail_client.dart': (1, 'Gmail internalDate (ms)'),
  'lib/adapters/auth/google_auth_service.dart': (1, 'OAuth expires_in'),
  'lib/adapters/email_providers/custom_imap_settings.dart': (1, 'IMAP port'),
  'lib/adapters/email_providers/gmail_api_adapter.dart':
      (1, 'Gmail internalDate (ms)'),
  'lib/core/models/rule_set.dart': (1, 'YAML integer field'),
  'lib/ui/screens/account_setup_screen.dart': (2, 'IMAP port field'),
  'lib/ui/screens/gmail_webview_oauth_screen.dart': (1, 'OAuth expires_in'),
  'lib/core/storage/settings_store.dart':
      (11, 'stored setting values (intervals, days, times, counts)'),
  'lib/ui/widgets/scan_interval_control.dart': (1, 'interval number field'),
  'lib/core/services/background_deferral_ingest.dart':
      (1, 'epoch millis in a deferral record'),
  'lib/ui/screens/rule_edit_screen.dart': (2, 'execution order field'),
  'lib/core/services/content_text_extractor.dart':
      (2, 'HTML numeric character references'),
  'lib/core/services/email_scanner.dart': (
    1,
    'the stored oldest-no-rule cursor: written by the app from a UID that '
        'already passed parseImapUid, never a message id'
  ),
  'lib/ui/screens/settings_screen.dart': (1, 'days field'),
  'lib/core/services/new_mail_trigger.dart':
      (2, 'epoch millis in a trigger record'),
  'lib/core/services/pattern_compiler.dart': (1, 'regex quantifier bound'),
};

String _rel(String path) {
  final p = path.replaceAll('\\', '/');
  final i = p.lastIndexOf('lib/');
  return i < 0 ? p : p.substring(i);
}

/// Every file whose parse count differs from [_reviewed], with its lines.
List<String> _violations(Iterable<File> files,
    {Map<String, (int, String)> reviewed = _reviewed}) {
  final out = <String>[];
  for (final f in files) {
    final rel = _rel(f.path);
    if (rel == _helper) continue;
    final text = f.readAsStringSync();
    final hits = _parse.allMatches(text).toList();
    final allowed = reviewed[rel]?.$1 ?? 0;
    if (hits.length != allowed) {
      final lines = [
        for (final m in hits) text.substring(0, m.start).split('\n').length
      ];
      out.add('$rel: ${hits.length} int.parse/tryParse call(s) at lines '
          '$lines, $allowed reviewed');
    }
  }
  return out;
}

void main() {
  group('F302: no UID consumer bypasses the shared helper', () {
    test('every int.parse / int.tryParse in lib/ is reviewed (count per file)',
        () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(_violations(files), isEmpty,
          reason: 'A message id is parsed only by parseImapUid(id, '
              'folderName:, context:) from lib/core/services/imap_uid.dart '
              '(it refuses kNoValidImapUid and logs the folder, F302). If the '
              'new parse is NOT a message id, update its file count and '
              'reason in _reviewed.');
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

      // The shapes the name-based regex caught, and the two it missed.
      final direct = probe('direct.dart',
          'int? a(dynamic m) => int.tryParse(m.id);\n');
      final renamed = probe('renamed.dart',
          'int? b(String identifierValue) => int.parse(identifierValue);\n');
      final viaLocal = probe('via_local.dart',
          'int? c(dynamic m) { final x = m.id; return int.tryParse(x); }\n');
      for (final f in [direct, renamed, viaLocal]) {
        expect(_violations([f]), hasLength(1), reason: f.path);
      }

      // A reviewed file that gains one more parse fails too.
      final grown = probe('grown.dart',
          'int? d(String s) => int.tryParse(s);\n'
          'int? e(dynamic m) => int.tryParse(m.id);\n');
      expect(
          _violations([grown], reviewed: {'lib/grown.dart': (1, 'probe')}),
          hasLength(1));

      final clean = probe('clean.dart', '''
import 'package:my_email_spam_filter/core/services/imap_uid.dart';
int? one(dynamic message) => parseImapUid(message.id,
    folderName: message.folderName, context: 'probe');
''');
      expect(_violations([clean]), isEmpty);
    });
  });
}
