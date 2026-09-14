import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PR #410 (Sprint 69): no documentation file may contain a raw control
/// character.
///
/// **Why this exists.** Copilot found a "ready to paste" Windows path in
/// `GOOGLE_PLAY_RELEASE_PROCESS.md` that had been silently destroyed when it
/// was written:
///
/// ```
/// mobile-app\build\app\outputs\bundle\...   <- intended
/// mobile-app<0x08>uild<0x07>pp\outputs...   <- what landed on disk
/// ```
///
/// `\b` and `\a` inside a non-raw Python string are ESCAPE SEQUENCES, so they
/// were consumed before the file was ever written, leaving literal backspace
/// (0x08) and bell (0x07) bytes. The corruption is invisible in most editors
/// and in rendered Markdown -- the path simply does not work when pasted.
///
/// A sweep after that finding turned up **four more instances across three
/// files**, including the MSIX path in `STORE_RELEASE_PROCESS.md` that is
/// pasted into Partner Center on every Windows release. This is the same class
/// that corrupted a path twice in Sprint 68.
///
/// The fix when writing paths from a script: build the separator from its code
/// point (`chr(92)`), or use a raw string, and verify by reading control
/// characters back OFF DISK rather than trusting the write.
///
/// **Scope note**: `docs/sprints/` is excluded. Those are archives, and two of
/// them legitimately quote the corrupted bytes while DOCUMENTING this very
/// defect -- gating them would force the record to be falsified.
void main() {
  test('no doc contains a raw control character', () {
    final docs = Directory('../docs');
    expect(docs.existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');

    // Tab, CR and LF are legitimate. Everything else below 0x20 is damage.
    bool isDamage(int c) => c < 32 && c != 9 && c != 10 && c != 13;

    final violations = <String>[];

    for (final entity in docs.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      // Archives may quote the corruption while documenting it.
      if (entity.path.replaceAll(r'\', '/').contains('/sprints/')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final bad = lines[i].codeUnits.where(isDamage).toList();
        if (bad.isEmpty) continue;
        final hex = bad.map((c) => '0x${c.toRadixString(16)}').join(', ');
        violations.add(
          '${entity.uri.pathSegments.last}:${i + 1} contains $hex\n'
          '    ${lines[i].replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '?')}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'A control character in a doc almost always means an escape '
          'sequence was consumed when the file was written -- `\b` becoming '
          '0x08 in a Windows path, for example. The text looks correct in an '
          'editor and fails when pasted.\n\n'
          'Write paths with a raw string or build the separator from '
          'chr(92), then verify by reading control characters back off '
          'disk.\n\n${violations.join('\n\n')}',
    );
  });
}
