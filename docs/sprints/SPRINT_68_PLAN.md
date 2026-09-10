# Sprint 68 Plan

**Status**: AWAITING PHASE 3.7 APPROVAL (not approved; no task work has started)
**Branch**: `feature/20260909_Sprint_68`
**Planned**: 2026-09-09
**Scope selected by**: Harold, 2026-09-09 (Phase 8.4 backlog refinement pass 2)

## Sprint Goal

Finish the publisher rename, and convert three recurring failure classes into things that
cannot recur: a question format corrected four times, a contrast defect with no gate, and a
public web property that drifted six months from the app it describes. Plus open the provider
gate on two mail services that are already built and unreachable.

## Scope

| ID | Title | Priority | Est |
|---|---|---|---|
| F199 | Rename the publisher to "Kimmey Consulting LLC" (finish) | 8 | 10-20m |
| F198 | Forcing function for the numbered-question format | 18 | 45-75m |
| F191 | Ship Yahoo Mail and iCloud Mail -- open the provider phase gate | 20 | 60-90m |
| F200 | Web Property Deep Dive -- myemailspamfilter.com + GitHub Pages | 20 | 240-480m |
| F197 | Dark-mode contrast: GATE for hardcoded-surface + theme-text | 26 | 45-90m |

**Total estimated coding time**: 400-755 minutes (~6.5-12.5 hours).

**Deliberately NOT in scope** (Harold, 2026-09-09): F165 (cross-device rules-DB sharing) and
GP-4 (Gmail OAuth verification / CASA) moved to HOLD. F192 (Custom IMAP host-entry UI) planned
for Sprint 69.

## Standing constraint -- ADR-0042 cross-platform parity (Harold, restated verbatim at scope selection)

> "everything needs to take into account both the Windows App and the Android app and ADR
> stating that everything should be functionally and UI the same unless it cannot be - and
> where it cannot be it should be implemented as a platform exception for what is needed --
> this applies to all backend code, frontend code, data, architecture, development, security,
> testing, deployment."

Applied per task below. Honest assessment of where it bites in this sprint:

- **F191 is the one task where this is load-bearing.** It changes shared provider-selection UI
  and shared adapter behavior. Both platforms must show the same providers and authenticate the
  same way. **A provider must not be enabled on one platform and hidden on the other**, and the
  validation burden is therefore doubled, not halved -- see R-5/AC-5.
- **F197** targets shared Flutter UI, so its gate protects both platforms by construction. No
  exception anticipated.
- **F199, F198, F200** are repo, tooling and web-property work with no platform surface. Parity
  is satisfied vacuously, and saying so explicitly is better than implying an analysis happened.

**No platform exception is anticipated in this sprint.** If one becomes necessary it must be
declared per ADR-0042, not implemented silently.

## Audit-first findings (MANDATORY per SPRINT_PLANNING.md, Sprint 65 retro IMP-2)

Performed at planning, 2026-09-09. **Two cards changed shape as a result**:

- **F197 said "add a gate". A contrast gate ALREADY EXISTS** --
  `mobile-app/test/policy/text_contrast_test.dart` (F133-S52, Sprint 52), which enforces a
  `grey.shade600` floor for text on white and carries a substring-keyed exemption map. It does
  NOT cover the mix pattern F197 is about (hardcoded container + theme-derived text). So the
  task is an EXTENSION of an existing gate, not a new file -- which changes the work, the risk,
  and the model tier. Extending a gate with a live exemption map is more delicate than writing
  one from scratch.
- **F191's premise VERIFIED TRUE.** `platform_registry.dart:128,144` set `yahoo` phase 2 and
  `icloud` phase 3; `generic_imap_adapter.dart:119,130` define both factories with real hosts
  (`imap.mail.yahoo.com`, `imap.mail.me.com`), port 993, TLS -- structurally identical to
  `aol()` at line 93, which ships today. The code change genuinely is two integers.
