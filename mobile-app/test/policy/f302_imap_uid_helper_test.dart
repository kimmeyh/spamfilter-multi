/// F302 (Sprint 81) prevention gate: every consumer of an IMAP message id as a
/// UID goes through `parseImapUid` / `hasValidImapUid`
/// (`lib/core/services/imap_uid.dart`).
///
/// Why: a message the server sent without a UID holds the constant
/// `kNoValidImapUid`. The helper is the one place that refuses it AND writes
/// the diagnostic line naming the folder. A new `int.tryParse(message.id)` in
/// `lib/` would skip both: it would act on (or silently drop) the message with
/// no log line. The regex below reads `int.tryParse(` / `int.parse(` applied to
/// an id expression (`id`, `x.id`, `x.y.id`, `fooId`, `uid`).
///
/// A hit that is NOT a message id (an id of something else) is listed in
/// [_allowed] with the reason. The list is empty on purpose; add to it only
/// with a reason a reviewer can check.
///
/// What this does NOT catch: a parse written another way (`int.parse(m.id
/// .trim())`, `m.id.codeUnits`, a `switch` on the id string), an id copied
/// into a local with another name first (`final x = m.id; int.tryParse(x)`),
/// and a UID consumer that never parses (an opaque-identity use such as a map
/// key). The behavior tests in
/// `test/unit/adapters/f302_no_valid_imap_uid_test.dart` cover the consumers
/// that exist today; this gate only stops the plain new ones.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `int.tryParse(<id expression>)` or `int.parse(<id expression>)`.
final RegExp _idParse = RegExp(
    r'int\.(?:tryParse|parse)\(\s*(?:[A-Za-z_][\w]*[?!]?\.)*(?:id|uid|[A-Za-z]*Id)\s*\)');

/// path (forward slashes) -> reason. Empty: every hit in lib/ is a message id.
const Map<String, String> _allowed = {};

/// The helper itself parses the id once, after the refusal.
const String _helper = 'lib/core/services/imap_uid.dart';

List<String> _violations(Iterable<File> files) {
  final hits = <String>[];
  for (final f in files) {
    final path = f.path.replaceAll('\\', '/');
    if (path.endsWith(_helper) || _allowed.containsKey(path)) continue;
    final text = f.readAsStringSync();
    for (final m in _idParse.allMatches(text)) {
      final line = text.substring(0, m.start).split('\n').length;
      hits.add('$path:$line  ${m.group(0)}');
    }
  }
  return hits;
}

void main() {
  group('F302: no UID consumer bypasses the shared helper', () {
    test('the gate pattern matches the shapes it exists to catch', () {
      for (final bad in [
        'int.tryParse(message.id)',
        'int.tryParse(ev.message.id)',
        'int.tryParse(result.email.id)',
        'int.tryParse(id)',
        'int.parse( m.id )',
        'int.tryParse(messageId)',
        'int.tryParse(widget.email.id)',
      ]) {
        expect(_idParse.hasMatch(bad), isTrue, reason: bad);
      }
      for (final fine in [
        'int.tryParse(cursorStr)',
        'int.tryParse(parts[1])',
        'int.tryParse(message.id.trim())', // known gap, see the header
        'parseImapUid(message.id, folderName: f, context: c)',
      ]) {
        expect(_idParse.hasMatch(fine), isFalse, reason: fine);
      }
    });

    test('lib/ has no int.tryParse / int.parse of a message id outside the '
        'helper', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(_violations(files), isEmpty,
          reason: 'Use parseImapUid(id, folderName:, context:) from '
              'lib/core/services/imap_uid.dart. It refuses kNoValidImapUid and '
              'writes the diagnostic line naming the folder (F302).');
    });

    test('the gate fails on a probe consumer that bypasses the helper', () {
      final probeDir = Directory.systemTemp.createTempSync('f302_probe_');
      addTearDown(() => probeDir.deleteSync(recursive: true));
      final probe = File('${probeDir.path}/probe_consumer.dart')
        ..writeAsStringSync('''
Future<void> moveOne(dynamic message) async {
  final uid = int.tryParse(message.id);
  if (uid == null) return;
}
''');
      final hits = _violations([probe]);
      expect(hits, hasLength(1), reason: '$hits');
      expect(hits.single, contains('int.tryParse(message.id)'));

      final clean = File('${probeDir.path}/clean_consumer.dart')
        ..writeAsStringSync('''
import 'package:my_email_spam_filter/core/services/imap_uid.dart';
int? one(dynamic message) => parseImapUid(message.id,
    folderName: message.folderName, context: 'probe');
''');
      expect(_violations([clean]), isEmpty);
    });
  });
}
