# Sprint 24 Plan

**Sprint**: Sprint 24 - Windows Store Readiness: Privacy Policy, Store Assets, and Submission
**Date**: March 20, 2026
**Branch**: `feature/20260320_Sprint_24`
**Base**: `develop`
**Estimated Total Effort**: ~9-16h

---

## Sprint Goal

Complete the remaining Windows Store readiness items: write and publish the privacy policy, create store listing assets, and submit the app to the Microsoft Store via Partner Center.

---

## Tasks

### Task A: WS-B4 - Privacy Policy (Delegated)

**Estimated Effort**: ~4-8h
**Model**: Sonnet (subagent)
**Execution**: Delegated, autonomous

**Deliverables**:
- Draft privacy policy based on ADR-0030 zero-telemetry design
- Create GitHub Pages site at myemailspamfilter.com/privacy
- Set up repository or gh-pages branch for hosting
- Configure custom domain in GitHub Pages settings

**Key Privacy Points (from ADR-0030)**:
- Email access is transient (read-only scanning, no storage of email content)
- Credential storage is encrypted (flutter_secure_storage)
- No analytics, no telemetry, no data sharing with third parties
- All data stored locally on device
- User-controlled data deletion (delete account removes all data)

**Acceptance Criteria**:
- [ ] Privacy policy written covering all data handling practices
- [ ] GitHub Pages site deployed at myemailspamfilter.com/privacy
- [ ] HTTPS enforced
- [ ] Policy URL accessible and loading correctly
- [ ] Policy content suitable for both Microsoft Store and future Google Play submission

### Task B: WS-I1 - Store Listing Assets (Collaborative)

**Estimated Effort**: ~3-4h
**Model**: Haiku + User
**Execution**: Collaborative

**Deliverables**:
- 4-5 screenshots of key app screens (Windows Desktop)
- App description (short and long)
- App icon at Store-required sizes (already generated in Sprint 23)
- Category and keywords

**Screenshots Needed**:
1. Select Email Provider screen (first impression)
2. Scan Results screen (core functionality)
3. Manage Rules screen (rule management)
4. Settings screen (configuration)
5. Email detail popup (optional, shows scan detail)

**Acceptance Criteria**:
- [ ] 4-5 screenshots captured from running Windows app
- [ ] Short description written (max 100 characters)
- [ ] Long description written (max 10,000 characters)
- [ ] Screenshots and descriptions stored in repository
- [ ] Content ready for Partner Center submission

### Task C: WS - Partner Center Account and First Submission (Collaborative)

**Estimated Effort**: ~2-4h
**Model**: Haiku + User
**Execution**: Collaborative (user registers, Claude guides)

**Deliverables**:
- Microsoft Partner Center developer account registered
- App name "MyEmailSpamFilter" reserved
- MSIX package built and submitted
- Store listing completed with assets from Task B
- Certification process initiated

**Acceptance Criteria**:
- [ ] Partner Center account registered
- [ ] App name reserved
- [ ] MSIX package uploaded
- [ ] Store listing complete (description, screenshots, privacy policy URL)
- [ ] Age rating questionnaire completed
- [ ] Submission sent for certification

---

## Execution Order

1. **Launch Task A** as background subagent (privacy policy, autonomous)
2. **Task B**: Collaborative - capture screenshots, write descriptions while Task A runs
3. **Task C**: After Tasks A and B complete - Partner Center setup and submission

---

## Dependencies

```
Task A (WS-B4) ──┐
Task B (WS-I1) ──┤── can run in parallel
                  v
Task C (WS)    ──── depends on A (privacy URL) and B (assets)
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GitHub Pages DNS not propagated | Low | Medium | DNS was configured in Sprint 23, should be ready |
| Partner Center account approval delay | Medium | Low | Registration is usually instant, verification may take days |
| MSIX certification failure | Medium | Medium | Fix issues and resubmit; first submission is a learning process |
| Privacy policy needs legal review | Low | Low | Template-based, zero-telemetry simplifies compliance |

**Risk Level**: Low-Medium
