# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records for the spamfilter-multi project. ADRs capture significant architectural decisions along with their context, alternatives considered, and consequences.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-flutter-dart-single-codebase.md) | Flutter/Dart Single Codebase for All Platforms | Accepted | ~2025-10 |
| [0002](0002-adapter-pattern-email-providers.md) | Adapter Pattern for Email Providers | Accepted | ~2025-10 |
| [0003](0003-regex-only-pattern-matching.md) | Regex-Only Pattern Matching | Accepted | 2025-11-10 |
| [0004](0004-dual-write-sqlite-yaml.md) | Dual-Write Storage (SQLite + YAML Export) | Accepted | ~2026-01 |
| [0005](0005-safe-senders-evaluated-before-rules.md) | Safe Senders Evaluated Before Rules | Accepted | ~2025-10 |
| [0006](0006-four-progressive-scan-modes.md) | Four Progressive Scan Modes | Accepted | ~2025-10 |
| [0007](0007-move-to-trash-not-permanent-delete.md) | Move-to-Trash, Not Permanent Delete | Accepted | ~2026-02 |
| [0008](0008-platform-native-secure-credential-storage.md) | Platform-Native Secure Credential Storage | Accepted | ~2025-10 |
| [0009](0009-provider-pattern-state-management.md) | Provider Pattern for State Management | Accepted | ~2025-10 |
| [0010](0010-normalized-database-schema.md) | Normalized Database Schema (9 Tables) | Accepted | ~2026-01 |
| [0011](0011-desktop-oauth-loopback-redirect-pkce.md) | Desktop OAuth via Loopback Redirect with PKCE | Accepted | ~2025-10 |
| [0012](0012-apppaths-platform-storage-abstraction.md) | AppPaths Platform Storage Abstraction | Accepted | ~2025-10 |
| [0013](0013-per-account-settings-with-inheritance.md) | Per-Account Settings with Inheritance | Accepted | ~2026-01 |
| [0014](0014-windows-background-scanning-task-scheduler.md) | Windows Background Scanning via Task Scheduler | Accepted | ~2026-02 |
| [0015](0015-gitflow-branching-strategy.md) | GitFlow Branching Strategy | Accepted | ~2026-01 |
| [0016](0016-sprint-model-tiering-haiku-sonnet-opus.md) | Sprint Model Tiering (Haiku/Sonnet/Opus) | Accepted | ~2026-01 |
| [0017](0017-powershell-build-automation.md) | PowerShell as Primary Build and Automation Shell | Accepted | ~2025-10 |
| [0018](0018-windows-toast-notifications-powershell.md) | Windows Toast Notifications via PowerShell | Accepted | ~2026-02 |
| [0019](0019-windows-system-tray-integration.md) | Windows System Tray Integration | Accepted | ~2026-02 |
| [0020](0020-demo-mode-synthetic-emails.md) | Demo Mode with Synthetic Emails | Accepted | ~2025-10 |
| [0021](0021-yaml-to-database-one-time-migration.md) | YAML-to-Database One-Time Migration | Accepted | ~2026-01 |
| [0022](0022-throttled-ui-progress-updates.md) | Throttled UI Progress Updates | Accepted | ~2025-10 |
| [0023](0023-in-memory-pattern-caching.md) | In-Memory Pattern Caching | Accepted | ~2025-10 |
| [0024](0024-canonical-folder-mapping.md) | Canonical Folder Mapping | Accepted | ~2026-01 |
| [0025](0025-changelog-per-commit-policy.md) | CHANGELOG Updated Per Commit Policy | Accepted | ~2026-01 |
| [0026](0026-application-identity-and-package-naming.md) | Application Identity and Package Naming | Proposed | 2026-02-15 |
| [0027](0027-android-release-signing-strategy.md) | Android Release Signing Strategy | Proposed | 2026-02-15 |
| [0028](0028-android-permission-strategy.md) | Android Permission Strategy | Proposed | 2026-02-15 |
| [0029](0029-gmail-api-scope-and-verification-strategy.md) | Gmail API Scope and Verification Strategy | Proposed | 2026-02-15 |
| [0030](0030-privacy-and-data-governance-strategy.md) | Privacy and Data Governance Strategy | Proposed | 2026-02-15 |
| [0031](0031-app-icon-and-visual-identity.md) | App Icon and Visual Identity | Proposed | 2026-02-15 |
| [0032](0032-user-data-deletion-strategy.md) | User Data Deletion Strategy | Proposed | 2026-02-15 |
| [0033](0033-analytics-and-crash-reporting-strategy.md) | Analytics and Crash Reporting Strategy | Proposed | 2026-02-15 |
| [0034](0034-gmail-access-method-for-production.md) | Gmail Access Method for Production | Proposed | 2026-02-15 |

## Creating a New ADR

1. Copy the template below into a new file named `NNNN-short-title.md`
2. Fill in all sections
3. Add an entry to the index table above
4. Commit with the related code changes (if any)

## Template

```markdown
# ADR-NNNN: [Title]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-NNNN]

## Date

[YYYY-MM-DD when the decision was made, or best estimate with ~ prefix]

## Context

[What problem or need motivated this decision? What forces, constraints,
and requirements were in play? Include relevant project history.]

## Decision

[What was decided? State the decision clearly and concisely.]

## Alternatives Considered

### [Alternative 1 Name]
- **Description**: [What this alternative would look like]
- **Pros**: [Benefits]
- **Cons**: [Drawbacks]
- **Why Rejected**: [Specific reason it was not chosen]

### [Alternative 2 Name]
(same structure)

## Consequences

### Positive
- [What becomes easier, better, or possible]

### Negative
- [What becomes harder, more complex, or limited]

### Neutral
- [Trade-offs that are neither clearly positive nor negative]

## References
- [Links to issues, PRs, docs, code files, external resources]
```

## Conventions

- **Numbering**: Sequential 4-digit numbers (0001, 0002, ...)
- **File naming**: `NNNN-short-title.md` using lowercase and hyphens
- **Status lifecycle**: Proposed -> Accepted -> (optionally) Deprecated or Superseded
- **Immutability**: Once accepted, ADRs are not modified. If a decision changes, create a new ADR that supersedes the old one and update the old ADR status to "Superseded by ADR-NNNN"
- **Date format**: Use exact dates when known, prefix with `~` for approximate dates
