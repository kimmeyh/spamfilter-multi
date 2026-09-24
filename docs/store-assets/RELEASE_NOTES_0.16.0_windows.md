# Release notes -- 0.16.0 -- Microsoft Store

**Derived at Phase 7.7 from the finished CHANGELOG** (re-derived 2026-09-24; the Phase 3.7.0b
provisional draft is replaced). Per ADR-0043 and STORE_RELEASE_PROCESS.md Step 1b.

**Range**: everything after the last version this store received. The Microsoft Store is live at
**0.15.2** (Submission 28, 2026-09-21), and 0.15.3 was never submitted, so this covers BOTH the
Sprint 72 and Sprint 73 entries of `CHANGELOG.md` `[Unreleased]`.

**Excluded from this file** (audit trail):
- Background scans in Doze, and restoring them after a restart: Android only. Windows has no Doze
  equivalent and schedules through Task Scheduler.
- The Settings note that the phone may delay background scans while idle: Android only.

**Not yet submitted.**

---

You can now cancel a scan that is taking too long. What it already checked is kept.

A manual scan no longer warns about a background scan that has already finished.

When an account is set to read-only, adding a rule now shows what it would have filed or moved,
so you can check a new rule before letting it act. Your mailbox is not changed.

A new control on the scan results screen shows everything you did in the session, and messages
about failed actions stay on screen longer.

The app no longer reports success when your mail server refused a change. It says how many emails
could not be updated.

Adding a rule while reviewing a saved scan now acts on your mailbox.

Exporting results from Scan History now includes the results, not just the column headings.
Exported files also record the app version that produced them.

An optional diagnostic log in Settings records why an action on your mailbox failed. It is off by
default, records no message content, and can be deleted from the same screen.

The email action panel is easier to read: larger text that follows your text-size setting, and the
sender address is no longer cut short.

The app version is shown on every screen, including in narrow windows.
