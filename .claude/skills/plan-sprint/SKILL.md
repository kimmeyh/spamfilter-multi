# Plan Sprint Skill

Analyzes GitHub issues (Cards) and automatically generates task breakdowns with intelligent model assignments (Haiku → Sonnet → Opus).

## Command

```
/plan-sprint [issue-description or issue-number]
```

## What It Does

1. **Analyzes** the Card description to understand scope and complexity
2. **Breaks down** the Card into granular tasks
3. **Assigns models** based on complexity heuristics (Haiku/Sonnet/Opus)
4. **Calculates confidence** (High/Medium/Low) based on pattern matching
5. **Provides rationale** explaining each assignment decision
6. **Suggests labels** for consistent GitHub organization
7. **References learning** from prior similar tasks in heuristic database

## Usage Examples

### Example 1: Single Card Analysis

**Input**:
```
/plan-sprint Issue #45 - Add DKIM validation for all OAuth providers
```

**Context** (from GitHub issue):
```
Description: Implement DKIM header validation in RuleEvaluator, integrate with
all email adapters (Gmail, AOL, Yahoo), and add comprehensive test coverage.

Current: Emails are not validated for DKIM signatures, so spoofed emails appear legitimate.
```

**Output**:
```
📋 SPRINT CARD ANALYSIS

Card: Issue #45 - Add DKIM validation for all OAuth providers
Sprint: [Sprint field from issue]
Priority: High

Complexity Score: 18/40
- File impact: 2-3 files (+20)
- Cognitive load: "Integrate with adapters" (+5)
- Risk: Core email validation (-10 for moderate risk)

Task Breakdown:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task A: Implement DKIM validation logic in RuleEvaluator
├─ Model: 🟢 Haiku
├─ Complexity: Low
├─ Files: 1 (lib/core/services/rule_evaluator.dart)
├─ Time Est: 2-3 hours
└─ Rationale: Clear implementation following existing header validation pattern
              (similar to Issue #37 Gmail header parsing). Tests already exist for
              header matching. Well-defined scope.

Task B: Integrate DKIM check into all email adapters
├─ Model: 🟠 Sonnet
├─ Complexity: Medium
├─ Files: 3 (generic_imap_adapter.dart, gmail_api_adapter.dart, etc.)
├─ Time Est: 4-6 hours
└─ Rationale: Requires understanding each adapter's email header handling pattern.
              Multiple adapter implementations need coordination. Moderate risk of
              missing edge cases in specific email formats.

Task C: Create comprehensive test coverage for DKIM validation
├─ Model: 🟢 Haiku
├─ Complexity: Low
├─ Files: 1 (test/unit/rule_evaluator_test.dart)
├─ Time Est: 2-3 hours
└─ Rationale: Testing patterns well-established for RuleEvaluator. Can reuse existing
              mock email fixtures with DKIM headers.

Summary:
├─ Haiku: 2 tasks (Task A, Task C) - 4-6 hours
├─ Sonnet: 1 task (Task B) - 4-6 hours
├─ Total Estimated: 8-12 hours
└─ Confidence: HIGH (83%) - Similar to prior validation work (Issue #37)

Suggested GitHub Labels:
- sprint
- card
- phase:3.5
- priority:high
- category:security (DKIM is security-focused)

Next Steps:
1. Create GitHub issue using sprint_card.yml template
2. Copy task breakdown from above into "Model Assignment" section
3. Add sprint number (e.g., "Sprint 5")
4. Run Haiku on Task A first, then Sonnet on Task B, then Haiku on Task C
```

### Example 2: Quick Analysis

**Input**:
```
/plan-sprint Issue #52 - Fix off-by-one error in email counter
```

**Output** (abbreviated):
```
📋 QUICK ANALYSIS

Card: Issue #52 - Fix off-by-one error in email counter
Complexity Score: 5/40

Task: Debug and fix counter increment logic
├─ Model: 🟢 Haiku
├─ Files: 1 (email_scan_provider.dart)
├─ Complexity: Low
└─ Confidence: HIGH (92%) - Similar pattern fixed in Issue #48

Status: Ready for Haiku assignment
```

