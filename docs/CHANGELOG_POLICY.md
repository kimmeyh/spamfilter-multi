# Changelog Policy

This project follows [Keep a Changelog](https://keepachangelog.com/) conventions.

**Source**: Extracted from CLAUDE.md on 2026-05-18 (Sprint 38 retro IMP-A) to reduce CLAUDE.md size below 40K threshold while preserving full release-process detail here.

## Adding Entries (During Development)

**CHANGELOG.md** should be updated with each commit that introduces user-facing changes:

1. **When to Update**: Update CHANGELOG.md in the same commit as the code changes (not after PR merge)
2. **Format**: `- **type**: Description (Issue #N)` where type is:
   - `feat`: New feature or enhancement
   - `fix`: Bug fix
   - `chore`: Maintenance, refactoring, dependencies
   - `docs`: Documentation only changes
   - `test`: Adding or updating tests
3. **Location**: Add entries under `## [Unreleased]` section, grouped by date (newest first)
4. **Issue References**: Always include GitHub issue number when applicable
5. **Commit Together**: Stage CHANGELOG.md with the related code changes in a single commit

**Example Entry**:

```markdown
### 2026-01-12
- **feat**: Update Results screen to show folder - subject - rule format (Issue #47)
- **feat**: Add AOL Bulk/Bulk Email folder recognition as junk folders (Issue #48)
```

## Releasing (After PR Merge to main)

This project uses **GitFlow**: feature branches -> `develop` -> `main`

- **PRs to `develop`**: Entries stay in `[Unreleased]` - these are integration builds
- **PRs to `main`**: Move entries from `[Unreleased]` to a versioned release - these are production releases

When `develop` is merged to `main`, create a versioned release:

1. **Check for merged PRs to develop**: Review what is included since last release

   ```powershell
   # PRs merged to develop since a date
   gh pr list --state merged --base develop --json number,title,mergedAt

   # Commits on develop not yet on main
   git rev-list --count origin/main..origin/develop
   ```

2. **Create version section**: Move relevant `[Unreleased]` entries to a new version heading

   ```markdown
   ## [1.0.0] - 2026-01-12
   ### 2026-01-12
   - **feat**: Update Results screen format (Issue #47)
   ...

   ## [Unreleased]
   (empty or new entries since release)
   ```

3. **Version numbering**: Follow [Semantic Versioning](https://semver.org/)
   - **MAJOR**: Breaking changes or major milestones (Phase releases)
   - **MINOR**: New features (feat)
   - **PATCH**: Bug fixes (fix)
   - **[ENFORCEMENT MARKER, Harold 2026-08-07]**: this policy was documented from early on but not actually followed -- every release from `0.5.1` through `0.5.10` bumped only PATCH regardless of whether it contained `feat` entries (several did: F133/F134/F135/F136 among others). **Confirmed gap, decision made 2026-08-07 (Sprint 54 retro follow-up)**: start enforcing this policy from the NEXT release forward. Before choosing a release's target version, check the `[Unreleased]` entries being rolled in -- if ANY entry is `feat`, the release bumps MINOR (not PATCH); if the release also contains a breaking change or is a deliberate milestone, it bumps MAJOR instead. A release containing only `fix`/`chore`/`docs`/`test` entries still bumps PATCH. No renumbering of past `0.5.x` releases -- history stays as recorded.

4. **Update Version History**: Add summary to the `## Version History` section at bottom of CHANGELOG.md

5. **Link versions**: Add comparison links at bottom of CHANGELOG.md

   ```markdown
   [1.0.0]: https://github.com/kimmeyh/spamfilter-multi/compare/v0.9.0...v1.0.0
   [Unreleased]: https://github.com/kimmeyh/spamfilter-multi/compare/v1.0.0...HEAD
   ```

## Best Practices

- **Human-readable**: Write for users, not developers. Focus on "what changed" not "how"
- **Group by date**: Keep daily entries together for easy scanning
- **Do not delete**: Never remove entries; move them to versioned sections
- **PR description**: Use CHANGELOG entries as basis for PR descriptions
