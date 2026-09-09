# Release notes -- 0.14.2 (Microsoft Store)

Derived per ADR-0043 from `CHANGELOG.md`, covering everything since **0.14.1**,
which is the version the Microsoft Store currently has live (Submission 23,
certified 2026-09-09).

Paste into Partner Center: **Store listings -> English (United States) ->
"What's new in this version"**. The field only appears once a package is
attached, so upload the MSIX and let validation finish first.

---

Scan history now tells you when a scan actually stopped.

- A scan that stopped early -- because the app closed, the device slept, or a
  connection stalled -- now shows its own icon in Scan History and reads
  "Not finished", instead of the clock icon used for a scan that is still
  running. Previously a stopped scan looked like it was still going, sometimes
  for hours.
- The account box at the top of Settings is readable in dark mode. It was
  drawing light text on a light background, which made the email address nearly
  invisible.

---

**Excluded from this file** (present in CHANGELOG.md, not user-facing on Windows):
`[internal]` entries -- the Manual-Validation evidence gate (F193), the per-store
release-notes procedure (F196, this file), and the ADR that defines it. None
changes anything a Store customer can see.
