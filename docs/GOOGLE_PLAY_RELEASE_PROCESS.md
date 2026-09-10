# Google Play Release Process

The repeatable procedure for shipping an update to Google Play. The Microsoft Store
equivalent is `docs/STORE_RELEASE_PROCESS.md`; one-time account and listing setup lives in
`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md` and is NOT repeated here.

**Why this document exists.** Sprint 66's Play submission was improvised end to end, and it
cost: the release-notes limit was discovered mid-write, the reviewer-instructions field's
500-character cap was found by hitting it, the join link's availability rules were guessed at
twice, and a false provider claim reached the console. Harold, 2026-09-09: *"we also will need
a defined process, which we can work through now before it is time critical."* That timing is
the point -- a process written under deadline is a process that encodes whatever shortcut was
taken that day.

---

## Precondition: is this release worth shipping to Play?

Play and the Microsoft Store are released INDEPENDENTLY (ADR-0043: one version across all
platforms, but a version may advance without being submitted everywhere). Ask before building:

- **Does the release fix something a tester or user will actually hit?** If the derived Play
  notes (Step 2) come out empty or trivial, that is the answer.
- **Is a closed test running?** During the 12-tester / 14-continuous-day window, weigh the fix
  against update churn. Harold's rule from Sprint 67: *"they are issues that users very likely
  will run into and would cause unnecessary feedback"* -- a defect that generates support
  noise outweighs the churn, a cosmetic one may not.
- **An update does NOT reset any tester's 14-day clock.** Opting OUT does. Shipping a fix mid
  test is safe; it is only the tester's continuous opt-in that matters.

---

## Step 1: Version verification, INCLUDING the build number

The semantic version is bumped at sprint-plan approval (F190, Phase 3.7.0b), so it is normally
already correct. **The build number is not, and this is the step that will reject an upload.**

```powershell
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
Select-String -Path pubspec.yaml -Pattern '^version:'
```

`version: 0.14.2+2` means semantic version `0.14.2`, **build number `2`**.

**Play's rule: `versionCode` must be strictly HIGHER than any bundle previously uploaded to
any track.** `android/app/build.gradle.kts:39` sets `versionCode = flutter.versionCode`, which
Flutter derives from the `+N` build number. So:

- **The `+N` must increase for EVERY Play upload**, even a rebuild of the same semantic
  version, even one that never reached production.
- Windows does NOT use it -- `msix_version` is `X.Y.Z.0` and ignores `+N` entirely. So bumping
  the build number alone is a Play-only change and cannot affect a Store package.
- A version code is consumed permanently once uploaded, whether or not that release was rolled
  out. Never reuse one.

**Found the hard way (Sprint 67, 2026-09-09)**: 0.14.1 shipped to the closed track as
`0.14.1+1` -> versionCode 1. The 0.14.2 bump left `+1` untouched, which would have produced
versionCode 1 again and been rejected at upload. F190 governs the SEMANTIC version and never
considered the build number.

Verify against what Play already has: Play Console -> Test and release -> App bundle explorer
lists every uploaded version code.

Then run the gates:

```powershell
flutter test test/policy/version_consistency_test.dart test/policy/dev_version_ahead_test.dart
```

## Step 2: Derive the Play release notes

Per ADR-0043 and `STORE_RELEASE_PROCESS.md` Step 1b, notes are DERIVED per store from one
`CHANGELOG.md`, covering everything since the last version **Play** received -- not since the
last version, because the two stores can sit at different points in the same sequence.

Produce `docs/store-assets/RELEASE_NOTES_<version>_play.md`.

**Hard limits, both learned by hitting them:**

- **500 characters per language.** MEASURE it, never estimate -- Sprint 66 estimated three
  times running and was wrong every time (claimed 486, then 523, actual 485).
- The field requires **`<en-US>` language tags** around the text. Their absence is a silent
  rejection at paste time.

```powershell
flutter test test/policy/release_notes_test.dart
```

That gate measures the count, asserts the tags exist, and fails if internal identifiers
(`F194`, `GP-4`, `issue #392`) leak into text a user reads.

**Write for a tester, not an engineer.** During a closed test the notes are also the only
channel for asking testers to do something -- "please keep the app installed for the full 14
days" belongs here.

## Step 3: Build the bundle

