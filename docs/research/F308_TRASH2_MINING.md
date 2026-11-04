# F308: Mining the AOL Trash2 folder for delete-rule patterns

Sprint 83 Task 7 (Issue #541). Run 2026-11-03/04 on the Windows DEV build data. Developer tool output only: nothing
here is imported, applied or bundled.

## BLUF

- The tool found **178 single-part candidates and 3 AND pairs** that almost never hit a safe sender. Only **29 of the
  181** hit mail that no current rule catches (No Rule). The rest hit only mail that was already deleted by rules or by
  hand.
- The two strongest are sender shapes: `news_` plus digits (262 rule-deleted, **69 No Rule**, 534 hand-deleted, 0
  safe-sender hits) and `otp-` plus digits (1,453 rule-deleted, 3 No Rule, 256 hand-deleted, 0 safe-sender hits). The
  first is the F323 `news_` suggestion, now with a count behind it. Both also pass the F267 bar.
- Nothing was imported. The candidate YAML holds phrases from private mail and stays in the session scratchpad
  (`scratchpad/s83_task7/cand.yaml`); this report lists counts, domains, shapes and a few generic phrases only.

## Method

1. **Read (R-1, Q5 = 1)**: a scratch probe (`scratchpad/s83_task7/trash2_probe.py`, run through
   `trash2_probe_launch.ps1`) opened the DEV AOL account with IMAP **EXAMINE** (`select(readonly=True)`) and asserted
   `is_readonly` before the first fetch. It fetched with `BODY.PEEK[]<0.300000>` only (no `\Seen` change). It never
   called STORE, EXPUNGE, MOVE, COPY, APPEND or DELETE; the script checks its own source for those verbs and printed
   an empty list. The DEV AOL credential was decrypted **in memory** from the DEV app's secure store, handed to the
   child process through its environment (not the command line), and removed afterwards. It was never written,
   printed or logged. Yahoo and Prod data were not read. The folder list showed one folder named `Trash2`.
2. **Data**: 10,000 messages (the folder's EXISTS count) written to a private JSONL in the scratchpad. 9,997 had a
   Message-ID (9,092 distinct), 9,981 had a usable date (9,885 in 2026, 89 in 2025, 7 older), 49 had an empty body, 6,297
   had Reply-To, 4,448 had List-Unsubscribe, **none had Return-Path** (AOL did not return it, so no Return-Path
   candidate was possible). Whether 10,000 is the whole folder or a server limit is **unverified**.
3. **Copies**: the DEV `spam_filter.db` (with `-wal` and `-shm`) and `content_history.db` were copied to the scratchpad
   first; the tool opens copies read-only and refuses a live path.
4. **Mining**: `tool/rule_miner` trash2 mode (`trash_miner_core.dart`), see its README.

## Groups (R-5, R-6)

- **One record per email**: 905 Trash2 duplicates dropped (Message-ID; From + Date + Subject when none); 1,105 history
  rows dropped because the same email is in Trash2.
- **Rule-deleted (the only mining pool)**: 3,809. A Trash2 email that a current delete rule matches, or whose history
  outcome is `delete`.
- **Hand-deleted (own group, neutral)**: 4,593. In Trash2 and no delete rule matches. Counted per candidate for
  information, never for or against it.
- **No Rule**: 350 history emails. **Safe-sender**: 1,459 (history mail from a current safe sender, plus Trash2 mail
  from one). 541 other history emails are not counted.
- Current rules read: 2,212.

## Threshold (R-2, AC-2)

A candidate is reported only when it matches **at least 5 rule-deleted emails**, hits safe-sender mail on **at most 2
emails AND at most 0.5 percent** of the safe-sender mail it could be checked on, and adds coverage (hits No Rule or
hand-deleted mail). A candidate that could not be checked on any safe-sender mail is not reported. An AND pair is built
only from parts that fail alone, in different fields. Candidates with identical matched emails collapse to the simplest
(149 collapsed). Phrases containing an account name were dropped (4,207 phrase windows). Over-broad shapes were
rejected by the F268 guard (231 weak phrases, 4 shared-mailbox domains).

The largest safe-sender hit among reported candidates is 2 emails (0.14 percent for "don t miss", 0.15 percent for the
URL domain googleusercontent.com). Body candidates are checked on
1,311 safe-sender emails (those with a stored body), header candidates on 1,373.

Verification: the fast counts of every listed candidate equal the app's own `RuleEvaluator` (0 differ), and every
candidate was also scored with the F267 core (`scoreCandidates`); "F267 PASS" below means it also meets the F267 bar
(zero safe-sender hits in the table, precision 0.99, 20 labeled matches).

**Reading the counts**: "delete" is rule-deleted mail, which a current rule already catches, so a high delete count
alone adds nothing. The value of a candidate is its No Rule and hand-deleted hits.

## Results by kind (AC-1)

Counts are rule-deleted / No Rule / hand-deleted / safe-sender hits.

- Single-part: 372 scored, 347 pass the threshold, **178 reported** (169 more pass but add no coverage).
  - subject phrase: 70 reported, 10 hit No Rule, 0 meet the F267 bar (29 hit No Rule in all kinds)
  - body phrase: 45 reported, 11 hit No Rule, 6 meet the F267 bar
  - body-URL domain: 52 reported, 0 hit No Rule, 1 meets the F267 bar
  - sender domain: 8 reported, 6 hit No Rule, 1 meets the F267 bar
  - sender local-part shape: 2 reported, 2 hit No Rule, 2 meet the F267 bar
  - header value: 1 reported (Reply-To domain), 0 hit No Rule
- AND pairs: 18 scored, 3 pass, **3 reported**, none hit No Rule (all three pair `List-Unsubscribe` present with a body
  phrase or a URL domain).

### Sender shapes (strongest)

- `news_` plus digits: 262 / **69** / 534 / 0. F267 PASS.
- `otp-` plus digits: 1,453 / 3 / 256 / 0. F267 PASS.

### Sender domains that hit No Rule

- brooklynvegan.com: 24 / 3 / 0 / 0 (F267 PASS)
- favellest.com: 45 / 1 / 0 / 0
- findyourfit.net: 12 / 1 / 0 / 0
- loyalobject.com: 10 / 1 / 0 / 0
- 558fawin.com: 6 / 1 / 0 / 0
- tracthere.com: 5 / 1 / 0 / 0

### Subject phrases that hit No Rule (six generic ones shown; the other four and all hand-deleted-only phrases are in the YAML)

- "your weight loss": 19 / 3 / 5 / 0
- "2 free months": 34 / 2 / 4 / 0
- "will be removed today": 21 / 2 / 53 / 0
- "don t miss": 19 / 3 / 4 / 2 (0.14 percent; the weakest of the reported)
- "feel more confident": 26 / 1 / 16 / 0
- "limited time offer": 16 / 1 / 8 / 0

### Body phrases that hit No Rule

- "or write to us at": 83 / **8** / 25 / 0 (F267 PASS), with the same 8 No Rule emails for "to be removed from our list"
  (82 / 8 / 18 / 0, PASS) and "from our list simply click here" (79 / 8 / 17 / 0, PASS)
- Newsletter boilerplate: "to unsubscribe click here" 336 / 3 / 553 / 1, "to view this email" 977 / 1 / 255 / 1.
  These pass the threshold but are **risky**: any wanted newsletter carries them (see Caveats).

### Body-URL domains and hand-deleted-only candidates

No URL domain hits No Rule. The strongest by hand-deleted hits: imgur.com 1,616 / 0 / 774 / 0 (F267 PASS),
zupimages.net 363 / 0 / 632 / 0, baleama.com 198 / 0 / 226 / 0, lynkmedia.net 126 / 0 / 237 / 0. A Reply-To domain
(keys4us.com: 23 / 0 / 247 / 0) is the one header candidate. Several subject phrases cover hundreds of hand-deleted
emails (for example a "your photos and videos will be deleted" family: 106 / 0 / 219 / 0). Under R-6 these are
information for Harold, not evidence for or against.

## Caveats and what was NOT checked

- **Safe-sender mail is only mail from senders already marked safe.** A phrase, URL host or boilerplate line that wanted
  mail from an unlisted sender carries (imgur.com, "to view this email") can show zero hits here and still be a
  false-positive risk. The threshold measures the safe list, not all wanted mail. Read the boilerplate and shared-host
  candidates (imgur.com, search.app, pinimg.com) with that in mind.
- Hand-deleted is "no current delete rule matched", not proof Harold meant to delete it for the reason the pattern
  states. It is also not proof the mail was deleted at all by Harold: 4,593 includes everything in Trash2 that rules did
  not claim.
- Headers: only Reply-To, Return-Path and List-Unsubscribe exist in both Trash2 and the content history. List-Id,
  Precedence and the others were not checked; Return-Path came back empty from Trash2.
- Body candidates were checked on safe-sender mail with a stored body (1,311 of 1,459); the rest could not be checked.
- Phrases are ASCII words only, like F268. No time split (F313 R-2): the positives and the checks come from the same
  period, so a pattern may be a short campaign.
- Folder: 10,000 messages is the EXISTS count; whether older mail exists beyond it is unverified. The 3 messages without
  a Message-ID and the 19 without a date were still read and deduplicated by From + Date + Subject.
- The Trash2 read happened once. Nothing was changed in the mailbox (EXAMINE and `BODY.PEEK`); the Seen flags were not
  inspected afterwards (no read of flags was made), so "unchanged" rests on the protocol guarantee, not on a before and
  after comparison.
- AOL-specific: no Yahoo, no Gmail, no Prod data.

## Reproduce

```
powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_miner\rule_miner.ps1 `
  -DbDir <copy folder> -Trash2Jsonl <probe jsonl> -OutYaml <yaml> -OutReport <report> [-ShowPhrases]
```

The JSONL and the YAML hold private mail text; keep them out of the repository.