### Example 3: Sprint Backlog (Multiple Cards)

**Input**:
```
/plan-sprint sprint-backlog
Issue #45 - Add DKIM validation
Issue #48 - Optimize folder discovery
Issue #51 - Fix race condition in token refresh
```

**Output**:
```
📋 SPRINT BACKLOG ANALYSIS

Sprint: [Ask user which sprint]
Total Cards: 3
Estimated Total Effort: 18-28 hours

Detailed Analysis:

Card #45 - Add DKIM validation
├─ Score: 18/40 → Model Assignment: Haiku→Sonnet
├─ Confidence: High
└─ Est: 8-12 hours

Card #48 - Optimize folder discovery
├─ Score: 22/40 → Model Assignment: Sonnet
├─ Confidence: Medium (similar to #37 but new optimization angle)
└─ Est: 6-10 hours

Card #51 - Fix race condition in token refresh
├─ Score: 32/40 → Model Assignment: Sonnet→Opus
├─ Confidence: Medium (complex concurrency issue)
└─ Est: 4-6 hours

Summary by Model:
├─ Haiku: 1 task (Task A from #45) - 2-3 hours
├─ Sonnet: 3 tasks (Task B from #45, all of #48, #51) - 10-16 hours
├─ Opus: 1 task (escalation for #51 if needed) - 4-6 hours
└─ Total: 16-25 hours (realistic: 18-28 with integration/review)

Recommendation: This is a realistic 1-week sprint with focus on security (#45)
and performance (#48). #51 race condition is high-risk; escalate quickly if
Sonnet hits blockers.
```

## How It Works

### 1. Parsing Phase
Extracts:
- Card description
- Acceptance criteria
- Scope (files affected, components)
- Risk factors (security, core models, new dependencies)
- Keywords ("refactor", "optimize", "bug fix", etc.)

### 2. Complexity Scoring

**Scoring Matrix** (0-40 points):

| Factor | Points | Logic |
|--------|--------|-------|
| **File Impact** | | |
| 1 file | +10 | Single-file changes (Haiku zone) |
| 2-3 files | +20 | Multi-file coordination (Sonnet zone) |
| 4+ files or arch-wide | +30 | System-wide change (Opus likely) |
| **Cognitive Load** | | |
| "Bug fix" in description | +5 | Straightforward bug fixes |
| "Add" / "implement" | +5-10 | New feature at existing pattern |
| "Refactor" / "improve" | +15 | Requires design knowledge |
| "Optimize" algorithm | +15 | Performance tuning |
| "Design" / "architecture" | +25 | Architectural decision |
| **Risk Factors** | | |
| UI-only changes | +5 | Low risk |
| Core model changes | +20 | High risk (affects core business logic) |
| New dependencies | +15 | Integration risk |
| Security-related | +20 | Critical review needed |
| **Heuristic Match** | -5 to +5 | Adjust based on prior similar work |

### 3. Task Breakdown

Automatically breaks complex Cards into smaller tasks:

