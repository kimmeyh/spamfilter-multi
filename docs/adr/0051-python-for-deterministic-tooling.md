# ADR-0051: Python for Deterministic Tooling

## Status

Accepted (Harold, 2026-11-04, Sprint 83 Manual Validation Q8): *"yes, python 3.14 is currently preferred, prompt that
can be easily rewritten deterministically should be rewritten. If there are common tools needed by prompts that can be
written deterministically (python), then these helper tools should be written and then used by the prompts. Accept 3
hooks and agent-work-status."* Proposed in Sprint 83 (F321, GitHub #544).

## Date

2026-11-01

## Context

The repository's hooks, helper scripts and build scripts are PowerShell. Counted 2026-11-01: 11 `.ps1` files in
`.claude/hooks/`, 13 in `scripts/`, 31 in `mobile-app/scripts/`, 3 in `.claude/scripts/`. PowerShell runs on Windows
natively and on Linux and macOS only where `pwsh` is installed. CI runs on `ubuntu-latest` (`.github/workflows/ci.yml`),
so every `.ps1` guard has been Windows-only protection. Harold (2026-10-31, Sprint 82 retrospective): convert the
scripts to OS-agnostic Python, build a small shared layer, start with a small pilot so the bugs surface early, and
convert the Claude tools (skills, hooks) that are mostly deterministic while GenAI work stays in `.md` files.

Two further facts shaped the decision:

- All hook registrations ran Windows PowerShell 5.1 (`powershell -NoProfile ...`), while the Claude Code PowerShell
  tool runs PowerShell 7. Two PowerShell versions were in use at once (Sprint 82 retro IMP-3).
- Sibling repositories already do this. `hsbc-qfraud-phase2/.claude/hooks/hooklib.py` (its F78) holds one module for
  payload reading, project root, path normalizing, git calls and allow/block exit codes, and every hook fails open.
  `EvidenceBasedDB/.claude/hooks/*.py` has Python versions of the mutation lock, close-out check, sprint-cards check
  and stash guard. Both were read, not copied: this layer is smaller and keeps this repo's exit codes and messages.

## Decision

Deterministic tooling is written in Python 3 using the standard library only. A dependency change needs Harold's
approval, so there are no pip installs. A tool that needs judgment (writing, ranking, reviewing) stays a Markdown
prompt (skill, command or agent).

Additions at acceptance (Harold, 2026-11-04):

- **Interpreter**: Python 3.14 is the preferred version. On this machine the `py` launcher defaults to 3.14, while
  `python` on PATH, which the hook registrations call, is 3.12.10 (both read 2026-11-04). Until the registrations
  change, code must run on 3.12 as well; CI uses its runner's Python. Moving the hooks to 3.14 is a settings change
  asked separately.
- **Prompts**: a prompt (skill, command or agent) whose steps can be written deterministically is rewritten as a tool.
  Only the parts that need judgment stay Markdown.
- **Helper tools for prompts**: when several prompts need the same deterministic step (read a file's format, count
  rows, check a gate, build a footer), that step becomes a Python helper, and the prompts call it instead of
  repeating the step in prose.

### The shared layer: `.claude/hooks/lib/`

- `common.py`: UTF-8 stdout and stderr, stdin read as bytes, project root (`CLAUDE_PROJECT_DIR`, else walk up to
  `.git` or `.claude`), path normalizing, a non-raising `git()` call, tool lookup (`find_tool`), and ISO 8601 UTC
  parsing and formatting that does not depend on the interpreter version.
- `hooklib.py`: the hook contract. A hook defines `decide(payload) -> Verdict`; `hooklib.run` reads the payload,
  calls `decide`, writes stdout and stderr and exits. Exit 0 allows. Exit 2 blocks and puts the message on stderr
  (Claude Code feeds Claude the stderr of an exit-2 hook).
- `mutation_lock.py`: the lock library and command line (`new`, `remove`, `list`, `info`).

