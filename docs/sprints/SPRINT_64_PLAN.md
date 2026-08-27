# Sprint 64 Plan -- STUB (created at Sprint 63 close-out, 2026-08-27)

**Status**: STUB. Scope is selected at Phase 8.4 (refinement pass 2) after the Sprint 63 PR
merges and the Store release is in process. This stub carries the Sprint 63 retrospective
Category 13 items and standing process rules forward.

## Decided carry-ins (Sprint 63 retro Category 13 / MV decisions)

1. **FIRST TASK (Harold decision, 2026-08-26): GP-16 guided Google Play account-creation
   walkthrough.** Harold: "Need to be walked through this." Claude walks him through
   step-by-step per `docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` (PERSONAL account route, $25
   one-time, 12 testers / 14 days closed-test gate, no DUNS). This task ALSO includes the
   GP-5 publication step: hosting/URL decision (GitHub Pages is the recorded default) and
   replacing the "[SET AT PUBLICATION]" placeholders in `docs/legal/PRIVACY_POLICY.md` and
   `TERMS.md` (text already approved 2026-08-26).
2. **F94 follow-on at refinement**: the four Firebase/GCP console prerequisites for the .dev
   package proved OPTIONAL (dev-flavor Gmail sign-in works via the appauth redirect-scheme
   flow, which does not consult google-services.json). Re-scope or close those items.
3. **SEC-9 unblocked**: F94 shipped, so SEC-9 (hardcoded Android client id -> build-time
   injection) is selectable; design should target the appauth client id path.

## Fresh MV-sourced candidates (registered Sprint 63, prioritized in master plan)

- F186 (P22): body-rule authoring via Manual Rule Create + Manage Rules round-trip.
- F187 (P24): remove Harold's 647 URL-shape body rules (dev AND prod DBs, F33/F144
  discipline) -- also cuts most F180 deferred fetches on real scans.
- F188 (P26): silent neutralization of rules with unparseable condition JSON (Logger.w +
  Manage Rules "invalid" flag + integrity sweep).

## Standing process rules (apply from Sprint 63 retro, all applied 2026-08-27)

- Isolated-branch guard tests for shared-fixture suites (TESTING_STRATEGY.md).
- Scratch probes never under test/ (scratchpad or gitignored test/scratch/).
- No compound decision questions; unanswered halves are re-ask triggers.
- Announce background launches in the next user-visible message.
- Python raw-string/SyntaxWarning hard rule; verify through the real consuming code path.
- No build-input edits while any Flutter build runs (CLAUDE.md).
- Timestamp footer on decision-point/milestone responses.

## Notes

- Demo body rule `body_united__nations__compensation__commissioncom`
  (`created_by='sprint63_mv_demo'`) was deliberately LEFT in the Android dev DB at Harold's
  request for his own experimenting; removable on request (F187 cleanup will not target it --
  it is a phrase rule, not URL-shape).
- Sprint 63 PR: #366. Branch policy: on merge, branch feature/YYYYMMDD_Sprint_64 FROM
  feature/20260824_Sprint_63 immediately (Phase 6.6).