- **F198's detection half largely exists.** `.claude/hooks/sprint-auto-advance.ps1` already
  parses the last assistant message for question shapes, and `.claude/hooks/test-cases/` holds
  **17 allow-cases** plus a runner. The new work is recognising the numbered-list form and
  adding cases -- not building question detection.
- **F199 is mostly done.** Repo, Play developer name, and Partner Center listing fields all
  landed 2026-09-09. Only the Partner Center publisher display name remains, and it is blocked
  externally.

---

## Task 1 -- F199: Finish the publisher rename (Priority 8)

**Value**: This completes the entity rename so every customer-visible surface names the LLC that
actually publishes the app.

**Requirements**:
- R-1: Audit first. Repo, Play developer name and Partner Center listing fields are ALREADY
  delivered (commits `8558aa3`, `5865794`; console changes 2026-09-09). Verify, do not redo.
- R-2: The Partner Center publisher display name is the only remaining surface. Microsoft's own
  documentation contradicts itself on whether an Individual account can change it, so this is
  resolved by a support ticket, not by editing.
- R-3: Do NOT change `msix_config.publisher` (`CN=84EA8722-...`), the dated sprint docs/ADRs, or
  the already-submitted Play "government app" declaration. Each is a record of external or
  historical state.

**Affected components / files**:
- `docs/LEGAL_ENTITY.md` -- record the support outcome when it arrives
- No code changes.

