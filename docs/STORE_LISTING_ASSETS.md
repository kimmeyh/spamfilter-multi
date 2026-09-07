# Microsoft Store Listing Assets

**App Name**: MyEmailSpamFilter
**Developer Account**: kimmeyh@outlook.com (Microsoft Store developer account)
**Publisher Display Name**: Kimmey Consulting - Ohio
**Store ID**: 9N5QK9G904C0
**Partner Center ID**: 768eaaca-92b9-4871-a10f-da17dbf92e91
**Category**: Productivity / Utilities & Tools
> **CORRECTED 2026-09-06 (Sprint 65 GP-6 cross-store comparison).** Two claims here had
> drifted from the shipped behaviour and from the published privacy policy:
> 1. The description said email content is "never stored". A bounded 100-character preview
>    IS retained for messages awaiting review (`kBodyPreviewMaxLength`, enforced at the
>    write boundary in `unmatched_email_store.dart`). The Play listing was written with the
>    accurate wording rather than inheriting this one.
> 2. The privacy policy URL predated the canonical address published in Sprint 64. Both
>    resolve, so nothing was broken -- but two live addresses for one policy invites drift.
>
> This file is the REPO COPY. The LIVE Partner Center listing must be edited by Harold for
> the correction to reach users; presented to him 2026-09-06.

> **SUBMISSION 22 (2026-09-06/07), listing-only update -- no new package.** Three changes,
> all made by Harold in Partner Center:
> 1. Description "Privacy First" paragraph rewritten (text below) so the local-only promise
>    LEADS rather than arriving as an exception, and so the 100-character preview is
>    explicitly described as saved on the device.
> 2. Privacy policy URL set to the canonical GP-5 address.
> 3. **Product declaration "Windows can include this product's data in automatic backups to
>    OneDrive" UNCHECKED.** Found while reviewing the Properties page against the new
>    description. The app transmits nothing, so the claim was literally true either way --
>    but that declaration lets WINDOWS copy the app-support folder (rules DB, scan history,
>    the 100-character previews, encrypted credentials) to the user's OneDrive. A reader of
>    "Everything stays on your device" would not expect their scan history in the cloud.
>    Unchecking it keeps the description true with no asterisk, which is the whole value of
>    the rewrite. Trade-off accepted: no automatic backup, mitigated by the app's existing
>    YAML rule import/export.

**Privacy Policy URL**: https://myemailspamfilter.com/legal/PRIVACY_POLICY.html
**Website**: https://myemailspamfilter.com
**Support Contact**: kimmeyh@outlook.com
**Discoverability**: Direct link only (soft launch)
**Pricing**: Free
**Markets**: United States

---

## Package Identity

| Field | Value |
|-------|-------|
| Package/Identity/Name | KimmeyConsulting-Ohio.MyEmailSpamFilter |
| Package/Identity/Publisher | CN=84EA8722-0CA5-4EC0-9B10-07EE79B66062 |
| Package/Properties/PublisherDisplayName | Kimmey Consulting - Ohio |
| Package Family Name (PFN) | KimmeyConsulting-Ohio.MyEmailSpamFilter_3t07cykjy5226 |

---

## Short Description

Filter spam from multiple email providers using customizable rules. Works offline.

*(89 characters - max 100)*

---

## Long Description

MyEmailSpamFilter is a desktop email spam filter that scans your email inbox and identifies spam using customizable rules. All processing happens locally on your device with no data sent to external servers.

### Key Features

**Multi-Provider Support**
Connect multiple email accounts from different providers including AOL Mail and Gmail. Manage all your accounts in one place and scan them all for spam.

**Customizable Rules Using Powerful Search Tools**
Use the default rule that will work for 99% of spam and define your own spam filtering rules using powerful regular expression patterns for any others. Match against sender addresses, subject lines, and email content. Import and export rule sets in portable YAML format to share with others or back up your configuration.

**Safe Sender Whitelist**
Protect important emails by adding trusted senders to your "safe sender" list. Emails from safe senders bypass all spam rules, ensuring you never miss messages from contacts you trust.

**Background Scanning**
Set up automatic background scans to check your inbox periodically. Configure scan frequency from every 5 minutes to once daily. View scan history and logs to track what was found.

**Manual and Demo Scanning**
Run manual scans on demand to check your inbox immediately. Try Demo Mode with 50+ sample emails to explore the app features without connecting a real email account.

