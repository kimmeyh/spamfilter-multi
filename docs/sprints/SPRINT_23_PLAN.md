# Sprint 23 Plan

**Sprint**: Sprint 23 - Windows Store Readiness: MSIX, Signing, Domain, and Branding
**Date**: March 20, 2026
**Branch**: `feature/20260320_Sprint_23`
**Base**: `develop`
**Estimated Total Effort**: ~6-9h

---

## Sprint Goal

Complete the first wave of Windows Store readiness items: fix MSIX configuration, decide signing strategy, register the app domain, and finalize app icon/branding. This unblocks the privacy policy, store listing assets, and final submission in Sprint 24.

---

## Tasks

### Task A: WS-B1 - MSIX Config Fixes (Delegated)

**Estimated Effort**: ~1h
**Model**: Haiku (subagent)
**Execution**: Autonomous, delegated

**Deliverables**:
- Enable `store: true` in pubspec.yaml msix_config
- Fix logo path reference to point to correct asset
- Sync msix_version with pubspec version
- Verify MSIX build succeeds

**Acceptance Criteria**:
- [ ] pubspec.yaml msix_config has `store: true`
- [ ] Logo path points to valid asset file
- [ ] msix_version matches pubspec version
- [ ] `dart run msix:create` completes without errors (or documents if MSIX tooling not installed)

### Task B: WS-B3 - MSIX Signing Strategy ADR (Delegated)

**Estimated Effort**: ~2h
**Model**: Sonnet (subagent)
**Execution**: Autonomous, delegated

**Deliverables**:
- Research Microsoft Store signing options (auto-signing vs developer certificate)
- Draft ADR documenting the decision and rationale
- Consider CI/CD implications

**Acceptance Criteria**:
- [ ] ADR created in docs/adr/ with signing strategy decision
- [ ] Pros/cons of each approach documented
- [ ] Recommendation made with rationale
- [ ] CI/CD impact noted

### Task C: F29 - Register myemailspamfilter.com Domain (Collaborative)

**Estimated Effort**: ~1h
**Model**: Haiku (research) + User (registration)
**Execution**: Collaborative - Claude researches, user registers

**Deliverables**:
- Research domain registrar options (price, GitHub Pages DNS support)
- Present recommendations to user
- User registers domain
- Document DNS configuration for GitHub Pages

**Acceptance Criteria**:
- [ ] Domain registrar options researched and presented
- [ ] User registers myemailspamfilter.com (or chosen alternative)
- [ ] DNS configuration documented for GitHub Pages hosting

### Task D: F28 - App Icon and Branding Finalization (Collaborative)

**Estimated Effort**: ~2-4h
**Model**: Sonnet (design research) + User (approval)
**Execution**: Collaborative - iterate on design together

**Deliverables**:
- Finalize ADR-0031 (app icon and visual identity)
- Create Store-ready icon assets (300x300+ PNG for Microsoft Store)
- Create assets suitable for both Windows Store and future Google Play
- Document icon specifications and asset locations

**Acceptance Criteria**:
- [ ] ADR-0031 finalized with accepted icon design
- [ ] Icon assets created at required sizes (300x300+ PNG minimum)
- [ ] Assets stored in repository at documented location
- [ ] Icon works for Windows Store, Windows desktop, and future Android

---

## Execution Order

1. **Launch Tasks A and B** as background subagents (parallel, autonomous)
2. **Task C**: Research domain options, present to user, user registers
3. **Task D**: Collaborative icon/branding work while Tasks A/B complete
4. **Review**: Check subagent output from Tasks A and B

---

## Dependencies

```
Task A (WS-B1) ──┐
Task B (WS-B3) ──┤── no dependencies, parallel
Task C (F29)   ──┤── user action required
Task D (F28)   ──┘── collaborative

Sprint 24 unlocked by:
  WS-B4 (privacy policy) ← depends on Task C (domain)
  WS-I1 (store assets)   ← depends on Task D (icon)
  WS (submission)         ← depends on all
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| MSIX tooling not installed | Medium | Low | Document steps, defer build verification |
| Domain already taken | Low | Medium | Have alternative names ready |
| Icon design iteration takes long | Medium | Low | Start with simple professional design, iterate later |
| Signing ADR needs user input | Low | Low | Present options with clear recommendation |

**Risk Level**: Low (no code changes to core app, mostly config and documentation)
