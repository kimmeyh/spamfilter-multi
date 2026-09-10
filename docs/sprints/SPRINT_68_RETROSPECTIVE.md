# Sprint 68 Retrospective

**Sprint**: 68
**Branch**: `feature/20260909_Sprint_68`
**PR**: #403 (draft)
**Dates**: 2026-09-09 (single-day sprint)
**Manual Validation**: complete, declared by Harold 2026-09-09

## Delivered

| ID | Title | Est | Actual | Card |
|---|---|---|---|---|
| F199 | Finish the publisher rename to Kimmey Consulting LLC | 10-20m | ~10m | #398 |
| F198 | Forcing function for the numbered-question format | 45-75m | ~45m | #399 |
| F191 | Ship Yahoo Mail and iCloud Mail | 60-90m | ~55m | #400 |
| F200 | Web Property Deep Dive | 240-480m | ~95m | #401 |
| F197 | Dark-mode contrast gate | 45-90m | ~40m | #402 |

**Totals**: estimated 400-755m, actual ~245m. Suite 2,060 -> 2,070 passing (15 skipped, 0
failing). Policy gates 99 -> 105. Hook suite 53/53. Analyzer clean throughout.

**Also delivered, unplanned**: the dev version bump to 0.15.0+3 (owed at Phase 3.7.0b under
F190 and missed -- Harold caught it), both 0.15.0 per-store release-notes files, an in-app
app-password instruction fix for three providers, and four new backlog items (F200 rewritten,
F201, F202, F203).

---

