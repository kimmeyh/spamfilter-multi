# Release notes -- 0.17.0 -- Google Play

**Re-derived at Sprint 75 Phase 7.7 (2026-10-04) from the finished CHANGELOG** (STORE_RELEASE_PROCESS.md
Step 1b). Covers the Sprint 74 and Sprint 75 entries. The Windows-only background-scan change
is excluded.

**Range**: everything after the last version Play received (0.16.0, versionCode 7, submitted
2026-09-24).

**Not yet submitted.** The Sprint 74 release hold (Harold, 2026-09-27) is satisfied: the "stop the
background scan and start mine" action shipped in Sprint 75. Sprint 75 kept version 0.17.0 by exception
(Harold, 2026-10-02). The 0.17.0+8 AAB built on 2026-09-25 is superseded; build a new one from `main`.

Paste the en-US block below into the Play Console release-notes field, tags included. The
500-character limit applies to the text BETWEEN the tags; `release_notes_test.dart` measures it.

**No internal identifiers anywhere in this file** -- the gate scans the whole file.

**Excluded for length** (true, but lower value to a tester): the Manage Rules subject label, the
missing-folder change, separate development/production diagnostic logs, the YAML version header,
the text-size and slider alignment fixes, the "Scan not started" wording.

---

<en-US>
Scan results show each email's date; Sort lists newest first.

Rules added while reviewing a saved scan work again.

One scan per account at a time. You can stop a running background scan and start yours. A stuck scan no longer shows "In progress".

New accounts get the right folders, including spam.

Gmail offers Sign In Again when needed, keeps its settings, and shows real email dates.

Exports save to Documents, can hide sender details, and rule export works. Scan history can be cleared.
</en-US>
