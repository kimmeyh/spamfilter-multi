# Legal Entity of Record

The publishing entity for MyEmailSpamFilter on all stores.

## Kimmey Consulting LLC

- **Legal name**: Kimmey Consulting LLC
- **Type**: Domestic Limited Liability Company
- **State**: Ohio
- **Ohio Secretary of State document number**: 202624702988
- **Effective date**: 2026-09-05 (filed 2026-09-05; certificate issued 2026-09-08)
- **Stated purpose**: Provide Information Technology consulting services to personal and
  business clients.

Verify independently at the Ohio Secretary of State business search using the document
number above. That number is the useful key -- it is what verification forms ask for, and
it does not change.

## Where the Articles of Organization live

**NOT in this repository, deliberately.** The filed Articles carry a residential address and
a signature. This repo is public, and git history is effectively permanent: a file committed
and later deleted stays in history, in every clone, and in whatever caches and mirrors have
touched the repo since. Nothing in the build or in either store submission reads that
document, so there is no engineering reason to accept that exposure.

The PDF is filed with Harold's tax and entity records off-repo. Ask Harold; the path is not
recorded here on purpose, because a path is a detail that goes stale on the next
reorganization and tells a reader of this repo something they have no need to know.

**Upload it directly to a console's verification flow when asked.** That is the only place
it is needed -- Microsoft Partner Center company verification, Google Play organization
verification. Never route it through source control to get it there.

## Name strings currently in use, and why they differ

These are NOT typos. Each is what the named system actually holds today, and they disagree:

| System | String held today | Notes |
|---|---|---|
| Microsoft Partner Center (publisher name) | `Kimmey Consulting - Ohio` | hyphen; account type **Individual** |
| Google Play (developer name, public) | `Kimmey Consulting LLC` | **DONE 2026-09-09** (F199) |
| `pubspec.yaml` `publisher_display_name` | `Kimmey Consulting LLC` | F199; used for the MSIX package |
| `pubspec.yaml` `identity_name` | `KimmeyConsulting-Ohio.MyEmailSpamFilter` | **Store-assigned. NEVER change.** |
| `pubspec.yaml` `publisher` | `CN=84EA8722-...` | **Partner Center GUID, not a name. NEVER change.** |

F199 (Sprint 68) renames the two customer-visible console strings to `Kimmey Consulting LLC`.
It does NOT touch `identity_name` or `publisher`: those two are how Windows matches an
installed app to its updates, and changing either orphans every installed copy.

**A declaration already submitted under the old name stays under the old name.** See
`GOOGLE_PLAY_ACCOUNT_SETUP.md` -- the "Is this a government app?" justification names
`Kimmey Consulting, Ohio` because that is what was submitted to Google. Records of external
state are not updated to reflect intentions.

## Account type: Individual/Personal vs Company/Organization (researched 2026-09-09)

Researched against MICROSOFT and GOOGLE OWN documentation when Harold formed the LLC and
asked whether company accounts are worth it. Recording it because the answer is
non-obvious, the documentation contradicts itself in two places, and re-deriving this
costs an hour.

**DECISION (Harold, 2026-09-09): stay Individual/Personal on BOTH stores. Not "for now" --
decided. Only the customer-visible NAMES change.**

This closes the question rather than deferring it. Everything below is retained as the
REASONING behind that decision and as the reference if it is ever reopened -- not as
pending work. Concretely, the following are NOT requirements for this project and should
not be treated as blockers by any future reader:

- a verified organization website (Google's account-type gate)
- a work email on the organization's domain (Microsoft's company prerequisite)
- a D-U-N-S number
- domain ownership records or purchase invoices
- the Microsoft support ticket about Individual -> Company conversion

The one Microsoft question still worth asking, and it is unrelated to account type: **can
this Individual account's publisher display name be changed** from `Kimmey Consulting - Ohio`
to `Kimmey Consulting LLC`? The vendor docs contradict each other on that point (below), and
it is the last open piece of F199.

### Google Play

- **Developer name: change it any time.** Play Console -> Developer account -> About you.
  Google: the name "can be changed any time" and "does not need to match the organization
  name". Goes through review. **No documented effect on a running closed test** -- the
  14-day clock is defined purely by tester opt-in continuity.
