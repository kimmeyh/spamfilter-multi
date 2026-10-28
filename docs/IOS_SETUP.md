# iOS Setup (F67a, Sprint 81 Task 1)

Three console jobs that only Harold can do. Each one unblocks Task 2 (F304, the signed iOS build on a GitHub
`macos-26` runner) and the first TestFlight install on Harold's iPhone (iOS 27.1).

Do them in this order. Part A has the longest wait (Apple reviews the enrollment), so start it first.

**Claim status.** Each external claim below is marked:
- **VERIFIED**: read on the vendor's own page, with the read date.
- **UNVERIFIED**: from general knowledge, not read on the vendor page in this sprint. The screen you see wins.
  When a screen differs from this guide, note the difference in "Results" at the end, as `GOOGLE_PLAY_ACCOUNT_SETUP.md`
  did ("Signup walkthrough deviations").

**Never commit** the `.p8` key file, the key contents, a certificate, a provisioning profile, or a client secret. The
client IDs are not secrets in the strict sense (they ship inside the app), but this repo keeps every client ID out of
the tree and injects it at build time, the same as Windows and Android.

## Part A -- Apple Developer Program, Individual (Harold Q1 = 1, 2026-10-23)

Decision: enroll as an **Individual**, the same account type as Microsoft and Google Play (`LEGAL_ENTITY.md`,
"Account type: CLOSED").

Facts:
- **VERIFIED** (developer.apple.com/help/account/membership/D-U-N-S/, read 2026-10-23): *"If you're enrolling as an
  individual, you don't need a D-U-N-S Number."*
- **VERIFIED** (developer.apple.com/programs/enroll/ and /help/account/membership/program-enrollment/, read
  2026-10-28): the fee is 99 USD per membership year. The Apple Account needs two-factor authentication on, and its
  first and last name must be your legal name (an alias or nickname delays approval). *"Your name will be displayed
  as the seller name of your apps on the App Store."* P.O. boxes are not accepted. On the web, an Individual must pay
  with their own credit card, or Apple asks for a government photo ID.
- **VERIFIED** (developer.apple.com/help/account/membership/enrolling-in-the-app/, read 2026-10-28): the Apple
  Developer app path needs an iPhone with Face ID, Touch ID or a passcode, iCloud signed in, and the same device for
  the whole enrollment. It asks for a photo of a passport or driver's license, then Individual, then the License
  Agreement, then an auto-renewing subscription paid from the Apple Account (gift-card balance not accepted).
- **VERIFIED** (program-enrollment page): no membership confirmation within 24 hours of purchase means contact
  Apple Developer Support with your Enrollment ID.
- **UNVERIFIED**: how long Apple's review takes; the pages give no time.

Steps:
1. Choose the Apple Account. Recommended: the same dedicated address as Play (`myemailspamfilter.dev@gmail.com`),
   so the store accounts stay together and off your personal address. Turn on two-factor authentication.
2. On an iPhone, you can enroll through the **Apple Developer** app (UNVERIFIED that this path is still offered for
   Individuals). On the PC, go to `https://developer.apple.com/programs/enroll/` and select **Start your
   enrollment**.
3. Select **Individual / Sole Proprietor** as the entity type (UNVERIFIED label text).
4. Enter your legal name and address as on your ID. Pay the fee.
5. Wait for the approval email. Record the enrollment date and the approval date in "Results".
6. After approval, open `https://developer.apple.com/account` and select **Membership details**. Record the
   **Team ID** (10 characters). Task 2 needs it. The Team ID is an identifier, not a secret.

## Part B -- iOS OAuth client in Google Cloud Console

The Gmail sign-in on iPhone needs its own OAuth client of type **iOS** (ADR-0050: `gmailOAuthClient` = `ios`; Google
requires an iOS client type for iOS, and the loopback redirect Windows uses is not available for iOS clients). Use the
same Google Cloud project as the Android and Windows clients, so the consent screen and its Test users are shared.

Steps:
1. Open `https://console.cloud.google.com/` and select the project that holds the Android client.
2. Go to **APIs & Services > Credentials** (or **Google Auth Platform > Clients**, which newer consoles show
   instead; UNVERIFIED which one your console shows).
3. Select **Create credentials > OAuth client ID** (or **Create client**).
4. Application type: **iOS**.
5. Name: `MyEmailSpamFilter iOS`.
6. Bundle ID: `com.myemailspamfilter` (exactly this; it is set in `mobile-app/ios/Runner.xcodeproj/project.pbxproj`
   and mirrors the Android applicationId, ADR-0026).
7. Leave App Store ID empty (the app has no App Store ID yet). Enter the **Team ID** from Part A step 6 if the form
   asks for it.
