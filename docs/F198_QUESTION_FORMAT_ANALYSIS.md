# F198: forcing function for the numbered-question format -- R-1 comparison

**Required by the card BEFORE any hook is built.** The card said: evaluate whether a lighter
change suffices, "cheaper, and it may be enough. The card should compare both rather than
assume a hook."

**Recommendation: the documentation change. Do NOT build the hook.**

That is not the cheap answer chosen for being cheap -- it is what the evidence supports once
the four violations are examined individually, and one finding rules the hook out on
correctness grounds rather than cost.

---

## What actually went wrong, all four times

The rule lives in memory as `feedback_qa_style_plain_numbered`: a decision question is a plain
numbered list Harold answers by typing a digit.

- **Violations 1-3 (2026-08-10, one session)**: all three were reaching for the
  **AskUserQuestion tool** by reflex. Harold's third correction was the sharpest -- "Please
  stop asking questions this way. See memory and prior sprint notes" -- because the memory was
  available and unread.
- **Violation 4 (Sprint 67)**: **prose**. The emulator uninstall decision was asked as two
  bolded paragraphs with a recommendation. No tool involved.

**Those are two different failure modes**, and it matters. The memory's "How to apply" section
is written almost entirely against the first: "Before calling AskUserQuestion in this project,
stop and check this memory first -- the failure mode is not forgetting the rule exists, it is
reaching for the familiar tool by reflex."

Violation 4 was not covered by that guidance. A prose question never touches the tool the
memory warns about. **The rule was not repeated four times against a stable target; the target
moved, and the guidance had not.**

## The finding that rules out the hook

`.claude/hooks/sprint-auto-advance.ps1` already detects question shapes -- Gate 2, with 13
procedural patterns plus 4 commitment patterns. Reusing it looked obvious.

**But that hook only runs INSIDE the enforcement window** (Phase 3.7 approval -> Manual
Validation). Gate 1b sets the lower bound, Gate 1c the upper, and both `exit 0` outside it.

Now check where the violations happened:

| Violation | When | Inside the window? |
|---|---|---|
| 1-3 (2026-08-10) | clarifying questions during a working session | No |
| 4 (Sprint 67) | Manual Validation | **No -- Gate 1c exits precisely here** |

**All four occurred where the hook deliberately stops looking.** Gate 1c exists because asking
outside the window is CORRECT: post-Manual-Validation work is Harold-driven, and the Phase 8
release cycle is explicitly outside it too (F170).

So a format check cannot ride along on the existing detection. It would have to run in the
region the hook was deliberately taught to ignore -- which is exactly the region where asking
is legitimate and only the FORMAT is at issue. That is a new gate with new semantics, not a
reuse.

## What the hook would have to distinguish

In a region where questions are legitimate, a format checker must let through:

1. A numbered question (the desired form) -- allow
2. A prose question -- **block**
3. A question inside a fenced code block -- allow
4. A question quoted from Harold -- allow
5. The Phase 7 retrospective prompt -- allow
6. A rhetorical question in explanatory prose -- allow
7. A question in a commit message being previewed -- allow

Items 6 and 7 are not in the card's list and are common in normal output. Distinguishing "a
decision question addressed to Harold" from "a question-shaped sentence in prose" is a
semantic judgment, not a regex one. The existing hook's 13 patterns work because they target a
narrow, formulaic set ("want me to proceed", "should I continue"). Decision questions have no
comparable fixed shape -- that is the whole reason violation 4 slipped through.

**Sprint 67 shipped exactly this failure**: the F193 evidence gate broke 6 of the hook's own
allow-cases, including `allow-2-no-question`, whose premise is that a turn ending in a period
is not a violation. IMP-2 exists because of it. A gate that blocks correct work trains bypass,
and bypass is worse than the original defect.

## Why the documentation change is the RIGHT fix, not just the cheaper one

**The rule is not in `CLAUDE.md` at all.** Verified by grep: `CLAUDE.md` has one incidental
mention of "numbered" and no entry in "Things Claude Should NOT Do". The rule lives ONLY in
memory.

That is the actual gap. `CLAUDE.md` is read in full at the start of every session. Memory is
recalled **selectively** -- which is precisely why violation 3 happened with the memory
present but unconsulted, and why Harold's correction said "See memory and prior sprint notes."

So the comparison is not "cheap fix versus real fix". It is:

- **Hook**: a new gate, in a region deliberately excluded from gating, needing 7 allow-shapes
  including two that require semantic judgment, with a demonstrated false-positive history one
  sprint old.
- **Docs**: put the rule where it is read every time, and fix the guidance so it covers the
  failure mode that actually recurred (prose), not only the one that has not recurred since
  August (the tool).

## What was done

1. **`CLAUDE.md`** -- a "Things Claude Should NOT Do" entry, covering **both** shapes: not the
   tool, and not prose. It names the four violations and states the test: if Harold cannot
   answer by typing a digit, it is not formatted correctly.
2. **The memory** -- "How to apply" widened, since it addressed only tool-reflex and violation
   4 was prose.

**No hook.** Recorded as a decision with reasons, not a deferral. If a fifth violation occurs
AFTER the rule is in `CLAUDE.md`, that is new evidence the documentation route failed, and the
hook should be reconsidered with this analysis as its starting point -- including the Gate 1c
problem, which any implementation must solve first.

## The honest counter-argument

A documentation rule is not a forcing function. Harold asked for a forcing function, and this
delivers a stronger rule in a more reliable location instead.

The reason to accept that: the four violations are not four failures of the same mechanism.
Three were tool-reflex, and there have been none since August. One was prose, against guidance
that never mentioned prose. Building a Stop hook to catch a failure mode whose guidance had a
hole in it is treating a documentation gap with automation -- and the automation would run in
the one region the codebase has deliberately decided not to gate.

Fix the hole first. Measure. Automate only if it recurs.
