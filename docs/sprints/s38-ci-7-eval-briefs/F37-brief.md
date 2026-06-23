# F37 Eval Brief (Sprint 40 Task 5, S38-CI-7 eval subject)

**Productive run model**: Sonnet
**Eval re-run model**: Opus 4.6 (this brief)
**Branch for eval**: `feature/20260525_Sprint_40_F37-opus46`

---

You are executing Sprint 40 Task 5 (F37) on this repo: `D:\Data\Harold\github\spamfilter-multi`.

## Task

Folder selectors: **two-level listing** + provider-default-first flat lists + per-provider path-separator detection. This is the highest-UI-risk task in Sprint 40 -- the two-level collapsible folder tree is a novel widget with no historical analogue. Estimate held conservatively at **40-60 min**.

## Three sub-parts (acceptance criteria)

- [ ] **Part A -- Two-level collapsible folder tree** for the **Default Folders selector** (the multi-select folder picker at `mobile-app/lib/ui/screens/folder_selection_screen.dart`). Parse each folder's full path using the provider's hierarchy delimiter (e.g., AOL/IMAP uses `/`, others may differ) into a tree of depth-2: parent folder + child folders. Render as a list of `ExpansionTile`s (or equivalent collapsible widget) -- parent folders collapsible; children selectable. Top-level/root folders (no delimiter in name) render as flat rows. Selection state persists per leaf folder name (current behavior preserved).

- [ ] **Part B -- Provider-default-first flat lists** for the Safe Sender / Deleted Rule folder selectors (these run in `singleSelect: true` mode). Today the folder list is sorted alphabetically. Reorder so the **canonical default folder** for the action appears FIRST in the list, then the rest alphabetical. For Safe Sender -> default = INBOX. For Deleted Rule -> default = TRASH/Deleted. Use the existing `FolderInfo.canonicalName: CanonicalFolder` to identify defaults (declared at `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart:312`). Existing test claim: "Part B PARTIAL" -- review what is already done and finish what is not.

- [ ] **Part C -- Per-provider path-separator detection.** Today no code consumes a per-provider delimiter (grep finds none -- `lib/ui/screens/folder_selection_screen.dart` does not use a delimiter). Add a `hierarchyDelimiter` field (String, default `/`) to `FolderInfo` at `spam_filter_platform.dart:304`. Populate it from each adapter:
  - **Gmail (`gmail_api_adapter.dart:818 listFolders`)**: use `/` (Gmail labels use `/` for nesting).
  - **Generic IMAP (`generic_imap_adapter.dart:973 listFolders`)**: use whatever the IMAP `LIST` response returns as the hierarchy delimiter (the second untagged response field after `LIST (...)` is the delimiter, e.g., `* LIST (\HasNoChildren) "/" "INBOX"`). If the adapter package surfaces this, plumb it through; if not, default to `/` with a TODO comment naming the gap (do NOT introduce a custom IMAP parse -- use what enough_mail or imap_client exposes; check pubspec for the IMAP lib in use).
  - **Outlook (`outlook_adapter.dart:155 listFolders`)**: use `/`.
  - **Mock (`mock_email_provider.dart:177`)**: use `/`.
  Part A consumes this `hierarchyDelimiter` to split folder paths into tree nodes (do NOT hardcode `/`).

## Pre-authorized decisions (do NOT re-ask)

- Extend `FolderInfo` with `hierarchyDelimiter` field (Class-2, but explicitly in task spec). Default to `/` for backward compat so existing callers/tests do not break.
- Choose `ExpansionTile` (Flutter built-in) for the collapsible tree -- do not add a new dependency for a tree widget.
- For singleSelect mode (Part B), do NOT change the existing selection semantics; ONLY reorder the displayed list.

## Decisions that DO require surfacing (STOP and report)

- Any change that breaks an existing folder-selection caller signature.
- Any change to the `EmailProvider.listFolders()` signature (the one at `email_provider.dart:36`).
- Any change to how folders are persisted (DB schema or settings keys).
- Any change to the IMAP library or addition of new dependencies.

## Critical context

