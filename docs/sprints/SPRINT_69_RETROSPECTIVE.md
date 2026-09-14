# Sprint 69 Retrospective

**Sprint**: 69 -- Android tester experience
**Dates**: 2026-09-11 to 2026-09-13
**Scope**: F211 + F210 + F208 + F209 + F203 (5 tasks, all delivered)
**Branch**: `feature/20260910_Sprint_69` | **PR**: #410 (draft)
**Version**: 0.15.0 -> 0.15.1+4

## Outcome

| | |
|---|---|
| Tasks delivered | 5 of 5 |
| Test suite | 2,074 -> **2,118** passed, 15 skipped, **0 failed** |
| Policy gates | 109 -> **113** |
| Analyzer | clean |
| Code-review findings | 7 found, 7 addressed, 0 deferred |
| F-PRECHECK findings | 2 found, 2 fixed |
| New backlog items filed | 6 (F212-F217) |

**Manual Validation**: Windows complete. F210 7 of 9 cells good, 2 untestable now and carried
forward. F203 good. Windows no-regression good. F208 and F209 deferred to the next Play release
by Harold's decision, since both need a Play-installed build.

---

## Sprint 69 Retrospective Feedback

### 1. Effective while as Efficient as Reasonably Possible

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Five tasks landed inside the 6-10h target, and the audit-first
  check earned its place: it turned F210 from "one instance" into four before any code was
  written, and showed F209 was the app-wide default rather than a few missed screens. The
  inefficiency worth naming is the F211 console work. I concluded "console-only, one setting"
  from reading the code that consumes the client id, never opened the console, and it took three
  rounds with Harold to discover the package name and fingerprint were also wrong. That was not
  slow work; it was work aimed at the wrong target, and Harold's screenshots did the finding.

### 2. Testing Approach

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Every new test was mutation-verified before being trusted, and
  the verification repaid itself twice. The F210 gate mutation proved it caught the exact defect;
  the F203 mutation proved skips could not be laundered into `processedCount`. The gap is that my
  own gates were the least reliable code in the sprint: code review found the F210 detector
  passing vacuously on the commonest layout in the codebase, and the same flaw in the F197 gate I
  shipped in Sprint 68. A gate that is green because nothing matches looks identical to one that
  is green because nothing is wrong.

### 3. Effort Accuracy

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The estimate held for the five tasks. What the estimate did not
  carry was the review-and-rework tail: the F209 re-implementation after code review was
  effectively a second delivery of the same task, and the F211 console diagnosis consumed more
  wall-clock than its 30-60m card suggested because the card assumed the answer. Neither is an
  estimation error exactly -- both are work the plan did not know existed -- but a sprint that
  budgets only for first attempts will keep overrunning at the same place.

### 4. Planning Quality

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The audit-first check is the strongest part of this process and
  it changed four of five cards before approval. Recording the two dropped carry-ins (F202, F192)
  meant the scope change was visible rather than silent. Where planning fell short was F211's R-1:
  I wrote a determination that read as settled ("CONSOLE-ONLY. No repo change required") on
  evidence that only supported half of it. A plan that states a conclusion more confidently than
  its evidence warrants is worse than one that says "unknown, resolve first".

### 5. Model Assignments

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: All five tasks ran on the session model rather than their
  assigned tiers, which the plan anticipated and recorded once rather than as five deviations
  (Sprint 68 IMP-4). That convention works and should stay. Worth noting for the record: the
  cheapest-first ladder assigned Sonnet to every task, and the code review found three critical
  defects in that work -- so the assignment was not obviously wrong, but the review was what
  caught them, not the tier.

### 6. Communication

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold corrected me twice on how information reaches him, and
  both corrections were fair. "The plan from earlier" made him hunt through 50 screens of build
  logs for a checklist I could have restated in ten lines; that is now a rule in CLAUDE.md and in
  Phase 5.3. He also had to ask where screenshots were being kept, and my answer -- "nowhere" --
  was wrong, which he caught by asking whether they were in the scratchpad. Two corrections in one
  sprint about the usability of what I hand him is a pattern, not two incidents.

### 7. Requirements Clarity

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Harold's ADR-0042 constraint was restated verbatim at scope
  selection and applied per task in the plan, which made F208's and F209's platform exceptions
  deliberate rather than discovered. His two answers on the font-size question ("1. a", "2. a")
  resolved a genuine ambiguity I could not have settled from the code, because the list row uses
  two different sizes and "match the scan results page" had two defensible readings. Asking was
  correct there.

