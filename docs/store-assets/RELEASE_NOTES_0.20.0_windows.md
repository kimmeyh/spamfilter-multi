# Release notes -- 0.20.0 -- Microsoft Store

PROVISIONAL, written 2026-10-13 at Sprint 79 plan approval (Phase 3.7.0b, the Sprint 77 and 78 precedent).
Re-derive from the finished CHANGELOG at Phase 8.3 (STORE_RELEASE_PROCESS.md Step 1b) before any upload.

**Range**: everything after 0.19.0 (submitted to the Store 2026-10-13; the Store row still reads 0.18.0.0 until
certification is observed): CHANGELOG `[Unreleased]` entries dated 2026-10-13 under "Sprint 79".

**Excluded from this file**: process documents (backlog presentation), the notification plugin upgrade itself (no
visible change beyond the new notification), and the diagnostic-log line for schedule changes (seen only with
diagnostic logging on; listed under Fixes if it is kept at re-derivation).

---

When a background scan of an account finishes, Windows now shows a notification naming the account and what the scan found, for example "Back. scan k*@aol completed" and "No rule 9 Deleted 1 Safe 0". Each account has one notification, replaced by the next scan. A read-only scan says so in the title.