**Privacy First**
Your privacy is a core design principle. Everything stays on your device. MyEmailSpamFilter does not collect analytics, telemetry, or usage data, and it sends nothing to us or to anyone else. Your rules, your scan history, and your credentials are stored locally and encrypted on your device. Email content is read during a scan and is not kept, apart from a short excerpt of up to 100 characters saved on your device for messages awaiting your review, so you can see what they were when you decide what to do with them. All credentials are encrypted and stored locally on your device. You are in full control of your data and can delete everything at any time.

**Offline Operation**
Rules and configuration are stored locally. The app only connects to the internet when scanning your email server. No cloud account or subscription required.

*(1,914 characters - max 10,000)*

---

## Product Features

1. Scan multiple email accounts for spam
2. Customizable regex-based filtering rules
3. Safe sender whitelist
4. Automatic background scanning
5. Demo mode with 50+ sample emails
6. 100% local processing - no data leaves your device
7. Support for AOL Mail and Gmail
8. Import and export rules in YAML format

---

## Keywords

spam filter, email filter, regex, IMAP, AOL, Gmail, inbox, junk mail, bulk mail, privacy, efficiency, productivity, save time

---

## Age Ratings

| Rating System | Rating | Description |
|--------------|--------|-------------|
| ESRB (United States) | E | Everyone |
| IARC (Global) | 3+ | 3+ |
| PEGI (Europe) | 3 | 3+ |
| USK (Germany) | 0 | Everyone |
| CCC (Chile) | TE | All ages |
| DJCTQ (Brazil) | L | All ages |

---

## Product Declarations

- [x] Customers can install to alternate drives or removable storage
- [x] Windows can include data in automatic backups to OneDrive
- [ ] Non-Microsoft drivers or NT services (not used)
- [ ] Accessibility tested (not formally tested)
- [ ] Pen and ink input (not supported)
- [ ] Generative AI features (not used)

---

## Screenshots

Five screenshots captured from the Windows Desktop application:

| # | Filename | Screen | Description |
|---|----------|--------|-------------|
| 1 | Screen Select Email Provider.png | Select Email Provider | First-run experience showing available providers (AOL, Gmail) and Demo Mode option |
| 2 | Screen Select Email Account.png | Select Account | Saved accounts list with multiple providers configured |
| 3 | Screen Manaul Scan.png | Manual Scan | Scan ready screen with Live Scan, Demo Scan, and Scan History options |
| 4 | Screen Scan Filter Results.png | Scan Results | Color-coded results showing matched spam with sender, subject, and rule details |
| 5 | Screen Settings.png | Settings (Background) | Background scan configuration with frequency and scan range controls |

**Screenshot Location**: `D:\Data\Harold\spamfilter-multi\Windows Store\`

**Note**: For future Store updates, screenshot #4 (Scan Results) should be recaptured using Demo Mode scan to avoid displaying personal information. All screenshots should be taken from a production build (without [DEV] title bar tag).

---

## Store Logos

| Size | Filename | Required |
|------|----------|----------|
| 1080x1080 | myemailspamfilter-icon 1080x1080.png | Yes (1:1 Box art) |
| 2160x2160 | myemailspamfilter-icon 2160x2160.png | Optional (high-res) |

**Logo Location**: `D:\Data\Harold\spamfilter-multi\Windows Store\`

---

## Copyright and License

**Copyright**: Copyright 2026 Harold Kimmey. All rights reserved.

**License Terms**: This application is provided "as is" without warranty of any kind, express or implied. By installing and using MyEmailSpamFilter, you agree that the developer is not liable for any damages arising from the use of this software. This application processes email data locally on your device and does not collect, store, or transmit your data to any external servers. You may use this application for personal and commercial purposes. Redistribution or reverse engineering of this application is prohibited.

**Developed by**: Harold Kimmey

---

## Submission History

| Date | Version | Status | Notes |
|------|---------|--------|-------|
| 2026-03-21 | 0.5.1.0 | Submitted for certification | Initial submission, direct-link-only, free, US market |

---

## Store Listing Checklist

- [x] App name reserved: MyEmailSpamFilter
- [x] Short description (under 100 characters)
- [x] Long description (under 10,000 characters)
- [x] Privacy policy URL (https://myemailspamfilter.com/legal/PRIVACY_POLICY.html)
- [x] Keywords defined
- [x] Age rating questionnaire completed (IARC 3+)
- [x] 5 screenshots uploaded
- [x] Store logo uploaded (1080x1080 box art)
- [x] Product features listed (8 features)
- [x] Copyright and license terms provided
- [x] MSIX package built and uploaded (v0.5.1.0)
- [x] runFullTrust capability justified
- [x] Submission sent for certification (2026-03-21)
- [ ] Certification passed
- [ ] Screenshots recaptured from production build (no [DEV] tag)
- [ ] Screenshot #4 recaptured using Demo Mode scan