- **The organization exemption from the 12x14 testing gate is NOT documented by Google.**
  Every official page scopes the rule positively -- "personal developer accounts created
  after November 13, 2023" -- and is SILENT on organizations. The explicit "organizations
  are exempt" statements come only from Product Experts, who are Google-recognized
  VOLUNTEERS, not employees, on pages carrying the Google disclaimer "may not be verified
  or up-to-date". Strong signal, not a guarantee. Do not repeat it as fact.
- **Conversion is supported, one-way, and SLOW**: requires a D-U-N-S number ("can take up
  to 30 days"), a VERIFIED organization website as a gate before the option even appears,
  identity verification, then "wait at least 72 hours ... before you submit any new apps".
  "You cannot change the account type from an organization to an individual account."
- **Converting mid-test is undocumented and the community evidence CONFLICTS**: a Gold
  Product Expert said the requirement survives conversion; the original poster reported
  five days later that production unlocked immediately. One anecdote against one
  prediction. Whether conversion preserves, resets or voids accumulated tester days is
  unknown.
- **Play supports APP TRANSFERS between developer accounts.** Play Console -> Settings ->
  Developer account -> General -> **App transfers**, "Transfer your apps to another
  developer account". Observed in the console 2026-09-09. This is a real asymmetry with
  Microsoft, where transferring an app between accounts is UNDOCUMENTED -- so the
  "new account means abandoning the listing" risk applies to the Microsoft side and NOT
  necessarily to Play. Not needed today; it matters if the company-account question
  returns.
- **Cost of converting**: an Organization account publishes the legal ADDRESS and a PHONE
  NUMBER on every listing. Personal publishes neither -- though monetizing displays the
  full address either way.
- Note: `Kimmey Consulting, Ohio` on a PERSONAL account was the riskier configuration under
  the Google Impersonation policy (no "falsely imply a relationship to another company /
  entity"). The LLC makes the name MORE defensible, not less.

### Microsoft Store

- **Individual -> Company conversion is NOT SUPPORTED.** "To publish as a company, you will
  need to create a new Company developer account." A new account means a new
  `Package/Identity/Publisher`, i.e. a NEW PRODUCT LISTING, not an update. Whether an app
  can be TRANSFERRED between accounts is **undocumented** -- the transfer procedure in
  search results is from a Microsoft Q&A page labelled "AI answer".
- **The Microsoft docs CONTRADICT each other on the display name.** The Windows Store FAQ
  says publisher display name "cannot be changed after registration". The Partner Center
  account doc says you can "select the Update link to change your contact info, such as
  publisher display name". The console UI shows the Update link. Unresolved -- ask support.
- **Store Policy 10.14 is the finding that matters**: a company account is required "if a
  reasonable consumer would interpret your application or publisher name to be that of a
  business entity." `Kimmey Consulting - Ohio` on an Individual account arguably already
  meets that trigger. Stated as a reading of the policy TEXT: Microsoft documents no
  enforcement mechanism, notice process, or consequence, and this is NOT a prediction.
- Registration fee is now **$0 for both types** via storedeveloper.microsoft.com (the old
  $19/$99 split is obsolete through that flow). Only ONE capability is gated on account
  type (10.8.3, financial account information) and it does not apply to this app.

### Blockers if a company account is ever pursued

Both platforms require infrastructure the LLC does not have yet:

- Microsoft: a **work email on the organization domain**. "Personal emails like Gmail or
  Yahoo are not supported."
- Google: a **verified organization website**.

Microsoft would accept the Ohio Articles of Organization as an "equivalent formation
document"; a D-U-N-S number avoids a 2-5 day manual review there.

### Sequence

1. ~~Play developer name -> `Kimmey Consulting LLC`~~ **DONE 2026-09-09.** Developer
   account -> About you. No friction; the console accepted it while 0.14.2 was still in
   review, and nothing about the in-flight release or the closed test was disturbed. Google
   reviews the name before it shows publicly, so the Play LISTING may lag the console.
2. ~~Partner Center listing fields (Copyright, Developed by)~~ **DONE 2026-09-09.**
3. Partner Center publisher display name -- the ONLY F199 item still open. Ask support
   whether an Individual account can change it; the docs contradict each other. This is a
   NAME question, not an account-type question: the account-type decision is closed.

**Account type: CLOSED, 2026-09-09.** Both stores stay Personal/Individual. Conversion was
never going to accelerate this launch anyway -- the Play account is ~12 days old and D-U-N-S
alone can take 30 days -- but the decision is on the merits, not the timing, and it is not
revisited unless Harold reopens it.