Why under `.claude/hooks/lib/` and not `scripts/pylib/`: the hooks are the first and most critical users, and they run
before any other tooling exists. A script imports it with one line (`sys.path.insert(0, <repo>/.claude/hooks/lib)`;
`scripts/agent-work-status.py` shows it). If a third caller family appears that does not belong near hooks, the layer
moves to `scripts/pylib/` in one commit; the module names stay.

The layer holds only what the five pilot files needed (measured by reading the PowerShell they replace): stdio
encoding, project root, path spelling, git, UTC time, tool lookup. OS and hardware detection, home and app-data
folders and line-ending helpers are NOT written yet; the batch that first needs one adds it, with a test.

### Rules every Python hook follows

1. **Fails open.** An empty, malformed or non-object payload is allowed. Any exception inside `decide` is allowed with
   a note on stderr. A Python traceback exits 1, which Claude Code treats as non-blocking, so the handler turns an
   unhandled bug into an explicit allow with a visible note instead of an unexplained one.
2. **Same interface.** Same exit codes, same bypass tokens, same message text as the PowerShell hook. A gate or test
   that matches on a message keeps working.
3. **Reads and writes UTF-8 bytes.** A Windows console defaults to cp1252. Without this, a payload with a curly quote
   fails to decode (the hook fails open on a real violation) or the block message fails to encode (Python exits 1 and
   the block is lost). `test_blind_staging_blocks_with_non_ascii_text_under_cp1252` guards it.
4. **Regex flags are chosen call by call.** PowerShell `-match`, `-replace` and `-in` are case-insensitive;
   `-cmatch` and `[regex]::Match` are case-sensitive. Python 3.11 and later reject an inline `(?i)` that is not at the
   start of a pattern.
5. **Tests.** Each hook keeps its recorded cases in `.claude/hooks/test-cases/<folder>/` (allow-* exit 0, violation-*
   exit 2). `run-test-cases.ps1` runs a `.py` route under `python`; `.claude/hooks/tests/test_pylib.py` (stdlib
   `unittest`) replays the same cases through each hook's `decide`, so CI on Linux proves the hooks as well as the
   layer.

### Registration form

```
python "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.py"
```

Forward slashes only, double-quoted path, no shell operators. It runs unchanged under Git Bash and cmd on Windows and
under sh on Linux and macOS, and it is the form the sibling repository uses. Requirements: `python` must be on PATH. On
Linux that means the `python-is-python3` package or a `python` symlink; on a runner that has only `python3`, the
CI step uses `python3` directly (the hooks are not registered in CI). No `python3 ... || python ...` fallback is
used: the first run consumes stdin, so a second run would read an empty payload and allow.

### The PowerShell interface of `mutation-lock.ps1` stays

`mutation-test.ps1`, `agent-work-status.ps1` and CLAUDE.md call `. .claude\hooks\mutation-lock.ps1` and then
`New-MutationLock`, `Remove-MutationLock`, `Get-MutationLock` and `Get-MutationLockInfo`. `mutation-lock.ps1` is now a
thin shim: each function calls `lib/mutation_lock.py`. The lock files are unchanged (same folder, same name rule, same
four JSON fields), so a lock written by either implementation is read by the other. `scripts/agent-work-status.ps1`
likewise stays as the entry point the hourly wake-up runs and calls `scripts/agent-work-status.py`. Output is unchanged.

### Pilot set (Sprint 83 Task 10, Q9 = 1)

Converted: `block-blind-staging`, `block-heredoc-python-backslash`, `block-commit-during-mutation`, the mutation lock
library, and `scripts/agent-work-status`. Their `.ps1` hook files are removed from registration and from the
runner routes; the `.ps1` originals are deleted in the same change. Defects found while converting are recorded in
the Sprint 83 plan, Task 10 "Result (Phase 4)".

### Classification (R-4)