8. Select **Create**. The console shows the **Client ID** (ends in `.apps.googleusercontent.com`) and the **iOS URL
   scheme** (the reversed client ID, starts with `com.googleusercontent.apps.`). Keep both for Part D.
9. Record in "Results": the client was created, the date, and the verification status the console shows for the
   restricted Gmail scope. Do NOT paste the client ID into this file.

Notes:
- The consent screen stays in **Testing** (ADR-0029 Phase 1; Sprint 81 Q1 = 1). Every tester's Gmail sign-in expires
  after 7 days. This applies on iPhone exactly as on Android and Windows.
- App Review cannot add itself as a Gmail test user. The App Store reviewer signs in with an IMAP demo account
  instead (F67d, Sprint 83).

## Part C -- App Store Connect API key (for the GitHub runner)

The runner signs and uploads with an App Store Connect API key, so no one has to sign in to Xcode on a Mac.

Steps (after Part A is approved):
1. Open `https://appstoreconnect.apple.com/` and sign in with the Part A Apple Account.
2. Go to **Users and Access > Integrations > App Store Connect API** (UNVERIFIED menu path; older consoles show a
   **Keys** tab under Users and Access).
3. If asked, select **Request Access** and accept the terms (UNVERIFIED that an Individual account must do this).
4. Under **Team Keys**, select **Generate API Key** (or the **+** button).
5. Name: `GitHub iOS build`. Access: **App Manager** (UNVERIFIED that App Manager is enough for automatic signing
   with `-allowProvisioningUpdates`; if the first Task 2 run fails on a permission error, the fix is **Admin**).
6. Record the **Key ID** and the **Issuer ID** shown on that page.
7. Select **Download API Key**. The file is `AuthKey_<KeyID>.p8`. **Apple lets you download it only once**
   (UNVERIFIED wording; widely documented). Save it outside the repo, for example in your tax-and-entity records
   folder, never under `D:\Data\Harold\github\`.

## Part D -- GitHub repository secrets (Task 2 reads these names)

Enter these on GitHub: **kimmeyh/spamfilter-multi > Settings > Secrets and variables > Actions > New repository
secret**. Claude never sees the values.

- `APPLE_TEAM_ID`: the Team ID from Part A step 6.
- `ASC_KEY_ID`: the Key ID from Part C step 6.
- `ASC_ISSUER_ID`: the Issuer ID from Part C step 6.
- `ASC_KEY_P8`: the full text of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and
  `-----END PRIVATE KEY-----` lines.
- `IOS_GMAIL_CLIENT_ID`: the Client ID from Part B step 8.
- `IOS_GMAIL_REVERSED_CLIENT_ID`: the iOS URL scheme from Part B step 8.

The `.p8` text is easiest to set from PowerShell with the GitHub CLI (one line, run in the folder that holds the
file; replace the file name):

```
Get-Content .\AuthKey_ABC123.p8 -Raw | gh secret set ASC_KEY_P8
```

**F127 note.** The CI secrets for `ci.yml` stay deliberately unset (F127, 2026-07-24). These six secrets are read only
by `.github/workflows/ios.yml`, because a TestFlight build is a shipped artifact that needs a real client ID and
signing. `ci.yml` does not read them.

## Results (filled in as each part completes)

- Part A: enrollment submitted: _(date)_; approved: _(date)_; seller name shown: _(text)_; Team ID recorded in
  GitHub: _(yes/no)_.
- Part B: iOS client created: _(date)_; restricted-scope status shown: _(text)_.
- Part C: API key created: _(date)_; role: _(App Manager / Admin)_.
- Part D: six secrets set: _(date)_.
- Deviations from this guide:
  - 2026-10-26, Part A step 1: the request to open a new Apple Account failed. Harold: *"could be due to PHP issue
    or other"*; cause unknown. Retry planned 2026-10-27.
  - 2026-10-26/27: about six web attempts over 2 days with `myemailspamfilter.dev@gmail.com` all ended in Apple's
    generic refusal "Your account cannot be created at this time" (Apple support article 120636 lists another
    device, another network, or later; no form error).
  - 2026-10-27, Part A step 1 decision (Harold): use his EXISTING Apple ID -- the same account as the iCloud test
    email account -- instead of a new dedicated one. No new Apple Account is needed. The address is not written
    here (this file is public); it is the iCloud test account. Two-factor authentication on that account is still
    to be confirmed at enrollment.
  - 2026-10-27: the Apple Developer Program License Agreement was saved as a PDF, kept OUTSIDE the repo (the repo is
    public and the text is Apple's): `D:\Data\Harold\spamfilter-multi\Apple_Developer_Program_License_Agreement_LC644S5URF 20261027.pdf`.
    UNVERIFIED: whether `LC644S5URF` in the file name is the Apple Team ID; read it from the Membership page in Part A
    and record it here (F304 signing needs it; it is not a secret).
