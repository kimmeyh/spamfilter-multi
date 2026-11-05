# Release notes -- 0.24.0 -- Microsoft Store

Re-derived from the finished CHANGELOG at Sprint 83 Phase 7.7 (2026-11-05). Re-check at Phase 8.3
(STORE_RELEASE_PROCESS.md Step 1b), and again if the open 7.7.1 decisions (Block Body on HTML-only mail, the
refused-password retry) change what ships.

**Range**: everything after 0.23.0. If 0.23.0 was never submitted to the Store, widen the range at Phase 8.3 to
everything after the live Store version (`STORE_VERSION_STATUS.md`).

**Excluded from this file**: the iOS project, the iOS build workflow and TestFlight (not shipped to Windows);
Android-only changes (the two notification channels); developer tools (the rule miner, the Python hook layer);
`test`, `docs` and `chore` entries.

---

Settings > Background > Scan notifications lets you choose when background scans notify you: after every completed scan, or only when a scan finds one or more No Rule items.

Manage Safe Senders now suggests senders you may trust, based on the mail you have received. You accept or reject each one; nothing is added without your choice.

The No Rule Item pop-up has a Block Body button beside Block Subject. A sender whose Reply-To address is on another domain gets a suggested block, and no rule is suggested when the mail server's check of the sender did not finish. The pop-up no longer cuts off its buttons at the default window size.

An iCloud, AOL, Yahoo or custom email account whose password the provider rejects now shows Sign In Again in the account list, and its background scans are skipped with one notice a day. The account list also tells you when background scanning is off for an account, with a button to turn it on.

Removing and adding an account again keeps its folder, scan mode and background choices. Select Account no longer shows every account as "Missing credentials" while it loads.
