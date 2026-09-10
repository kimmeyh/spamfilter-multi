/// F191 (Sprint 68): Yahoo Mail and iCloud Mail are SELECTABLE, not "Coming Soon".
///
/// **What this gate is really protecting.** Both adapters were complete for
/// months -- `GenericIMAPAdapter.yahoo()` and `.icloud()` carry real hosts,
/// port 993 and TLS, structurally identical to `.aol()`, which ships today and
/// runs against a real mailbox. The only thing standing between a user and a
/// Yahoo account was the `phase` integer in the registry, which
/// `platform_selection_screen.dart` reads to decide whether a card renders as
/// selectable, as "Coming Soon", or not at all.
///
/// That made the gap INVISIBLE to every existing test: nothing was broken, the
/// adapters were fine, and the providers simply never appeared. Sprint 66 then
/// shipped a Play listing claiming Yahoo and iCloud support, because the
/// listing copy was traced to the registry (which lists them) rather than to
/// the screen (which hid them). A phase integer is a user-facing claim, and
/// this test treats it as one.
///
/// **The screen's filter is the reason iCloud mattered more than Yahoo.**
/// `_getSupportedPlatforms()` keeps `p.phase <= 2`, so Yahoo at phase 2 at
/// least rendered as "Coming Soon" -- but iCloud at phase 3 was not rendered
/// AT ALL. Anyone reading the screen would have concluded iCloud was
/// unimplemented.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';

void main() {
  group('F191: provider phase gate', () {
    PlatformInfo byId(String id) =>
        PlatformRegistry.getSupportedPlatforms().firstWhere((p) => p.id == id);

    test('Yahoo and iCloud are phase 1 (selectable), like AOL', () {
      expect(byId('yahoo').phase, 1,
          reason: 'Yahoo was phase 2 ("Coming Soon") while its adapter was '
              'complete. F191 opened the gate.');
      expect(byId('icloud').phase, 1,
          reason: 'iCloud was phase 3, which the selection screen does not '
              'render at all (it keeps phase <= 2).');
      expect(byId('aol').phase, 1,
          reason: 'AOL is the reference: same adapter shape, already shipping. '
              'If this ever changes, the comparison above is meaningless.');
    });

    test('both carry the IMAP settings their vendors document', () {
      // Verified against the vendors' own current pages (2026-09-09):
      // Yahoo help SLN4075 -- imap.mail.yahoo.com, 993, SSL required.
      // Apple support 102525 (published 2026-02-03) -- imap.mail.me.com, 993,
      // SSL required. Apple also states iCloud Mail does NOT support POP.
      final yahoo = byId('yahoo').imapConfig!;
      expect(yahoo.host, 'imap.mail.yahoo.com');
      expect(yahoo.port, 993);
      expect(yahoo.isSecure, isTrue);

      final icloud = byId('icloud').imapConfig!;
      expect(icloud.host, 'imap.mail.me.com');
      expect(icloud.port, 993);
      expect(icloud.isSecure, isTrue);
    });

    test('both are reachable through the phase-1 query the screen uses', () {
      final phase1 = PlatformRegistry.getPlatformsByPhase(1).map((p) => p.id);
      expect(phase1, containsAll(<String>['yahoo', 'icloud']));
    });

    test('Custom IMAP stays gated -- it is genuinely unbuilt (F192)', () {
      // NOT an oversight. `GenericIMAPAdapter.custom()` defaults imapHost to
      // '' and expects a caller to supply host/port/TLS; no screen collects
      // them. Opening this gate would ship a provider that cannot connect to
      // anything. F192 (Sprint 69) builds the host-entry UI first.
      expect(byId('imap').phase, greaterThan(1),
          reason: 'Custom IMAP must not become selectable until F192 ships a '
              'form that collects the server address.');
    });
  });
}
