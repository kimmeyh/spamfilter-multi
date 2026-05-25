# F77 -- Hookify rule to block "want me to proceed?" phrasings

**Status:** Implemented via the existing `sprint-auto-advance.ps1` Stop hook;
a separate hookify rule was deliberately NOT created. See rationale below.

**Date:** 2026-05-25 (Sprint 39)

## Requirement (F77)

Reject end-of-turn phrasings such as "want me to proceed?", "should I
continue?", "ready to proceed with X?", "shall I proceed?" during sprint
execution, with a message reminding that sprint-plan approval (Phase 3.7) is
durable through Phase 7. The rule MUST NOT fire during Backlog Refinement
(Phase 1) -- coordinated with F93.

## Decision: route F77 through `sprint-auto-advance.ps1` (NOT a hookify rule)

A development decision (Decision-Class Taxonomy, Chief Developer): the cleanest
implementation of F77 is the Stop hook that already exists, not a new hookify
rule. The existing hook already satisfies F77 completely and correctly, and a
hookify rule cannot satisfy F77 without introducing false positives.

### Why a hookify rule cannot satisfy F77

Hookify (`claude-plugins-official/hookify`) loads rules from
`.claude/hookify.*.local.md` and evaluates them in
`core/rule_engine.py`. For `event: stop` rules the engine can only inspect
two fields (see `_extract_field` in rule_engine.py):

1. `reason` -- the Stop reason (almost always empty), and
2. `transcript` -- the ENTIRE conversation transcript file.

There is **no field for the last assistant message**. Consequences:

- **False positives (scope).** A `transcript regex_match` on
  `want me to proceed` would fire on every Stop once the phrase appeared
  ANYWHERE in the conversation history -- including inside this document, the
  hook source, retro notes, or a quoted user message. It cannot be scoped to
  "the message Claude just ended the turn with".
- **No Phase-1 awareness (F93 coordination).** Hookify conditions are limited
  to text-field regex. The engine has no access to the git branch or to
  `docs/sprints/SPRINT_<N>_PLAN.md` existence, so the F93 Phase-1 exemption
  CANNOT be reused or reimplemented inside a hookify rule. F93's gate lives in
  PowerShell (`sprint-auto-advance.ps1`) precisely because it needs git +
  filesystem access that hookify does not provide.

### Why the existing hook already satisfies F77

`.claude/hooks/sprint-auto-advance.ps1` is a Stop hook (registered in
`.claude/settings.json`) that:

- inspects `last_assistant_message` (correct scope -- only the final message),
- already blocks the F77 target phrasings via its `$procPatterns` list:
  - `want me to (proceed|continue|start|...)`
  - `should i (proceed|continue|start|...)`
  - `(shall|may) i (proceed|continue|...)`
  - `ready (to|for|when) (continue|proceed|go|...)`
- emits a correction message that cites the Phase Auto-Advance Rule
  (CLAUDE.md section 7) and the Standing Approval Inventory
  (SPRINT_EXECUTION_WORKFLOW.md Phase 3.7) -- exactly the F77 reminder, and
- as of F93, ALLOWS the stop during Phase 1 (when no
  `docs/sprints/SPRINT_<N>_PLAN.md` exists), satisfying the F77/F93
  coordination requirement.

Verification (2026-05-25), all four F77 target phrasings on a Sprint branch
with the plan file present -> exit 2 (BLOCK); same phrasings on a Sprint branch
with NO plan file (Phase 1) -> exit 0 (ALLOW). See
`.claude/hooks/test-cases/violation-2-want-me-to.json`,
`violation-4-phase4-plan-exists.json`,
`allow-8-phase1-no-plan-file.json`, and
`allow-9-phase1-bare-question.json`, all run by
`.claude/hooks/run-test-cases.ps1`.

## If a hookify rule is ever still desired (NOT recommended)

If the team later wants a hookify rule anyway (e.g. as a coarse secondary
warning), the file would be created at:

    .claude/hookify.block-proceed-questions.local.md

with content:

    ---
    name: block-proceed-questions
    enabled: false
    event: stop
    action: warn
    conditions:
      - field: transcript
        operator: regex_match
        pattern: (want me to proceed|should i continue|ready to proceed|shall i proceed)\s*\?
    ---

    Sprint-plan approval at Phase 3.7 is durable authorization through Phase 7.
    Do not pause to ask "want me to proceed?" during sprint execution. Identify
    the next action from SPRINT_N_PLAN.md / TaskList / SPRINT_EXECUTION_WORKFLOW.md
    and execute it. Only stop for the 9 SPRINT_STOPPING_CRITERIA.

It is kept `enabled: false` and `action: warn` on purpose because:
  - `transcript`-scope matching causes false positives (see above), and
  - hookify cannot honor the F93 Phase-1 exemption, so it would misfire during
    Backlog Refinement.

This rule file was intentionally NOT created. The authoritative F77 enforcement
is `sprint-auto-advance.ps1`.
