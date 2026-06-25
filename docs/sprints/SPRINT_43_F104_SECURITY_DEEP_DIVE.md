# Sprint 43 F104 -- Periodic Security Deep Dive (findings)

**Run of the F70 reusable template** against the codebase at Sprint 43 (after F102/F103/F96/F100/F101 landed).
**Date**: 2026-06-24. **Scope**: dependency CVEs, SQL injection / parameterization, regex injection / ReDoS, credential-storage + LOGGING audit (verify the F102 redaction invariant is enforced), platform security (MSIX, Android), app-store compliance.

**Outcome**: the security posture is healthy. The F102 redaction gate (this sprint) is GREEN with zero violations -- the credential-logging audit that previously found leaks now passes mechanically. No SQL injection, no unguarded ReDoS surface on the scan path, certificate pinning in place. Findings are small: a few dependency upgrades to evaluate (no known-exploited CVE blocking), surfaced as backlog. Full suite green at +1669 ~28.

---

## 1. Dependency CVEs / freshness (`flutter pub outdated`)

No dependency is flagged with a known-exploited CVE that blocks release. The notable gaps are version drift, not active vulnerabilities:

| Package | Current | Latest | Disposition |
|---------|---------|--------|-------------|
| `flutter_secure_storage` | 9.2.4 | 10.3.1 | **Backlog (evaluate)**: major bump; credential store is security-critical so upgrade deliberately + retest Windows/Android secure storage. Not urgent (9.2.4 has no known CVE). |
| `flutter_appauth` | 8.0.3 | 12.0.1 | Backlog: OAuth library; major bump, retest the full Gmail/AOL flows before adopting. |
| `msal_auth` | 3.3.0 | 3.5.0 | Backlog (low): Outlook OAuth is deferred (H5), so this is not on an active path. |
| `workmanager` | 0.5.2 | 0.9.0+3 | Backlog: Android background scheduling (F98); major bump, retest per-account WorkManager. |
| `file_picker` | 8.3.7 | 11.0.2 (12 beta) | Backlog (low): import/export only; stay off the beta. |
| `js` (transitive) | 0.6.7 | **discontinued** | **Note**: pulled in transitively; discontinued upstream. No action available directly (transitive); track for when a dependent drops it. |
| `logger`, `path_provider`, `sqflite`, `archive` | minor behind | -- | Low-risk minor/patch bumps; fold into a routine `pub upgrade` pass. |

- **No `--major-versions` upgrade performed this sprint** (a security deep dive surfaces; it does not silently bump security-critical deps mid-sprint -- each of the major bumps above warrants its own retest and is a Class-2 development decision). Filed as **F108** (backlog) below.
- **Action**: none blocking. Backlog F108 to evaluate the `flutter_secure_storage` / `flutter_appauth` / `workmanager` major bumps deliberately.

## 2. SQL injection / parameterization

- **Clean.** A full scan of `rawQuery` / `rawDelete` / `rawInsert` / `rawUpdate` / `execute` in `lib/` for string interpolation (`$var` / `${...}`) returned **zero** SQL-building interpolations. The only interpolations near `execute(` are the `PRAGMA` setup (`busy_timeout`, `journal_mode`, `foreign_keys`) -- constants, not user input.
- All dynamic queries use positional `?` placeholders + `whereArgs` (sqflite parameter binding). The v6/v7/v8 migrations that delete TLD rules read rows then delete by `id IN (?, ?, ...)` with bound args -- no interpolated user data.
- **OK -- no action.**

## 3. Regex injection / ReDoS

- **Scan path is guarded (SEC-1).** `PatternCompiler` runs rule-pattern matching in an isolate with a timeout (`defaultMatchTimeout`), and includes ReDoS heuristics: nested-quantifier detection (`pattern_compiler.dart` ~L265/284/304), alternation-with-quantifier and repeated-char checks. Invalid patterns fall back to a never-match regex (`(?!)`), not an exception.
- **UI validation/preview sites** (`manual_rule_create_screen`, `rule_edit_screen`, `rule_test_screen`, `safe_sender_quick_add_screen`, `safe_sender_list`) build `RegExp(pattern)` directly, but each is wrapped in try/catch and operates on the USER'S OWN pattern, on the user's own device, for live validation/preview -- a self-inflicted hang at most, not an injection vector. The authoritative scan-time matching uses the timeout-protected `PatternCompiler`.
- **OK -- no action** (consistent with prior audits; the SEC-1 design holds).

## 4. Credential-storage + LOGGING audit (verifies the F102 invariant)

- **The F102 redaction gate is GREEN.** `scripts/check-log-redaction.ps1` reports `[OK] No logging-redaction violations found`, and the Dart mirror (`test/policy/log_redaction_test.dart`) passes in the full suite. The Sprint-42 PII-in-logs theme (which F102 fixed 13 instances of) does not recur -- the gate now mechanically blocks regressions. **This is the headline result of the F104 audit: the policy introduced this sprint is enforced and clean.**
- **No `print()` in `lib/`** (Logger-only per the coding standard); the redaction gate covers `Logger` + `_bgLog` + generated PowerShell/Task-Scheduler artifacts.
- **Credential storage is centralized + secure**: secrets live in `flutter_secure_storage` via `secure_credentials_store.dart` / `secure_token_store.dart` / `database_encryption_key_service.dart`. No plaintext credential logging (gate-verified). The DB-encryption key service stores a 256-bit key (SEC-11 infra); the at-rest DB encryption itself is now SEC-11b (Post-MVP, see master plan).
- **OK -- no action; this is the audit's strongest area this sprint.**

## 5. Platform security

- **Windows / MSIX**: capabilities are minimal and appropriate -- `internetClient, internetClientServer, privateNetworkClientServer` (needed for IMAP/OAuth loopback). Publisher identity set. Single-instance mutex + env-aware app-data paths (ADR-0035). Certificate pinning via `PinnedHttpClient` / `certificate_pinner.dart` (the `badCertificateCallback` only runs on the post-platform-validation path). **OK.**
- **Android**: the main `AndroidManifest.xml` declares **no app-level permissions** itself (INTERNET is in debug/profile + merged from plugins) -- a minimal-permission posture. Per-account WorkManager (F98). **OK.**
- **iOS / Linux / macOS**: unvalidated (documented limitation F95/F67 HOLD); no platform-specific security regressions introduced this sprint.

## 6. App-store compliance

- MSIX identity/publisher fields present and consistent with the Store release process (`docs/STORE_RELEASE_PROCESS.md`). No new capability declarations needed this sprint. Privacy/data-governance is documented in ADR-0030 (extended this sprint by F102 with the Logging & Redaction section). **OK.**

---

## Findings disposition summary

- **Fixed this sprint (trivial)**: none required -- the audit found no new security defects. The one historically-recurring issue (PII in logs) is now gate-enforced GREEN by F102.
- **Backlog (new)**: **F108** -- evaluate the security-relevant major dependency bumps (`flutter_secure_storage` 9->10, `flutter_appauth` 8->12, `workmanager` 0.5->0.9) deliberately, each with a targeted retest. No known-exploited CVE makes this urgent; it is freshness/hardening hygiene.
- **No SQL injection, no unguarded ReDoS on the scan path, credentials centralized + redaction-enforced, pinning in place.**

**Conclusion**: security posture is healthy and the F102 redaction invariant introduced this sprint is verified enforced. The only follow-up is deliberate dependency-freshness work (F108, backlog).
