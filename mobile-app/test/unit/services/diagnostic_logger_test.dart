/// F233 (Sprint 72): the diagnostic log exists so a FAILURE can be read off an
/// installed build.
///
/// **What made this necessary.** Sprint 71 found two defects that reproduce on
/// demand -- F228 (a green success toast over a failed IMAP action) and F232
/// (rules from a historical view never reaching the mailbox) -- and neither
/// could be diagnosed, because the decisive lines were written by a bare
/// `Logger()` with no file sink. A grep for "F38" across every Windows log back
/// to 0.5.8 returned nothing.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they prove the logger
/// writes, rotates, reports size and deletes, and that the two failure SHAPES
/// are distinguishable. They do NOT prove the file is retrievable off a real
/// phone over MTP -- no test can enumerate a device over USB, so that stays a
/// manual validation step. They also do not prove the five production call
/// sites actually fire; the source assertions at the bottom cover the wiring,
/// and only a live failure proves the behavior.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diag_test_');
    DiagnosticLogger.debugSetDir(tempDir.path);
    DiagnosticLogger.debugSetEnabled(true);
  });

  tearDown(() async {
    DiagnosticLogger.debugSetDir(null);
    DiagnosticLogger.debugSetEnabled(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> readAll() async {
    final buffer = StringBuffer();
    await for (final entity in tempDir.list()) {
      if (entity is File) buffer.write(await entity.readAsString());
    }
    return buffer.toString();
  }

  group('F233: a failure reaches a file', () {
    test('writes a record that names the context and the reason', () async {
      await DiagnosticLogger.failure(
        context: 'F38/re-process',
        kind: DiagnosticLogger.kindException,
        reason: 'whole-batch failure: SocketException',
        attempted: 9,
        failed: 9,
      );

      final text = await readAll();
      expect(text, contains('F38/re-process'));
      expect(text, contains('SocketException'));
      expect(text, contains('attempted=9'));
      expect(text, contains('failed=9'),
          reason: 'the counts are what distinguish a total failure from a '
              'partial one -- the Sprint 71 evidence was "0 of 9 (9 failed)"');
    });

    test('THE POINT OF THE CARD: the two failure shapes are distinguishable',
        () async {
      // Before this card, an allFailed guard trip and a thrown exception both
      // surfaced to the user as "0 of N (N failed)". F232 carries two competing
      // mechanisms precisely because nobody could tell them apart.
      await DiagnosticLogger.failure(
        context: 'IMAP/takeActionBatch',
        kind: DiagnosticLogger.kindNotConnected,
        reason: 'adapter has no live client',
        attempted: 6,
        failed: 6,
      );
      await DiagnosticLogger.failure(
        context: 'F38/delete-batch',
        kind: DiagnosticLogger.kindServerRefused,
        reason: 'batch threw',
        attempted: 6,
        failed: 6,
      );

      final text = await readAll();
      expect(text, contains(DiagnosticLogger.kindNotConnected));
      expect(text, contains(DiagnosticLogger.kindServerRefused));
      expect(DiagnosticLogger.kindNotConnected,
          isNot(equals(DiagnosticLogger.kindServerRefused)),
          reason: 'if these two ever collapse to one value the card is undone');
    });

    test('a SKIPPED folder is recorded even though nothing threw', () async {
      // The shape that produces "0 succeeded / N failed" on a perfectly healthy
      // connection: moveToFolderBatch `continue`s past a folder whose UID list
      // came back empty. It left no trace at all before this card.
      await DiagnosticLogger.failure(
        context: 'IMAP/moveToFolderBatch',
        kind: DiagnosticLogger.kindSkipped,
        reason: 'no valid UIDs parsed for folder "Bulk"',
        attempted: 4,
        failed: 4,
      );

      final text = await readAll();
      expect(text, contains(DiagnosticLogger.kindSkipped));
      expect(text, contains('Bulk'));
    });
  });

  group('F233: default OFF', () {
    test('writes nothing when disabled', () async {
      DiagnosticLogger.debugSetEnabled(false);

      await DiagnosticLogger.failure(
        context: 'F38/re-process',
        kind: DiagnosticLogger.kindException,
        reason: 'should not be written',
      );

      final entities = await tempDir.list().toList();
      expect(entities, isEmpty,
          reason: 'a debugging aid must not accumulate on disk for users who '
              'never asked for it');
    });
  });

  group('F233: the retention promise is keepable', () {
    test('totalBytes reports what is actually held', () async {
      expect(await DiagnosticLogger.totalBytes(), 0);

      await DiagnosticLogger.failure(
        context: 'ctx',
        kind: DiagnosticLogger.kindInfo,
        reason: 'x' * 200,
      );

      expect(await DiagnosticLogger.totalBytes(), greaterThan(0),
          reason: 'the size is shown next to the delete action so the user can '
              'see what they are carrying before deciding');
    });

    test('deleteAll empties the logs and reports the count', () async {
      await DiagnosticLogger.failure(
        context: 'ctx',
        kind: DiagnosticLogger.kindInfo,
        reason: 'first',
      );
      expect(await DiagnosticLogger.totalBytes(), greaterThan(0));

      final removed = await DiagnosticLogger.deleteAll();

      expect(removed, greaterThan(0));
      expect(await DiagnosticLogger.totalBytes(), 0,
          reason: 'Harold made deletability a CONDITION of keeping the files: '
              '"if the user can easily get to them to delete the files"');
    });

    test('deleteAll on an empty directory is not an error', () async {
      expect(await DiagnosticLogger.deleteAll(), 0);
    });
  });

  group('F233: CONCURRENT writes must not destroy each other', () {
    // Phase 7 review CRITICAL, Sprint 72. `File.writeAsString(mode:
    // append)` is NOT an atomic append -- it opens, writes and closes, so
    // concurrent callers clobber one another. MEASURED before the fix, on
    // this machine: ten concurrent appends produced THREE lines, and two
    // produced one.
    //
    // Reachable in production. EVERY call site uses `unawaited(...)`, so the
    // futures are explicitly left to overlap, and
    // `generic_imap_adapter._parseUids` fires one per dropped message inside
    // a `for` loop -- twenty bad ids means twenty overlapping appends in one
    // synchronous pass.
    //
    // The existing tests missed this because each awaits a SINGLE call.
    // Their own IMP-1 sentence named MTP retrieval and call-site firing as
    // the gaps; it did not name concurrency, which is the gap that mattered.

    test('THE BUG: two simultaneous failures both survive', () async {
      // The delete-batch / move-batch pair from _reProcessAffectedEmails --
      // the exact shape that lost a record before the fix.
      await Future.wait([
        DiagnosticLogger.failure(
          context: 'F38/delete-batch',
          kind: DiagnosticLogger.kindServerRefused,
          reason: 'DELETE-MARKER',
        ),
        DiagnosticLogger.failure(
          context: 'F38/move-batch',
          kind: DiagnosticLogger.kindServerRefused,
          reason: 'MOVE-MARKER',
        ),
      ]);

      final text = await readAll();
      expect(text, contains('DELETE-MARKER'),
          reason: 'THE ASSERTION THAT WAS MISSING -- this record was reduced '
              'to a single character before the fix');
      expect(text, contains('MOVE-MARKER'));
    });

    test('a burst of twenty keeps every record', () async {
      await Future.wait(List.generate(
        20,
        (i) => DiagnosticLogger.log(
          kind: DiagnosticLogger.kindSkipped,
          context: 'IMAP/_parseUids',
          detail: 'BURST-$i',
        ),
      ));

      final text = await readAll();
      final count =
          text.split('\n').where((l) => l.contains('BURST-')).length;
      expect(count, 20,
          reason: 'ten concurrent appends produced three lines before the '
              'fix');
      for (var i = 0; i < 20; i++) {
        expect(text, contains('BURST-$i'),
            reason: 'record $i was lost');
      }
    });

    test('every line stays intact -- no torn records', () async {
      // Losing a line is one failure mode; a HALF-WRITTEN line is worse,
      // because it reads as real data.
      await Future.wait(List.generate(
        15,
        (i) => DiagnosticLogger.failure(
          context: 'ctx-$i',
          kind: DiagnosticLogger.kindException,
          reason: 'x' * 400,
          attempted: i,
          failed: i,
        ),
      ));

      final text = await readAll();
      final lines =
          text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines, hasLength(15));
      for (final line in lines) {
        expect(line.startsWith('['), isTrue,
            reason: 'a line not starting with a timestamp is a torn record');
        expect(line, contains('attempted='),
            reason: 'every record must carry its full payload');
      }
    });
  });

  group('F233: rotation bounds a permanently-enabled log', () {
    test('a file past the ceiling is rolled over', () async {
      // Harold runs with this enabled permanently, so an unbounded append is a
      // defect waiting to happen on a phone.
      //
      // The filename embeds the RUNTIME app version, so the test cannot
      // hardcode one -- write a first record, find whatever file that created,
      // then inflate THAT file past the ceiling.
      await DiagnosticLogger.failure(
        context: 'ctx',
        kind: DiagnosticLogger.kindInfo,
        reason: 'create the file',
      );
      final created = <File>[];
      await for (final e in tempDir.list()) {
        if (e is File && e.path.endsWith('.log')) created.add(e);
      }
      expect(created, hasLength(1),
          reason: 'the first record should create exactly one log file');
      await created.first
          .writeAsString('x' * (DiagnosticLogger.maxFileBytes + 1024));

      await DiagnosticLogger.failure(
        context: 'ctx',
        kind: DiagnosticLogger.kindInfo,
        reason: 'triggers rotation',
      );

      final names = <String>[];
      await for (final e in tempDir.list()) {
        names.add(path.basename(e.path));
      }
      expect(names.any((n) => n.endsWith('.bak')), isTrue,
          reason: 'the oversized file should have been rolled aside');
    });
  });

  group('F233: the production call sites are wired', () {
    test('the adapter records both connection failure and skipped folders', () {
      final source =
          File('lib/adapters/email_providers/generic_imap_adapter.dart')
              .readAsStringSync();
      expect(source.contains('DiagnosticLogger.kindNotConnected'), isTrue,
          reason: 'the allFailed guard must reach a file');
      expect(source.contains('DiagnosticLogger.kindSkipped'), isTrue,
          reason: 'a silently skipped folder is the shape that produced '
              '"0 succeeded / N failed" on a healthy connection');
    });

    test('the re-process paths record their exceptions', () {
      final source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
      expect(source.contains('DiagnosticLogger.kindException'), isTrue,
          reason: 'the outer catch is the line Sprint 71 needed and could not '
              'read');
      expect(source.contains('DiagnosticLogger.kindServerRefused'), isTrue,
          reason: 'the delete-batch catch must be distinguishable from the '
              'never-connected guard');
    });
  });
}
