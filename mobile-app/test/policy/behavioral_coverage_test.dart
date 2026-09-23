import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 73 retro IMP-1: a test file that verifies a feature ONLY by reading
/// its own source text must say so, and say what would settle it instead.
///
/// ## The defect this prevents, which happened TWICE in one sprint
///
/// Sprint 73 shipped two features that did nothing, both with fully green
/// suites, both found by the Phase 5.1 reviews rather than by their tests:
///
/// - **F234**: the read-only preview forced `ScanMode.readOnly` into gates
///   matching only the three ACTING modes, so both collection lists stayed
///   empty, the `isEmpty` guard returned `nothingToDo()` first, and the preview
///   block was unreachable. Inert from its first commit.
/// - **F224**: cancellation was swallowed by a second per-folder `catch` in the
///   IMAP adapter, so cancel did nothing on every real account.
///
/// Both were verified by asserting on SOURCE TEXT -- `source.contains(...)`,
/// `indexOf` ordering -- which proves a symbol EXISTS and can never prove a
/// branch is TAKEN.
///
/// ## Why this is a GATE and not another rule in CLAUDE.md
///
/// **Prose rules were already in place and did not prevent it.** CLAUDE.md's
/// Sprint 70 IMP-1 requires every test guarding a bug fix to carry a one-line
/// "what would this test NOT catch?", and `feedback_source_gates_verify_shape`
/// says a source gate must be paired with a behaviour test. BOTH F234 and F224
/// carried that paragraph. Both were still inert. A rule that was followed and
/// did not help is not made effective by restating it -- CLAUDE.md is already
/// ~790 lines, and a sixth entry on the same subject is an additional control,
/// not prevention.
///
/// So this runs in the suite and fails the build, which is the project's
/// established answer to exactly this situation (see
/// `ui_string_assertion_shadow_test.dart`, Sprint 65 retro IMP-3, written
/// after a gate passed while proving less than it appeared to).
///
/// ## What it asks for, and what it deliberately does not
///
/// It does NOT forbid source-text assertions. They are legitimate and
/// sometimes the only option -- proving a rethrow precedes a generic catch
/// needs a real IMAP connection to test behaviourally. What it forbids is
/// doing that SILENTLY. A file over the threshold must carry an explicit
/// declaration naming what would actually settle the behaviour.
///
/// It also does not try to judge whether a test is "good". It measures one
/// mechanical property -- the ratio of assertions made against source strings
/// to all assertions -- because a gate that needs judgement is a gate that
/// argues with you.
void main() {
  final testDir = Directory('test');

  /// Assertions made against a SOURCE STRING rather than a running object.
  final sourceAssertion = RegExp(
    r'\b(source|scanner|adapter|code|contents?|src|appBar|line)\s*\.'
    r'(contains|indexOf|lastIndexOf|allMatches)\s*\(',
  );
  final anyExpect = RegExp(r'\bexpect\s*\(');
  final readsDartSource = RegExp(r"""File\(['"][^'"]*\.dart['"]\)""");

  /// The declaration a source-heavy file must carry.
  ///
  /// Deliberately a distinctive phrase rather than loose prose: the F193
  /// evidence gate learned that a pattern matching anything vague is satisfied
  /// by text that happens to mention the topic.
  const marker = 'SOURCE-TEXT VERIFIED:';

  /// Ratio above which a file must declare itself.
  ///
  /// **Grounded in a survey of the real corpus, not guessed.** Of 21 files that
  /// read `.dart` source, seven sit at 0.73 or above -- near-total source
  /// verification -- and they are concentrated in the last two sprints' feature
  /// tests, which is exactly where both CRITICALs lived. Files that pair source
  /// checks with real behavioural tests land well below: `f234_readonly_preview`
  /// is at 0.46 AFTER its behavioural tests were added, and was far higher
  /// before. So the threshold separates the two populations as they actually
  /// exist.
  const threshold = 0.70;

  test('source-heavy test files declare what would really settle the behaviour',
      () {
    expect(testDir.existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');

    final undeclared = <String>[];

    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      // This file is itself full of the patterns it looks for.
      if (entity.uri.pathSegments.last == 'behavioral_coverage_test.dart') {
        continue;
      }

      final source = entity.readAsStringSync();
      // Only files that actually read production SOURCE are in scope. A test
      // driving real objects is not this defect class however it is written.
      if (!readsDartSource.hasMatch(source)) continue;

      final total = anyExpect.allMatches(source).length;
      if (total == 0) continue;
      final srcCount = sourceAssertion.allMatches(source).length;
      if (srcCount / total < threshold) continue;

      if (!source.contains(marker)) {
        undeclared.add('${entity.uri.pathSegments.last} '
            '(${(srcCount / total * 100).round()}% source assertions)');
      }
    }

    expect(
      undeclared,
      isEmpty,
      reason: 'These test files verify almost entirely by reading production '
          'SOURCE TEXT, which proves a symbol EXISTS and never that a branch '
          'is TAKEN.\n\n'
          'Sprint 73 shipped TWO features that did nothing with exactly this '
          'shape of suite green: F234\'s preview could not report a non-zero '
          'count, and F224\'s cancel was swallowed on every real IMAP '
          'account.\n\n'
          'Fix, in order of preference:\n'
          '  1. Add a test that EXECUTES the decision. Extracting a pure '
          'function to make that possible cost minutes in Sprint 73 '
          '(classifyForReProcess, ScanCoordinator.throwIfCancelled).\n'
          '  2. If execution is genuinely impossible, add a comment starting '
          '"$marker" naming what WOULD settle the behaviour (a device run, a '
          'live account, a manual check).\n\n'
          'Undeclared: ${undeclared.join(', ')}',
    );
  });

  test('the declaration must name what would settle it, not just appear', () {
    // A marker that can be satisfied by the bare phrase is a marker that will
    // be pasted in to silence the gate. Requiring following text is the same
    // lesson the F193 evidence gate learned when "N/A" alone was accepted.
    final offenders = <String>[];

    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      if (entity.uri.pathSegments.last == 'behavioral_coverage_test.dart') {
        continue;
      }
      final source = entity.readAsStringSync();
      final idx = source.indexOf(marker);
      if (idx == -1) continue;

      final rest = source.substring(idx + marker.length);
      final firstLine = rest.split('\n').first.trim();
      // Enough words to be a sentence about evidence, not a shrug.
      if (firstLine.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <
          5) {
        offenders.add(entity.uri.pathSegments.last);
      }
    }

    expect(offenders, isEmpty,
        reason: 'A "$marker" declaration must be FOLLOWED by what would '
            'actually settle the behaviour. The phrase alone is a shrug, and '
            'a marker that can be satisfied by pasting it in is a marker that '
            'will be pasted in.\n\nBare: ${offenders.join(', ')}');
  });
}
