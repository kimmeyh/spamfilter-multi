# Rule miner (F268)

This tool proposes delete rules from mail your current rules do NOT catch. It
scores every proposal with the F267 harness (`tool/rule_eval/`) and writes only
the proposals that PASS. It is read-only, runs on your PC, and its output is
never part of the app. Design source:
`docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md` Sections 4.7
and 4.8.

## Run

1. Copy the databases to a folder OUTSIDE `%APPDATA%\MyEmailSpamFilter`: copy
   `spam_filter.db` with its `-wal` and `-shm` files, and `content_history.db`.
   Live location: `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`.
2. From `mobile-app/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_miner\rule_miner.ps1 -DbDir C:\path\dbcopy -OutYaml C:\path\proposed.yaml -OutReport C:\path\report.txt
```

   `-OutReport` is optional. A run takes about 15 seconds. The wrapper uses
   `flutter test` for the same reason as the F267 tool (the engine imports
   Flutter; see `tool/rule_eval/README.md`).
3. Review `proposed.yaml`. To use it, import it through Settings > Import /
   Export YAML (once F269 Merge exists, choose Merge).

## What it mines (R-1): the pool

The pool is the set of history emails that are ALL of:

1. Labeled **deleted** by the F267 loader (`tool/rule_eval/README.md`, "Labels":
   a `block:` decision, a successful `delete` action, or a `delete` outcome).
2. **Not matched by any current rule** in `spam_filter.db` `rules`. Every rule
   counts, including a disabled one, so the tool does not re-propose what you
   turned off. Matching uses the app's own `RuleEvaluator`.
3. **Not from a current safe sender.**

Why: on the Windows DEV databases most `deleted` labels are verdicts of EXISTING
rules (DEV scans are read-only). Mining all deleted mail only rediscovers the
current rules, and a broad catch-all passes the F267 bar. Excluding mail the
current rules already catch leaves mail they MISS. Candidates are ranked by how
many pool emails are in the "No Rule later deleted" recall base (this includes
every `block:` decision, the closest thing to "Harold deleted it"), then by
support. The report prints the pool size and its recall-base count.

## Candidate kinds (R-2)

- **Sender domain.** Base (registered) domain of From, written as a `header`
  condition: `@(?:[a-z0-9-]+\.)*example\.com$` (the shape the app uses for its
  own domain rules). Needs at least 3 distinct pool emails.
- **Subject phrase.** Recurring word n-grams of 3 to 5 words, lowercase ASCII
  words, written as `\bw1[^a-z0-9]+w2[^a-z0-9]+w3\b`. Needs at least 3 pool
  emails. Only the most specific phrase is kept (a shorter phrase with the same
  support as a longer one is dropped).
- **Body phrase.** The same with 4 to 6 words, only for emails that have a
  stored body (`content_history`), first 4000 characters.

Never proposed (checked by `overBroadReason`, before scoring):

- a domain with fewer than two labels (TLD only), a public suffix such as
  `co.uk`, or a big shared mailbox provider (gmail.com, yahoo.com, and so on);
- a subject phrase under 3 words or a body phrase under 4 words, or a phrase
  with fewer than two meaningful (non-filler, non-numeric) words;
- a phrase that appears as consecutive words in any KEPT email;
- a pattern already present in a current rule;
- anything on mail from a current safe sender (the pool excludes it, and
  scoring fails a candidate that hits one).

At most 120 candidates per kind are scored.

## Scoring and output (R-3)

Each candidate is scored by the F267 core with the SAME bar: zero safe-sender
hits, precision at least 0.99, at least 20 labeled matches, a delete action, and
no pattern problem. The F266 dead-pattern check runs on domain candidates too.
Note that F267 scores over the WHOLE history, so a candidate's match counts
include mail current rules already catch; that is the F267 bar unchanged.

- **PASS** candidates are written to the output YAML (`docs/RULE_FORMAT.md`
  shape, `delete: true`).
- **NEAR MISS**: precision 1.0, no safe-sender hit, no pattern problem, and the
  only failed check is the 20-match floor. Listed in the report ONLY. Because
  user-labeled data is small, this is where most real candidates land. They are
  never written to the importable YAML; promote one by hand only after you
  review it.
- **FAIL**: everything else, with one `reason:` line per failed check.

The report holds counts, ids and domains only. A phrase candidate is listed by
id and word count, never by its text. A PASS phrase appears in the YAML, which
you review before importing.

## Safety (R-4)

- Inputs come from a COPY folder only. Any path under
  `%APPDATA%\MyEmailSpamFilter` (including `MyEmailSpamFilter_Dev`, and the
  `-wal` and `-shm` files) is refused before anything opens, using the F267
  refusal. The output paths are refused the same way.
- Databases are opened `readOnly: true`. There is no write statement.
- The output YAML and report stay on this PC. They derive from private mail
  history (Gmail and others). **Never commit them and never bundle them into the
  app's seed data** (`default_rule_set_service` and the asset rules).
- It is a developer tool under `tool/`; the app never imports it.

## Known weaknesses

- Only as good as the F267 labels, which approximate "deleted"; see
  `tool/rule_eval/README.md` "Known weaknesses".
- Body phrases need stored bodies. Few pool emails have one, so the body kind
  often produces nothing.
- Words are ASCII only; a non-English phrase yields no candidate.
- A base-domain guess uses a short second-level list (`co`, `com`, `org`, ...),
  not the full public suffix list.

## Tests

`flutter test test/unit/tool/rule_miner_test.dart` builds fixture databases in a
temp folder: a planted domain, subject phrase and body phrase are proposed and
PASS; a covered domain, a safe-sender hit, an F266 failure, over-broad shapes and
a live path are all rejected.