- **`FolderInfo`** at `lib/adapters/email_providers/spam_filter_platform.dart:304`: has `id`, `displayName`, `canonicalName: CanonicalFolder`, `messageCount?`, `isWritable`. Add `hierarchyDelimiter`.
- **`folder_selection_screen.dart`** has the `singleSelect: bool` flag (line ~46) and `initialSelectedFolders` (line ~42). Part A is for the multi-select mode (Default Folders); Part B is for the singleSelect mode (Safe Sender / Deleted Rule).
- **F25/F35 just landed today** -- new utility `ManualRulePatternGenerator`, new `RuleEditScreen`, updated provider rethrow. Your tests need to coexist with the +25 / +47 tests from those tasks.

## Reference (read in this order)

1. `mobile-app/lib/ui/screens/folder_selection_screen.dart` (full -- understand the existing flat list rendering)
2. `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart:300-340` (FolderInfo + CanonicalFolder enum)
3. `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart:818-870` (Gmail listFolders -- how to set delimiter from labels)
4. `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:973-1030` (IMAP listFolders -- find the IMAP lib's hierarchy delimiter exposure)
5. `mobile-app/lib/adapters/email_providers/outlook_adapter.dart:155-200`
6. `mobile-app/lib/adapters/email_providers/mock_email_provider.dart:177-220`
7. `mobile-app/pubspec.yaml` (look for `enough_mail` or `imap_client` to know the IMAP lib)

## Constraints

- Estimate: **40-60 min**. If you hit 70 min, STOP and report what is blocking.
- All new code MUST have tests. Tests under `mobile-app/test/`.
- `flutter analyze` MUST be clean (0 issues).
- Full suite MUST stay green. Currently **1612 pass / 28 skip / 0 fail**.
- Do NOT use emojis. Do NOT use contractions (CLAUDE.md style).
- Use `Logger` not `print()` for production logging.
- Do NOT commit. Leave changes staged.

## Workflow

1. Read the 7 reference files.
2. Decide IMAP delimiter approach (live from server, or default-to-`/` with TODO). Document.
3. Extend `FolderInfo` with `hierarchyDelimiter` (defaulted, backward-compat).
4. Update all 4 adapter `listFolders` implementations to populate it.
5. Refactor `folder_selection_screen.dart` to:
   - Detect singleSelect mode (Part B) -> reorder canonical default to first, rest alphabetical.
   - Multi-select mode (Part A) -> split each folder displayName on its `hierarchyDelimiter` into depth-2 groups; render as `ExpansionTile`s.
6. Add tests: unit tests for the tree-grouping logic (pure function), widget tests for the new ExpansionTile rendering + singleSelect reorder.
7. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter test`
8. Run: `cd "D:\Data\Harold\github\spamfilter-multi\mobile-app" && flutter analyze`
9. Fix anything red before reporting done.

## Output report

- Part A: status + ExpansionTile structure + how parent rows behave (selectable themselves? or expand-only?)
- Part B: status + before/after of the singleSelect list order for SafeSender/DeletedRule
- Part C: status + per-adapter delimiter source (esp. IMAP -- live or default+TODO)
- Tests added: count + names
- Full-suite count (was 1612 pass; target 1625+)
- `flutter analyze` result
- Wall-clock minutes spent
- Any Class-1/2/3 decisions encountered + how handled (pre-authorized: FolderInfo extension, ExpansionTile choice)

Note: this task is ALSO an S38-CI-7 EVAL SUBJECT. Opus 4.6 re-runs this identical brief later. Your output is being scored on: process adherence, instruction-following, architecture discipline (esp. how you handle the per-adapter delimiter plumbing), stopping-criteria, code quality. Be deliberate; document decisions.

---

## Eval-only note

For the 4.6 re-run, branch should fork from `develop` AT THE COMMIT immediately preceding the F37 productive run landing -- so the 4.6 run sees F25 (`ManualRulePatternGenerator`) and F35 (`RuleEditScreen`) merged but NOT the F37 `FolderInfo.hierarchyDelimiter` field. Use `git log --oneline` to identify the right starting commit.
