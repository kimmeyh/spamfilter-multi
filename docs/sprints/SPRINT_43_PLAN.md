# Sprint 43 Plan: redaction policy + deep dives + security/DB hardening + version bump

**Sprint**: 43
**Date**: 2026-06-23 (Planning / Phase 1-3)
**Branch**: `feature/20260623_Sprint_43` (already created off `develop` per Phase 6.6)
**PR**: #265 (the sprint PR -- created during pre-kickoff; will be updated per the PR lifecycle)
**Status**: PLANNING -- awaiting Harold Phase 3.7 approval
**Type**: Mixed -- Security/Privacy policy + enforcement (F102), Architecture + Security deep dives (F103/F104), DB-encryption (SEC-11b), anti-phishing coverage (F96), test-infra consolidation (F100), tuning (F101), release housekeeping (F105)
**Estimating method**: TWO-metric MINUTE-based per `docs/CODING_VELOCITY.md`.

> **Scope + order confirmed by Harold (2026-06-23).** Items execute in the order below. F103 = copy of the F71 Architecture-Deep-Dive template; F104 = copy of the F70 Security-Deep-Dive template (templates F70/F71 are retained for future runs). F101 is the confirmed "cap retry at ~15 min" change. F105 (version bump) is last.

---

## Sprint Objective

Close the Sprint-42 privacy gap by making log redaction a documented, enforced invariant (F102); run the periodic architecture (F103) and security (F104) deep dives now that the per-account bg-scan + two-harness-testing architecture has settled; complete the deferred DB-encryption driver swap (SEC-11b); extend anti-phishing auth coverage to the historical/detail quick-add paths (F96); consolidate the read-only E2E flows onto the in-VM harness (F100); shorten the F98 DB-lock retry cap (F101); and bump the dev version (F105).

---

## Sprint Scope (8 items, IN EXECUTION ORDER)

### 1. F102 -- Logging redaction policy: documented invariant + enforcement gate (FIRST)
- **Why first**: it establishes the invariant that F104's security deep dive will later verify, and prevents new PII-in-logs leaks during the rest of the sprint.
- Document the invariant (extend **ADR-0030** with a "Logging & Redaction" section; cross-ref in ARCHITECTURE.md Security Layers); add the **Phase 5 checklist grep line**; add a **lightweight enforcement gate** -- a test/script that fails when a `Logger`/`_bgLog` call interpolates a raw account id / email without `Redact.*`.
- **Acceptance**: policy documented + discoverable; gate fails on a deliberately un-redacted log line, passes on the redacted form.
- **Step-types**: DOCS + HOOK/test-gate. **Est-Effort: 25-40m | Est-Wall: 25-40m.**

### 2. F103 -- Periodic Architecture Deep Dive (Sprint 43 instance, copy of F71) (SECOND)
- Run the F71 scope vs the current codebase: ADR drift (esp. new ADR-0039/0040), ARCHITECTURE.md/ARSD.md alignment, platform-architecture, dead-code/deprecated-class detection, test-coverage-vs-architecture gaps. Produce a findings list; fix-now trivial items, backlog the rest.
- **Step-types**: DOCS/audit (read-only analysis + findings doc). **Est-Effort: 30-50m | Est-Wall: 30-50m.** (Spike -- depth-bounded.)

### 3. SEC-11b -- SQLCipher driver swap + plaintext->encrypted migration + verification dual-DB (THIRD) -- RESCOPED per Harold 2026-06-23
- Add `sqflite_sqlcipher` + `sqlcipher_flutter_libs`; Windows + Android plugin registration.
- **Prod upgrade path (<=0.5.3 unencrypted -> 0.5.4 encrypted)** -- the key requirement Harold raised:
  - On first 0.5.4 launch, detect "encrypted DB does not exist but plaintext `spam_filter.db` does" (= a pre-0.5.4 install).
  - Open the PLAINTEXT DB with the plaintext driver (SQLCipher cannot open a plaintext file with a key), generate/fetch the 256-bit key, create the ENCRYPTED DB with the SQLCipher driver, and copy all data (`sqlcipher_export()` or table-by-table). Verify row counts match.
  - Per Harold's dual-write requirement: **RETAIN the original plaintext file** (do NOT delete it) for a ~2-sprint verification window; cleanup is a deferred item (see F106).
- **Verification dual-write (Harold 2026-06-23): keep a pre- AND post-encrypted DB in sync for ~2 sprints, plaintext copy DEV-ONLY**:
  - **Dev**: write to BOTH the encrypted DB (primary) and a plaintext mirror so the two can be diffed/verified each sprint.
  - **Prod**: write to the encrypted DB ONLY after migration (a plaintext mirror in prod would defeat encryption-at-rest). The original pre-migration plaintext file is retained read-only as a rollback backup for the window.
- **Default flip**: flipping `encrypt_database` default to true is a Class-1/2 behavior change -- surface after QA before flipping (do not flip unilaterally this sprint unless Harold approves at the QA point).
- **Step-types**: DB-MIGRATE + SVC-EDIT + deps + native registration + dual-write infra. **Est-Effort: 90-150m | Est-Wall: 75-120m** (rescoped UP from 60-110 for the dual-write + prod-migration design). Largest + highest-risk item.
- **Spawns F106** (deferred cleanup): after the ~2-sprint verification window, remove the dual-write + delete the retained plaintext file (Sprint 45 candidate).

### 3b. F106 -- SEC-11b verification-window cleanup (~30m) -- DEFERRED to ~Sprint 45 (NOT in Sprint 43)
- After ~2 sprints of verified dual-DB operation: remove the Dev plaintext mirror + dual-write code path; delete the retained pre-migration plaintext file in prod. Listed here for traceability; added to the backlog, not executed this sprint.