```powershell
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts
.\build-with-secrets.ps1 -BuildType release -Output aab
```

**Use the script. Do NOT hand-write `flutter build appbundle`.** A hand-written invocation
fails at `android/app/build.gradle.kts:70` with *"SEC-9: androidGmailClientId gradle property
is missing for a RELEASE build"*, because it drops the gradle properties the script injects
from `secrets.*.json`. That gate exists because F119 shipped a credential-less build to the
Microsoft Store. (Sprint 66 IMP-1.)

Output: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.

Unlike Windows, Play builds come from the DEV worktree -- there is no separate prod worktree
for Android, and the `prod` flavor is selected by the script's default.

## Step 4: VERIFY the bundle before uploading

Never infer from the build log. F119 shipped a credential-less package whose build log looked
correct.

**This block was a bash heredoc labelled `powershell` and would FAIL if pasted** (PR #403
review). PowerShell has no `<<'PY'`. Rewritten as a here-string, which is the PowerShell
equivalent -- note the closing `'@` MUST be at column 0.

```powershell
cd D:\Data\Harold\github\spamfilter-multi\mobile-app
@'
import zipfile, re
z = zipfile.ZipFile('build/app/outputs/bundle/prodRelease/app-prod-release.aab')
txt = z.read('base/manifest/AndroidManifest.xml').decode('utf-8', 'ignore')
print('versionName :', set(re.findall(r'0\.\d+\.\d+', txt)))
print('.dev suffix :', '.dev' in txt[:4000], '(must be False -- that is the DEV package)')
hits = set(re.findall(r'com\.googleusercontent\.apps\.[0-9A-Za-z\-]+', txt))
print('OAuth scheme:', 'PRESENT' if hits else '*** MISSING -- F119 failure mode ***')
'@ | Out-File -Encoding utf8 "$env:TEMPerify_aab.py"
python "$env:TEMPerify_aab.py"
```

Confirm: the version name matches, there is no `.dev` package suffix, and the OAuth redirect
scheme is present.

## Step 5: Upload and roll out

Play Console -> Test and release -> Testing -> **Closed testing** -> the track -> **Create new
release**.

1. Upload the `.aab`.
2. **Release name**: internal only, never shown to testers. `Closed testing <version>`.
3. **Release notes**: paste the `<en-US>`-tagged block from Step 2, tags included.
4. Review, then **Save** -- Save is what persists it; Next stays disabled until then (Sprint 66:
   this cost a round of confusion).
5. Roll out.

Then **Publishing overview -> Send changes for review**. Managed publishing is OFF, so approval
publishes immediately.

Certification is usually fast: Sprint 66's Submission 1 published **ten minutes** after
submission, against an expectation of days.

## Step 6: Verify it actually reached testers

**Published in the console is not the same as installable.** Verify:

- Play Console -> Closed testing -> the track shows the new version as latest.
- The opt-in link resolves: `https://play.google.com/apps/testing/com.myemailspamfilter`
- Best evidence: install the update on a real device and confirm the version in Settings.

Testers receive the update through Play like any other app update. No re-opt-in, and their
14-day clocks are unaffected.

## Step 7: Record it

Update `docs/STORE_VERSION_STATUS.md` -- it tracks BOTH stores, and Play rows must state the
track and the tester count, because production access depends on those and not on the version.

Also update `.claude/sprint_status.json` `store_release`.

**BUILT and VALIDATED is not SUBMITTED, and SUBMITTED is not LIVE.** Record what was actually
observed in the console, not what was intended (`project_release_055_pending_upload`).

---

## The closed-test clock, restated because it drives every timing decision

Quoted from Google's own requirements page
(https://support.google.com/googleplay/android-developer/answer/14151465):

> "At least 12 testers must be opted in to your closed test when you apply for production
> access, and they must have been opted in continuously for the preceding 14 days."

- Each tester accumulates their own 14 days from their OWN opt-in. Nobody's clock restarts
  because someone else joined later.
- **The application date is 14 days after the TWELFTH person opts in**, because that is the
  first moment twelve clocks have all reached 14. Testers 13+ are insurance and never push
  the date out.
- Opting out breaks that tester's streak; re-joining restarts them at zero. Recruit 15-16, not
  exactly 12.
- **Releasing an update does not affect any of this.**
