# Release notes -- 0.15.2 -- Google Play

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 70 entries, per ADR-0043.
**RE-DERIVED at Phase 7.7 from the finished CHANGELOG** (Sprint 69 IMP-5). The provisional version
written at the Phase 3.7.0b bump described a sprint that had not happened yet; both of its
re-check items resolved, and the sign-in fix in particular now belongs here.
**Not yet submitted.** Paste the en-US block below into the Play Console release-notes field, tags
included. The 500-character limit applies to the text BETWEEN the tags, and the gate measures it
rather than estimating.

**No internal identifiers anywhere in this file** -- the gate scans the whole file, not just the
tagged block, because a paste error can ship any line of it. Sprint card ids live in the
CHANGELOG and the sprint plan.

---

<en-US>
Fixes for problems testers reported.

Google Sign-In now works. It failed before reaching your account.

Backgrounding the app during a scan no longer stops scanning until you restart.

Adding a rule to reviewed mail now applies it, and says so honestly when the mail server refuses.

Interrupted scans no longer sit in history as forever "in progress".
</en-US>

---

**Re-check outcomes** (the provisional file flagged three):

- **Google Sign-In -- NOW INCLUDED.** The fix landed and was verified on an Android 14 emulator:
  the OAuth redirect reaches the app instead of a system chooser. Testers who hit the sign-in dead
  end are the people most affected by this release, so it leads. End-to-end sign-in with a listed
  test user still needs this Play build to confirm, so shipping it is what enables the last check.
- **Deferred background scans -- still excluded.** That card was scoped to diagnose and recommend,
  and no fix landed. Harold chose the remedy on 2026-09-19 but it is not implemented, so there is
  nothing a tester would notice.
- **Toolchain upgrade -- still excluded.** Developer tooling, no user-visible change.
