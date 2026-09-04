import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rule display-value policy gate (Sprint 64 retro IMP-2, Issue #369).
///
/// **The defect this closes.** Every rule surface in Manage Rules renders
/// `rule.sourceDomain ?? rule.name` -- the list row, the detail dialog, the
/// delete confirmation, the search filter, and the semantics label. So
/// `source_domain` is not merely "the domain this rule came from": its real
/// contract is **the string the user sees**. F186 added a fifth manual rule
/// type (Body Phrase) whose author read the column by its NAME, correctly
/// concluded a body phrase has no domain, and wrote NULL. The fallback then
/// exposed the internal `manual_<slug>_<timestamp>` name in the UI. Harold
/// caught it on the first real Android create; 36 widget tests and 4 unit
/// tests were green the whole time, because none of them asserted what the
/// row displays.
///
/// **Why a source gate rather than a widget test.** The behavioural half is
/// already covered: the create-screen widget test asserts the "Phrase: ..."
/// summary and the exact DB row shape it writes. What is NOT coverable by a
/// widget test is the FUTURE sixth rule type, whose author will make exactly
/// the same reasonable-sounding mistake. This gate fails the build if the
/// create path ever writes a null/absent display value again, and it carries
/// the explanation to whoever trips it. Per
/// `feedback_source_gates_verify_shape`, a source gate proves shape, not
/// behaviour -- the paired behaviour proof lives in
/// `test/ui/screens/manual_rule_create_screen_test.dart`.
void main() {
  final createScreen =
      File('lib/ui/screens/manual_rule_create_screen.dart');
  final editScreen = File('lib/ui/screens/rule_edit_screen.dart');
  final rulesScreen =
      File('lib/ui/screens/rules_management_screen.dart');

  test('the manual create path never writes a null display value', () {
    final source = createScreen.readAsStringSync();

    // The insert's display column must be the plain _sourceDomain field for
    // EVERY type. The pre-fix code read `isBody ? null : _sourceDomain`,
    // which is the exact shape banned here.
    expect(
      source,
      contains("'source_domain': _sourceDomain,"),
      reason: 'source_domain is the UI display value for every rule type '
          '(rules_management_screen renders `sourceDomain ?? name`), so the '
          'insert must write it unconditionally. A type-conditional null is '
          'what leaked the internal manual_<slug>_<ms> name in F186.',
    );

    expect(
      RegExp(r"'source_domain'\s*:\s*\w+\s*\?\s*null\s*:").hasMatch(source),
      isFalse,
      reason: 'no rule type may opt out of having a display value -- give it '
          'a human-meaningful string (the phrase, the domain, the address) '
          'instead of null',
    );
  });

  test('every ManualRuleType assigns a non-empty sourceDomain', () {
    final source = createScreen.readAsStringSync();

    // _generatePattern's per-type switch assigns sourceDomain for each
    // ManualRuleType. An arm that assigns the empty string produces a rule
    // with no display value, which falls back to the internal name in the UI
    // just as a null would. Scope the check to that switch: resets to '' on
    // empty/cleared input elsewhere in the file are correct and expected.
    // Line scan rather than a source-spanning regex: the assignments that
    // matter are the LOCAL `sourceDomain = ...` arms of the per-type switch
    // (no leading underscore). The `_sourceDomain = ''` resets on cleared
    // input are a different, correct thing and are excluded by the underscore.
    final localAssignments = const LineSplitter()
        .convert(source)
        .map((l) => l.trim())
        .where((l) => l.startsWith('sourceDomain ='))
        .toList();

    expect(localAssignments, isNotEmpty,
        reason: 'could not locate the per-type sourceDomain assignments -- if '
            'they were refactored, update this gate rather than deleting it');

    for (final line in localAssignments) {
      expect(
        line == "sourceDomain = '';",
        isFalse,
        reason: 'an empty sourceDomain falls back to rule.name in Manage '
            'Rules exactly as null does -- assign the display string for the '
            'type. If a future type genuinely has no natural display string, '
            'change the UI contract deliberately rather than emptying this '
            'field. Offending line: $line',
      );
    }
  });

  test('the EDIT screen assigns the same display values as the create screen',
      () {
    // The edit screen is the create screen's parallel site: both run a
    // per-type switch producing sourceDomain, and both feed the same UI
    // contract. F-PRECHECK class 1 (mirror/parallel-site sync) caught it
    // still holding the pre-fix `sourceDomain = ''` for body phrases after
    // the create screen was fixed. The user-visible effect was narrower but
    // real: the save path falls back to the rule's ORIGINAL sourceDomain when
    // the new one is empty, so editing a body phrase left the rule titled
    // with the OLD phrase, and the preview showed no Phrase line.
    final source = editScreen.readAsStringSync();

    final localAssignments = const LineSplitter()
        .convert(source)
        .map((l) => l.trim())
        .where((l) => l.startsWith('sourceDomain ='))
        .toList();

    expect(localAssignments, isNotEmpty,
        reason: 'could not locate the edit screen per-type sourceDomain '
            'assignments -- if they were refactored, update this gate');

    for (final line in localAssignments) {
      expect(
        line == "sourceDomain = '';",
        isFalse,
        reason: 'the edit screen must assign a display value for every type, '
            'exactly as the create screen does. Offending line: $line',
      );
    }
  });

  test('the display-value contract is still `sourceDomain ?? name`', () {
    // If this fails, the contract these gates protect has MOVED. Re-read the
    // rules screen and update this file rather than deleting it: the point is
    // that some field is the display value and the create path must fill it.
    final source = rulesScreen.readAsStringSync();
    expect(
      source,
      contains('rule.sourceDomain ?? rule.name'),
      reason: 'Manage Rules derives every displayed rule title from this '
          'fallback; the create-path gates above exist because of it',
    );
  });
}
