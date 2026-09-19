# Release notes -- 0.15.2 -- Microsoft Store

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 70 entries, per ADR-0043.
**RE-DERIVED at Phase 7.7 from the finished CHANGELOG** (Sprint 69 IMP-5). The provisional version
flagged the backgrounding fix for re-check because it touches shared code. It does, and the shared
half changes Windows behaviour, so it is now described below.
**Not yet submitted.** 0.15.1 is in certification as Submission 27.

**No internal identifiers anywhere in this file** -- the gate scans the whole file, not just the
user-facing section, because a paste error can ship any line of it. Sprint card ids live in the
CHANGELOG and the sprint plan.

---

Fixes for problems found by people using the app.

Re-processing after adding a rule now works, and reports the truth. Adding a blocking rule to a
reviewed email could report that every action failed while, on some account types, quietly
reporting success without touching any mail. Failures are now named with a count, and a failed
email can be retried.

A manual scan that never finishes now stops after 30 minutes instead of running indefinitely. The
limit keeps counting while you are on other screens.

Scans interrupted by a crash or a shutdown no longer sit in Scan History as permanently "in
progress". They are resolved when the app next starts or returns to the foreground.

---

**Re-check outcomes** (the provisional file flagged two):

- **Backgrounding a live scan -- the Windows-relevant half is the manual-scan timeout above.** The
  original trigger is Android-only: Windows does not tear down sockets when a window is minimised.
  An early version of that fix ran on every platform and would have killed healthy Windows scans;
  a code review caught it, and the handler is now a declared ADR-0042 Android exception. The
  timeout is shared, so it is described for Windows users here.
- **Toolchain upgrade -- still excluded.** Developer tooling. Its acceptance criteria specifically
  checked for behaviour changes and found none a user would see.

**Also excluded**: the Android OAuth sign-in fixes (Windows uses a loopback redirect and was never
affected) and the deferred-background-scan diagnosis (Android power management; Windows uses Task
Scheduler).
