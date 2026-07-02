# Sprint 45 F111 -- Windows App Store upload readiness verification (findings)

**Date**: 2026-07-01. **Objective**: confirm the codebase is release-ready and everything is in order to build + upload a new version to the Microsoft Store, and produce a GO / NO-GO recommendation. F111 VERIFIES; it does not build/upload to the Store, and does not merge to main.

---

## Task 1 -- develop / main parity  [RESOLVED -- CLEAN, no action needed]

**Planning-time concern**: `git rev-list origin/develop..origin/main` = 15 commits (main "ahead"), `origin/main..origin/develop` = 0. Raw counts suggested main had diverged/advanced past develop.

**Analysis** (after fetching both):
- **The code trees are IDENTICAL.** `git diff origin/main origin/develop` is **empty** -- zero file differences.
- **`git diff --name-only origin/main origin/develop`** -- empty (not even the CNAME file differs; the Create/Delete CNAME toggles net out).
- **Merge-base** (`git merge-base origin/main origin/develop`) = **`0537a8f` "Merge pull request #266"** -- which is the current HEAD of `develop` (the Sprint 44 merge). i.e. develop's HEAD IS the common ancestor.
- The 15 "main-only" commits are ALL topology, not content:
  - 11x `Merge pull request #NNN from kimmeyh/develop` -- the merge COMMITS GitHub created on each develop->main release merge (these live on main's first-parent chain but carry no code develop lacks).
  - `Create CNAME` / `Delete CNAME` pairs -- GitHub Pages housekeeping on main; the net effect is no file difference vs develop.

**Conclusion**: **main and develop are in sync (identical content).** develop is a clean, complete base for the next release -- there is nothing on main that a new release from develop would drop, and nothing on develop missing from main. The "15 ahead" is a merge-commit/CNAME topology artifact, NOT a divergence. **No Chief-Developer reconciliation action is required.**

**Note for the release merge**: when develop -> main is merged for THIS release, GitHub will again create a `Merge pull request` commit on main (expected; adds no drift). The CNAME file is main-only GitHub-Pages config and is intentionally not on develop.

---

## Task 2 -- version compatibility  [VERIFIED with one QUESTION for Harold]

**Gates (green)**:
- Version-consistency gate GREEN (Dart `test/policy/version_consistency_test.dart` + `scripts/check-version-consistency.ps1`): all app-version literals in `lib/`+`windows/runner/`+`scripts/` match `pubspec.yaml`.
- Redaction gate GREEN.

**Version state**:
| Source | version | msix_version |
|--------|---------|--------------|
| dev worktree (this branch / develop) | `0.5.4+1` | `0.5.4.0` |
| prod worktree (`spamfilter-multi-prod`) | `0.5.2+1` | `0.5.2.0` |
| CLAUDE.md "last published Store" | prod = `0.5.2` (Sprint 35 store release) | -- |

**RESOLVED (Harold 2026-07-01)**: **currently PUBLISHED = `0.5.3`**; **this release ships `0.5.4`**; **next dev (Sprint 46) = `0.5.5`**.
- This is CLEAN: dev is already at `0.5.4` and the release is `0.5.4` -- they MATCH, so no dev/prod version literal changes are needed on develop for the release. `0.5.4 > 0.5.3` (published) -> Partner Center will accept it.
- Action at release Step 1 (prod worktree): bump prod `0.5.2 -> 0.5.4` (`pubspec.yaml version` + `msix_version` -> `0.5.4.0`), then run the version-consistency gate in the prod worktree.
- CLAUDE.md's stale "prod = 0.5.2 / published 0.5.2" note corrected to "published = 0.5.3, release = 0.5.4" (this sprint).
- **No open version question remains.**

## Task 3 -- MSIX build-path integrity  [VERIFIED -- OK]

The Store MSIX is built from the **prod worktree** (`D:\Data\Harold\github\spamfilter-multi-prod`, `main` branch, post-merge), NOT this dev branch. Verified there:
- **`build_windows_args: --dart-define=APP_ENV=prod --dart-define-from-file=secrets.prod.json`** IS present in the prod `msix_config` -- this is the single most dangerous omission (without it the MSIX builds fine but ships EMPTY OAuth credentials -> silent Gmail sign-in failure). **Present -> OK.**
- `msix_config` complete: identity_name, publisher `CN=84EA8722-...`, capabilities, `store: true`, `install_certificate: false`.
- **`secrets.prod.json` present** in the prod worktree (832 bytes).
- Supported build command is `flutter pub run msix:create` (Step 3). The deprecated `scripts/build-msix.ps1` still exists on disk (empty-credentials trap) but is NOT part of the process -- header notes deprecation. **Recommend**: confirm it is never invoked; optional cleanup to delete it (backlog, low).
- Prod worktree `msix_version` currently `0.5.2.0` (= published) -- will be bumped to the chosen release version at Step 1 of the release.

## Task 4 -- Store preconditions + full verification  [VERIFIED -- OK]

**Full verification (develop / this branch)**:
- `flutter analyze` -- **clean** (0 issues).
- Full `flutter test` -- **+1692 ~28 green** (see the DNS-flake fix note below).
- Windows **PROD build** (`build-windows.ps1 -Environment prod`) -- **succeeds**; produced `dist\prod\MyEmailSpamFilter.exe`, "[DONE] Build output verified". So the develop code builds clean in prod mode. (The MSIX credential-injection step is separate -- `msix:create` from the prod worktree at release time; verified in Task 3.)
- Version-consistency + redaction gates -- **green** (Task 2).

**Store-submission preconditions** (`docs/STORE_RELEASE_PROCESS.md` Pre-Release Checklist + Steps 1-4):
- Publisher identity `CN=84EA8722-...` / `identity_name` / `publisher_display_name` -- present + consistent (dev + prod).
- `store: true`, `install_certificate: false` -- set.
- Capabilities -- `internetClient, internetClientServer, privateNetworkClientServer` (matches the app's IMAP/OAuth needs).
- `build_windows_args` OAuth injection -- present in prod (Task 3, the critical one).
- `secrets.prod.json` -- present in prod worktree.
- Privacy policy landing site -- `.net -> .com` redirect verified LIVE (302 -> https://www.myemailspamfilter.com; `.com` 200 OK).

**DNS-flake fix (fixed as found)**: the live-network test `domain_dns_verification_test.dart :: ".net redirects to .com via HTTP"` flaked once during the concurrent suite (transient DNS/timing) even though the redirect is actually healthy (verified live). Added a connection-level try/catch + 10s timeouts that `markTestSkipped` on a network failure, while KEEPING the redirect assertions when the request connects (so a genuinely broken redirect still fails). Suite is now green + network-resilient. This matters for the Saturday/Sunday release run on a stable network.

---

## GO / NO-GO recommendation

**Recommendation: GO** -- the codebase is release-ready to build + upload `0.5.4` to the Microsoft Store. All F111 checks pass:

| Check | Result |
|-------|--------|
| develop / main parity | CLEAN -- identical content; the "15 ahead" is merge/CNAME topology, no real drift. No reconciliation needed. |
| Version compatibility | RESOLVED -- release `0.5.4` > published `0.5.3`; dev already at `0.5.4` (no develop version changes needed); prod worktree bumps `0.5.2 -> 0.5.4` at release Step 1. Version-consistency gate green. |
| MSIX build-path integrity | OK -- `msix:create` path; `build_windows_args` OAuth injection present in prod; `secrets.prod.json` present; deprecated `build-msix.ps1` not used. |
| Store preconditions | OK -- identity/publisher/capabilities/`store:true`/privacy-redirect all verified. |
| Full verification | GREEN -- analyze clean, tests +1692 ~28, prod build succeeds, all gates green. |

**Release timing (Harold 2026-07-01)**: upload targeted for **Saturday/Sunday on a stable network**. No blocker to that.

**Release-time actions (NOT part of F111 -- these are the Chief-Developer release steps, per STORE_RELEASE_PROCESS.md)**:
1. Merge `develop -> main` (Harold only). Parity is clean, so this is a straightforward fast-forward-of-content merge.
2. In the **prod worktree** (`main`, post-merge): bump `pubspec.yaml version` + `msix_config.msix_version` `0.5.2 -> 0.5.4`; run the version-consistency gate.
3. `flutter clean && flutter pub get && flutter pub run msix:create`.
4. Verify the MSIX (Step 4): manifest version `0.5.4.0`, OAuth credentials embedded (non-empty client_id).
5. Upload to Partner Center; `0.5.4.0 > 0.5.3.0` so no "version already submitted" rejection.

**Minor / optional (backlog, low)**: delete the deprecated `mobile-app/scripts/build-msix.ps1` to remove the empty-credentials trap entirely.

---

## GO / NO-GO recommendation  [pending -- completed after Tasks 2-4]