## Sprint 68 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Actual ~245m against a 400-755m estimate, driven almost
  entirely by F200 coming in at ~95m against 240-480m. That was not luck: the card required a
  LIVE inventory rather than reasoning from the repo, and the live inventory answered every
  question in one pass. The audit-first check paid twice more, reshaping F197 (a gate already
  existed) and F199 (already substantially delivered) BEFORE any code was written. The
  inefficiency was mine and it was in analysis, not execution -- four separate wrong readings
  of screenshots, each costing a correction cycle (see category 9).

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Every new gate was mutation-verified in both directions
  under a mutation lock, and one mutation restore FAILED LOUDLY rather than corrupting the
  wrong line -- `color: Colors.blue.shade50,` occurs twice in `settings_screen.dart` (my
  mutation at 933, the legitimate Default Folders card at 1717), and the count==1 assertion
  caught it. That is the mutation-lock discipline working as designed. The F191 validation
  matrix (2 providers x 2 platforms = 4 cells) was treated as four separate results rather
  than one; each cell has its own evidence. Honest limit recorded rather than smoothed: iCloud's
  evidence is thin by VOLUME on both platforms (2 messages, then 0), so it proves the provider
  works end to end but says little about rule evaluation at scale.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: 4 of 5 tasks landed at or under estimate; F200 came in at
  ~20-40% of its range. That range was deliberately wide ("unbounded discovery") and the width
  was correct given what was known at planning -- but it is worth recording WHY it collapsed,
  so the next unbounded-discovery card can be sized better: the discovery converged because the
  method was specified (inventory the live artifact, do not reason from the repo). A discovery
  card with a specified method is not the same risk as one without.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The mandatory audit-first check earned its place: it
  changed two of five cards before execution. F197 said "add a gate" when a contrast gate
  already existed with a live exemption map -- extending it is more delicate than authoring
  one, which changed both the work and the model tier. **One planning miss**: the F190 dev
  version bump is owed at Phase 3.7.0b and I did not do it. Dev sat at 0.14.2+2, byte-identical
  to what is live on both stores, which is the exact condition F190 exists to prevent. Harold
  found it by reading his own title bar.

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Assignments were Haiku x1 (F199, verification + doc) and
  Sonnet x4, each with a recorded "why not cheaper". All five actually executed on Opus, which
  is a deviation the `Executed-by` rule requires justifying: this was a single continuous
  interactive session driven by Harold's live validation feedback, with no natural handoff
  point to a cheaper tier. The honest read is that the ASSIGNMENTS were still right -- F199 was
  genuinely Haiku-shaped work -- and the deviation is a session-structure artifact, not a
  planning error. Worth noting for the next single-session sprint rather than treated as a
  process failure.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold corrected me four times on factual readings and each
  correction was accepted and recorded rather than argued. Two scope changes were surfaced at
  natural breaks per the Decision-Class Taxonomy instead of being folded in silently (F202's
  provider defaults, and the F200 web-property expansion). The failure mode I should name: I
  repeatedly stated conclusions with more confidence than the evidence carried, and Harold had
  to supply the correction each time. Hedging is not the fix; CHECKING is.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold's ADR-0042 argument for F202 was the clearest
  requirement of the sprint and reframed the work entirely: *"the development team cannot
  choose or override for the providers what they deem as the defaults (names of folders and how
  folders are used), so it requires an override by provider."* That turned "pick better
  defaults" into "record what each provider actually does" -- a different design. His
  "instructions must not fail" constraint on F191 similarly turned a footnote into a deliverable
  written from vendor pages.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: `LEGAL_ENTITY.md` and `APP_PASSWORD_SETUP.md` are new and
  both record what the vendors do NOT document, with evidentiary status attached -- the Yahoo
  2SV answer is labelled as a TESTED negative, not a documented one, because Yahoo publishes
  nothing either way. The F198 analysis doc records a decision NOT to build something, with the
  counter-argument stated. **A documentation defect found in the field**: the in-app
  app-password steps had four of six iCloud steps wrong and pointed at a card Apple retired --
  the standalone doc was correct while the in-app copy, which is what users actually see, had
  never been checked.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: **One pattern, four instances, and it is the single most
  important output of this retrospective.** In each case an artifact could support two
  readings, and I chose the more interesting one without checking:
  1. Yahoo folder picker -- read Harold's ticks as the app's pre-selection.
  2. Play Console line -- treated a record of CURRENT external state as a target to update.
  3. `deletedRuleFolder=Deleted Messages` in the scan log -- read Harold's saved setting as
     runtime resolution, and wrongly narrowed F202's blast radius.
  4. Empty-state wording -- read a PRE-scan Android screen against a POST-scan Windows screen
     and invented a platform difference that does not exist.
  Three were caught by Harold, one by me. None reached code, and all four are corrected in the
  record. But four in one session is a method problem, not four slips. **The shape is
  identical every time: a screenshot cannot distinguish "the app did this" from "Harold did
  this", or one app state from another -- and the source can.**

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: F191's R-3 partial-ship branch (ship Yahoo alone if iCloud
  fails) was never needed but was the right shape to carry. Mutation locks held on every
  deliberate break. F200's deletions were preceded by a full inbound-link inventory, and the
  new link-checker then FAILED ON ITS FIRST RUN reporting real links as broken -- I verified
  against the live URL before believing it, rather than "fixing" correct links. The
  `versionCode` +2 -> +3 bump avoided a Play collision that the release process was written to
  catch after a near-miss last sprint.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Sprint 69 has more real content than Sprint 68 started
  with. F202 (per-provider folder defaults) is well-specified with Harold's confirmed AOL,
  Gmail and Yahoo values recorded as observed truth, four decisions already made by him, and
  two code-level findings that would otherwise be discovered mid-execution (the missing-folder
  error-count interaction, and `initialSelectedFolders` shadowing the pre-select). F192 and
  F203 are also queued. iCloud's values await Harold.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: No ADR was created or changed this sprint, and none was
  needed -- correct rather than deferred. ADR-0042 was APPLIED rather than amended: the F191
  four-cell matrix exists because parity is load-bearing there, and F199/F198/F200 were
  explicitly recorded as having no platform surface rather than implying an analysis that did
  not happen. F202 will likely need an ADR for the provider-override mechanism; that belongs in
  its planning, not here.

### 13. Minor Function Updates for the Next Sprint Plan

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: none beyond what is already carded. F202, F192 and F203 are
  in the backlog with F202 targeted at Sprint 69 by Harold.

### 14. Function Updates for the Future Backlog

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: none new. Four items were added DURING the sprint rather
  than deferred to this category: F200 (rewritten as a deep dive), F201 (periodic web-property
  re-review, HOLD), F202 (per-provider folder defaults, Sprint 69), F203 (Found-vs-evaluated
  disclosure).

---

## Completeness Validation Gate (Phase 7.3 exit criterion)

- [x] All 14 categories present
- [x] Each category has explicit feedback from ALL 4 roles
- [x] No empty or placeholder feedback lines
- [x] Category 13 entries: none -- explicitly stated by all 4 roles
- [x] Category 14 entries: none new -- four items were carded during the sprint instead

---

## Improvement Recommendations

### High Priority (Implement Now)

**IMP-1: A screenshot cannot distinguish who acted, or which state it shows. Read the source.**

