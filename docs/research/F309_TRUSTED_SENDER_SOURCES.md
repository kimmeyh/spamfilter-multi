# F309: Global "trusted sender" sources for safe-sender suggestions

**Sprint**: 83, Task 8 (Issue #542). **Consumer**: Task 5 (F270).
**Date read for every source below**: 2026-11-02 unless stated.
**Status**: RESEARCH. No code changed.

## Bottom line

- No source proves that a sender is safe. Each one proves one narrow fact about the sender's domain.
- Every source is a suggestion input only. `dmarc=pass` from the receiving provider stays the gate.
- Best fit: the `.gov` list (CC0, small, clear meaning). It helps few users.
- Recommended: option 2 below (bundle a `.gov` snapshot as a chip hint in Task 5). Decision class: new data source.

## Method and limits

- Sources are the owners' own pages. WebFetch summarizes pages, so quotes are as the tool returned them.
- Where a primary page could not be read, the claim is marked UNVERIFIED with what would settle it.
- Web search results from vendors were used only as leads, never as evidence.

## Source 1: .gov domain list (CISA)

- What it proves: the registrant is a verified U.S. government organization. Quote, get.gov eligibility page:
  "Only verified U.S. government organizations can register and operate a .gov domain."
  (https://get.gov/domains/eligibility/, read 2026-11-02). Types: federal, state or territory, tribal, county, city,
  special district, school district, interstate.
- What it does NOT prove: that a given message is real. A government domain can be compromised or spoofed
  where DMARC is weak. The page makes no claim about mail.
- Data: the repository `cisagov/dotgov-data` publishes `gov.txt`, `current-full.csv` and `current-federal.csv`.
  `current-full.csv` lists second-level domains with the registrant organization. It includes "Ready" and
  "On hold" states, so an on-hold domain appears in it. (https://github.com/cisagov/dotgov-data, read 2026-11-02)
- Size: not measured in this research. UNVERIFIED. Download the CSV and count rows to settle it.
- Cadence: the repository page says "Three files are updated daily (when there is activity)."
- License: the repository shows "CC0-1.0 license". The LICENSE file begins "Creative Commons Legal Code / CC0 1.0
  Universal" (https://raw.githubusercontent.com/cisagov/dotgov-data/main/LICENSE, read 2026-11-02). CC0 is a public
  domain dedication, so bundling in a free app is allowed. UNVERIFIED: whether the CSV rows (registrant names) carry
  any extra restriction. The repository page shows none.
- Readable from headers alone: partly. The app can read the From domain and test it against a bundled list. The
  list itself is not in the headers. A subdomain such as `mail.example.gov` needs a suffix match, because the list
  holds second-level names only.
- Bundled-list question: the list changes daily, so a bundled copy goes stale. Staleness is low risk for a hint.

## Source 2: Tranco list

- What it proves: popularity only. Quote, tranco-list.eu: "hardened against manipulation". A domain on the list is
  widely visited or resolved. Spammers can own popular domains (for example, free hosting and mail services).
  Popular is not trusted. (https://tranco-list.eu/, read 2026-11-02)
- Data: one million domains in the standard list. It is the 30-day average of rankings from Cisco Umbrella,
  Majestic, Farsight (default list only), CrUX and Cloudflare Radar. The page itself is inconsistent about whether
  it averages four or five rankings, so the exact source set is UNVERIFIED.
- Cadence: "updated daily by 0:00 UTC" (same page).
- License: BLOCKER. The Tranco site states no license for the list. The FAQ URL tried returned HTTP 404. The
  methodology page (https://tranco-list.eu/methodology, read 2026-11-02) has no license or terms language. The home
  page names the source licenses: Majestic "CC BY 3.0", CrUX "CC BY-SA 4.0", Cloudflare Radar "CC BY-NC 4.0",
  Cisco Umbrella "available free of charge", Farsight none stated. A CC BY-NC input is a concern for a list that is
  built from it. Secondary leads (a repository commit listing Tranco as MIT, a dataset note saying CC0 does not
  apply to it) were NOT verified. Settle it by writing to the Tranco maintainers (contact on the site) and asking for
  a written license for redistribution in a shipped free app.
- Readable from headers alone: the domain is, the rank is not.
- Verdict: do not ship until the license is confirmed in writing. Even then, it proves popularity, not trust.

## Source 3: BIMI with a VMC or CMC

- What it proves: the sender domain publishes a BIMI record, has DMARC enforcement, and holds a certificate from a
  Mark Verifying Authority that ties a logo to the organization. Quote, Google Workspace help
  (https://knowledge.workspace.google.com/admin/security/set-up-bimi, read 2026-11-02): "BIMI doesn't support DMARC
  policies that have the p option set to none." The policy must be quarantine or reject, with pct 100. The
  certificate is a VMC (logo must be trademarked) or a CMC (logo not trademarked). "In Gmail, you'll see a
  checkmark next to senders verified with a VMC."
- It is the strongest per-sender proof in this report, because a third party checked the organization. It is also
  rare: it costs money and covers mostly large brands.
- Headers: the BIMI specification is still an Internet-Draft (version 15, "not endorsed by the IETF", expires
  4 May 2027). It says a receiving MTA inserts `BIMI-Location` (Section 5.2) and `BIMI-Indicator` (Section 5.3),
  must remove copies that arrive from outside (Section 5.6), and "SHOULD affix the result in the
  Authentication-Results header" (Section 7.7), for example `bimi=pass header.d=example.com header.selector=myselector`.
  (https://datatracker.ietf.org/doc/draft-brand-indicators-for-message-identification/, read 2026-11-02)
- Which providers add those headers to the copy an IMAP or API client reads: UNVERIFIED. The Gmail help page
  describes display in Gmail, not the stored headers. Yahoo's help page (https://help.yahoo.com/kb/SLN36219.html)
  says only that Yahoo Mail uses BIMI to show verified logos. What would settle it: fetch one BIMI-signed message
  from each of Harold's four DEV accounts (Gmail, AOL) through the Task 7 read-only probe and look for `bimi=` in
  `Authentication-Results` and for `BIMI-Indicator`. This costs minutes and uses no new permission.
- VMC versus CMC for Yahoo and AOL: UNVERIFIED. Only vendor blogs disagree on it. The Yahoo sender page that
  covers BIMI was not read.
- License: not a data list. No license issue. The signal is per message.
- Data source: none to bundle. No privacy-policy change, because the app reads a header it already has.

## Source 4: Mailbox-provider bulk-sender rules (Google, Yahoo)

- What they prove: the sender meets a minimum bar. Quote, Google (https://support.google.com/a/answer/81126, read
  2026-11-02): bulk senders must "Set up DMARC email authentication for your sending domain", and the DMARC
  enforcement policy "can be set to none". Yahoo (https://senders.yahooinc.com/best-practices/, read 2026-11-02):
  "Publish a valid DMARC policy with at least p=none - DMARC must pass." Both began in February 2024.
- Meaning: a bulk sender has valid SPF, DKIM and aligned DMARC. This is the same fact as `dmarc=pass`. It adds
  nothing new, and spammers can meet it too. Not a trusted-sender source.
- No list is published by either provider. UNVERIFIED that neither publishes one; no such page was found.

## Source 5: DMARC policy p=reject

- What it proves: the domain owner tells receivers to reject unaligned mail. It makes a `dmarc=pass` stronger,
  because a spoof is harder. It proves nothing about the owner's intent.
- Readable from headers alone: NO. The published policy is in DNS, not in the message. Some providers add
  `policy.dmarc=reject` or similar in `Authentication-Results`; that is UNVERIFIED for Gmail and AOL. The same
  probe as BIMI settles it. A DNS lookup at run time would be a network fetch (see decision class).

## Source 6: ARC (RFC 8617)

- What it proves: a chain of custody when mail is forwarded. Quote (https://www.rfc-editor.org/rfc/rfc8617, read
  2026-11-02): ARC "makes no claims about the semantic content of messages", and a validated chain does not say the
  message is safe. The status is Experimental.
- Use for F270: none. ARC helps only when forwarders break DKIM or SPF. Skip.

## How each combines with dmarc=pass (R-2)

- Rule for all: the candidate must already be GREEN (DMARC pass) under the Task 5 rules. A list match never
  replaces it.
- `.gov` match plus GREEN: show a hint on the suggestion row ("Government domain"). Suggest only. The user taps
  Accept.
- Tranco match plus GREEN: weak hint. Not recommended.
- BIMI pass plus GREEN: strong hint ("Verified brand logo"), if a provider writes the header.
- A match with a non-GREEN or "could not check" result (GREY, temperror, permerror) shows nothing. A list match
  must never turn a failed or unchecked result into a suggestion.
- No source ever adds a safe sender without a tap.
- Signal count for the card (ADR-0047 style): "N of M No Rule senders on DEV match `.gov`" is NOT measured here.
  UNVERIFIED. Task 5 must count it on DEV data before it ships the hint. Zero needs a written reason.

## Decision class (R-3)

- Bundled list shipped inside the app: a NEW DATA SOURCE. It is a development decision for Harold. It needs a license
  line in the app's third-party notices (CC0 needs none by law, but the card should record it). No privacy-policy
  change: the policy line "The only network connections the app makes are to your own email provider"
  (docs/legal/PRIVACY_POLICY.md, line 62) stays true.
- Network fetch at run time (list download or a DNS lookup of a sender's DMARC or BIMI record): Class 1
  (architecture) PLUS a privacy-policy change. The sentence at line 62 would become false, and a DNS lookup also
  tells a resolver which senders the user receives from.
- Header read (BIMI or provider results): no new data source and no network. It is a parser change in shared Dart.
  Whether it is Class 2 depends on whether the existing header parser changes signature. Task 5 must grep callers.

## Recommendation

Option 2 below. Reasons: the `.gov` list has a clear CC0 license, a clear meaning, a small size, and no network
fetch. It keeps the privacy policy true. It is a hint, so a stale copy does little harm. Tranco has no stated
license. BIMI is the best signal but is unproven in the headers, so settle that with a free probe first.
Decision class of the recommendation: new data source (development decision, Harold).

## Question for Harold (answer with a digit)

This decides whether Task 5 (suggested safe senders) gets an extra "why trusted" hint from a global source.

1. Do nothing. Task 5 stays on stored history plus GREEN only. Cost: none. Loses a hint.
2. Bundle a `.gov` snapshot (CC0) as a hint chip on suggestion rows in Task 5. Refresh by hand each release. Class:
   new data source. No privacy change. Adds a small asset and a refresh step.
3. Option 2, plus run the free BIMI and `Authentication-Results` probe on the DEV accounts, and add a "Verified
   brand logo" hint only if the headers exist. Class: new data source, and a header-parser change. No network.
4. Bundle the Tranco list as a hint. Blocked until the maintainers confirm a license in writing. Class: new data
   source. Proves popularity only. Not recommended.
5. Fetch lists or DNS records at run time (always fresh). Class 1 plus a privacy-policy change. Not recommended.
6. Defer all of it to the backlog and ask again after Task 5 ships with its DEV counts.

My recommendation: 2.

## UNVERIFIED claims (what would settle each)

- Row count of the `.gov` CSV: download `current-full.csv` and count.
- Any extra terms on the registrant data in the `.gov` CSV: none seen on the repository page; read the repository README.
- Tranco license: ask the maintainers in writing. The FAQ page returned 404.
- Whether Tranco averages four or five sources: the page text is inconsistent.
- Which providers store `bimi=`, `BIMI-Location` or `BIMI-Indicator` in mail an IMAP or API client reads: run the Task 7 probe.
- Whether Yahoo and AOL need a VMC: read the Yahoo BIMI page at senders.yahooinc.com (not read; the FAQ URL tried returned 404).
- Whether Gmail or AOL write DMARC policy details into `Authentication-Results`: same probe.
- Whether Google or Yahoo publish any list of authenticated senders: none found; ask their sender support.
- How many DEV No Rule senders match `.gov`: count in Task 5.