Classified 2026-11-01 from file names, sizes and the `.SYNOPSIS` or description of each. The batch that converts a
file re-reads it first. "Windows-bound" means the file drives a Windows-only tool (MSIX, Task Scheduler, WinWright,
Windows Error Reporting, the MTP COM shell); it keeps a Windows path, wrapped in Python only where that adds value.

Hooks (`.claude/hooks/`):
- Converted by the pilot: `block-blind-staging`, `block-heredoc-python-backslash`, `block-commit-during-mutation`,
  `mutation-lock`.
- Deterministic, convert later: `block-carry-forward-stash`, `require-sprint-cards`, `warn-commit-without-velocity`
  (F326); `verify-closeout-complete` (F327); `sprint-auto-advance` (F328); `run-test-cases`, `status-footer` (F329).
- GenAI: none. Every hook is a regex or file check.

Converted in Sprint 85 (originals deleted in the same change; port review and tests in `SPRINT_85_PLAN.md`):
- F332: `scripts/phone-log-health.py`, `mobile-app/scripts/r76_battery_arm.py` (was `.sh`; moved from F336).
- F330: `scripts/clean-temp-scripts.py`, `scripts/run-full-suite.py`, `scripts/validate-yaml-rules.py`,
  `scripts/test-regex-patterns.py`, plus the shared helper `scripts/regex_dialect.py` (.NET to Python `re`
  translation; patterns it cannot translate are reported NOT CHECKED, never as valid).
- F331: `scripts/install-custom-mcp.py`, `scripts/setup-claude-mcp.py`, `scripts/start-test-imap-servers.py`, plus the
  shared helper `scripts/mcp_config.py` (read, back up and write the Claude Code MCP configuration, `~/.claude.json`).

`scripts/`:
- Converted by the pilot: `agent-work-status`.
- Deterministic, convert later: `test-hook`, `mutation-test` (F329). Converted in Sprint 85: `clean-temp-scripts`,
  `run-full-suite`, `validate-yaml-rules`, `test-regex-patterns` (F330); `install-custom-mcp`, `setup-claude-mcp`,
  `start-test-imap-servers` (F331); `phone-log-health` (F332).
- Windows-bound, decide per file (F337): `enable-crash-dumps` (Windows Error Reporting), `pull-phone-screenshots`
  (MTP through the Windows shell COM).
- Already Python: `remove-emojis.py`, `remove-emojis-code.py`. Other: `email-rule-tester-mcp/` (a Node MCP server),
  `test-imap/` (fixtures).

`mobile-app/scripts/`:
- Deterministic, convert later: `check-log-redaction`, `check-version-consistency`, `validate-content-manifest`,
  `verify-aab-play-requirements`, `update_iana_tlds.ps1`, `update_iana_tlds.sh` (F333); `run-tests`,
  `run-integration-tests`, `monitor-tests`, `check_scans`, `check_task`, `test-background-scan-skip`,
  `generate-test-emails`, `ww-test-helper.sh` (F334); `build-with-secrets`, `build-with-secrets-clean`, `build-apk`
  (F335); `run-emulator`, `start-emulator`, `setup-android-oauth`, `export-tokens-for-android`,
  `capture-diagnostic-logs`, `enable-screen-reader-flag`, `fix-flutter-git`, `r76_battery_arm.sh` (F336);
  `cleanup-url-body-rules`, `fix-header-patterns` (F338).
- Windows-bound (F337): `build-windows`, `build-msix` (deprecated; delete candidate), `launch-msix`,
  `create-test-cert`, `generate-appinstaller`, `run-winwright-tests`, `winwright-db-snapshot`.
- Already Python: `r76_battery_summarize.py`, `rebuild_rules_yaml.py`, `send-test-emails.py`. Dart one-offs that stay
  Dart (run with the Dart SDK, no PowerShell involved): `cleanup_body_rules.dart`, `dedup_rules.dart`,
  `fix_tld_rules.dart`, `fix_wildcard_tld.dart`, `remove_ambiguous_tld_rules.dart`, `repair_safe_sender_types.dart`,
  `split_rules.dart`, `tld_audit_and_gapfill.dart` (F338 audits whether they are still needed). Data and notes:
  `EMULATOR_AUTO_START.md`, `split_edge_cases.txt`.

