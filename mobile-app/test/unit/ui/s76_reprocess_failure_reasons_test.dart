/// Sprint 76 (0.17.2 Fold log): a rule update's failed mailbox actions are
/// logged WITH their reasons. The log read "acted on 0 of 29 (failed 29):
/// moveSafe=29" and nothing said why.
///
/// What this does NOT catch: whether the screen calls the summary on every
/// failure path -- the per-id path is wired in two places and pinned by the
/// source gate below; the whole-batch throw path writes its own line.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/screens/results_display_screen.dart';

void main() {
  test('identical reasons collapse to one counted line, most common first', () {
    final lines = summarizeBatchFailureReasons({
      'a': 'NO [TRYCREATE] folder missing',
      'b': 'NO [TRYCREATE] folder missing',
      'c': 'NO [TRYCREATE] folder missing',
      'd': 'BAD command',
    });
    expect(lines, ['3 x NO [TRYCREATE] folder missing', '1 x BAD command']);
  });

  test('addresses are scrubbed and message ids are never written', () {
    final lines =
        summarizeBatchFailureReasons({'msg-123': 'refused for someone@example.com'});
    expect(lines.single, isNot(contains('someone@example.com')));
    expect(lines.single, isNot(contains('msg-123')));
  });

  test('at most three distinct reasons, then a count of the rest', () {
    final lines = summarizeBatchFailureReasons({
      for (var i = 0; i < 5; i++) 'id$i': 'reason $i',
    });
    expect(lines.length, 4);
    expect(lines.last, '... and 2 other reason(s)');
  });

  test('a long reason is capped', () {
    final lines = summarizeBatchFailureReasons({'a': 'x' * 500});
    expect(lines.single.length, lessThan(220));
  });

  test('both per-id batch paths write the reasons', () {
    // SOURCE-TEXT VERIFIED: the batch paths need a live mailbox platform;
    // the gate pins that both outcomes are passed to the logger.
    final src =
        File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    expect(src.contains("_logReProcessFailureReasons('delete', result.failedIds)"),
        isTrue);
    expect(
        src.contains('_logReProcessFailureReasons(\n'
            '              \'safe-sender move to "\$targetFolder"\', result.failedIds)'),
        isTrue);
  });
}
