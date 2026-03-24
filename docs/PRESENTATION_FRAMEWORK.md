# GenAI Happy Hour Presentation: Building a Real App with Claude Code

**Audience**: Developers (Python, Go, TypeScript, C#/.NET)
**Format**: ~20-30 min talk + Q&A
**Tone**: Honest, practical, developer-to-developer

---

## Slide-by-Slide Outline

### Slide 1: Title

**"From Side Project to Windows Store: Building a Real App with Claude Code"**

- Harold Kimmey
- GenAI Happy Hour - [Date]
- Subtitle: "25 sprints, 1,178 tests, 0 regressions — what I learned using AI as a co-developer"

---

### Slide 2: The Problem

**I was drowning in spam.**

- Multiple email accounts (Gmail, AOL, Yahoo)
- Each provider has different spam filtering quality
- Had a working Python/Outlook desktop script — but it only worked on one machine, one provider
- Wanted: one app, all providers, all platforms, portable rules

> **Talking point**: "I had a working solution. But it was duct tape. I wanted a real app — and I wanted to see if Claude Code could help me build one."

---

### Slide 3: The Starting Point

**Legacy Python App (Outlook-only)**

- win32com automation talking to Outlook COM objects
- Hardcoded rules in Python dicts
- Windows-only, single account
- It worked... barely

**The Goal**: Cross-platform Flutter/Dart app with OAuth, IMAP, regex rules, background scanning

> **Talking point**: "I am not a Flutter developer. I had never written Dart. This is relevant."

---

### Slide 4: What Got Built (Demo or Screenshots)

**MyEmailSpamFilter — shipped to Windows Store**

- 5-platform Flutter app (Windows, Android, macOS, Linux, iOS)
- 4 email providers (Gmail OAuth, AOL, Yahoo, generic IMAP)
- 3,291 regex-based spam rules
- Background scanning with Windows Task Scheduler
- System tray, toast notifications, MSIX packaging
- Safe sender whitelist with pattern matching

> **Talking point**: Show 2-3 screenshots — the scan results screen, the rule manager, the settings screen. Keep it brief.

---

### Slide 5: By the Numbers

| Metric | Value |
|--------|-------|
| Timeline | ~2 months (Jan 19 - Mar 22, 2026) |
| Sprints | 25 completed |
| Tests | 1,178 passing |
| Production regressions | 0 |
| Analyzer warnings | 0 |
| Lines of test code | 12,037 |
| Individual rules | 3,291 |
| Windows Store | Submitted for certification |

> **Talking point**: "These numbers are real. Not cherry-picked. The zero regressions across 25 sprints is the one I am most proud of — and most surprised by."

---

### Slide 6: How I Used Claude Code — The Sprint Model

**Not "write me an app." Structured sprints.**

```
Phase 1: Pre-Sprint    → Review backlog, pick work items
Phase 2: Planning      → Define cards, acceptance criteria, model assignments
Phase 3: Plan Approval → I review, approve, then Claude executes autonomously
Phase 4: Execution     → Claude works continuously (no per-task approval)
Phase 5: Testing       → Run full suite, fix failures
Phase 6: PR + Review   → Create PR to develop branch
Phase 7: Retrospective → What worked, what did not
```

> **Talking point**: "The key insight was Phase 3. Once I approve the sprint plan, Claude has blanket authorization to make all implementation decisions. This eliminated the biggest bottleneck — me."

---

### Slide 7: Model Tiering — Right Tool for the Job

**Not every task needs the biggest model.**

| Model | Used For | Example |
|-------|----------|---------|
| Haiku | Bug fixes, tests, docs, single-file changes | "Add 15 unit tests for PatternCompiler" |
| Sonnet | Multi-file refactoring, architecture | "Restructure Settings screen into tabbed layout" |
| Opus | Deep debugging, performance, critical path | "Split 5 monolithic rules into 3,291 individual rules" |

> **Talking point**: "Model assignment was 100% accurate across all sprints. The heuristics are simple: if it touches one file, Haiku. Multiple files with design decisions, Sonnet. If I would lose sleep over a bug in it, Opus."

---

### Slide 8: What "Co-Lead Developer" Actually Means

**Division of labor, not delegation.**

| I Own | Claude Owns |
|-------|-------------|
| Product vision | Implementation details |
| Acceptance criteria | Test strategy and writing |
| Sprint approval | Architecture within constraints |
| "What" and "Why" | "How" |
| Final review | Documentation |

**Example**: Sprint 20 — I said "rules are too monolithic, we need individual rules." Claude designed the migration, split 5 rules into 3,291, removed the YAML dual-write layer, updated all tests. I reviewed and approved.

> **Talking point**: "Think of it like pair programming where your partner never gets tired, never forgets the test, and writes the docs without being asked."

---

### Slide 9: The Process Documentation Rabbit Hole

**11 documents govern sprint execution.**

- Master plan, planning methodology, execution workflow, stopping criteria, retrospective guide, testing strategy, quality standards, troubleshooting, performance benchmarks, architecture, changelog

**Why this matters**:
- Claude Code sessions are stateless — context resets between conversations
- Documentation IS the memory
- Each new session reads CLAUDE.md + sprint docs and picks up where the last one left off

> **Talking point**: "This is the unsexy part. But it is the difference between 'Claude wrote some code' and 'Claude delivered 25 consecutive sprints.' The docs are the institutional knowledge."

---

### Slide 10: What Worked Surprisingly Well

1. **Test-first development** — Claude writes tests alongside code, not after. 1,178 tests emerged naturally.

2. **Estimation accuracy** — Sprint 1 estimated 9-13 hours, delivered in ~4. Once I learned to calibrate, estimates were 30-40% of conservative.

3. **Zero regressions** — Not a single production bug across 25 sprints. The test suite catches everything.

4. **Learning a new framework** — I do not know Flutter/Dart. Claude does. I reviewed, asked questions, learned. The code is production quality.

5. **Autonomous execution** — After plan approval, Claude works continuously. No "should I use method A or B?" interruptions.

---

### Slide 11: What Did NOT Work (Honest Assessment)

1. **Early sprints had too much hand-holding** — I was approving every task. Sprint 6 fixed this with explicit autonomy rules.

2. **Context window limits are real** — Long sprints hit context limits. Had to build memory-save/restore skills.

3. **UI testing gap** — 28.9% coverage sounds low because UI screens have 0% coverage. Claude is great at logic tests, weak at widget tests.

4. **Not a replacement for domain expertise** — Claude does not know your email provider quirks. I had to debug OAuth flows, IMAP edge cases, Norton antivirus intercepting TLS. Domain knowledge is still yours.

5. **Process overhead is front-loaded** — Writing CLAUDE.md, sprint docs, and quality standards took real time. Pays off by sprint 3-4.

---

### Slide 12: Code Examples — Before and After

**Before (Python, Outlook COM)**:
```python
# Legacy: hardcoded, fragile, Windows-only
outlook = win32com.client.Dispatch("Outlook.Application")
inbox = outlook.GetNamespace("MAPI").GetDefaultFolder(6)
for msg in inbox.Items:
    if "viagra" in msg.Subject.lower():
        msg.Delete()
```

**After (Dart, cross-platform)**:
```dart
// Provider-agnostic, pattern-based, testable
final result = ruleEvaluator.evaluate(
  email: message,
  rules: ruleSet.rules,
  safeSenders: safeSenderList,
);
if (result.action == RuleAction.delete) {
  await emailProvider.moveToTrash(message.uid);
}
```

> **Talking point**: "Same problem. Completely different engineering quality. And I did not write the Dart — I reviewed it."

---

### Slide 13: Architecture That Emerged

```
UI Layer (Flutter widgets)
    |
State Management (Provider/ChangeNotifier)
    |
Core Services (RuleEvaluator, EmailScanner, PatternCompiler)
    |
Adapter Layer (GmailApiAdapter, GenericImapAdapter)
    |
Providers (Gmail OAuth, IMAP, generic)
```

- **Adapter pattern** — add a new email provider by implementing one interface
- **Database-first** — SQLite is source of truth, YAML is import/export
- **Scan modes** — readonly, testLimit, testAll, fullScan (progressive safety)

> **Talking point**: "This architecture was not designed upfront. It emerged through sprints. But because Claude follows patterns consistently, it is surprisingly clean."

---

### Slide 14: Practical Tips for Your Projects

1. **Write a good CLAUDE.md** — This is the single highest-leverage thing you can do. It is your project's constitution.

2. **Use sprints, not prompts** — "Build me X" produces demos. Sprints produce software.

3. **Trust but verify** — Approve the plan, let Claude execute, review the PR. Do not micromanage the implementation.

4. **Tests are non-negotiable** — Make it part of the acceptance criteria. Claude will write them if you require them.

5. **Document for amnesia** — Every session starts fresh. If it is not written down, it does not exist.

6. **Right-size the model** — Haiku for grunt work, Sonnet for architecture, Opus for the hard stuff. Your wallet will thank you.

7. **Own the domain** — Claude does not know your business. You bring the "what" and "why." Claude brings the "how."

---

### Slide 15: Q&A / Discussion Prompts

**Questions I expect**:
- "How much of the code did YOU write vs Claude?" → ~5% me, 95% Claude. But 100% of the decisions were collaborative.
- "Would this work for a team project?" → Yes, with good CLAUDE.md and branch strategy. PRs to develop, never main.
- "What about languages other than Dart?" → Claude Code is language-agnostic. The sprint methodology works for any stack.
- "Cost?" → Varies by sprint. Model tiering keeps it reasonable. Haiku is cheap for grunt work.
- "Is the code actually good?" → 0 analyzer warnings, adapter pattern, 1,178 tests. You tell me.

---

## Appendix: Supporting Materials

### Sprint Velocity Chart (for optional slide)

```
Sprint  1: ~4h   (database foundation)
Sprint 14: ~8h   (settings restructure + demo scan)
Sprint 15: ~16h  (batch operations, performance)
Sprint 18: ~6h   (13 bug fixes from user testing)
Sprint 20: ~20h  (major rule overhaul)
Sprint 22: ~3h   (Windows Store research)
Sprint 24: ~4h   (store assets + submission)
```

### Performance Wins (for optional slide)

- Pattern compiler cache: 2.1ms to 0.18ms (~100x speedup)
- Batch IMAP operations: 3N round-trips to ~3 total
- Progressive UI throttling: refresh every 10 emails OR 2 seconds

### The "Aha" Moment

Sprint 6 retrospective identified that per-task approval was the bottleneck. After implementing autonomous execution post-plan-approval, sprint velocity approximately doubled. The lesson: **the human was the slowest part of the system.**

---

## Presentation Notes

- **Length**: Aim for 20 slides max. Cut appendix slides unless Q&A needs them.
- **Screenshots**: Capture from the running Windows app before the talk.
- **Live demo**: Consider a 2-minute live demo of a scan if the app is installed.
- **Repo link**: Offer to share the repo (public GitHub) for people who want to see the CLAUDE.md and sprint docs.
- **Handout**: Consider sharing just the "Practical Tips" slide as a one-pager.
