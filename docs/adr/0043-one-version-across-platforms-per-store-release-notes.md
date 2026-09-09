# ADR-0043: One version across all platforms; release notes derived per store

**Status**: Accepted
**Date**: 2026-09-08
**Deciders**: Harold (Chief Architect / Product Owner)
**Sprint**: 67 (F196, Issue #395)

## Context

The app ships to two stores today (Microsoft Store, Google Play) and is
architecturally ready for a third (iOS). Two questions came up together during
the Sprint 66 release cycle, and they turn out to be the same question:

1. **Versioning.** Harold, 2026-09-08: *"if Production version is n.n.n and
   development includes changes... Example, Android publishes a fix to the
   background scan on Android (version now 0.14.2), then a bug to Microsoft
   Store (version now 0.14.3), then bug fix to Android (is it now 0.14.4 for
   both?)"*
2. **Release notes.** *"when providing new app updates... provide specific
   release notes content for each (Microsoft Store with release notes
   applicable for Microsoft Store version) and release notes as applicable for
   the Google Play Store."*

Sprint 66 made both concrete. Windows Submission 23 shipped 0.14.1 whose
`[Unreleased]` section contained ten entries, **nine of which were Google Play
work** meaningless to a Store customer -- the only user-facing Windows change
was the Gmail scope narrowing. In the same sprint, the Play closed-test release
notes were drafted from scratch against a 500-character limit discovered
mid-write, taking three re-measurements to fit.

Each store's users were being shown the other platform's changelog.

## Decision

### 1. One version number, advanced in lockstep, across every platform

There is ONE `version:` in `mobile-app/pubspec.yaml`. Every platform derives
from it. A version number identifies a state of the codebase, not a state of a
particular store.

In Harold's example the answer is: **0.14.5 for both**.

### 2. A version may advance without being submitted everywhere

Publishing is a separate decision from versioning. If 0.14.4 fixes an
Android-only defect, it can ship to Play while the Microsoft Store stays on
0.14.3 until something warrants a submission there.

Versions therefore form one sequence; stores simply sit at different points
along it. Stores are never *ahead* of each other on different numbers -- they
are at different positions in the same ordering.

### 3. Release notes are DERIVED per store, from one changelog

`CHANGELOG.md` remains the single engineering record. Each entry may carry a
platform tag (`[android]`, `[windows]`, `[internal]`; no tag means all
platforms) per `CHANGELOG_POLICY.md`.

At release time, `STORE_RELEASE_PROCESS.md` derives
`RELEASE_NOTES_<version>_windows.md` and `RELEASE_NOTES_<version>_play.md`,
each covering **every change since the last version THAT STORE received** --
not since the last version, because of decision 2.

## Consequences

### Accepted costs

**A store sometimes gets a version bump containing nothing for it.** Windows
0.14.1 is exactly that: a permissions reduction plus nine entries of Android
work. Users do not audit version numbers, and the release notes carry the
meaning, so this is a small price.

**The tag is one more thing to remember per entry.** Mitigated by making "no
tag" mean "all platforms", which is the common case -- the convention costs
nothing to ignore and only pays attention when a change genuinely is
platform-specific.

### What this buys

**A single source of truth.** Per-platform version numbers would mean either
two `version:` fields or a per-platform override, and `version_consistency_test`
already enforces that every literal in the repo matches the one field. Divergence
would mean strictly more machinery to maintain forever.

**Answerable support.** When a tester says "0.14.4 does the wrong thing", that
identifies exact code on any platform. With drift, the first question would
always be which store they installed from.

**Consistency with ADR-0042.** Cross-platform parity is the standing
architecture, with platform exceptions declared only where behaviour genuinely
cannot be shared. A version number is not a behaviour, so there is nothing to
except.

**Per-store notes are NOT a parity violation.** The notes differ by design
because the audience differs; the app's behaviour is identical. What must stay
identical is the underlying CLAIM -- a feature described to Play users must not
be described differently to Store users, and neither may describe something the
other platform lacks without saying so.

### iOS, when it arrives

Apple requires the version to increase for each submission and is stricter about
it than either current store. A single forward-only sequence satisfies that
naturally. No change to this decision is anticipated.

## Alternatives considered

**Per-platform version numbers.** Rejected: two sources of truth, a
`version_consistency_test` that would need per-platform awareness, and support
questions that always start with "which store?". The only benefit is avoiding an
occasional uninformative bump, which is not worth permanent machinery.

**One shared release-notes text for both stores.** Rejected as the status quo
that produced the problem. It forces either the union of all changes (Windows
users reading about Play declarations) or the intersection (nearly empty).

**Two separate changelogs.** Rejected: duplication drifts. The engineering
record must stay single, with store-facing text derived from it.

## References

- `docs/CHANGELOG_POLICY.md` -- the platform tag convention
- `docs/STORE_RELEASE_PROCESS.md` -- the derivation step
- ADR-0042 -- cross-platform parity and platform exceptions
- F190 (Sprint 66) -- the bump happens at sprint-plan approval, not at release
- Sprint 66 Submission 23 -- the worked example of the problem
