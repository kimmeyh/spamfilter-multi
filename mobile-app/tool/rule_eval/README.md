# Rule evaluation harness (F267)

This tool scores candidate rules against your own scan history before any
rule can act on mail. It is read-only. It reuses the app's `RuleEvaluator` and
`PatternCompiler` unchanged, so a rule scores here the way it matches in the
app. Design source: `docs/research/R76-3_HEURISTICS_ML_GENAI_SPAM_IDENTIFICATION.md`
Section 4.8.

## Run

1. Copy the databases to a folder OUTSIDE `%APPDATA%\MyEmailSpamFilter`. Copy
   `spam_filter.db` together with its `-wal` and `-shm` files (the app keeps
   recent data in the WAL), and `content_history.db`. Live location:
   `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`.
2. From `mobile-app/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\rule_eval\rule_eval.ps1 -Candidate C:\path\candidates.yaml -DbDir C:\path\dbcopy
```

   Optional `-Out report.txt` also writes the report to a file. The report holds
   counts and rule names only, never email content.

The candidate file uses the `docs/RULE_FORMAT.md` shape (`rules:` list with
`conditions`, `actions`, optional `exceptions`).

## Why `flutter test` runs it (not `dart run`)

The engine imports `package:flutter/foundation.dart` (through
`lib/util/redact.dart`), which needs `dart:ui`. `dart run` fails to compile it
("Dart library 'dart:ui' is not available"). The engine must stay unchanged, so
the wrapper runs `tool/rule_eval/rule_eval.dart` under `flutter test`, which
provides `dart:ui`. Inputs reach it as environment variables set by the
wrapper. SQLite comes from `sqflite_common_ffi`, the same way the app's tests
load it; no new dependency was added. A run takes about 15 seconds.

## Output per candidate rule

- `matches`: emails the rule matches, with `deleted`, `kept` and `unlabeled`
  counts among them.
- `precision` = deleted / (deleted + kept) over the matches. Unlabeled matches
  are not in the denominator.
- `safe-sender hits`: matches on mail from a CURRENT safe sender.
- `recall` = matched / all "No Rule mail later deleted".
- `PASS` or `FAIL`, with one `reason:` line per failed check.

## The bar (R76-3 4.8)

PASS needs ALL of: zero safe-sender hits, precision at least 0.99, and at
least 20 labeled matches. Two more checks also fail a rule: the rule does not
delete (`actions.delete` is not true), and a pattern problem the app already
detects at import (ReDoS rejection, invalid regex, an address pattern that can
never match, F266).

## How each rule is scored

Each rule runs alone, with an EMPTY safe sender list. The engine checks safe
senders first, so with the real list a safe sender's mail would never reach
the rule and the hit would be invisible. Safe-sender hits are counted
separately by matching the email's From against the current `safe_senders`
table. A disabled rule is scored as if enabled.

## Safety refusal (R-4)

The tool refuses any path under `%APPDATA%\MyEmailSpamFilter` (a prefix match,
so `MyEmailSpamFilter_Dev` is refused too, and so are the `-wal` and `-shm`
files). It prints why and stops before opening anything. It opens every copy
with SQLite `readOnly: true` and has no write statement. It does not stop you
from pointing at a copy that is itself stale; copy fresh before a decision.

## Labels (R-5)

The history has two sources. All of these are APPROXIMATIONS: nothing in the
schema records "the user deleted this email" directly.

**Source A, `content_history` (has the body).** One row per email. Label, first
rule that applies:

1. `user_decision` starts with `safe_sender:` -> **kept**.
2. `user_decision` starts with `block:` -> **deleted**.
3. A matching `email_actions` group has a successful `delete` -> **deleted**.
4. `outcome` is `delete` -> **deleted**.
5. `outcome` is `safe_sender`, or the group has a safe-sender action -> **kept**.
6. Otherwise **unlabeled** (for example a No Rule email nobody acted on).

A row is linked to its `email_actions` group by Message-ID, else by provider id
within the account. The user decision comes from the Results and Review quick
actions (ADR-0047 item 5), so a `block:` is the closest thing to "Harold
deleted it".

**Source B, `email_actions` only (no body).** Emails seen by scans but absent
from `content_history`. A read-only scan sees the same email every cycle, so the
rows are grouped per email (account plus Message-ID, else provider id) and
counted once. Label: any successful `delete` action -> **deleted**; any
`safeSender` action -> **kept**; else **unlabeled**. These samples have only
From and Subject, so body and header conditions cannot match them.

**No Rule mail later deleted (the recall base).** An email that is deleted AND
either carries a `block:` decision, or whose first `email_actions` row was
`none` (No Rule) with a later successful `delete`.

**Not used as a label:** `unmatched_emails.processed`. It means Harold dismissed
the row from Review, which can be a block, a safe sender, or a plain dismissal,
so it cannot say "deleted". The `block:` and `safe_sender:` decisions in
`content_history` carry that direction instead.

### Known weaknesses

- Windows DEV scans are read-only, so a `delete` outcome or action is what a
  rule WOULD delete, not proof that you deleted the email. Rows labeled by rule
  verdict (rules 3 and 4, and most of source B) measure agreement with your
  existing rules. A candidate that duplicates an existing rule scores well for
  that reason. User-labeled rows (rules 1 and 2) are the stronger evidence.
- `content_history.outcome` is overwritten on every sighting, so it shows the
  latest verdict, including a rule you created after the email arrived.
- Raw headers are not stored. Header conditions see only `reply-to`,
  `return-path` (the domain), `list-unsubscribe` (the word `present`) and
  `from`. A candidate that depends on other headers cannot be scored.
- The precision denominator excludes unlabeled matches, and the 20-match floor
  counts labeled matches only. A rule that mostly matches unlabeled mail FAILs
  on volume, which is the intended direction.
- Mail the Fold deleted before any Windows DEV scan saw it is not in the
  history (ADR-0047, Consequences).
- The tool does not split by time (R76-3 4.8 item 1). With a small history,
  train/test splitting is a later refinement.

## Tests

`flutter test test/unit/tool/rule_eval_test.dart` builds fixture databases in a
temp folder and checks the numbers against hand-computed values.