Skills (`.claude/skills/`, 10):
- Deterministic (a script does the work; the skill stays as a short `.md` that runs it): `startup-check`, `full-test`,
  `validate-rules`, `deploy-debug` (F339).
- Hybrid (a script gathers the facts, the model judges them; the skill stays `.md`): `phase-check`, `memory-save`
  (F339).
- GenAI (stays `.md`, no card): `plan-sprint`, `backlog-refinement`, `first-principles`.
- Retired: `memory-restore` (delete candidate, F340).

`.claude/scripts/` (3 `.ps1`): `archive-memory`, `check-memory-on-startup`, `save-memory` are deterministic and look
obsolete since the Sprint 51 retirement of `/memory-restore`; F340 audits them and deletes or converts.

`.claude/commands/` (5) and `.claude/agents/` (5) are prompts to a model and stay `.md`. The brief did not ask for them
to be classified; they are listed here so the inventory is complete.

### Conversion log

- Sprint 84 F326 (GitHub #554), 2026-11-06: `block-carry-forward-stash.ps1` converted to `block-carry-forward-stash.py`
  (stash-guard, 8 recorded cases). Registered in `.claude/settings.json` in Python form; the `.ps1` is kept until F329.
- Sprint 84 F326 (GitHub #554), 2026-11-06: `require-sprint-cards.ps1` converted to `require-sprint-cards.py`
  (sprint-cards, 8 recorded cases). It makes no `gh` call, so the layer gained no `gh` wrapper. Registered in Python form.
- Sprint 84 F326 (GitHub #554), 2026-11-06: `warn-commit-without-velocity.ps1` converted to `warn-commit-without-velocity.py`
  (velocity-warn, 12 recorded cases). Its JSON warning matches the PowerShell output except one trailing CRLF that the
  shared layer adds on Windows. Registered in Python form.
- Sprint 84 F327 (GitHub #555), 2026-11-06: `verify-closeout-complete.ps1` (Stop hook) converted to
  `verify-closeout-complete.py` (closeout, 25 recorded cases plus one CRLF case). This is the first hook that calls `gh`,
  so the layer gained `common.gh()`, the same never-raising `(exit code, stdout)` shape as `git()`, with an 8 second
  timeout so the hook's two possible calls fit its 20 second budget. A missing, offline or slow `gh` skips check 3c (fail
  open), as the PowerShell `catch { }` did. Markdown is read as bytes and decoded `utf-8-sig`, so CRLF survives. Registered
  in Python form under `Stop`; the `.ps1` is kept until F329.
- Sprint 84 F328 (GitHub #556), 2026-11-06: `sprint-auto-advance.ps1` (Stop hook, 756 lines) converted to
  `sprint-auto-advance.py` (top-level route, 55 recorded cases plus 16 footer cases added for R-5). All 13 commitment
  patterns, 13 question patterns and 40 whitelist patterns keep their order and text; every one is compiled
  case-insensitive (the source has no `-cmatch`). One .NET construct has no Python spelling: FORM 6's variable-width
  lookbehind `(?<!\b(is|are|was|were|been|being)\s)` became six fixed-width lookbehinds. JSON `-eq $true` and `-eq $false`
  comparisons are reproduced by `ps_eq_bool`. One deliberate difference (R-6): the PowerShell wrapped the whole F193
  evidence evaluation in `try { } catch { }`, so an unreadable plan or velocity file fell through silently; the Python
  lets that exception reach `hooklib.run` (exit 1, a visible hook error). Only the status-file and plan-head reads keep
  the swallow. Registered in Python form under `Stop`; the `.ps1` is kept until F329.
- Sprint 84 5.1.2 F6, 2026-11-06: fail-open stays, but it is no longer silent. A `gh` failure in check 3c of
  `verify-closeout-complete.py` now gives the notice "check 3c did not run: gh unavailable (<reason>)"; an existing but
  unreadable `sprint_status.json` gives "sprint_status.json unreadable (<error>); sprint gates skipped"; `hooklib.run`
  gives "[<hook>] input unreadable (<why>); allowed without checking" for non-empty input that is not a JSON object. All
  three still allow (exit 0). Claude Code never shows stderr of a hook that exits 0, so `hooklib.notice()` queues the
  text and `hooklib.run` delivers it as the `systemMessage` stdout field, merged into any JSON the hook already prints
  (one object), or as a "Note:" paragraph in the stderr reason on a block. A hook with plain-text stdout
  (`block-commit-during-mutation`) gets the notice on stderr, which is not shown.

### Conversion order

Smallest and most used first, harness last: F326, F327, F328 (hooks), then F329 (the test tooling, which switches
`run-test-cases` to Python and retires the `.ps1` shims once nothing calls them), then the `scripts/` and
`mobile-app/scripts/` batches (F330 to F338), then skills (F339) and the audit (F340). Each card names its batch size in
minutes and keeps the converted file's interface or updates every caller in the same commit.

## Alternatives Considered

### Keep PowerShell and install `pwsh` on the Linux runner
- **Pros**: no rewrite.
- **Cons**: a second PowerShell version stays in use; every macOS and Linux contributor installs PowerShell; the
  `-match` case-insensitive defaults and `Write-Host` stream behavior stay as traps (the pilot found one: a block
  message sent to stdout that Claude never saw).
- **Why Rejected**: it does not remove the cause Harold named, a tooling language that is not native to the
  platforms the repository targets.

### Node.js or Bash
- **Pros**: Bash exists on Linux and macOS.
- **Cons**: Bash is not native on Windows and is weak at JSON, dates and encodings; Node adds a runtime this repo
  does not otherwise need for tooling.
- **Why Rejected**: Python is already present on the development machine and on every CI runner, ships `json`,
  `re`, `subprocess`, `pathlib` and `unittest` in the standard library, and the sibling repositories already use it.

### Convert everything in one change
- **Why Rejected**: Harold asked for a small pilot first so the defects surface early. A broken hook can block every
  tool call, so each hook is registered only after its cases pass.

## Consequences

### Positive
- The pilot hooks run on Windows, Linux and macOS and are tested on the CI Linux runner (a `unittest` step).
- Fail-open and UTF-8 handling are written once, in `hooklib` and `common`, instead of once per hook.
- Two PowerShell versions matter less over time: each converted hook removes one `powershell -File` launch.

### Negative
- A Python process starts for each registered hook on each Bash or PowerShell tool call. Measured on this machine,
  see the Sprint 83 plan Task 10 Result for the numbers.
- `python` must be on PATH for hooks to run. If it is missing, every Python hook fails (a missing command is not exit
  2, so tool calls are not blocked, but the guards are off).
- Until F329 lands, both PowerShell and Python test routes exist in `run-test-cases.ps1`.

### Neutral
- The Dart one-off scripts and the GenAI prompts are unchanged.
- Windows-bound scripts keep a PowerShell path.

## References
- Sprint 83 plan, Task 10; ALL_SPRINTS_MASTER_PLAN.md F321 and the cards F326 to F340
- `.claude/hooks/lib/` (the layer), `.claude/hooks/tests/test_pylib.py` (its tests)
- `.claude/hooks/test-cases/` (recorded cases), `.claude/hooks/run-test-cases.ps1`, `scripts/test-hook.ps1`
- CLAUDE.md: the heredoc backslash rule (IMP-3), the blind-staging rule, the mutation-lock rule (Sprint 65 IMP-5)
- Prior art (read only): `hsbc-qfraud-phase2/.claude/hooks/hooklib.py`, `EvidenceBasedDB/.claude/hooks/*.py`
