# Release notes -- 0.15.3 -- Microsoft Store

**PROVISIONAL.** Written at the Phase 3.7.0b version bump, so it describes a sprint that has not
finished. **RE-DERIVE at Phase 7.7 from the finished CHANGELOG** (Sprint 69 IMP-5).

**Derived from** `CHANGELOG.md` `[Unreleased]`, Sprint 72 entries, per ADR-0043. Per-store by
design: Windows sees only what applies to Windows. The Android battery-optimization work is
excluded because Windows has no equivalent, and the Google Sign-In verification is Android-only.

**Not yet submitted.**

---

Fixes for problems found in testing.

Adding a rule while reviewing an older scan now acts on your mailbox. Before, it looked like it
worked and nothing happened on the server.

The app no longer reports success when the mail server refused the change.

Exporting scan results from a stored scan now writes the results. It previously wrote an empty
file and reported success.

Scan results are easier to read, and the sender address is no longer cut short in the action
panel.

Action results stay on screen long enough to read.

An optional diagnostic log can be enabled in Settings to help investigate problems, and deleted
from the same screen.
