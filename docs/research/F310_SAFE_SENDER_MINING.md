# F310: Mining safe-sender mail for safe-sender patterns

Sprint 83 Task 9 (Issue #543). Run 2026-11-04 on a copy of the Windows DEV data. Developer tool output only: nothing here
is imported, applied or bundled. No mailbox was read for this task and no credential was used.

## BLUF

- The tool reports **30 sender domains and 1 signal pair** that almost never match delete-rule mail (0 to 1 hits on 4,127
  delete-rule emails; 38 to 62 gate-proven safe-sender emails for the strongest). All 30 domains are ordinary
  safe-sender regexes.
- **22 of the 30 domains are already matched by a current safe-sender pattern.** Only **1** of the other 8 would cover
  mail that is No Rule today (5 emails). So the useful new output is small: the method confirms the current safe list,
  and finds one new domain.
- **No signal works alone.** Reply thread, transactional subject, few links, no List-Unsubscribe and long sender history
  each match 1 to 62 percent of delete-rule mail. Only the pair "reply thread + long sender history" passes (38 safe, 1
  delete-rule hit). On history alone, 3 more pairs pass; adding the Trash2 delete-rule mail (auth class unknown) removes
  them.
- **The DMARC requirement (R-3) cannot be met exactly.** Stored data keeps one auth class per email (green, yellow, red,
  grey), not the DMARC verdict and not DKIM alignment. The gate is the stored class `green` (a proxy). The runtime
  suggestion (F270) must read the raw `Authentication-Results` header.
- The gate changed nothing on this data: 31 candidates meet the threshold on content alone, 31 are reported, and 0 pass
  only because of the gate. It is a safety rule, not a filter that earned its keep here.

## Auth signals actually available

- `content_history.auth_class` holds `green`, `yellow`, `red` or `grey` for all 2,043 DEV history rows (1,887 green, 143
  yellow, 7 red, 6 grey). It is `AuthResultsParser.classify` of the headers at scan time. **Green means every one of SPF,
  DKIM, DMARC that returned a verdict passed and at least one did.** A mail with SPF pass and no DMARC record is green.
  So green does not prove DMARC pass.
- **Not stored**: the per-method SPF/DKIM/DMARC verdicts, DKIM alignment, the `Authentication-Results` text.
- **Trash2 mail has no auth data at all**: the F308 probe stored only Reply-To and List-Unsubscribe headers (checked: 0 of
  10,000 records have `Authentication-Results`). A Trash2 email takes its class from a matching history row (same
  Message-ID, else From + Date + Subject); otherwise it is unknown. Delete-rule corpus: 4,127 emails, **987 with a known
  class** (the rest are Trash2 only).
- Other signals used and their source: reply thread (subject starts `re:`, `aw:`, `sv:`), transactional subject (a fixed
  list of 20 words, such as order, receipt, invoice, statement, confirmation, password, verification, shipped,
  delivery, appointment, payment, billing, booking, ticket), links (count of `http(s)://` in the stored body, at most
  2), List-Unsubscribe present (stored flag), sender history (emails from the base domain in the corpus: at least 5 over
  at least 90 days, using `received_at`).

## Method

1. **Copies**: the DEV `spam_filter.db` (with `-wal` and `-shm`) and `content_history.db` copied by Task 7 to the
   scratchpad; the tool opens them read-only and refuses a live path. The Task 7 Trash2 JSONL was reused as extra
   delete-rule mail (read only; no new read).
2. **Corpus**: the Task 7 corpus builder (`buildCorpus`), now carrying the stored auth class, received time and outcome.
   10,752 emails: delete-rule (spam pool) 4,127 = Trash2 emails a current delete rule matches or whose history outcome is
   `delete`, plus history mail with outcome `delete`; safe-sender 1,459 (792 gate-proven); No Rule 350.
3. **Candidates**: one per sender domain with at least 5 gate-proven safe-sender emails (4 shared mailbox providers
   rejected by the F268 guard); 5 signals; all 10 pairs of signals. Every candidate carries the gate.
4. **Scoring**: a safe-side hit needs the gate proven (`green`). A delete-rule hit counts when the content matches and the
   class is `green` **or unknown**; known non-green mail is stopped by the gate. Matching uses the app's
   `PatternCompiler` and `SafeSenderList`; reported domains were re-checked with `SafeSenderList` (0 differ).
   `scoreCandidates` (F267) scores delete rules and does not apply to safe senders, so it was not used.
5. **Without the gate**: each candidate is also scored ungated to count what the gate refuses.

## Threshold (R-2)

Reported when the candidate matches **at least 5 gate-proven safe-sender emails** and hits delete-rule mail on **at most 2
emails AND at most 0.5 percent** of the delete-rule mail it could be checked on. A candidate with nothing to check on is
not reported. These bounds are the same as the F308 safe-side bounds. Candidates are reported if they meet this and carry
the gate (AC-2); the report also marks domains a current safe-sender pattern already matches.

## Results

Corpus: 10,752 emails; delete-rule 4,127 (987 known class); safe-sender 1,459 (792 green); No Rule 350. 46 candidates
scored, 31 reported.

Signals alone (share of the mail each could be checked on):

- Reply thread: safe 3.8 percent, No Rule 3.4, delete-rule 1.2 (51 hits). Fails the threshold.
- Transactional subject: safe 7.6, No Rule 3.7, delete-rule 2.0 (84 hits). Fails.
- At most 2 links: safe 26.1, No Rule 59.7, delete-rule 13.5 (558 hits). Fails.
- No List-Unsubscribe: safe 37.7, No Rule 23.5, delete-rule 61.9. Fails (spam often has none stored).
- Long sender history: safe 36.1, No Rule 5.7, delete-rule 30.8 (1,271 hits). Fails.

What safe mail has that No Rule mail does not: long sender history (36 vs 6 percent). Few links does not separate them
(No Rule mail has more). On the 987 delete-rule emails with a known class, the same signals are much weaker spam markers than
in the full pool (history only: long history matches 0.3 percent of delete-rule mail, but 32 percent of safe mail).

Reported:

- **Sender domains: 30.** Safe-sender emails 5 to 62 each; delete-rule hits 0 for every one. 22 already match a current
  safe-sender pattern. Of the 8 others, 1 hits No Rule mail (5 emails), 7 hit none. Domains are not named here; they are
  in the scratchpad.
- **Signal pairs: 1 (joint run).** Reply thread + long sender history: safe 38, delete-rule 1, No Rule 1.
- **History only (no Trash2 mail)**: 4 pairs pass (few links + long history: 187 safe, 2 delete-rule, 6 No Rule; reply
  thread + no List-Unsubscribe: 45, 1, 2; reply thread + long history: 38, 0, 1; transactional + long history: 20, 0,
  10). The Trash2 mail has no auth class, so each of its content matches counts as a risk; that removes the other three (only reply thread + long history stays).
  Which of the two runs is right depends on how many of the unknown-class Trash2 emails would really fail DMARC; that is
  **unverified**.
- **Gate effect**: 31 candidates meet the threshold on content alone (34 on history alone); 0 pass only because of the
  gate. The gate's value is that a content-only candidate is never a suggestion, not that it removes any of these.

## What was NOT checked

- DMARC pass itself, DKIM alignment (not stored). No Authentication-Results header was read for any email.
- Whether the 792 green safe-sender emails have a DMARC record (a green mail can have none).
- Yahoo and Prod data (excluded by the task). The history is the DEV scan history (2,043 rows) plus the Task 7 Trash2
  read, not a whole mailbox; no per-account breakdown was made.
- Whether a suggested domain is spoofable by a DMARC-passing sender on the same domain (a legitimate domain can still send
  bulk mail or be abused through a subdomain; the pattern matches subdomains).
- Phrase-level safe signals (subject or body text): not mined; transactional is a fixed word list.
- A temporal split (train and test periods): none, so counts describe this data, not future mail.

## Output and tests

- Report and YAML are in the scratchpad (`scratchpad/s83_task9/`): domain names and patterns stay out of the repo. The
  YAML lists only reported domains and carries a header saying each entry is a suggestion only for DMARC-passing mail,
  because the `safe_senders` list cannot hold that condition.
- Tool: `tool/rule_miner/safe_miner_core.dart`, run with `rule_miner.ps1 -Safe`. Tests:
  `test/unit/tool/rule_miner_safe_test.dart` (25 tests; 24 mutants, all killed).