**Strategy**:
- Each task = 2-4 hour window (ideally complete within one focus session)
- Group related work (don't split tightly coupled changes)
- Front-load risky tasks (Sonnet reviews architecture first)
- Save tests for last (often can be done by different model)

**Example breakdown logic**:
```
If score ≤ 15 (Haiku territory):
  - Single task: "Implement [feature]"
  - Assign to Haiku

If score 16-25 (Sonnet zone):
  - Task 1: Core implementation (Sonnet for design)
  - Task 2: Integration (Sonnet or Haiku depending on complexity)
  - Task 3: Tests (often Haiku after design is proven)

If score > 25 (Opus likely):
  - Task 1: Design/architecture (Sonnet)
  - Task 2: Implementation (attempt Sonnet, escalate to Opus if blocked)
  - Task 3: Tests (Haiku)
```

### 4. Confidence Scoring

Checks heuristic database (`.claude/model_assignment_heuristics.json`) for prior similar tasks:

```
If similar pattern exists with success_rate > 0.85:
  Confidence = High (83-95%)
Else if similar pattern exists with success_rate 0.70-0.85:
  Confidence = Medium (60-82%)
Else if new or untested pattern:
  Confidence = Low (< 60%, manual review recommended)
```

### 5. Output Formatting

Generates structured output with:
- Clear task descriptions
- Model assignments with rationale
- Confidence scores
- Suggested GitHub labels
- Recommended execution sequence

## Implementation Details

### Heuristic Database

The skill reads from: `.claude/model_assignment_heuristics.json`

**Structure**:
```json
{
  "task_patterns": [
    {
      "pattern": "Add new widget to existing screen",
      "keywords": ["widget", "ui", "screen"],
      "recommended_model": "haiku",
      "success_rate": 0.95,
      "sample_size": 20
    }
  ],
  "escalation_triggers": [
    "Test failure after 2 attempts",
    "Architecture decision required"
  ]
}
```

### When Haiku Should Escalate

Haiku automatically escalates if:
- Description matches escalation trigger
- Task complexity score > 15 and task is multi-file
- Test failures indicate design issue (not implementation issue)
- Cross-cutting concerns detected (security, performance, architecture)

### When Sonnet Should Escalate to Opus

Sonnet escalates if:
- Score > 30 and hitting fundamental design blocker
- Performance profiling reveals systemic bottleneck
- Race conditions or concurrency issues
- Security vulnerability requiring deep analysis

## Workflow Integration

### During Sprint Planning

```
1. User proposes sprint goal and selects potential Cards
2. For each Card, user runs: /plan-sprint Issue #X
3. Skill generates task breakdown with model assignments
4. User reviews confidence scores and rationale
5. If confidence is Low, manually adjust or ask for clarification
6. Create GitHub issues with approved breakdowns
```

### During Sprint Execution

```
1. Haiku picks up assigned tasks
2. If Haiku hits escalation trigger:
   - Document blocker in GitHub comment
   - Post comment: /escalate-to-sonnet [reason]
3. Sonnet continues work, escalates to Opus if needed
4. Task status updates in issue comments
```

### During Sprint Review

```
1. Collect outcomes: Did assigned model succeed?
2. If escalation occurred: Document reason
3. Run: /update-heuristics with sprint data
4. Heuristic database is updated for future sprints
```

## Tips for Accurate Analysis

### For Better Model Assignments:

1. **Clear descriptions**: Detailed Card descriptions lead to better analysis
   - ✅ "Add DKIM header validation following Issue #37 pattern"
   - ❌ "Improve email security"

2. **Explicit acceptance criteria**: Help the skill understand scope
   - ✅ "Tests pass, all adapters support DKIM, 90% coverage"
   - ❌ "Works well"

3. **Reference similar work**: Link to prior issues for pattern matching
   - Example: "Similar pattern to Issue #37 Gmail header parsing"
   - Boosts confidence score automatically

4. **Flag new/uncertain work**: If trying something new, let skill know
   - ✅ "First time implementing pattern X - may need escalation"
   - Triggers Medium/Low confidence rating for manual review

### For Improving Heuristics Over Time:

1. **After each sprint**: Run `/update-heuristics` with outcomes
2. **Watch success rates**: When a pattern drops below 80%, review
3. **Track escalations**: Escalations are learning opportunities
4. **Adjust thresholds**: If too many Sonnet tasks are actually Haiku-ready, lower threshold

## Limitations & Mitigations

| Limitation | Mitigation |
|-----------|-----------|
| Cannot read private GitHub context (access tokens) | User provides Card description in command |
| Initial heuristics may be inaccurate | Start conservative (bias toward Sonnet), refine over 3-5 sprints |
| Ambiguous descriptions → poor assignments | Require clear acceptance criteria in Card template |
| New task types not in database | Low confidence rating triggers manual review |
| Human bias in heuristic updates | Use objective metrics (test results, time tracking) not opinions |

## See Also

- **docs/SPRINT_PLANNING.md** - Full sprint methodology
- **CLAUDE.md** - Quick reference
- **.claude/model_assignment_heuristics.json** - Heuristic database
- **`.github/ISSUE_TEMPLATE/sprint_card.yml`** - Issue template
