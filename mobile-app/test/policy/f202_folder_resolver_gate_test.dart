/// F202 (Sprint 74) AC-6: the scan and re-process paths resolve folders
/// through the account -> provider -> overall resolvers, never a raw
/// per-account getter plus a hardcoded fallback.
///
/// The escape this pins: before F202 the Safe Sender and Deleted Rule
/// folders were read with `getAccount*Folder(...) ?? 'INBOX'` / `?? 'Trash'`
/// at each call site, so a provider whose folders differ (iCloud's deleted
/// folder is "Deleted Messages") silently got a folder that did not exist --
/// and the re-process call site is a LIVE-DELETION path.
///
/// SOURCE-TEXT VERIFIED: proves the raw getter / literal is absent at these
/// call sites, not that the resolvers return the right values -- that is
/// `test/unit/storage/f202_folder_defaults_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'lib/core/services/email_scanner.dart',
    'lib/ui/screens/results_display_screen.dart',
  ];

  String code(String file) => File(file)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('scan and re-process paths use the effective folder resolvers', () {
    for (final file in files) {
      final src = code(file);
      expect(src.contains('getAccountSafeSenderFolder('), isFalse,
          reason: '$file reads the raw per-account Safe Sender folder; use '
              'getEffectiveSafeSenderFolder so provider defaults apply');
      expect(src.contains('getAccountDeletedRuleFolder('), isFalse,
          reason: '$file reads the raw per-account Deleted Rule folder; use '
              'getEffectiveDeletedRuleFolder so provider defaults apply');
      expect(src.contains("?? 'INBOX'"), isFalse,
          reason: "$file re-introduced a hardcoded ?? 'INBOX' fallback");
    }
  });

  test("the only remaining ?? 'Trash' in the scanner is the F91 dedup "
      'last resort', () {
    final hits = RegExp(r"\?\? 'Trash'")
        .allMatches(code('lib/core/services/email_scanner.dart'))
        .length;
    expect(hits, 1,
        reason: "email_scanner.dart keeps exactly one ?? 'Trash' -- the F91 "
            'dedup target when the resolver returns null (adapter default). '
            'A second one is a new hardcoded fallback: route it through '
            'getEffectiveDeletedRuleFolder instead.');
  });
}