- **Root Cause**: Four times this sprint I resolved an ambiguous artifact toward the more
  interesting conclusion. The ambiguity is structural: an artifact captured AFTER a user acts
  cannot distinguish "the app did this" from "the user did this", and a screenshot of one app
  state cannot prove another state renders differently. I treated screenshots as evidence of
  CAUSE when they are only evidence of STATE.
- **Proposed Solution**: A `CLAUDE.md` entry in "Things Claude Should NOT Do": *do not infer
  application BEHAVIOUR from a screenshot when a user action could explain it, or infer a
  PLATFORM difference from screens captured in different states -- read the code that produces
  it, in the same turn, before writing the conclusion down.* Name all four instances so the
  rule carries its evidence.
- **Effort**: 15-25m
- **Impact**: Removes the single largest source of rework in this sprint. Each instance cost a
  correction cycle and put a wrong claim into a committed record.
- **Files to Update**: `CLAUDE.md`

**IMP-2: Gate the F190 dev version bump at plan approval.**

- **Root Cause**: F190 moved the bump to Phase 3.7.0b so a tester can distinguish a dev build
  from production. Sprint 68 was approved and the bump never happened; dev sat byte-identical
  to the live store version. Nothing enforces it -- `dev_version_ahead_test` compares dev
  against the last RELEASED version, which passed because 0.14.2 had not yet been recorded as
  released in that gate's source of truth.
- **Proposed Solution**: Extend `dev_version_ahead_test` (or add a sibling) to assert dev
  `version:` is strictly ahead of BOTH store rows in `STORE_VERSION_STATUS.md`, not just the
  Windows one. Play is now a second shipping surface and the gate predates it.
- **Effort**: 30-45m
- **Impact**: Makes the F190 rule enforceable rather than remembered. Harold caught this one by
  eye; the next one might ship.
- **Files to Update**: `mobile-app/test/policy/dev_version_ahead_test.dart`,
  `docs/STORE_VERSION_STATUS.md`

### Medium Priority (Next Sprint)

**IMP-3: In-app instruction text needs the same freshness discipline as the docs.**

- **Root Cause**: `docs/APP_PASSWORD_SETUP.md` was written from current vendor pages and was
  correct. The in-app dialog -- which is what users actually see at setup -- had four of six
  iCloud steps wrong and named an "Account Security" card that exists and does something else.
  Nothing connects the two, and no gate reads the in-app strings.
- **Proposed Solution**: Consider a policy test asserting that provider setup steps in
  `platform_selection_screen.dart` reference the same URLs and UI labels as
  `APP_PASSWORD_SETUP.md`. Cheaper alternative worth comparing first: fold the in-app steps
  into F201's periodic re-review, since both are "external text that silently goes stale".
- **Effort**: 45-90m for the gate; ~0 to add it to F201's checklist
- **Impact**: Prevents the class where a correct document sits beside incorrect in-app copy.
- **Files to Update**: `mobile-app/test/policy/`, or `ALL_SPRINTS_MASTER_PLAN.md` F201

**IMP-4: Record the single-session model-deviation pattern.**

- **Root Cause**: All five tasks were assigned Haiku/Sonnet and all five executed on Opus,
  because the sprint ran as one continuous interactive session with Harold's live validation
  interleaved. There was no natural handoff point.
- **Proposed Solution**: Note in `SPRINT_PLANNING.md` that a sprint expected to run as a single
  interactive session should either (a) record the deviation up front rather than per task, or
  (b) batch the cheaper-tier tasks into a delegable block before validation begins.
- **Effort**: 20-30m
- **Impact**: Makes the `Executed-by` justification honest and one-time instead of five
  identical per-task notes.
- **Files to Update**: `docs/SPRINT_PLANNING.md`

### Low Priority (Backlog)

**IMP-5: Commit messages containing backticks can be silently mangled.**

- **Root Cause**: A backticked code reference in a bash heredoc commit message ran as a shell
  command substitution and was swallowed, leaving a sentence with a hole in it. Caught and
  amended, but only because I re-read the message.
- **Proposed Solution**: Prefer writing commit messages to a file and using `git commit -F`,
  or avoid backticks in commit bodies. A note in `CLAUDE.md` under the git section.
- **Effort**: 10m
- **Impact**: Small. Prevents silent corruption of the sprint's most durable record.
- **Files to Update**: `CLAUDE.md`
