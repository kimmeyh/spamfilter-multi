# F270 R-4: Sent-folder reply pairs (Sprint 83, Task 5)

This report holds counts only. No address, subject or body is recorded here.

## Method

- Harold's decision (Q7, 2026-11-01): the Sent-folder part is a developer tool run on his own
  account, like F308. No app code reads any user's Sent folder, so the privacy policy does not
  change.
- A scratch probe (not in the repository, because it reads a credential) opened the DEV AOL Sent
  folder with IMAP EXAMINE and asserted read-only before the first fetch. It fetched only the To,
  Cc and Date headers with `BODY.PEEK[HEADER.FIELDS (TO CC DATE)]`. It issued no STORE, EXPUNGE,
  MOVE, COPY, APPEND or DELETE. The credential came from the DEV secure store in memory and was
  never written, printed or put on a command line.
- `tool/rule_miner` reply-pair mode (`reply_pair_core.dart`, `rule_miner.ps1 -SentJsonl`) compares
  the recipients with the senders stored in a COPY of the DEV database (`unmatched_emails` and
  `email_actions`). Gate: every stored email from the sender has auth class green, no rule deleted
  mail from them, and no saved safe sender covers them.

## Result (DEV copy, 2026-11-04)

- Sent emails read: 170 (the Sent folder was found and fully read).
- Distinct recipients, not counting Harold's own addresses: 35.
- Reply pairs (a recipient who also sent mail that a scan stored): 5.
- Candidates after the gate: 0. All 5 pairs are already covered by a saved safe sender.
- Not gated for a non-green class: 0. Not gated for a rule delete: 0.

## Reading the result

- The reply-pair signal found nothing new on DEV: the people Harold writes to and hears from are
  already safe senders. It confirms the signal is consistent with his own choices, and it adds no
  suggestion today.
- Limitation: "also sends him mail" means only mail a scan stored. A correspondent whose mail
  always landed in a rule-matched or safe-sender path and was never stored in `unmatched_emails`
  or `email_actions` is not counted, so 5 is a lower bound.
- Limitation: 170 Sent emails over the life of one account is a small sample.
- Nothing is imported or applied. The candidate YAML (empty here) stays in the scratchpad.
