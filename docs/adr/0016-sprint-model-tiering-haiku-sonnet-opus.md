# ADR-0016: Sprint-Based Development with Model Tiering (Haiku/Sonnet/Opus)

## Status

Accepted

## Date

~2026-01-24 (Sprint 1, formalized in SPRINT_PLANNING.md)

## Context

The spam filter project uses Claude Code (an AI coding assistant) as the primary implementation tool, with the user serving as co-lead developer and reviewer. Claude Code operates through different model tiers with varying capabilities and costs:

- **Haiku**: Fast, cost-efficient, good for straightforward tasks
- **Sonnet**: Balanced, capable of architectural reasoning and multi-file changes
- **Opus**: Most capable, best for deep debugging, security analysis, and systemic optimization

Sprint work consists of tasks ranging from simple bug fixes (change one line) to complex architectural refactoring (redesign multiple components). Assigning all tasks to Opus wastes resources on simple work; assigning all to Haiku risks quality on complex work.

The challenge is: how to systematically match task complexity to the right model tier, ensuring quality while minimizing cost and latency?

## Decision

Implement a complexity scoring system (0-40 points) that assigns each task to the appropriate model tier based on measurable factors:

### Scoring Dimensions

**File Impact**:
- 1 file modified: +10 points
- 2-3 files modified: +20 points
- 4+ files or architecture-wide: +30 points

**Cognitive Load**:
- Bug fix or simple addition: +5 points
- Refactoring or optimization: +15 points
- Design or architecture: +25 points

**Risk Factors** (additive):
- New external dependency: +15 points
- Security-related change: +20 points
- Core model/schema change: +20 points
- UI-only change: +5 points

### Tier Assignment Thresholds

| Score | Model | Work Distribution |
|-------|-------|-------------------|
| 0-15 | Haiku | ~70% of tasks |
| 16-25 | Sonnet | ~20-25% of tasks |
| 26+ | Opus | ~5-10% of tasks |

### Escalation Patterns

- **Haiku to Sonnet**: Architectural decision needed, cross-cutting concerns discovered, design rationale required
- **Sonnet to Opus**: Fundamental algorithmic challenge, systemic performance bottleneck, security vulnerability, Sonnet attempts fail after 2 iterations

### Confidence Scoring

Each task also receives a confidence score:
- **High (85%+)**: Similar pattern exists in codebase; clear requirements
- **Medium (60-84%)**: Requirements clear but implementation uncertain
- **Low (below 60%)**: Ambiguous requirements or novel implementation needed

## Alternatives Considered

### Single Model for All Tasks
- **Description**: Use Sonnet (or Opus) for every task regardless of complexity
- **Pros**: No scoring overhead; consistent quality; simpler workflow
- **Cons**: Opus is slower and more expensive for simple tasks (adding a test, fixing a typo); Haiku is faster for straightforward work; no cost optimization; underutilizes the model tiering capability
- **Why Rejected**: The 70/25/5 distribution means the majority of work is straightforward. Using Opus for a simple bug fix adds latency and cost without quality benefit

### Manual Developer Assignment (No Scoring)
- **Description**: The user or Claude manually decides which model to use for each task based on intuition
- **Pros**: Flexible; no formula to maintain; can account for context that scoring misses
- **Cons**: Inconsistent; depends on estimator's experience; no repeatable methodology; hard to learn from past assignments; no data for retrospective analysis
- **Why Rejected**: A scoring system provides repeatability and data. Sprint retrospectives can compare estimated vs. actual complexity and refine the scoring formula over time

### Two Tiers Only (Simple/Complex)
- **Description**: Binary assignment - Haiku for simple tasks, Opus for complex tasks (no Sonnet middle tier)
- **Pros**: Simpler decision; fewer thresholds; clear binary choice
- **Cons**: Many tasks fall in a middle ground where Haiku struggles but Opus is overkill; Sonnet is the right tool for multi-file refactoring, architectural decisions that are not deeply novel, and integration work
- **Why Rejected**: The three-tier system better matches the actual distribution of task complexity. Sonnet handles the substantial middle tier (architectural but not novel) that would be either under-served by Haiku or over-served by Opus

## Consequences

### Positive
- **Cost efficiency**: ~70% of tasks use the most cost-effective model (Haiku) without quality compromise
- **Quality matching**: Complex security and architecture tasks get the most capable model (Opus)
- **Repeatable methodology**: Scoring provides a consistent, documentable assignment process
- **Sprint planning efficiency**: Complexity scores inform sprint capacity planning (higher-score tasks take more time)
- **Retrospective data**: Actual vs. estimated complexity can be compared to refine scoring over time

### Negative
- **Scoring overhead**: Every task requires complexity assessment before assignment, adding planning time
- **Threshold sensitivity**: Tasks near boundaries (14-16 points, 24-26 points) may be assigned to the wrong tier; requires judgment calls
- **Model capability assumptions**: The scoring system assumes stable model capabilities; if Haiku improves significantly, thresholds need recalibration

### Neutral
- **Escalation is common**: Tasks frequently escalate from Haiku to Sonnet mid-implementation when unexpected complexity is discovered. This is expected and documented in the escalation patterns, not a failure of the scoring system

## References

- `docs/SPRINT_PLANNING.md` - Model tiering methodology (lines 348-469), complexity scoring (lines 425-450), escalation patterns (lines 456-469), worked example (lines 505-548)
- `docs/ALL_SPRINTS_MASTER_PLAN.md` - Model assignments per sprint
- `docs/SPRINT_EXECUTION_WORKFLOW.md` - Sprint execution phases
- ADR-0015 (GitFlow Branching Strategy) - Sprint workflow context
