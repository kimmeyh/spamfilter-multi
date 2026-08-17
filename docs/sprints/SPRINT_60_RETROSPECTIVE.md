# Sprint 60 Retrospective

**Sprint**: 60 (2026-08-15 to 2026-08-16)
**Branch**: `feature/20260815_Sprint_60` | **PR**: #335 (draft, targets `develop`)
**Scope**: F160 (skipped-test audit), F156 (Android walk-through), F157 (gradle/minSdk study + implement), F158 (Android CI job), F159 (metadata gates), F143 (touch selection), F144 (Android background-scan re-evaluation). Mid-sprint additions per Harold's plan-then-execute steering: F166 (Results header redesign, card #336) plus four Manual Validation fix rounds.
**Result**: All 7 planned tasks complete plus F166 executed; 4 MV rounds resolved (2 CRITICAL Android defects: PRAGMA scan failure, accounts-FK persistence failure). Final suite 1,859 passed / 26 skipped / 0 failed; analyze clean.

## Sprint 60 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Good. "Can you address these errors in such a way as they are done correctly in the future:" followed by two quoted failure transcripts:

  ```
  Bash(python - <<'EOF' ... [reading f166_tests.log and printing a TestFailure block] ... EOF)
  Error: Exit code 1
  Traceback (most recent call last):
    File "<stdin>", line 7, in <module>
    File "C:\python312\Lib\encodings\cp1252.py", line 19, in encode
      return codecs.charmap_encode(input,self.errors,encoding_table)[0]
  UnicodeEncodeError: 'charmap' codec can't encode characters in position 30-149: character maps to <undefined>
  ```

  ```
  Bash(python - <<'EOF' ... subprocess.run(["flutter","test",...]) ... EOF)
  Error: Exit code 1
  Traceback (most recent call last):
    File "<stdin>", line 4, in <module>
    File "C:\python312\Lib\subprocess.py", line 548, in run
    File "C:\python312\Lib\subprocess.py", line 1026, in __init__
    File "C:\python312\Lib\subprocess.py", line 1538, in _execute_child
      hp, ht, pid, tid = _winapi.CreateProcess(executable, args,
  FileNotFoundError: [WinError 2] The system cannot find the file specified
  ```
- **Claude Code Development Team**: Both failures are the same class: using python heredocs on Windows without accounting for Windows process/console semantics. Root causes and permanent corrections: (a) Windows python stdout defaults to cp1252; any script that prints file or log content must start with `sys.stdout.reconfigure(encoding="utf-8", errors="replace")`. (b) `flutter` is `flutter.bat` on Windows and `CreateProcess` does not resolve batch files without a shell; the correct pattern is to never wrap tool invocations in python `subprocess` at all: run the tool via the shell to a log file, then parse the file with python. Both recovered in under a minute each mid-sprint, but they were foreseeable; proposed as IMP-1 (memory rule). One additional self-caught inefficiency: during mutation-verification of the demo-label fix, `git checkout --` was used to restore the mutated file while the real fix was still uncommitted, reverting the fix itself (caught immediately because the test was re-run; proposed as IMP-2).

### 2. Testing Approach

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: The mutation-verification discipline earned its keep twice: it exposed a worthless popup-fit test (green at 900px against the broken code; tightened to 650px where the overflow reproduces) and confirmed every MV fix test goes red under the reverted code. On-device DB forensics (adb run-as WAL-safe pull + sqlite3) turned two "it does not work" reports into exact root causes, and in round 4 proved a suspected bug was correct behavior before any code was touched. The persistence regression test seeds NO accounts row, the exact condition every sibling test masked.

### 3. Effort Accuracy

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: The 7-10h plan estimate held for the planned tasks; F157 stayed inside its 200-LOC/2h implement-if box. The four MV rounds were unplanned by nature but each fix landed inside a single round trip; no estimate revisions were needed mid-sprint.

