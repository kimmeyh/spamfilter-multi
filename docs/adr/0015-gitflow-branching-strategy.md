# ADR-0015: GitFlow Branching Strategy

## Status

Accepted

## Date

~2026-01-24 (formalized at Sprint 1, enforced from Sprint 2 onward)

## Context

The spam filter project uses a sprint-based development workflow where Claude Code (an AI coding assistant) implements features autonomously within approved sprint plans, and the user (project owner) reviews and approves changes. This collaborative model requires a branching strategy that:

- **Separates integration from release**: Sprint work should be integrated and tested before becoming a release candidate
- **Maintains user control over releases**: The project owner must approve what goes to the production/release branch
- **Supports parallel sprint work**: Multiple sprints or hotfixes may be in progress simultaneously
- **Provides clear PR targets**: Claude Code must know where to create pull requests without ambiguity
- **Enables rollback**: Individual sprints can be reverted without affecting other work

The project has two roles with different responsibilities:
- **Claude Code**: Implements features, creates feature branches, submits PRs
- **User**: Reviews PRs, approves merges, controls releases

## Decision

Implement a three-tier GitFlow branching hierarchy with role-based PR policies:

### Branch Hierarchy

```
main (release branch)
  |
  ↑ (user merges stable develop → main for releases)
  |
develop (integration branch)
  |
  ↑ (Claude creates PRs from feature branches → develop)
  |
feature/YYYYMMDD_Sprint_N[_optional_suffix]
```

### Branch Purposes

| Branch | Purpose | Who Creates PRs To It | Lifetime |
|--------|---------|----------------------|----------|
| `main` | Stable release branch; production-ready code | User only | Permanent |
| `develop` | Integration branch; all sprint work merges here | Claude Code | Permanent |
| `feature/*` | Sprint work in progress | N/A (created from develop) | Temporary (deleted after merge) |

### PR Policies

1. **Claude Code PRs**: Always target `develop`, never `main`
   - Source: `feature/YYYYMMDD_Sprint_N`
   - Target: `develop`
   - Created via: `gh pr create --base develop`

2. **User PRs**: Merge `develop` → `main` for releases
   - Only the user decides when `develop` is stable enough for a release
   - Typically after one or more sprints are integrated and tested

3. **Draft PRs**: Recommended at sprint start for early visibility
   - Created immediately after branch creation
   - User can track progress via PR commits
   - Marked ready for review at sprint completion

### Feature Branch Naming

Format: `feature/YYYYMMDD_Sprint_N[_optional_suffix]`

Examples:
- `feature/20260124_Sprint_2`
- `feature/20260124_Sprint_2_Rule_Migration`
- `feature/20260214_Sprint_15`

The date prefix ensures branches sort chronologically and avoids naming conflicts.

### Release Process

When the user decides to release:
1. Review all merged PRs on `develop` since last release
2. Create PR from `develop` → `main`
3. Move CHANGELOG entries from `[Unreleased]` to versioned section
4. Tag the release with semantic version (e.g., `v1.0.0`)

## Alternatives Considered

### Trunk-Based Development
- **Description**: All developers commit directly to `main` (or a single trunk branch), using feature flags and short-lived branches (< 1 day) for isolation
- **Pros**: Simpler workflow; faster integration; no long-lived branches; encourages continuous deployment; fewer merge conflicts
- **Cons**: No integration buffer between feature work and release; every commit to main is implicitly a release candidate; requires comprehensive CI/CD to catch issues before they reach main; feature flags add complexity; less suitable for sprint-based development where work spans multiple days
- **Why Rejected**: The project uses sprint-based development where feature branches last 1-7 days. Trunk-based development would merge incomplete sprint work directly to main, bypassing the user's release control. The `develop` branch provides a safe integration point where multiple sprints can be tested together before release

### GitHub Flow (Feature Branches → Main)
- **Description**: Feature branches created from `main` and merged back to `main` via pull request. No `develop` branch. `main` is always deployable
- **Pros**: Simpler than GitFlow (one fewer branch); widely adopted; `main` is always the latest code; less merge ceremony
- **Cons**: No separation between "integrated but untested" and "released". Every merged PR immediately becomes part of the release branch. The user would need to review and approve every PR immediately, as `main` is the only integration point. No buffer for accumulating sprint work before release
- **Why Rejected**: The project owner wants to control when code is promoted to the release branch. With GitHub Flow, merging a Claude Code PR to `main` immediately makes it a release candidate. The `develop` branch provides a holding area where multiple sprints can accumulate and be tested before the user promotes them to `main`

### Release Branches (Full GitFlow)
- **Description**: In addition to `main`, `develop`, and `feature/*`, create `release/*` branches for preparing each release (version bumping, final testing, release notes)
- **Pros**: Dedicated branch for release preparation; can stabilize a release while new development continues on develop; standard GitFlow pattern
- **Cons**: Additional branch management overhead; release preparation is lightweight for this project (version bump + CHANGELOG move); adds complexity without proportional benefit for a small team; more branches to track and clean up
- **Why Rejected**: The project's release process is simple: move CHANGELOG entries and tag. This does not justify a separate release branch. The `develop` → `main` merge is sufficient for the current release complexity. Release branches could be added later if the process grows more complex

## Consequences

### Positive
- **Clear release control**: The user has explicit control over what code reaches `main`. No surprise releases from automated merges
- **Safe integration**: Sprint work merges to `develop` first, where it can be tested alongside other sprints before promotion to `main`
- **Parallel sprint support**: Multiple feature branches can exist simultaneously, each targeting `develop`. Merge order does not affect `main`
- **Audit trail**: PR history on `develop` shows every sprint's changes. PR history on `main` shows every release
- **Rollback granularity**: Individual sprint PRs can be reverted on `develop` without affecting `main`

### Negative
- **Merge overhead**: Code travels through three branches (feature → develop → main), requiring two PR reviews. For urgent fixes, this adds latency
- **Develop branch maintenance**: `develop` must be kept in a mergeable state. If a sprint introduces breaking changes, subsequent sprints may need to resolve conflicts
- **Branch cleanup**: Feature branches must be deleted after merge to avoid clutter. This is documented but requires discipline

### Neutral
- **No CI/CD automation**: The project does not currently have GitHub Actions workflows for automated testing on PR. Build verification is manual (PowerShell scripts on the developer machine). This works for the current team size but would need automation as the team grows
- **Draft PR convention**: Creating draft PRs at sprint start is recommended but not enforced. Some sprints may not create PRs until completion

## References

- `CLAUDE.md` - PR Branch Policy section (defines the three-tier hierarchy and role-based policies)
- `docs/SPRINT_EXECUTION_WORKFLOW.md` - Phase 1.3: Branch creation (lines 156-162), Phase 1.3.1: Draft PR creation (lines 163-194), Phase 4.3: PR submission
- `docs/SPRINT_PLANNING.md` - Sprint methodology and feature branch naming conventions
- `CHANGELOG.md` - Changelog policy for `[Unreleased]` vs. versioned sections