### 8. Documentation

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: `OAUTH_SETUP.md` went from a one-setting note to a full
  Android OAuth client reference with all three fingerprints recorded and the upload-key trap
  named explicitly -- that page will save the next person hours. The validation-screenshot folder
  and its tracked INDEX close a real gap. Against that: the R-1 determination had to be corrected
  after being committed, and the fingerprint table had to be corrected after being committed,
  because I recorded conclusions before verifying them.

### 9. Process Issues

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The F193 evidence gate blocked me twice and was right both
  times -- once because the Phase 5.1 pre-checks genuinely had not run, and once because I had
  written the evidence as prose headings rather than the bullet markers the gate reads. The second
  block is worth keeping in mind: the gate deliberately rejects prose that merely mentions
  "5.1.1", and my headings were exactly that. The hooks did their job this sprint; the mutation
  lock, the card/PR gate and the auto-advance gate all fired correctly.

### 10. Risk Management

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The F209 re-implementation is the sprint's best risk outcome.
  Code review caught that my first version would have re-broken the F178 action popup -- a fix
  Harold found by screenshot in Sprint 62 -- and would have pushed every keyboard screen 48 pixels
  too high. Both were verified by probe before I accepted them, and the rewrite was verified the
  same way. Running the review BEFORE Manual Validation, which the F193 gate forced, is what kept
  those off Harold's phone.

### 11. Next Sprint Readiness

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: The slate is unusually well-evidenced: six items filed this
  sprint (F212-F217), five of them from Harold or his tester using the app on real hardware, and
  F217 corroborated by a screenshot rather than by recollection. F217 is the one that should
  shape the next sprint -- background scanning not running while the phone is locked undermines
  the app's core value on Android, and it also means every closed-test observation so far may
  reflect scans that ran on app-open rather than on schedule.

### 12. Architecture Maintenance

- **Product Owner**: Very Good
- **Scrum Master**: Very Good
- **Lead Developer**: Very Good
- **Claude Code Development Team**: Both new platform exceptions are declared in code with what
  cannot be shared and why (F208's picker filter, F209's inset handling), and F208 resolved toward
  REMOVING the platform difference rather than encoding it, which is the better outcome under
  ADR-0042. One architectural record is now known to be wrong: the Doze caveat at
  `background_scan_scheduler.dart:188` says inexact timing is an "accepted difference" because
  "the scan is periodic hygiene, not a deadline." F217's evidence shows hours of deferral, not
  minutes. That declaration needs rewriting once the real behaviour is understood.

### 13. Minor function updates that need to be added to the next sprint plan

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: none. Two validation cells carry forward (F210's sign-in
  failure details and the Gmail manual token warning, both needing a real sign-in failure to
  provoke), and F208/F209 validation carries to the next Play release. These are carried
  VALIDATION items, not carried development work.

### 14. Function updates that can be added to the backlog for a future sprint

- **Product Owner**: *"Noted several times today and yesterday on the Android app that background
  tasks did not run when I was not actively looking at the app (meaning that when the app was in
  the background and not the focus or the phone was 'locked' the background tasks did not run),
  and no notifications. As soon as I switched to the app, went to the Scan History and did a
  refresh, both the aol and gmail background tasks would be running and incomplete). I would
  refresh until both completed and then would immediately get the notification. It does not appear
  to be running every 15 minutes in the background, regardless of screen focus or phone locked.
  Download pictures from attached phone from today"*
- **Scrum Master**: As above.
- **Lead Developer**: As above.
- **Claude Code Development Team**: Filed as **F217 at Priority 6** and corroborated from the
  evidence rather than taken on report: `Screenshot_20260913_202951.png` shows AOL background scans
  at **5:15 PM and 7:57 PM -- 2h42m apart, not 15 minutes** -- and both accounts firing at the same
  minute, which is the signature of Android batching deferred work rather than two independent
  timers. The scheduling code is correct (`registerPeriodicTask`, 15 minutes, per-account unique
  names), so the leading hypothesis is Doze and App Standby, supported by the manifest declaring no
  battery-related permission at all. The fix is a Class-1 decision -- a battery-optimisation
  exemption prompt or a foreground service -- and is surfaced, not chosen. 9 screenshots pulled
  from the phone as requested.

  Also filed this sprint from Harold and his tester: **F213** (Custom URI schemes are Google's
  legacy path), **F214** (slider margins, from the tester), **F215** (wire the screenshot folder
  into every process), **F216** (supporting text smaller than the text it should match, three
  screens, expanded at Harold's direction).

### Questions to be discussed before ending the sprint

- **Product Owner**: none
- **Scrum Master**: none
- **Lead Developer**: none
- **Claude Code Development Team**: none blocking. Two dependencies stay open by design: the F211
  console changes (package name and SHA-1) and the Android validation of F208/F209, both of which
  need Harold or a Play release rather than sprint work.
