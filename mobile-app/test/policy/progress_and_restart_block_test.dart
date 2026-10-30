// F317 / Sprint 82 -- "Progress and restart" block gate.
//
// WHY: a subagent that stops at a usage limit loses its work unless its prompt
// tells it to save progress to files, read them on a restart, restore a held
// mutation lock, and never repeat a release or store action. The canonical
// block lives in docs/SPRINT_EXECUTION_WORKFLOW.md. Every place that launches
// a subagent refers to it as "the Progress and restart block". This test FAILS
// when the block loses a required rule, when a launch location stops
// referring to it, or when the delegation checklist loses item 8.
//
// What this does NOT catch:
//   - A prompt written at run time that forgets to paste the block. The test
//     reads the docs, not the prompts a session actually sends.
//   - A NEW launch location added to the workflow without a reference. Add it
//     to `_launchAnchors` when it is created.
//   - A block whose rules are present but wrong in meaning. It checks the key
//     phrases, not the logic.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _workflowPath = '../docs/SPRINT_EXECUTION_WORKFLOW.md';
const _planningPath = '../docs/SPRINT_PLANNING.md';

/// Phrase that every launch location must contain on the anchor line.
const _reference = 'Progress and restart block';

/// A unique phrase of each launch location in the workflow doc. The line that
/// holds the anchor must also hold [_reference].
const _launchAnchors = [
  'Every delegated prompt carries', // 4.1 delegated tasks
  'Each toolkit prompt carries', // Phase 7 order step 1 and step 5
  'each prompt carrying the', // 7.7.1 improvement review bullet
  'Paste the Progress and restart block into both toolkit prompts', // 7.7.1 start
  'A background CI-fix agent carries', // 7.7.1 CI run 1
  'the prompt carries the Progress and restart block', // 5.1.1 procedure
];

/// Rules the fenced canonical block must keep.
const _blockRules = [
  'PROGRESS AND RESTART',
  'FIRST ACTION: read',
  'Write tool',
  'STATUS: FINISHED',
  'MUTATION LOCK',
  'Remove-MutationLock',
  'NEVER repeat a release or store action',
  'Resumed:',
];

String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path is missing');
  return f.readAsStringSync();
}

/// The text of the fenced block that starts with PROGRESS AND RESTART.
String _canonicalBlock(String doc) {
  final start = doc.indexOf('PROGRESS AND RESTART (apply to yourself)');
  expect(start, greaterThanOrEqualTo(0),
      reason: 'canonical Progress and restart block is missing from '
          'SPRINT_EXECUTION_WORKFLOW.md');
  final end = doc.indexOf('```', start);
  expect(end, greaterThan(start), reason: 'canonical block is not fenced');
  return doc.substring(start, end);
}

void main() {
  test('workflow doc holds the canonical block with every rule', () {
    final block = _canonicalBlock(_read(_workflowPath));
    for (final rule in _blockRules) {
      expect(block.contains(rule), isTrue,
          reason: 'canonical block lost the rule: "$rule"');
    }
  });

  test('every subagent launch location refers to the block', () {
    final lines = _read(_workflowPath).split('\n');
    for (final anchor in _launchAnchors) {
      final hits = lines.where((l) => l.contains(anchor)).toList();
      expect(hits, isNotEmpty,
          reason: 'launch location anchor not found: "$anchor"');
      for (final line in hits) {
        expect(line.contains(_reference), isTrue,
            reason: 'launch location "$anchor" does not refer to the '
                '"$_reference"');
      }
    }
  });

  test('delegation checklist item 8 requires the block', () {
    final doc = _read(_planningPath);
    final start = doc.indexOf('DELEGATION CHECKLIST:');
    expect(start, greaterThanOrEqualTo(0),
        reason: 'delegation checklist is missing');
    final end = doc.indexOf('-->', start);
    final checklist = doc.substring(start, end);
    expect(RegExp(r'\n\s+8\. Paste the "Progress and restart" block')
        .hasMatch(checklist), isTrue,
        reason: 'delegation checklist item 8 (Progress and restart) is missing');
  });
}
