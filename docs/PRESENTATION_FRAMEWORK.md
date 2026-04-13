# GenAI Happy Hour Presentation: Building a Real App with Claude Code

**Audience**: Developers (Python, Go, TypeScript, C#/.NET) at GenAI Happy Hour
**Format**: ~25-30 min talk + Q&A
**Tone**: Honest, practical, developer-to-developer
**Total Slides**: ~27 slides

---

## SECTION 1: Introduction (2 slides)

### Slide 1: Title

**"From Side Project to Windows Store: Building a Real App with Claude Code"**

- Harold Kimmey
- GenAI Happy Hour - [Date]
- Subtitle: "25 sprints, 1,178 tests, 0 regressions"

---

### Slide 2: The Problem and Starting Point

**I was drowning in spam across multiple email accounts.**

- Had a working Python/Outlook desktop script (win32com, hardcoded rules, Windows-only)
- Each email provider has different spam filtering quality
- Wanted: one app, all providers, all platforms, portable rules
- "I am not a Flutter developer. I had never written Dart. This is relevant."

> **Talking point**: "I had a working solution. But it was duct tape and baling wire. I wanted a real app — and I wanted to see if Claude Code could help me build one."

---

## SECTION 2: App Functionality (2 slides, ~10 bullet points)

### Slide 3: What MyEmailSpamFilter Does — Core Features

**Email Scanning and Filtering**
- Connects to Gmail (OAuth), AOL, Yahoo, and any generic IMAP provider
- Evaluates emails against 3,291 regex-based spam rules with first-match-wins logic
- Safe sender whitelist — trusted senders bypass all rules automatically
- Four progressive scan modes: read-only (default), test limit, safe-senders-only, full production
- Move-to-trash safety — never permanently deletes; recoverable from trash

**Multi-Account Management**
- Add and manage multiple email accounts across different providers
- Per-account folder selection and scan configuration

---

### Slide 4: What MyEmailSpamFilter Does — Advanced Features

**Background and Automation**
- Scheduled background scanning via Windows Task Scheduler (headless, no UI)
- System tray icon with context menu; toast notifications on scan completion
- Scan history with retention settings — review what was caught and when

**Rules Management**
- Search, browse, and manage 3,291+ individual rules organized by pattern type
- Add block rules or safe senders inline during scan results review
- Rule conflict detection — warns when rules prevent other rules from firing
- Import/export rules via YAML for version control and portability

---

## SECTION 3: Application Screenshots (12 slides)

> **Note**: Capture these screenshots from the running Windows app before the talk. Each slide should be a full-screen or near-full-screen screenshot with a short title and 1-2 bullet annotations.

### Slide 5: Account Selection Screen

**Screenshot**: `AccountSelectionScreen` — the landing page

- List of configured email accounts (Gmail, AOL, etc.)
- Add Account button, account status indicators
- Bottom navigation bar on Android; traditional nav on Windows

> **Source file**: `lib/ui/screens/account_selection_screen.dart`

---

### Slide 6: Platform Selection Screen

**Screenshot**: `PlatformSelectionScreen` — choosing an email provider

- Provider cards: Gmail, AOL, Yahoo, Generic IMAP, Demo Mode
- Each card shows supported auth method (OAuth, App Password, IMAP)

> **Source file**: `lib/ui/screens/platform_selection_screen.dart`

---

### Slide 7: Account Setup / Gmail OAuth Screen

**Screenshot**: `AccountSetupScreen` or `GmailOAuthScreen` — configuring an account

- Credential entry (IMAP) or OAuth browser flow (Gmail)
- Folder selection for which folders to scan
- Scan mode configuration

> **Source files**: `lib/ui/screens/account_setup_screen.dart`, `lib/ui/screens/gmail_oauth_screen.dart`

---

### Slide 8: Folder Selection Screen

**Screenshot**: `FolderSelectionScreen` — picking email folders to scan

- Tree view of IMAP folders
- Checkbox selection for folders to include
- Junk folder auto-detection per provider (AOL: Bulk Mail, Gmail: Spam, etc.)

> **Source file**: `lib/ui/screens/folder_selection_screen.dart`

---

### Slide 9: Scan Progress Screen

**Screenshot**: `ScanProgressScreen` — live scan in progress

- Real-time progress bar with email count
- Throttled UI updates (every 10 emails or every 2 seconds)
- Current folder, emails processed, matches found

> **Source file**: `lib/ui/screens/scan_progress_screen.dart`

---

### Slide 10: Scan Results Screen

**Screenshot**: `ResultsDisplayScreen` — scan results with filtering

- Email list showing: folder, subject, matched rule
- Filter chips by category (spam type, safe sender, no match)
- Search bar for finding specific results
- Inline actions: add as safe sender, add block rule

> **Source file**: `lib/ui/screens/results_display_screen.dart`

---

### Slide 11: Email Detail View

**Screenshot**: `EmailDetailView` — drilling into a specific email

- Full email headers (From, Subject, Date)
- Matched rule name and pattern that triggered
- Action taken (moved to trash, no action, safe sender)

> **Source file**: `lib/ui/screens/email_detail_view.dart`

---

### Slide 12: Rules Management Screen

**Screenshot**: `RulesManagementScreen` — browsing 3,291 rules

- Searchable rule list with pattern type classification
- Rule details: name, conditions (from/subject/body/header patterns), actions
- Enabled/disabled toggle

> **Source file**: `lib/ui/screens/rules_management_screen.dart`

---

### Slide 13: Safe Senders Management Screen

**Screenshot**: `SafeSendersManagementScreen` — whitelist management

- Three pattern types: exact email, exact domain, entire domain (with subdomains)
- Category filter chips to view by type
- Add/remove safe sender entries

> **Source file**: `lib/ui/screens/safe_senders_management_screen.dart`

---

### Slide 14: Rule Test Screen

**Screenshot**: `RuleTestScreen` — testing patterns against sample emails

- Enter a regex pattern, test against sample emails
- Match highlighting showing which emails would be caught
- Useful for refining rules before deploying

> **Source file**: `lib/ui/screens/rule_test_screen.dart`

---

### Slide 15: Settings Screen

**Screenshot**: `SettingsScreen` — tabbed configuration

- Tabs: Manual Scan, Background Scan, Account, Import/Export
- Scan mode selection, folder configuration, frequency settings
- YAML import/export for rule portability

> **Source file**: `lib/ui/screens/settings_screen.dart`

---

### Slide 16: Scan History Screen

**Screenshot**: `ScanHistoryScreen` — historical scan results

- Unified view of manual and background scans
- Per-scan stats: emails processed, deleted, moved, safe, errors
- Retention settings for history cleanup

> **Source file**: `lib/ui/screens/scan_history_screen.dart`

---

## SECTION 4: Architecture (4 slides)

### Slide 17: Architecture Decision — Why Flutter/Dart?

**Key Requirement**: One codebase, 5 platforms, multiple display sizes

| Considered | Rejected Because |
|------------|-----------------|
| Keep Python + build separate mobile apps | Rule engine reimplemented 3x; maintenance unsustainable for solo dev |
| React Native | Desktop support (Electron) was less mature at decision time |
| Kotlin Multiplatform (KMP) | Still requires separate UI per platform |
| .NET MAUI | No Linux support; too coupled to Microsoft ecosystem |
| **Flutter/Dart** | **Chosen**: single UI framework, all 5 platforms, strong desktop story |

> **Talking point**: "This was ADR-0001. We documented the decision with alternatives considered, pros/cons, and consequences. This is how every major decision was made."

---

### Slide 18: Layered Architecture

```
+-----------------------------------------------+
|              UI Layer (Flutter)                |
|  Material Design - responsive to device size  |
+-----------------------------------------------+
|        State Management (Provider)            |
|  RuleSetProvider | EmailScanProvider          |
+-----------------------------------------------+
|            Core Services                      |
|  RuleEvaluator | EmailScanner | PatternCompiler|
|  RuleConflictDetector | YamlService           |
+-----------------------------------------------+
|            Adapter Layer                      |
|  GmailApiAdapter | GenericIMAPAdapter         |
|  MockEmailProvider (Demo)                     |
+-----------------------------------------------+
|          Platform Services                    |
|  AppPaths | SecureCredentials | SQLite DB     |
|  TaskScheduler | SystemTray | Notifications   |
+-----------------------------------------------+
```

**Key design pattern**: Provider-agnostic core. Add a new email provider by implementing one interface (`SpamFilterPlatform`). Business logic never changes.

---

### Slide 19: The ADR Process — Architecture Decision Records

**36 ADRs documented across 25 sprints** ([docs/adr/](docs/adr/))

**Format** (every ADR follows this template):
- **Context**: What problem motivated this decision?
- **Decision**: What was decided?
- **Alternatives Considered**: What else was evaluated, with pros/cons?
- **Consequences**: Positive, negative, and neutral trade-offs

**Example ADRs that shaped the app**:

| ADR | Decision | Impact |
|-----|----------|--------|
| 0001 | Flutter/Dart single codebase | 5 platforms from 1 codebase |
| 0002 | Adapter pattern for email providers | Add providers without touching core |
| 0006 | Four progressive scan modes | Safety: never accidentally delete in dev |
| 0007 | Move-to-trash, not permanent delete | User trust and recoverability |
| 0023 | In-memory pattern caching | 100x performance improvement (2.1ms to 0.18ms) |
| 0035 | Dev/prod side-by-side builds | Run dev and production on same machine |

> **Talking point**: "The ADR-first approach was a lesson from Sprint 21. Design the ADR in one sprint, get review, implement in the next. Less rework, better results."

---

### Slide 20: Platform-Specific Adaptations

**One codebase, different behaviors per platform**:

| Capability | Windows | Android | macOS/Linux/iOS |
|-----------|---------|---------|-----------------|
| OAuth | Browser loopback redirect + PKCE | Native Google Sign-In | Browser-based (planned) |
| Background scan | Windows Task Scheduler | WorkManager (infra ready) | Planned |
| Notifications | PowerShell toast via WinRT | System notifications | Planned |
| System tray | Native tray icon + context menu | N/A | Planned |
| Storage | `AppData\Roaming\MyEmailSpamFilter\` | App-private `/data/` | Platform-specific paths |
| Navigation | Traditional nav (no bottom bar) | Bottom navigation bar | TBD |
| Packaging | MSIX (Windows Store) | APK/AAB | TBD |

**Handled via**:
- `AppPaths` abstraction (ADR-0012) for storage
- `Platform.isAndroid` / `Platform.isWindows` for UI behavior
- Platform-specific adapter implementations behind common interfaces

---

## SECTION 5: Agile/Scrum Process (3 slides)

### Slide 21: Sprint Methodology — Not "Write Me an App"

**7-Phase Sprint Execution Workflow**:

```
Phase 1: Pre-Sprint     -> Verify environment, restore context
Phase 2: Planning        -> Review backlog, select cards, define acceptance criteria
Phase 3: Plan Approval   -> I review and approve -> AUTONOMOUS EXECUTION AUTHORIZED
Phase 4: Execution       -> Claude works continuously, no per-task approval needed
Phase 5: Testing         -> Full test suite, lint, analyze
Phase 6: PR + Review     -> Create PR to develop (never main), I review
Phase 7: Retrospective   -> What worked, what did not, process improvements
```

**Key insight**: Phase 3 approval pre-authorizes ALL implementation decisions. This eliminated the biggest bottleneck: me approving every task. Sprint velocity doubled after Sprint 6 when this was formalized.

**Sprint cadence**: 25 sprints in ~2 months. Sprints ranged from 3 hours (focused research) to 20 hours (major refactoring).

---

### Slide 22: Model Tiering — Right Tool for the Job

**Not every task needs the biggest model.**

| Model | Complexity | Used For | Example Task |
|-------|-----------|----------|--------------|
| **Haiku** | Low | Bug fixes, tests, docs, single-file changes | "Add 15 unit tests for PatternCompiler" |
| **Sonnet** | Medium | Multi-file refactoring, architecture research | "Restructure Settings screen into tabbed layout" |
| **Opus** | High | Deep debugging, performance, critical path | "Split 5 monolithic rules into 3,291 individual rules" |

**Escalation path**: Haiku encounters blocker -> escalate to Sonnet -> escalate to Opus -> report to user

**Result**: Model assignment was 100% accurate across all sprints. Heuristic is simple:
- Touches 1 file? Haiku.
- Multiple files with design decisions? Sonnet.
- Would I lose sleep over a bug in it? Opus.

---

### Slide 23: Process Artifacts That Made It Work

**11 documents govern sprint execution** ([docs/](docs/)):

| Document | Purpose |
|----------|---------|
| `CLAUDE.md` | Project constitution — read first every session |
| `ALL_SPRINTS_MASTER_PLAN.md` | Backlog, priorities, feature details |
| `SPRINT_EXECUTION_WORKFLOW.md` | 7-phase checklist |
| `SPRINT_STOPPING_CRITERIA.md` | Exactly when to stop (9 criteria) |
| `TESTING_STRATEGY.md` | What to test, how, coverage expectations |
| `ARCHITECTURE.md` | System design reference |
| 36 ADRs | Every major decision documented |
| Per-sprint docs | Plan, retrospective, summary for each sprint |

**Why this matters**: Claude Code sessions are **stateless** — context resets between conversations. Documentation IS the memory. Each new session reads CLAUDE.md and picks up where the last one left off.

> **Talking point**: "This is the unsexy part. But it is the difference between 'Claude wrote some code' and 'Claude delivered 25 consecutive sprints.'"

---

### Slide 24: The Claude Code Instruction Stack

**CLAUDE.md — the project constitution (691 lines)**

Everything Claude needs to know, read automatically at session start:
- Project overview, repo structure, common commands
- Coding style (no contractions, no emojis, Logger not print)
- Development workflow (sprints, not phases)
- Branch policy (PRs to develop, never main)
- Co-lead developer philosophy
- Sprint autonomy rules (do not stop for per-task approval)
- Platform constraints (Windows primary, PowerShell, no jq/sed/awk)

**Custom Skills** (`.claude/skills/` — 9 skills):

| Skill | What It Does |
|-------|-------------|
| `/startup-check` | Verify environment, restore saved context — run FIRST every session |
| `/plan-sprint` | Analyze issues, generate task breakdown with model assignments |
| `/phase-check` | Sprint phase transition checkpoint |
| `/full-test` | Run all Flutter tests + analyze code quality |
| `/memory-save` | Save sprint context to file for next session |
| `/memory-restore` | Restore sprint context from saved memory |
| `/validate-rules` | Validate YAML rule files for syntax and regex errors |
| `/deploy-debug` | Build, install, and launch debug APK on emulator |
| `/first-principles` | Deconstruct problems to fundamentals when stuck |

> **Talking point**: "Skills are reusable prompts. `/startup-check` runs every session — it verifies git, GitHub CLI, and restores memory. Without it, every session starts from scratch."

---

### Slide 25: Memory, Commands, and Agents

**The Stateless Problem**: Claude Code has no memory between sessions. Every conversation starts fresh.

**Memory System** (`.claude/memory/`):
- `/memory-save` serializes current sprint context (active sprint, completed tasks, blockers, decisions made) to `current.md`
- `/memory-restore` loads it back at session start via `/startup-check`
- PowerShell scripts (`save-memory.ps1`, `check-memory-on-startup.ps1`) automate the process
- "Document for amnesia" — if it is not written down, it does not exist

**Slash Commands** (`.claude/commands/` — 5 commands):
- `/quick-commit` — Stage all changes, generate descriptive commit message
- `/commit-push-pr` — Full commit, push, and open PR workflow
- `/review-changes` — Review uncommitted changes and suggest improvements
- `/test-and-fix` — Run tests and automatically fix failures
- `/first-principles` — Break down problems when conventional approaches fail

**Agents** (`.claude/agents/` — 5 agents):
- `build-validator` — Verify builds pass on target platforms
- `code-architect` — Architectural analysis and recommendations
- `code-simplifier` — Review for reuse, quality, efficiency
- `oncall-guide` — Troubleshooting guidance
- `verify-app` — Application verification checks

**Cumulative investment**: These artifacts were built over 25 sprints. Each sprint added or refined instructions. By Sprint 25, a new Claude session can pick up any task with full context in under 2 minutes.

> **Talking point**: "This is the compounding return. Sprint 1 had just a CLAUDE.md. By Sprint 25, there is a full instruction stack — skills, memory, commands, agents, 11 process docs, 36 ADRs. Each session starts smarter than the last."

---

## SECTION 6: Team Roles (1 slide)

### Slide 26: Application and Team Roles

**Human Roles (Harold Kimmey)**:

| Role | Responsibility |
|------|---------------|
| Customer Representative | Real-world requirements, acceptance criteria from user perspective |
| Product Owner | Backlog priority, sprint scope approval, trade-off decisions |
| Chief Architect | Final architectural decisions, ADR approval |
| Chief Developer | PR approval, manual testing, merge-to-main authority |
| Scrum Master | Sprint ceremonies, timeline, scope discipline |
| Lead Test Engineer | Test strategy, exploratory testing, quality approval |

**Claude Code Team Roles**:

| Role | Model | Responsibility |
|------|-------|---------------|
| Lead Developer | Opus | Critical path features, deep debugging, performance |
| Senior Developers | Sonnet | Architecture, complex refactoring, multi-file changes |
| Developers | Haiku | Implementation, bug fixes, tests, documentation |
| Assistant Scrum Master | All | Sprint checklist execution, status tracking, docs |
| Architecture Dev Team | All | ADR research, gap analysis, design implementation |
| Senior Test Engineers | All | Unit/integration tests, test suite, failure analysis |

> **Talking point**: "I own the 'what' and 'why.' Claude owns the 'how.' Every role maps to a real Scrum role — this is not a novelty, it is a working team structure."

---

## SECTION 7: Closing (1 slide)

### Slide 27: Key Takeaways and Q&A

**What I learned in 25 sprints**:

1. **Write a good CLAUDE.md** — Single highest-leverage investment. It is the project constitution.
2. **Use sprints, not prompts** — "Build me X" produces demos. Sprints produce software.
3. **Document for amnesia** — Every session starts fresh. If it is not written down, it does not exist.
4. **Tests are non-negotiable** — Make it acceptance criteria. Claude will write them if required.
5. **The human is the bottleneck** — Autonomous execution post-approval doubled velocity.

**Questions I expect**:
- "How much code did YOU write?" -> ~5% me, 95% Claude. 100% of decisions were collaborative.
- "Would this work for a team?" -> Yes, with good CLAUDE.md and branch strategy.
- "What about other languages?" -> Claude Code is language-agnostic. Sprint methodology works for any stack.
- "Is the code good?" -> 0 analyzer warnings, adapter pattern, 1,178 tests, 36 ADRs. You tell me.

**GitHub**: github.com/kimmeyh/spamfilter-multi

---

## Presentation Notes

- **Total slides**: 27 (Title + 1 Intro + 2 Functionality + 12 Screenshots + 4 Architecture + 3 Agile + 2 Instruction Stack + 1 Roles + 1 Closing/Q&A)
- **Screenshots**: Capture from the running Windows app before the talk. Use the Demo Mode (55 synthetic emails) to populate realistic scan results without exposing real email data.
- **Live demo option**: Consider a 2-minute live demo scan using Demo Mode if time permits.
- **Timing guide**:
  - Intro + Functionality: 3-4 min
  - Screenshots walkthrough: 8-10 min (move quickly, ~45 sec per screen)
  - Architecture: 5-6 min
  - Agile/Scrum: 4-5 min
  - Instruction Stack (CLAUDE.md, Skills, Memory): 3-4 min
  - Roles + Closing: 2-3 min
  - Q&A: remaining time
- **For the developer audience**: They will care most about the ADR process, the architecture decisions, and the sprint methodology. Do not rush the architecture section.
- **Handout**: Consider sharing the "Key Takeaways" slide as a one-pager, plus a link to the repo.
