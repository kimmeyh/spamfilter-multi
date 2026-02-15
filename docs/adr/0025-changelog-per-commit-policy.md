# ADR-0025: CHANGELOG Updated Per Commit Policy

## Status

Accepted

## Date

~2026-01-24 (formalized at Sprint 1)

## Context

The spam filter project follows the [Keep a Changelog](https://keepachangelog.com/) convention for documenting user-facing changes. The key process question is: when should CHANGELOG.md be updated?

Options range from fully manual (update at release time) to fully automated (generate from git commits). The project uses a sprint-based GitFlow workflow (ADR-0015) where:

- Feature branches merge to `develop` (integration)
- `develop` merges to `main` (release)
- Multiple sprints may accumulate on `develop` before a release

The changelog needs to serve multiple audiences:
- **Users**: What changed in each release?
- **Developers**: What changed in each sprint/PR?
- **Reviewers**: What is included in this PR?

## Decision

Update CHANGELOG.md in the same commit as the code changes, not after PR merge or at release time.

### Format

```markdown
## [Unreleased]

### YYYY-MM-DD
- **feat**: Description of new feature (Issue #N)
- **fix**: Description of bug fix (Issue #N)
- **chore**: Maintenance or refactoring description
- **docs**: Documentation change description
- **test**: Test addition or update description
```

### Entry Types

| Type | Usage |
|------|-------|
| `feat` | New feature or enhancement |
| `fix` | Bug fix |
| `chore` | Maintenance, refactoring, dependencies |
| `docs` | Documentation-only changes |
| `test` | Adding or updating tests |

### Commit Strategy

CHANGELOG.md is staged with related code changes in a single commit:
```
git add mobile-app/lib/core/services/new_feature.dart CHANGELOG.md
git commit -m "feat: Add new feature (Issue #42)"
```

### GitFlow Integration

- **PRs to `develop`**: Entries stay in `[Unreleased]` section (these are integration builds)
- **PRs to `main`**: Entries are moved from `[Unreleased]` to a versioned section (these are production releases)

### Release Process

When `develop` is merged to `main`:
1. Move relevant `[Unreleased]` entries to a new version heading (`## [X.Y.Z] - YYYY-MM-DD`)
2. Follow [Semantic Versioning](https://semver.org/): MAJOR (breaking), MINOR (features), PATCH (fixes)
3. Add comparison links at the bottom of CHANGELOG.md
4. Leave `[Unreleased]` section empty for future entries

### Enforcement

Manual/process-based enforcement documented in CLAUDE.md. No pre-commit hook currently validates CHANGELOG.md updates. The convention is reinforced through:
- Sprint execution workflow documentation
- PR review process (reviewer checks for CHANGELOG entries)
- Claude Code instructions (CLAUDE.md specifies the policy)

## Alternatives Considered

### Auto-Generated from Commit Messages
- **Description**: Generate CHANGELOG entries automatically from git commit messages using tools like `conventional-changelog` or `auto-changelog`
- **Pros**: Zero manual effort; always in sync with commits; consistent format; no forgotten entries
- **Cons**: Commit messages are developer-focused ("fix null check in email_scanner.dart:145"), not user-focused ("Fix scan mode bypass that could delete emails in readonly mode"); not all commits are user-facing changes; requires strict commit message conventions; generated changelogs are often noisy and hard to scan
- **Why Rejected**: Commit messages serve a different purpose than changelog entries. Commits describe what changed in the code; changelog entries describe what changed for the user. Auto-generation conflates these audiences. Hand-written entries produce clearer, more useful changelogs

### Updated at PR Merge Only
- **Description**: Update CHANGELOG.md as part of the PR description or merge commit, not in individual development commits
- **Pros**: One changelog update per PR (not per commit); PR author can summarize all changes at once; cleaner commit history
- **Cons**: Easy to forget during merge (CHANGELOG update is a separate step from code review); PR description format differs from CHANGELOG format (requires translation); changes are not tracked in the same commit as the code they describe; harder to correlate changelog entries with specific code changes
- **Why Rejected**: Updating CHANGELOG in the same commit as code changes provides the strongest association between what changed and why. It also forces the developer to think about user-facing impact while writing the code, not as an afterthought during PR creation

### Release-Only Changelogs
- **Description**: Only update CHANGELOG.md when cutting a release (merging develop to main), summarizing all changes since the last release
- **Pros**: Simplest workflow; no changelog maintenance during sprints; single summary per release
- **Cons**: Requires reconstructing what changed from git history (tedious and error-prone); easy to miss changes; release process becomes heavier; cannot use CHANGELOG entries as PR descriptions during development
- **Why Rejected**: Reconstructing changes at release time is error-prone and time-consuming. During sprint work, the developer has the best context about what changed and why. Waiting until release time loses that context

### Separate CHANGES-PER-SPRINT Files
- **Description**: Each sprint maintains its own changes file (e.g., `changes/sprint-14.md`), consolidated into CHANGELOG.md at release
- **Pros**: Clean separation between sprint work and release notes; no merge conflicts on CHANGELOG.md (each sprint writes its own file); easy to see what each sprint contributed
- **Cons**: Additional files to maintain; consolidation step required at release; CHANGELOG.md is not incrementally updated; harder to get a unified view of all unreleased changes
- **Why Rejected**: The `[Unreleased]` section of CHANGELOG.md already serves as the consolidated view of all unreleased changes. Per-sprint files would add a consolidation step without clear benefit

## Consequences

### Positive
- **Developer context preserved**: The person making the change writes the changelog entry while the change is fresh in their mind, producing more accurate and user-friendly descriptions
- **Strong code-changelog association**: Each changelog entry lives in the same commit as the code it describes, making it easy to trace changes to their source
- **PR descriptions for free**: CHANGELOG entries serve as the basis for PR descriptions, reducing duplicate work
- **Always current**: The `[Unreleased]` section always reflects the current state of development, not a stale summary

### Negative
- **Manual discipline required**: Developers must remember to update CHANGELOG.md with each user-facing commit. There is no automated enforcement (no pre-commit hook)
- **Merge conflicts**: Multiple developers working on the same `[Unreleased]` section can create merge conflicts. This is mitigated by the sprint-based workflow where typically one feature branch is active at a time
- **Noise from non-user-facing changes**: Developers may include entries for internal changes (refactoring, test updates) that do not benefit end users, making the changelog harder to scan

### Neutral
- **Keep a Changelog format**: The project follows the Keep a Changelog convention, which is well-known but not universal. Some teams prefer different formats (e.g., GitHub release notes, conventional commits)

## References

- `CHANGELOG.md` - Active changelog following this policy
- `CLAUDE.md` - Changelog Policy section (lines 1076-1162): format, commit strategy, release process, best practices
- ADR-0015 (GitFlow Branching Strategy) - Branch workflow that determines when entries move from [Unreleased] to versioned sections
