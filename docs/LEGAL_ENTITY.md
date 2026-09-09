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
| Google Play (developer name, public) | `Kimmey Consulting, Ohio` | comma |
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