**Dependencies / blockers**:
- EXTERNAL, Harold: open the Partner Center support ticket (https://aka.ms/windowsdevelopersupport)
  asking whether an Individual account can change its publisher display name. The sprint cannot
  close this item without that answer, and that is acceptable -- it does not block the other tasks.

**Acceptance criteria**:
- AC-1: `docs/LEGAL_ENTITY.md` records the support answer, or explicitly records that the ticket
  is open and unanswered at sprint close.
- AC-2: No further repo occurrences of the old publisher name on any LIVE surface (dated records
  excluded), verified by grep.

**Tests to write**:
- T-1 (verifies AC-2) -- TEST-POLICY, existing: `test/policy/version_consistency_test.dart` and
  the full policy suite must stay green. No new test; this is a verification task.

**Definition of Done**: default task-level DoD PLUS:
- The outcome is recorded whether or not it is favorable. "Support did not answer" is a result.

**Model**: Haiku -- verification and a doc update, no design.

**Step-types**: DOCS

**Est-Effort**: 10-20m

---

## Task 2 -- F198: Forcing function for the numbered-question format (Priority 18)

**Value**: This prevents a question-format rule that has been corrected four times from being
broken a fifth.

**Requirements**:
- R-1: **Evaluate the cheap option FIRST and record the comparison in the card's outcome.**
  Moving the rule from selectively-recalled memory into `CLAUDE.md`'s "Things Claude Should NOT
  Do" (read every session) may be sufficient. Build the hook only if the comparison says the
  doc change is not enough. Do not assume a hook.
- R-2: If a hook is built, it extends the EXISTING question detection in
  `.claude/hooks/sprint-auto-advance.ps1` rather than duplicating it.
- R-3: **Allow-cases FIRST, before the check.** At minimum: numbered question (allow), prose
  question (block), question inside a fenced code block (allow), question quoted from Harold
  (allow), Phase 7 retro prompt (allow).
- R-4: Mutation-verified in BOTH directions -- the check fires on a prose question and does NOT
  fire on each allow-case.
- R-5: `run-test-cases.ps1` green. This is the suite Sprint 67 IMP-2 exists because it was not run.

**Affected components / files**:
- `CLAUDE.md` -- the cheap option, if it wins
- `.claude/hooks/sprint-auto-advance.ps1` -- the check, if built
- `.claude/hooks/test-cases/` -- new allow/block cases

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Platform: N/A (repository tooling; no app surface, so ADR-0042 parity is not engaged).

**Acceptance criteria**:
- AC-1: The comparison in R-1 is written down with a recommendation, before any hook exists.
- AC-2: If a hook ships, every allow-case in R-3 passes and the prose-question case blocks.
- AC-3: `powershell -File .claude\hooks\run-test-cases.ps1` exits green with the full pre-existing
  suite (17 allow-cases) still passing.
- AC-4: Mutation-verified per R-4, with the verification recorded.

**Tests to write**:
- T-1 (verifies AC-2, AC-3) -- HOOK, in `.claude/hooks/test-cases/`: one JSON case per R-3 shape.
- T-2 (verifies AC-4) -- HOOK, manual mutation: break the check, confirm the suite goes red,
  restore, confirm green.

**Definition of Done**: default task-level DoD PLUS:
- **A gate that blocks correct work is worse than no gate.** If the allow-cases cannot be made to
  pass cleanly, ship the `CLAUDE.md` change alone and say so -- that is a success, not a
  de-scope.

**Model**: Sonnet -- *why not Haiku*: the risk is false positives on a Stop hook that can block
every turn; tuning detection against 5 allow-shapes is judgment work, and Sprint 67 shipped
exactly this defect.

**Step-types**: DOCS, HOOK

**Est-Effort**: 45-75m

_**Risk & rollback**_: A mistuned Stop hook blocks legitimate turns repo-wide. Mitigation:
allow-cases before the check (R-3), mutation in both directions (R-4). Rollback: revert the hook
file; the `CLAUDE.md` line can stand alone.

---

## Task 3 -- F191: Ship Yahoo Mail and iCloud Mail (Priority 20)

**Value**: This enables two mail providers that are already built and reachable only through a
display gate, and makes the Play listing's existing provider claim true.

**Requirements**:
- R-1: Audit confirmed at planning -- both factories are complete and structurally identical to
  `aol()`, which ships today. The code change is `yahoo` phase 2 -> 1 and `icloud` phase 3 -> 1.
- R-2: **The work is PROOF, not the edit.** Each provider needs a live end-to-end validation the
  gate has never permitted: app-password auth, folder discovery, a real scan, and the
  safe-sender and delete paths -- the same validation AOL receives.
- R-3: If iCloud does not authenticate cleanly (Apple ID app-specific password, or an account
  IMAP precondition), **ship Yahoo alone and leave iCloud gated.** Shipping a provider that
  fails at sign-in is worse than shipping neither.
- R-4: Only after a provider actually validates may listing copy be widened to claim it. The
  Sprint 66 defect was copy that outran the shipped app.
- R-5 (**ADR-0042**): the phase change is in shared `platform_registry.dart` and therefore
  affects Windows and Android identically. Validate on BOTH platforms. A provider enabled on one
  and hidden on the other is a parity violation, not a partial success.

**Affected components / files**:
- `mobile-app/lib/adapters/email_providers/platform_registry.dart:130` -- yahoo `phase: 2` -> `1`
- `mobile-app/lib/adapters/email_providers/platform_registry.dart:146` -- icloud `phase: 3` -> `1`
- Listing copy (`docs/store-assets/`) -- only if R-4 is satisfied

**Dependencies / blockers**:
- EXTERNAL, Harold: a Yahoo account and an iCloud account, each with an app-specific password.
  **Task cannot be validated without these.** If unavailable at kickoff, this task should be
  pulled from scope rather than shipped unvalidated.

**Non-functional requirements**:
- Platform: shared UI and shared adapter; identical on Windows and Android per ADR-0042. No
  platform exception anticipated.
- Security: app passwords go through the existing platform-native secure credential storage --
  no new credential path is introduced by this task.

**Acceptance criteria**:
- AC-1: `getAvailablePlatforms()` returns Yahoo and iCloud as phase 1, and
  `platform_selection_screen.dart` renders them as enabled rather than "Coming Soon".
- AC-2 (behavioral): Given a real Yahoo account with an app password, When the user adds it and
  runs a scan, Then folders are discovered and rule actions apply -- verified on Windows AND on
  Android.
- AC-3 (behavioral): same as AC-2 for iCloud, OR iCloud remains phase 3 with the blocking reason
  recorded per R-3.
- AC-4: No listing copy claims a provider that did not pass AC-2/AC-3.

**Tests to write**:
- T-1 (verifies AC-1) -- TEST-UNIT in `test/unit/platform_registry_test.dart`: the enabled-phase
  set contains yahoo and icloud, and `getPlatformsByPhase(1)` includes them.
- T-2 (verifies AC-2/AC-3) -- MANUAL, both platforms: live scan per provider, recorded in the
  plan's Phase 5 evidence with account, folder count and action outcome.
- T-3 (verifies AC-4) -- TEST-POLICY, existing `play_listing_assets_test.dart` /
  `help_platform_claims_test.dart` stay green.

**Definition of Done**: default task-level DoD PLUS:
- Manual validation evidence recorded per platform per provider. Four cells; a missing cell is a
  missing result, not an assumed pass.

**Model**: Sonnet -- *why not Haiku*: the edit is trivial but the judgment is not -- deciding
whether a provider has genuinely validated, and handling the R-3 partial-ship branch, is exactly
where a cheaper tier would declare success on a two-integer diff.

**Step-types**: SVC-EDIT, TEST-UNIT, DOCS

**Est-Effort**: 60-90m (excludes Harold's account-setup time)

_**Risk & rollback**_: A provider ships that cannot authenticate for real users. Mitigation: R-2
live validation and the R-3 partial-ship branch. Rollback: restore the phase integers -- a
one-line revert per provider.

---

## Task 4 -- F200: Web Property Deep Dive (Priority 20)

**Value**: This stops a public page from telling users their email content is never written to
disk when the app stores sender, subject and a 100-character preview.

**Requirements**:
- R-1: **Fix the false persistence claim FIRST, independently of the rest.**
  `docs/index.html:235` asserts email content "is never persisted to disk", contradicting
  `PRIVACY_POLICY.md`. This is inaccuracy, not staleness, on a page the Play listing cites.
- R-2: Inventory everything served LIVE under the domain -- both directory trees, every page,
  every internal link -- rather than reasoning from the repo. The two have already diverged.
- R-3: Resolve the duplicate policies: `/privacy` (March 20) vs `/legal/PRIVACY_POLICY.html`
  (August 28). Exactly ONE privacy policy and ONE deletion page may remain reachable.
- R-4: Resolve `docs/website/`, a byte-identical second copy of the site.
- R-5: Bring content current for BOTH stores -- Play presence, store links, platform status,
  publisher identity, contact.
- R-6: **Close the gate gap.** `test/policy/legal_docs_test.dart` validates the Markdown and does
  not inspect the served site at all. Without this, the same drift recurs.
- R-7: F201 (periodic re-review template) must exist as a HOLD backlog item. This is the final
  criterion in sequence, not a substitute for R-1..R-6.

**Affected components / files**:
- `docs/index.html` -- the false claim, publisher identity, contact, both stores
- `docs/privacy/`, `docs/delete/` -- correct or delete
- `docs/website/` -- resolve the duplicate
- `mobile-app/test/policy/legal_docs_test.dart` -- extend to the served site
- `docs/ALL_SPRINTS_MASTER_PLAN.md` -- F201 (already drafted; verify it survives)

**Dependencies / blockers**:
- Harold may fix parts of this directly ("likely all be fixed by tomorrow"). **Re-audit at
  kickoff before doing any work**; the scope may have shrunk.
- GitHub Pages serves `main`, so nothing is live until merge.

**Non-functional requirements**:
- Platform: web property, no app surface. ADR-0042 parity engaged only in CONTENT -- the site
  must describe both platforms accurately, which is R-5.
- Security/privacy: every claim must match `PRIVACY_POLICY.md` and actual app behavior. This
  task exists because that invariant broke.

**Acceptance criteria**:
- AC-1: No page makes a claim contradicting `PRIVACY_POLICY.md` or actual app behavior.
- AC-2: Every URL served is inventoried and is either current or deleted.
- AC-3: Exactly one privacy policy and one deletion page are reachable; every internal link
  targets them.
- AC-4: The site presents both stores accurately, and names Kimmey Consulting LLC with contact
  information.
- AC-5: A gate fails the build when a served-site claim contradicts the policy.
- AC-6: F201 exists as a HOLD backlog item.

**Tests to write**:
- T-1 (verifies AC-1, AC-5) -- TEST-POLICY, extending `test/policy/legal_docs_test.dart`: assert
  the served HTML makes no persistence/collection claim contradicting `PRIVACY_POLICY.md`.
  Mutation-verify by reintroducing the false claim and confirming red.
- T-2 (verifies AC-3) -- TEST-POLICY: exactly one privacy-policy page exists under `docs/`.

**Definition of Done**: default task-level DoD PLUS:
- The live site is re-checked AFTER merge to `main`, since Pages serves `main` and a green local
  test does not prove what the public sees.

**Model**: Sonnet -- *why not Haiku*: unbounded discovery, deletion decisions on published pages,
and a gate extension. The deletion judgment (which of two policies is canonical) is not
mechanical.

**Step-types**: DOCS, TEST-POLICY

**Est-Effort**: 240-480m (unbounded discovery; the widest estimate in this sprint)

_**Risk & rollback**_: Deleting a page that something still links to. Mitigation: R-2 inventory
of every internal link before any deletion. Rollback: git revert; the site is versioned.

---

## Task 5 -- F197: Contrast gate for the hardcoded-surface + theme-text pattern (Priority 26)

**Value**: This prevents a third instance of the dark-mode defect class that produced two
user-visible bugs in Sprint 67.

**Requirements**:
- R-1: **Audit finding, and it changes the task**: a contrast gate ALREADY EXISTS at
  `mobile-app/test/policy/text_contrast_test.dart` (F133-S52). It enforces a `grey.shade600`
  floor for text on white and carries a substring-keyed exemption map. It does NOT cover the
  mix pattern. **Extend it; do not create a second contrast gate.**
- R-2: The defect is MIXING a hardcoded `Colors.*.shadeNN` container with theme-derived text.
  A fully-hardcoded card is CORRECT and must not be flagged -- Default Folders measures 7.56:1.
  The gate must not fire on it.
- R-3: Both known instances are already fixed (F195 account header; Scan History info strip).
  The gate must pass against the current tree on day one.
- R-4: Mutation-verify: reintroduce the mixed pattern, confirm red; restore, confirm green.
- R-5: Preserve the existing exemption map and its substring keying. Widening an exemption to
  make a new check pass is how a gate quietly stops gating.
- R-6 (ADR-0042): shared Flutter UI, so the gate protects Windows and Android identically. No
  platform exception anticipated.

**Affected components / files**:
- `mobile-app/test/policy/text_contrast_test.dart` -- extend

**Dependencies / blockers**: None.

**Non-functional requirements**:
- Accessibility: WCAG 2.1 AA per ADR-0037 -- 4.5:1 normal text, 3:1 large.
- Platform: shared UI; identical on both platforms.

**Acceptance criteria**:
- AC-1: The gate fails when a `Colors.*.shadeNN` container encloses text taking its color from
  `Theme.of(context)` / `textTheme`.
- AC-2: The gate passes on a fully-hardcoded container (both halves pinned), verified against
  the Default Folders card specifically.
- AC-3: The gate passes against the current tree with no new exemptions added.
- AC-4: All pre-existing `text_contrast_test.dart` assertions still pass.

**Tests to write**:
- T-1 (verifies AC-1, AC-2) -- TEST-POLICY, self-check inside the gate: a fixture proving it
  detects the mixed pattern and allows the fully-hardcoded one (mirrors the file's existing
  self-check convention).
- T-2 (verifies AC-3, AC-4) -- TEST-POLICY: `flutter test test/policy` green.

**Definition of Done**: default task-level DoD PLUS:
- Mutation evidence recorded per R-4.
- If the check cannot distinguish AC-1 from AC-2 without exemptions, STOP and surface it rather
  than adding exemptions to force it green.

**Model**: Sonnet -- *why not Haiku*: extending a live gate with an exemption map is more
delicate than authoring one; the AC-1/AC-2 distinction is the whole difficulty, and getting it
wrong either blocks correct code or gates nothing.

**Step-types**: TEST-POLICY

**Est-Effort**: 45-90m

_**Risk & rollback**_: A gate that flags correct fully-hardcoded cards would block legitimate
work (the Sprint 67 F193 failure mode). Mitigation: AC-2 tests the false-positive case
explicitly. Rollback: revert the test file.

---

## Model assignment summary

| Task | Model | Why not cheaper |
|---|---|---|
| F199 | Haiku | Verification + doc update, no design |
| F198 | Sonnet | Stop-hook false-positive risk; 5 allow-shapes to tune |
| F191 | Sonnet | Validation judgment + partial-ship branch |
| F200 | Sonnet | Unbounded discovery; deletion decisions on published pages |
| F197 | Sonnet | Extending a live gate with an exemption map |

Planner/analyst tier stays top (Opus) per SPRINT_PLANNING.md "Activities Requiring Fable/Opus".

## Sequencing

1. **F199** (10-20m) -- shortest; unblocks nothing but closes an assigned item.
2. **F197** (45-90m) -- self-contained, no external dependency.
3. **F198** (45-75m) -- self-contained; R-1 may conclude the cheap option suffices.
4. **F191** (60-90m) -- gated on Harold's Yahoo/iCloud accounts; start once available.
5. **F200** (240-480m) -- largest and least bounded; re-audit at kickoff, Harold may have
   already fixed part of it.

F199, F197 and F198 are mutually independent and could run in parallel across agents. F191 and
F200 both have external dependencies and should be sequenced against them, not against each
other.

## Open questions for Phase 3.7 approval

1. **F191 accounts**: are a Yahoo account and an iCloud account with app-specific passwords
   available? If not, F191 should be pulled rather than shipped unvalidated.
2. **F200 overlap**: you expected to fix much of this directly. Should F200 stay at full scope,
   or be re-scoped at kickoff to whatever remains?

## Phase 5.3 Manual Validation evidence

Recorded as it happens. A missing cell is a MISSING RESULT, not an assumed pass.

### F191 -- four cells (2 providers x 2 platforms, ADR-0042)

| Provider | Windows | Android |
|---|---|---|
| Yahoo Mail | **PASS** 2026-09-09 | **PASS** 2026-09-09 |
| iCloud Mail | **PASS** 2026-09-09 | **PASS** 2026-09-09 |

**All four cells PASS. AC-1, AC-2, AC-3 and AC-5 are met.**

**Yahoo / Windows -- PASS (2026-09-09, Harold, screenshots)**

- Account added and listed: `kimmeyh@yahoo.com - Yahoo Mail - App Password`, alongside the
  existing AOL and Gmail accounts. It was selectable at all, which is the phase-gate change
  (AC-1) demonstrated end to end.
- Live scan **completed in 35s**, read-only mode, against `kimmeyh@yahoo.com`.
- 41 emails evaluated across Inbox and Bulk, all "No rule" -- expected, since no
  Yahoo-specific rules exist yet. Rule EVALUATION ran on every message; nothing matched.

**FOLDER HANDLING -- corrected THREE times. Harold's account is the authority; the
screenshots were not.**

The sequence, kept because the mistake is more instructive than the fact:

1. I wrote that the adapter found Bulk "with no configuration".
2. Harold: he set the folders himself. I over-corrected to "the adapter did not decide to
   scan Bulk".
3. I saw his folder-picker screenshot showing Inbox and Bulk both ticked with "Recommended"
   badges and swung back, claiming the app pre-checked them.
4. Harold: *"I checked them... they were not both pre-checked."*

**Step 3 was my error, and it is a repeat of a class already hit this sprint.** The
screenshot was taken AFTER his edit, and I read a post-change state as a pre-change one --
the same mistake as the Play Console line reverted in `5865794`, where a record of CURRENT
state was treated as a target. Two ticked boxes are exactly what his own edit produces, so
that screenshot could not distinguish the two explanations, and I chose the one that
flattered the app.

**What the CODE says, traced rather than inferred from pixels**
(`folder_selection_screen.dart:269-277`):

```dart
if (widget.initialSelectedFolders != null) {
  selections[folder.id] = widget.initialSelectedFolders!.contains(folder.displayName);
} else {
  selections[folder.id] = PRESELECT_FOLDER_TYPES.contains(folder.canonicalName);
}
```

**`initialSelectedFolders` WINS over the canonical pre-select.** The account already carried a
saved selection of Inbox alone from setup, so that branch ran and Bulk loaded UNCHECKED.
`PRESELECT_FOLDER_TYPES = {inbox, junk}` applies only when there is NO prior selection.

The "Recommended" badge is unconditional (line 469: it renders for any folder in
`PRESELECT_FOLDER_TYPES`, independent of the tick). So Bulk showed **a Recommended badge on an
unchecked box** -- recommendation and selection are separate, and only the badge was
automatic.

**Accurate version: the app CLASSIFIED Yahoo's `Bulk` as `CanonicalFolder.junk` and labelled
it "Spam/Junk folder", but did NOT select it. Harold ticked it in Manual Scan and again in
Background.**

**This is a finding, not just a record correction.** A user who accepts the defaults at
account setup gets Inbox only, and their spam folder is never scanned -- for a SPAM FILTER
that is the folder that matters most. The pre-select exists and is correct; a prior saved
selection silently outranks it. Whether setup should seed the junk folder, or the picker
should surface "Recommended but not selected" more loudly, is a product question worth a
backlog item. Not raised as a defect here: it is pre-existing behavior, unrelated to F191,
and outside this sprint's approved scope.

**What IS proven by these screens, independent of who ticked what:**

- **All 9 Yahoo folders enumerated over IMAP**, including Harold's custom ones (Diet, Misc,
  SBC) alongside the standard set.
- **`Bulk` classified and labelled "Spam/Junk folder"** with the junk icon, distinct from the
  plain icon on custom folders -- the app states the Bulk/Spam equivalence itself.
- **Per-folder message counts read** ("0 messages" on the empty custom folders).
- Safe Sender picker correctly single-select ("Select one folder (9 available)"); scan picker
  multi-select with Select All.

**The counts reconcile exactly, and the apparent mismatch is a Yahoo WEB UI artifact.**
Harold flagged that the Yahoo web screens "don't match up to the scan results" -- worth
chasing, and it resolves cleanly:

- Yahoo web **Inbox badge: 40**. Yahoo web **Spam: 1**. Total **41** = the scan's 41.
- The Inbox screenshot is filtered to the **Primary** tab. Primary / Offers / Social /
  Newsletters are a Yahoo web feature ("Newsletters 11 new" is visible in the same
  screenshot); **IMAP has no concept of them** and sees the whole Inbox. The ~40
  fantasy-sports messages live in the other tabs -- present over IMAP, invisible on Primary.
  Yahoo's own hint appears at the bottom of that screenshot: "Looking for older messages? Try
  checking the All tab."
- The single message in Yahoo's **Spam** folder ("Changes to your Yahoo Mail Storage are
  coming soon") is **row 1 of the scan results, tagged `Bulk`**.

**So `Bulk` is Yahoo's IMAP name for the folder the web UI labels `Spam`.** The scan saying
"Bulk" while the browser says "Spam" is CORRECT, not a discrepancy.
`junk_folder_config.dart:77` already carries both: `defaultJunkFolders: ['Bulk', 'Spam']`.
Worth recording because it will look like a bug to the next person who compares the two
screens.

**The app-password instructions are independently confirmed by the scan itself.** Two Yahoo
notification emails appear in the results: *"An app password was generated for your Yahoo
account"* and *"Your app password was used to sign in to a third-party app."* Yahoo
acknowledged both halves of the flow, so `docs/APP_PASSWORD_SETUP.md`'s Yahoo section is
verified against a real account rather than only against Yahoo's help pages. Both messages
are also visible in Harold's Yahoo web Inbox, timestamped 7:29 PM and 7:30 PM.

**On the 2SV question**: Harold does not believe two-step verification was required to reach
"Create app password" (2026-09-09). Recorded as HIS OBSERVATION, which is the best evidence
available -- Yahoo documents it neither way. The doc continues to present 2SV as a FALLBACK if
the option is missing rather than as a stated requirement, which remains the right shape.

### Android cells (2026-09-09, after rebuilding at 0.15.0)

The emulator first showed the PRE-F191 build -- Yahoo under "Coming Soon / Phase 2", iCloud
absent entirely. Harold spotted it. Rebuilt and reinstalled, then both cells ran.

**Version confirmed on device**: Android Settings > General reads **Version 0.15.0**, so the
F190 bump propagated to the platform it exists for -- a tester can now tell this build from the
0.14.2 in production at a glance.

**Yahoo / Android -- PASS.** Scan completed in **15s**: 41 emails, **Processed: 41, No rule:
41, Safe: 0, Deleted: 0, Errors: 0**.

**This is the ADR-0042 parity evidence the card required (R-5/AC-5).** Same account, same
mailbox, same 41 messages as the Windows run, same all-"No rule" outcome. The two platforms
agree, which is the whole point of validating both rather than assuming shared code behaves
identically. The Yahoo notification mails ("An app password was generated...", "...used to
sign in to a third-party app") appear in the Android results too.

**iCloud / Android -- PASS.** Account present and selectable, scan ran cleanly, all counters 0.

Different from the Windows iCloud run ("Found 2") and that difference is EXPECTED, not a
discrepancy: those 2 were safe-sender-skipped at `email_scanner.dart:330` on Windows (see
F203), and no new mail has arrived since. A near-empty new mailbox proves authentication,
folder enumeration and a clean scan -- it does not exercise rule evaluation, and this cell is
recorded with that limit stated rather than implying Yahoo-grade coverage.

**A CLAIM MADE HERE AND RETRACTED (2026-09-09).** This section briefly recorded that Android's
empty-state wording was honest where Windows' was misleading, and called it "worth more than
the cell itself". **It was wrong**, and Harold caught it: *"Not sure this was true or just the
timing of results pasted were out of order."*

It was the timing. The Android screen reading "No Results Yet" was captured BEFORE that scan
ran; the Windows screen was captured AFTER. Different states, not different platforms. Both
strings live in the shared `lib/ui/widgets/empty_state.dart`, and
`results_display_screen.dart:791-797` selects between them with one shared conditional --
never-scanned versus scanned-and-found-nothing. Android renders identical text in identical
state.

Kept rather than deleted because the error matters more than the finding did: it was the
fourth time this session I resolved an ambiguous screenshot toward the more interesting
conclusion instead of reading the code. See F203 for the corrected, SHARED scope.

### Cells NOT run, and why that is fine

Nothing outstanding. All four ran. Two limits stated honestly rather than buried:

- iCloud's evidence is thin by VOLUME on both platforms (a new mailbox with 2 then 0
  messages). It proves the provider works end to end; it does not prove much about rule
  evaluation at scale. Yahoo's 41 messages carry that weight on both platforms.
- No listing copy has been widened to claim either provider (R-4). That stays true until
  Harold decides to update store copy, which is a separate action from this sprint.

## Definition of Done (sprint level)

Per `SPRINT_EXECUTION_WORKFLOW.md` Phases 5-7. Additions for this sprint:

- F191 manual validation evidence recorded per platform per provider (four cells).
- F198 and F197 mutation evidence recorded in both directions.
- F200 re-verified against the LIVE site after merge to `main`.
- No un-surfaced Class-1/2/3 decisions.
- No platform exception introduced without an ADR-0042 declaration.