### 4. Planning Quality

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: The plan-then-execute steering for mid-MV asks worked well: F166 got a card (#336) and a spec echo before code, while smaller fixes were executed directly as MV items. F160's audit-table format (purpose / why skipped / recommendation per test) made the approval a single sentence.

### 5. Model Assignments

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: Cheapest-first assignment produced no top-tier tasks at planning time (Haiku 1, Sonnet 6). Executed-by: all tasks ran on the session model (Fable 5) because execution was single-session and MV-interleaved; recorded per the Executed-by rule rather than silently.

### 6. Communication

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: BLUF answers to the standing questions (parity, emulator commands, account preservation, netsimd) kept MV moving. The round-4 answer led with "the fix works and the empty screen is correct" before the forensics detail, which is the right order for a validation-blocking question.

### 7. Requirements Clarity

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: Harold's F166 chips spec was precise enough to implement without a clarifying round. The stale-app incident is a reminder that observed-behavior reports must be validated against what build is actually installed before being treated as requirements input; that rule is now written into F162.

### 8. Documentation

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Developer Team**: Plan completion notes and per-round MV records were written in-stride; CHANGELOG entries shipped in the same commits as the changes. One miss found and fixed during this retrospective: ARCHITECTURE.md still listed `BackgroundScanManager` and the Android `BackgroundScanWorker`, both deleted by F144; corrected now (proposed as IMP-4: deletion tasks must grep docs/ for the deleted class names before closing).

### 9. Process Issues

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: The PreToolUse card-gate hook blocking an entire chained command (including its innocent tail) cost one lost docs write earlier in the sprint, caught by grep-verification; the standing correction (status-file update as its own command first) held for the rest of the sprint. No auto-advance violations; the MV window questions were all legitimately Harold-driven.

### 10. Risk Management

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: The account-preserving deploy flow (`adb install -r`, never uninstall) was adopted after the keystore-wipe lesson and held for the rest of MV; the storage pre-flight in build-with-secrets.ps1 prevents the INSTALL_FAILED_INSUFFICIENT_STORAGE recurrence. Two CRITICAL silent-failure bugs (PRAGMA, accounts-FK) were found by walking the platform rather than trusting the green suite, which is exactly what F156 was for.

### 11. Next Sprint Readiness

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: Backlog is well-stocked and prioritized: F161 (Android scheduler), F162 (parity audit + ADR), F163 (skipped-test remediation), F164 (Android scan performance), F165 (cloud rules sharing), plus Harold's new Android Help text item (Category 14). Store release 0.9.0.0 is in certification; Step 7 close-out triggers on certification, not on sprint close.

### 12. Architecture Maintenance

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): Very Good.
- **Claude Code Development Team**: F144 removed the unwired pre-architecture Android background-scan code (four classes + workmanager dependency) with the design verdict recorded and the live `ScanFrequency` enum extracted cleanly. ARCHITECTURE.md updated (after the retro-time catch noted in Category 8). No ADR-level decisions were made this sprint; the parity ADR is deliberately scoped to F162.

### 13. Minor Function Updates for the Next Sprint Plan

(Each entry below is a CARRY-IN to the next sprint's plan. Apply during Phase 3 of Sprint N+1.)

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): none
- **Claude Code Development Team**: None.

### 14. Function Updates for the Future Backlog

(Each entry below MUST be added to `docs/ALL_SPRINTS_MASTER_PLAN.md` "Next Sprint Candidates" with a feature/issue number assigned during Phase 7.7 documentation updates.)

- **Product Owner / Scrum Master / Lead Developer** (combined, Harold verbatim): "Android - updates to Help text specific to Android - again follow the best practice of everything the same unless that is not reasonably possible, then adapt for the platform as minimally as possible while still meeting what is reasonably needed - see ADR for details."
- **Claude Code Development Team**: None beyond the items already registered in-sprint (F161-F166). Harold's item to be registered as **F167** in Phase 7.7, linked to the F162 parity ADR as its governing policy.

### Questions to be discussed before ending the sprint

- **Harold (verbatim)**: none

## Improvements (Phase 7.5) -- dispositions (Harold, 2026-08-16)

- **IMP-1 (APPLIED)**: Python-on-Windows heredoc rules, per Harold's explicit Category 1 ask. (a) Any heredoc printing file/log content starts with `sys.stdout.reconfigure(encoding="utf-8", errors="replace")` (Windows stdout defaults to cp1252). (b) Never wrap `flutter`/`gh`/`dart` in python `subprocess` (they are `.bat` shims CreateProcess cannot resolve); run the tool via the shell to a log file and parse the file. Saved as memory rule `feedback_python_heredoc_windows`.
- **IMP-2 (DECLINED by Harold)**: mutation-verification restore discipline (no `git checkout --` on a file whose fix is uncommitted). Not applied.
- **IMP-3 (DECLINED by Harold)**: deletion tasks grep docs/ for deleted class names before closing. Not applied. (The specific ARCHITECTURE.md staleness found this sprint was fixed directly.)
- **IMP-4 (DECLINED by Harold)**: hook-safe command discipline (no unrelated writes chained into hook-blockable commands). Not applied.
- **Category 14 item**: registered as **F167** (Android Help text, minimal platform adaptation per the F162 parity ADR) in `ALL_SPRINTS_MASTER_PLAN.md` during Phase 7.7.