### 4. F96 -- F89 auth-state coverage for historical / email-detail quick-add paths (FOURTH)
- Persist the auth classification (or raw auth headers) at scan time so quick-add from Scan History reload + email-detail evaluates SPF/DKIM/DMARC identically to a live scan (RED dialog fires when warranted). DB migration + scanner-capture wiring + read-back across the two reconstructed paths.
- **CLASS-1 decision (PENDING Harold -- "need more info" 2026-06-23)**: (a) persist the `AuthClassification` enum (GREEN/YELLOW/RED/GREY) -- ~4 bytes/row, simplest, cannot re-score old emails if the classification rules change later; vs (b) persist the raw `Authentication-Results`/`Received-SPF`/`ARC` headers -- larger + more sensitive at rest, but re-parses identically and re-scores correctly if rules change. **Deciding question for Harold**: do you ever expect to change the SPF/DKIM/DMARC classification rules AND want historical emails re-scored under the new rules? No -> (a) [recommended]; Yes/maybe -> (b). Confirm before F96 starts.
- **Step-types**: DB-MIGRATE + SVC-EDIT + tests. **Est-Effort: 45-75m | Est-Wall: 40-65m.**

### 5. F100 -- Port WinWright read-only flows to `integration_test` (FIFTH)
- Incrementally port the 6 read-only WinWright flows (navigation, settings_tabs, scan_history, text_selection, f25, f35) to the F99 in-VM lane; retire each WinWright script as covered. Harness + seams already exist (F99).
- **Step-types**: TEST-INFRA (in-VM port). **Est-Effort: 40-70m | Est-Wall: 40-70m.** Consolidation, not new coverage.

### 6. F101 -- Shorten F98 DB-lock retry bound to ~15 min (SIXTH)
- Change `_dbLockMaxAttempts` 20 -> 15 in `background_scan_windows_worker.dart` (keep `_dbLockRetryDelay = 1 min`), so worst-case hang is ~15 min instead of ~20. Update the related comment + any unit-test expectation referencing the count.
- **Step-types**: SVC-EDIT (constant + comment + test). **Est-Effort: 15m | Est-Wall: 15m.**

### 7. F104 -- Periodic Security Deep Dive (Sprint 43 instance, copy of F70) (SECOND-TO-LAST)
- **Runs AFTER all dev items** so it audits the final sprint state. F70 scope vs current code: dependency CVEs, SQL/parameterization, regex/ReDoS, **credential + logging audit (verifies the F102 redaction invariant is actually enforced)**, platform security, app-store compliance. Findings list; fix-now trivial, backlog the rest.
- **Step-types**: SECURITY/audit (read-only analysis + findings doc). **Est-Effort: 30-50m | Est-Wall: 30-50m.**

### 8. F105 -- Version bump 0.5.3 -> 0.5.4 (dev) (LAST)
- Bump dev version per the 5-file checklist (`pubspec.yaml` `0.5.3+1 -> 0.5.4+1`; background-scan log filename version token in `background_scan_windows_worker.dart` + `main.dart`; any other version refs per CLAUDE.md / STORE_RELEASE_PROCESS.md). Prod stays 0.5.2.
- **Step-types**: release housekeeping. **Est-Effort: 10m | Est-Wall: 10m.**

---

## Sprint total

**Est-Effort ~255-420m | Est-Wall ~240-390m** (items run largely in the specified sequence; within-item work parallelizes where independent). SEC-11b dominates and carries the most risk. Well under the 400-HOUR stopping threshold.

---

## Model assignments

- **F102 (policy/gate design), F103 + F104 (deep-dive analysis), F96 Class-1 decision, SEC-11b (native + migration)**: **Opus** -- judgment/architecture/security.
- **F100 (test port), F101 (constant change), F105 (version bump)**: **Sonnet** -- mechanical with clear spec.

---

## Decision-Class interrupts (NOT pre-authorized -- surface + wait)

- **F102 policy home** (Class-1): confirm extend-ADR-0030 vs standalone ADR at Phase 3.
- **F96 persist-classification vs raw-headers** (Class-1): surface at Phase 3 / F96 start.
- **SEC-11b default flip** (Class-1/2): flipping `encrypt_database` default to true is a behavior change -- surface after QA before flipping.
- Any deep-dive (F103/F104) finding that implies an architecture/scope change -> surface, don't unilaterally fix large items.

---

## PR lifecycle (per updated SPRINT_EXECUTION_WORKFLOW.md)

PR #265 is the sprint PR (created pre-kickoff). On Phase 3.7 approval -> update PR to the approved plan (checkpoint #2). End of dev -> update (#3). End of Phase 7.7 (retro improvements done) -> `gh pr ready`. 7.7.5 -> final update if needed + notify PO/SM for final approval.

---

## Coverage / velocity tracking

Each item gets a PLANNED Coverage Ledger row in `docs/CODING_VELOCITY.md` at approval; both actuals filled at completion; Accuracy Trend row at retro. Phase 7 EXIT GATE: every touched item has a ledger row with both estimates + both actuals.

---

## Phase 3.7 Standing Approval Inventory (pre-authorized through Phase 7 on approval)

All 8 items' execution as scoped (excluding the decision-class interrupts above); committing/pushing to the sprint branch; updating CHANGELOG.md + this plan + CODING_VELOCITY.md; updating the sprint PR (#265) to `develop`.

---

**Status**: PLANNING. Next: Harold reviews + answers the two early decision-class items (F102 policy home; F96 persist strategy), then Phase 3.7 approval to begin F102.
