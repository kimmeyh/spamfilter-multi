# R76-3: Heuristics, ML and GenAI Spam Identification -- Research

**Sprint**: 77, Task 8 (Issue #468) | **Type**: research only (no code, no model, no new dependency)
**Time-box**: 240 minutes (Harold Q26 = 1) | **Sources read**: 2026-10-06 (US Eastern), unless a line says otherwise
**Card**: `docs/sprints/SPRINT_77_PLAN.md`, Block C, "Task 3 -- R76-3"

**Evidence labels used in this document**: **[V]** verified against a primary source or the repository in this
session; **[I]** inference from verified facts; **[O]** opinion or recommendation; **[UNVERIFIED]** not confirmed
from a primary source, with what would settle it.

---

## 1. Bottom line

1. **[O] Build the heuristic and rule-mining tools first.** They extend the existing regex YAML engine, run as
   shared Dart code on Windows and Android, add no network destination, and need no privacy-policy change as long
   as they read only what the app already stores. They also fix a real gap: the bundled rule corpus has zero
   subject or body rules, so today the app only knows bad senders, not bad content.
2. **[O] Build a measurement harness before anything that acts on mail.** Nothing proposed here should move or
   delete a message until it has been scored against Harold's own history (precision on "would delete",
   false-positive rate on safe senders).
3. **[I] On-device ML is feasible as a pure-Dart, per-user classifier.** A throwaway probe scored a 1,232-character
   text in about 161 microseconds with a 2.0 MiB model on the development laptop. A per-user model trained only on
   that user's own decisions is the one ML shape that Google's Workspace AI/ML clause explicitly permits for Gmail
   data. It depends on R76-4 (labeled history), which is a Class-1 decision.
4. **[O] Hold GenAI.** No on-device GenAI runtime serves the app's core path today: Android's Gemini Nano API is
   foreground-only and absent from the Galaxy S24 family; the Windows API needs a Copilot+ NPU or a Developer
   Mode GPU path, and its model (Phi Silica) is being replaced in January 2027. A cloud route contradicts the
   published privacy policy in four places and is a Class-1 decision. Revisit on a named trigger.
5. **[V] Side finding (defect)**: 23 of the 426 bundled safe-sender patterns can never match any address (they
   contain a second literal `@`). The existing pattern validator does not catch this shape. See R77-RS-1.

---

## 2. Constraints this research works under

- **Personal email only** (Harold, 2026-10-06, plan Q2): *"This is a personal email only app - no business usage
  should be encouraged or used (at this time)."* Every item below assumes one person's own mailboxes. No item
  proposes shared or crowd-sourced reputation data between users.
- **Published privacy policy** (`docs/legal/PRIVACY_POLICY.md`, effective August 28, 2026) [V]. The sentences
  any pipeline would touch:
  - "MyEmailSpamFilter runs entirely on your device. We do not operate any server. We do not collect, transmit,
    receive, sell, or share any of your data."
  - "a message body is retrieved only when one of your body rules requires it, and is discarded after evaluation."
  - "a short body preview (at most 100 characters). Full message bodies are never stored."
  - "Nothing is uploaded anywhere: the app has no backend, no analytics, no crash reporting, no advertising, and
    no third-party tracking of any kind."
  - "The only network connections the app makes are to your own email provider (Google, or your IMAP provider)
    to read and act on your mailbox at your direction."
- **Play Data safety as submitted**: "Does your app collect or share any of the required user data types? NO"
  (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:164`), guarded by `test/policy/data_safety_declarations_test.dart` [V].
- **ADR-0042 parity**: every candidate is evaluated for Windows and Android; a runtime on only one platform is a
  declared exception.
- **Prevention first**: extend the regex YAML engine (`docs/RULE_FORMAT.md`) and its existing extension points
  before creating a new mechanism.

---

## 3. What the app already holds (audit, R-1)

All [V] from the repository on 2026-10-06 unless marked.

- **Rule corpus (bundled seed)**: `mobile-app/assets/rules/rules.yaml` holds 1,824 rules, **all**
  `patternCategory: header_from`: 1,370 `entire_domain`, 445 `top_level_domain`, 9 `exact_domain`. **Zero subject
  rules and zero body rules.** `rules_safe_senders.yaml` holds 426 patterns. Harold's live database is the source
  of truth since Sprint 20 and may differ from the seed **[UNVERIFIED]**: settle by exporting his rules through
  Settings > Import / Export YAML and repeating the counts.
- **Consequence [I]**: any subject or body heuristic has **no labeled positive examples** in the rule corpus. The
  only content-level labels are the user's own actions over time (R76-4) and Harold's partial deleted-mail
  history (external).
- **Per-email fields stored today**: `email_actions` (sender, subject, folder, action, matched rule and pattern,
  safe-sender flag, `rfc5322_message_id` from F91, `auth_classification` from F96) and `unmatched_emails`
  (sender, subject, folder, `body_preview`, `auth_classification`, `processed`) (`docs/ARCHITECTURE.md:360-366`).
- **`body_preview` is mostly empty in practice**: the manual-scan path deliberately does not persist it
  ("SEC-14: body content deliberately NOT persisted here", `email_scan_provider.dart:719-720`). The card's R-1
  overstates its availability.
- **Headers are available without a body fetch on both providers**: IMAP fetches `BODY.PEEK[HEADER]`
  (`generic_imap_adapter.dart:1605`); Gmail fetches `format: 'metadata'` with no `metadataHeaders` filter
  (`gmail_api_adapter.dart:688`), which returns all headers **[I: Gmail API default when the filter is absent;
  settle with the `users.messages.get` reference]**. Bodies are fetched one at a time only when a body rule needs
  one (F180, `generic_imap_adapter.dart:1598-1602`, `gmail_api_adapter.dart:1150`).
- **Header rules can already express many heuristics**: `RuleEvaluator` matches non-From headers as `key:value`
  (`rule_evaluator.dart:270-287`), so a YAML `header` pattern such as `^reply-to:.*@` or `^list-unsubscribe:` is
  already legal. What the engine cannot express is a **comparison between two headers** (Reply-To domain differs
  from From domain) or a **weighted score**.
- **Import replaces, it does not merge**: "Import rules from user-selected YAML file (replaces existing)"
  (`yaml_import_export_screen.dart:9-10`). Feeding mined rules "through the existing import path" therefore means
  export, merge offline, re-import -- or a new merge mode (R77-RS-4).
- **Read-only dry run exists**: Windows DEV and Prod scan read-only with background off; only the Android closed
  test acts on mail (`docs/GOOGLE_PLAY_ACCOUNT_SETUP.md:524-541`). This is the evaluation harness's natural home.
- **Existing validator**: `PatternCompiler.validatePattern` (`pattern_compiler.dart:198-240`) warns on ReDoS,
  unescaped domain dots, `.*.*`, empty alternation and repeated characters. It does **not** detect an
  unmatchable pattern.
- **Side finding [V]**: 23 of 426 bundled safe-sender patterns have the shape
  `^[^@\s]+@(?:[a-z0-9-]+\.)*@<domain>$` -- a second literal `@` after the subdomain group -- so they cannot match
  any address. Two patterns are not anchored with `^`, and one of those carries an unescaped dot. Whether
  Harold's live database carries the same 23 is **[UNVERIFIED]** (same export settles it).

---

## 4. R-3 questions

### 4.1 Heuristic pipeline (R-3.1)

**Signals available without new data** (headers only, both providers, no body fetch) [I]:

| Signal | Source | Expressible as YAML today? |
|---|---|---|
| Sender domain or TLD on a known-bad list | From | Yes (1,815 of 1,824 seed rules already are this) |
| SPF/DKIM/DMARC fail or none | `Authentication-Results` (F89/F96) | Partly (header regex); the parsed class is stored |
| Reply-To domain differs from From domain | Reply-To + From | **No** (needs a two-header comparison) |
| Display name contains an address or brand unlike the From domain | From display name | **No** (needs a comparison) |
| `List-Unsubscribe` present (bulk mail marker) | header | Yes (`^list-unsubscribe:`) |
| Subject n-grams that recur in mail the user deleted | Subject + user action | Yes, once mined (subject regex) |
| Lookalike domain (digit-for-letter, extra hyphen) | From | Yes, once mined (domain regex) |

- **[V]** Gmail requires one-click unsubscribe (`List-Unsubscribe-Post: List-Unsubscribe=One-Click`, RFC 8058)
  and DMARC from senders of more than 5,000 messages a day, and SPF or DKIM from all senders, since February 1,
  2024 (https://support.google.com/a/answer/81126, read 2026-10-06). **[I]** So a missing `List-Unsubscribe` on
  marketing-shaped mail, and DMARC failure on a bulk sender, are informative signals; `List-Unsubscribe` alone is
  not spam evidence (legitimate newsletters carry it).
- **[V]** The heuristic-plus-score design has a long precedent: Apache SpamAssassin "uses a robust scoring
  framework and plug-ins to integrate a wide range of advanced heuristic and statistical analysis tests on email
  headers and body text including text analysis, Bayesian filtering, DNS blocklists, and collaborative filtering
  databases" (https://spamassassin.apache.org/, read 2026-10-06; latest release 4.0.2, August 30, 2025).

**How a heuristic feeds NEW YAML delete rules [O]**: the heuristic never acts on mail itself. It produces
**candidate rules** in the existing format (`header` domain pattern, `subject` pattern, `body` pattern) that the
user accepts or rejects; accepted candidates become ordinary rules. This keeps one acting mechanism (the regex
engine), keeps the user in control, and keeps every action explainable by a named rule. Mining sources:
(a) senders and subjects of mail the user deleted from No Rule Review; (b) Harold's deleted-mail history,
processed **on his PC** by a script that writes a YAML file (R77-RS-3). Because import replaces all rules, either
the script merges with an exported copy or the app gains a merge import (R77-RS-4).

**Network-based signals (domain age, blocklists) [I/UNVERIFIED]**: domain age needs an RDAP lookup (RFC 9224,
"Finding the Authoritative Registration Data Access Protocol (RDAP) Service", Internet Standard STD 95,
https://www.rfc-editor.org/rfc/rfc9224, read 2026-10-06); a DNS blocklist needs a DNS query. Both send the
sender's domain to a third party, which contradicts "The only network connections the app makes are to your own
email provider". The Spamhaus fair-use policy allows free use "for non-commercial use by small and medium sized
organisations" and requires "a recursive resolver run on your own network or ... a public resolver which supports
ECS" (https://www.spamhaus.org/blocklists/dnsbl-fair-use-policy/, read 2026-10-06); whether a publicly
distributed client app qualifies is **[UNVERIFIED]** (settle by asking Spamhaus in writing). **[O]** Prefer
bundled, user-reviewable domain lists (the current seed model) over live lookups.

### 4.2 Safe-sender discovery (R-3.2)

Candidate sources, in order of privacy cost [I]:

1. **No new data**: senders that pass DMARC (F96 class stored), appear repeatedly in No Rule, and that the user
   has never deleted. Output: a candidate list on a review screen; the user accepts each, never silently.
2. **Reply pairs**: addresses the user has sent mail to (Sent folder `To:`/`Cc:` headers). Requires reading a
   folder the app does not scan today. Gmail `gmail.modify` already covers it (ADR-0029) and IMAP needs no new
   permission, but the privacy policy says Gmail data is used "only to provide the app's user-facing
   spam-filtering features"; safe-sender discovery is a spam-filtering feature **[O]**, yet the "What the app
   accesses" section should name the Sent folder if this ships (wording change, not a Class-1 store change).
3. **Device contacts**: needs `READ_CONTACTS` on Android (ADR-0028 permission strategy) and a different API on
   Windows. **[O] Exclude from the first version**: a new runtime permission and a platform difference for a
   marginal gain over source 2.

Quality gate [O]: every candidate pattern runs through the extended `PatternCompiler.validatePattern`
(R77-RS-1) before it is shown, so the tool cannot add another unmatchable pattern like the 23 in the seed.

### 4.3 ML on device (R-3.3)

| Runtime | Windows | Android | Status read 2026-10-06 | Assessment |
|---|---|---|---|---|
| Pure-Dart classifier (hashed-token naive Bayes / logistic regression) | Yes (shared code) | Yes (shared code) | No dependency | **[O] Recommended** |
| `tflite_flutter` (TensorFlow) | Yes, but "build" a `.dll` and copy `libtensorflowlite_c-win.dll` into a `blobs` folder | Yes | 0.12.1, "published 11 months ago" per pub.dev; absolute date **[UNVERIFIED]** (the fetched page gave a contradictory date) | Native build burden on Windows |
| `onnxruntime` (pub.dev) | Listed | Listed (API 21+) | 1.4.1, "2 years ago", unverified uploader, MIT | Stale; supply-chain risk |
| `flutter_edge_ai` (LiteRT-LM, ONNX) | Yes | Yes | 2.1.0, hours old; replaces the discontinued `flutter_gemma` | LLM-oriented; single-publisher maintenance risk |

Sources: https://pub.dev/packages/tflite_flutter, https://pub.dev/packages/onnxruntime,
https://pub.dev/packages/flutter_gemma, https://pub.dev/packages/flutter_edge_ai (all read 2026-10-06).

**Measured (throwaway probe, scratchpad, deleted the same session)** [V for this machine only]: pure-Dart
multinomial naive Bayes over 262,144 FNV-hashed token buckets, Dart 3.13.3 (JIT, `dart run`), Intel Core
i9-14900HX: training 2,000 synthetic texts took 299 ms; scoring 1,000 texts of 1,232 characters on average took
160 ms (**about 161 microseconds per text**); model state 2 x 262,144 x 4 bytes = **2.0 MiB** uncompressed.
Synthetic data only; accuracy on real mail is unmeasured. **Fold timing [UNVERIFIED]** -- settle with the same
probe in an Android debug build on the Fold. **[I]** Even at 20x slower on a phone, 1,000 emails cost about
3 seconds of CPU, small next to network time.

**Statistical precedent [V]**: Sahami, Dumais, Heckerman and Horvitz, "A Bayesian Approach to Filtering Junk
E-Mail", AAAI-98 Workshop on Learning for Text Categorization, AAAI Technical Report WS-98-05
(https://cdn.aaai.org/Workshops/1998/WS-98-05/WS98-05-009.pdf). Paul Graham, "A Plan for Spam" (August 2002)
reports, on his own mail, "less than 5 per 1000 spams" missed "with 0 false positives", using "the most
interesting fifteen tokens" (https://paulgraham.com/spam.html). **[I]** A personal corpus is exactly the setting
these results come from.

**Where training happens [I, from 4.7]**: on the user's device, from that user's own decisions. Training one
model on Harold's Gmail-derived history and shipping it as an asset to other users is "beyond that specific
user's personalized model" and is prohibited for Gmail data (see 4.7). Update mechanics: incremental -- each
user decision adds token counts; no download, no server.

### 4.4 GenAI (R-3.4)

**Android on-device -- ML Kit GenAI / Gemini Nano** [V] (https://developers.google.com/ml-kit/genai, page
"Last updated 2026-09-28 UTC", read 2026-10-06):
- Prompt API status: **Beta**.
- "GenAI API inference is permitted only when the app is the top foreground application"; background or
  foreground-service use returns `ErrorCode.BACKGROUND_USE_BLOCKED`; per-app inference quotas (`ErrorCode.BUSY`)
  and a battery quota (`PER_APP_BATTERY_USE_QUOTA_EXCEEDED`).
- Samsung devices listed: Galaxy S25 and S26 families, Z Flip8, **Z Fold8, Z Fold8 Ultra**, Z Fold7, Z TriFold.
  **Galaxy S24, S24+ and S24 Ultra are not listed.**
- **[I]** The app's core Android path is the background scan (WorkManager, ADR-0039; notification trigger,
  ADR-0044). This runtime cannot serve it at all, and cannot run on one of Harold's two test phones.

**Windows on-device -- Windows AI APIs / Phi Silica** [V] (https://learn.microsoft.com/en-us/windows/ai/apis/,
updated 2026-10-02; https://learn.microsoft.com/en-us/windows/ai/apis/get-started, updated 2026-08-19):
- Phi Silica runs on a Copilot+ PC NPU, or on GPU "NVIDIA GeForce RTX 30 series and newer (6+ GB vRAM)" with
  "Developer Mode" enabled; not on CPU. GPU support needs Windows App SDK "2.2.2-experimental9 (June 2026
  Experimental)" and an Insider Experimental Channel build. The stable path is "Phi Silica (Limited Access
  Feature)" in Windows App SDK 1.8.
- Apps declare the `systemAIModels` capability in a package manifest and call WinRT APIs from C#/C++.
- "**Phi Silica is being replaced by Aion Instruct** ... rolling out ... to retail devices in January 2027, at
  which point Phi Silica will be removed."
- Development laptop: Intel Core i9-14900HX has **no NPU** (Intel specification page, read 2026-10-06) and an
  NVIDIA GeForce RTX 4070 Laptop GPU (WMI). Its VRAM is reported as 4 GB by WMI, which caps the 32-bit field;
  the real figure is **[UNVERIFIED]** (settle with `nvidia-smi`).
- **[I]** A Flutter app would need a native WinRT plugin, an MSIX-only code path (dev builds are not packaged),
  and users with Developer Mode on. Not shippable to Store users today.

**Cross-platform on-device LLM** [V]: MediaPipe LLM Inference "is now in maintenance-only mode. New features and
optimizations will be focused on LiteRT-LM" (https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference,
updated October 1, 2026). Gemma 3 270M has "170 million embedding parameters ... and 100 million for our
transformer blocks", QAT INT4 checkpoints, and is pitched for "text classification and data extraction"
(https://developers.googleblog.com/en/introducing-gemma-3-270m/, August 14, 2025). Its INT4 size of roughly
125-200 MB comes from secondary sources **[UNVERIFIED]**. Gemma 3 ships under the Gemma Terms of Use, which
require passing the use restrictions through and a "Notice" file with every distribution; Gemma 4 points to an
Apache 2.0 license (https://ai.google.dev/gemma/terms, modified April 1, 2026). **[O]** A 100+ MB model download
to classify mail that a 2 MiB per-user classifier and regex rules already handle is poor value today; the
plausible GenAI use is *explaining* a candidate rule to the user, which is a convenience, not detection.

**Cloud API** [V prices, I cost per email]:
- Claude Haiku 4.5: $1 / MTok input, $5 / MTok output; Batch API half (https://platform.claude.com/docs/en/about-claude/pricing,
  read 2026-10-06).
- `gemini-3.5-flash-lite` paid tier: $0.30 / MTok input, $2.50 / MTok output; the free tier's content is "used to
  improve our products" (https://ai.google.dev/gemini-api/docs/pricing, page dated 2026-10-07 UTC). The Gemini API
  terms say for unpaid services "human reviewers may read, annotate, and process your API input and output" and
  "Do not submit sensitive, confidential, or personal information to the Unpaid Services"
  (https://ai.google.dev/gemini-api/terms, modified April 28, 2026).
- Assumption [I]: 500 input tokens (headers, subject, about 1,000 body characters) and 20 output tokens per email.
  Cost: Haiku 4.5 about **$0.0006 per email**; Flash-Lite about **$0.0002 per email**. At 200 emails a day, about
  $3.60 or $1.20 a month per user. Latency: one network round trip per email or per batch **[UNVERIFIED]**.
- **What leaves the device**: sender, subject and body text of personal mail, to a third party.
- **[I] Not justifiable under the current posture**: it contradicts four sentences of the privacy policy (Section
  2), flips the Play Data safety answer (Section 4.7), and the app has no server, so an API key would be either
  embedded in the client (extractable) or supplied by each user. **Class-1 architecture decision** if ever raised.

### 4.5 What each pipeline needs from R76-4 (R-3.5)

| Pipeline | Minimum fields | Body text? | Retention |
|---|---|---|---|
| Heuristic signals | From address + display name, Reply-To, Return-Path domain, `List-Unsubscribe` presence, auth class, received date | No | Life of the email's review row |
| Rule mining (sender/subject) | From domain, subject, user's final action (deleted / kept / safe), date | No | Rolling window (for example 365 days) |
| Body-rule mining | Body tokens | **Yes** (or hashed tokens) | Shortest workable; prefer PC-side mining of Harold's own history instead |
| Per-user ML | Hashed token counts per label, not the messages | No (counts only) | Model state persists; per-message rows can expire |
| Safe-sender discovery | From address, auth class, user action, Sent-folder recipient addresses | No | Rolling window |
| GenAI (held) | Whatever the prompt needs, at evaluation time only | Ephemeral | None stored |

Full recommendation in Section 6.

### 4.6 ADR-0042 parity (R-3.6)

- Heuristic signals, rule mining, merge import, validator, safe-sender discovery (sources 1-2), pure-Dart ML,
  evaluation harness: **shared Dart code on both platforms** [I]. The OS behavior assumed identical: header
  availability from the provider, which is the same IMAP and Gmail API path on both platforms (Section 3).
- PC-side rule miner (R77-RS-3): a developer tool in `scripts/`, not app code; parity N/A.
- Device contacts (excluded): would be a declared exception (Android permission vs Windows API).
- Android ML Kit GenAI: Android only, foreground only, device-limited -- would be a declared exception; Windows
  has no equivalent available to Store users.
- Windows AI APIs: Windows only, packaged-app and hardware-limited -- would be a declared exception.
- Cloud GenAI: identical on both platforms, but Class-1.

### 4.7 Store and data policy (R-3.7)

**(a) Google API Services User Data Policy** (https://developers.google.com/terms/api-services-user-data-policy,
"Last updated February 15, 2024", read 2026-10-06), quoted:
- "Limit your use of data to providing or improving user-facing features that are prominent in the requesting
  application's user interface"
- "Transfers of data are not allowed, except: To provide or improve your appropriate access or user-facing
  features that are visible and prominent in the requesting application's user interface and only with the
  user's consent; For security purposes (for example, investigating abuse); To comply with applicable laws; or,
  As part of a merger, acquisition, or sale of assets of the developer after obtaining explicit prior consent
  from the user"
- "Don't allow humans to read the data, unless: You first obtained the user's affirmative agreement to view
  specific messages, files, or other data ..."
- This page contains **no** AI/ML clause (verified by a second targeted read).

**(a2) Google Workspace API User Data and Developer Policy** -- the AI/ML clause lives here
(https://developers.google.com/workspace/workspace-api-user-data-developer-policy, "Last updated 2026-09-03 UTC",
read 2026-10-06). Among uses that are "completely prohibited":
- "Transferring, selling, or using user data to create, train, or improve a machine learning or artificial
  intelligence model beyond that specific user's personalized model for the appropriate use case or user-facing
  feature."

**Consequences [I]**:
- A per-user model trained on device from that user's Gmail data, for the spam-filtering feature, is inside the
  carve-out.
- A model trained on Harold's Gmail-derived data and shipped to other users is prohibited for Gmail data.
- Sending Gmail content to a cloud LLM is a transfer; it would need to fit "user-facing features ... only with the
  user's consent", and Restricted-scope verification (CASA, ADR-0029) would examine it.
- AOL and other IMAP data is outside Google's policy but inside the app's own privacy policy.
- **Open legal question [UNVERIFIED]**: the bundled domain rules were presumably derived from Harold's own mail.
  Domain patterns are not message content, but whether any seed rule was derived from Gmail API data, and
  whether that counts as "user data" under the policy, is not settled. The privacy policy cites only the API
  Services policy; it should also cite the Workspace policy when any ML ships.

**(b) Play Data safety** (https://support.google.com/googleplay/android-developer/answer/10787469, "Last Updated:
March 31, 2023" as rendered, read 2026-10-06), quoted:
- "'Collect' means transmitting data from your app off a user's device."
- "User data accessed by your app that is only processed locally on the user's device and not sent off-device
  does not require disclosure as collected."
- Processing "ephemerally" means "accessing and using it while stored only in memory, retained no longer than
  necessary to service the specific real-time request."
- Data type "Emails": "A user's emails including the email subject line, sender, recipients, and the content of
  the email."

**Exactly what would change, per case**:

| Case | Privacy policy | Play Data safety | Other |
|---|---|---|---|
| On-device content store beyond today (R76-4) | Rewrite "Full message bodies are never stored" and the stored-fields list in "What is stored, and where"; add retention | **No change** (nothing leaves the device) [I] | ADR (content history); `data_safety_declarations_test.dart` re-checked |
| On-device per-user ML | Add "the app learns from your own decisions on your device"; name the derived data | No change | Cite the Workspace policy |
| Sender-domain lookups (RDAP, DNSBL) | Rewrite "The only network connections the app makes are to your own email provider"; name the third party | Possibly "Emails" (sender) collected/shared **[UNVERIFIED]**: settle by asking Play support whether a domain-only lookup counts | Third-party terms (Section 4.1) |
| Cloud GenAI | Rewrite the short version, "Nothing is uploaded anywhere", "Data sharing", and the Limited Use paragraph | "Emails" **collected and shared**; the "No" answer flips; the guard test changes | Class-1 ADR; API key design; CASA scope |

### 4.8 Evaluation design (R-3.8)

[O] Measure before acting:
1. **Labeled set**: Harold's history -- deletions and safe-sender additions as labels, from `email_actions`,
   `unmatched_emails.processed`, scan exports, and his deleted-mail history. Split by time (train on older, test
   on newer) so the test resembles the future.
2. **Metrics**: precision on "would delete" (of the mail a candidate would delete, how much Harold did delete);
   **false-positive rate on safe senders** (any candidate that would delete mail from a current safe sender fails
   outright); recall on No Rule mail Harold later deleted (how much manual work it removes).
3. **Thresholds** [O]: a candidate rule ships only with zero safe-sender hits on the test set and precision of at
   least 0.99 on at least 20 matches; a classifier score only ranks the review list until it meets the same bar.
4. **Dry run**: run candidates on Windows DEV, which is read-only by design (Section 3); compare "would delete"
   counts against the same period on the Android closed test, which acts on mail.
5. **Where it runs**: a Dart CLI in `scripts/` reading an exported database copy, or a debug-only screen. No data
   leaves Harold's PC.

---

## 5. Proposed backlog items (prioritized)

Effort is in minutes, derived from the `docs/CODING_VELOCITY.md` Estimate Table by step-type. IDs are
placeholders for the lead to renumber. Selection is Harold's at the next Backlog Refinement.

**Order and why**: the defect first (R77-RS-1, it corrupts the safe-sender data the other tools read); then the
measurement harness (R77-RS-2), because nothing below may act on mail until it is measured; then the tools that
extend the YAML engine with no privacy change (RS-3 to RS-6); then the items gated on Class-1 decisions (RS-8
before RS-7, because the policy must be true before the classifier ships); GenAI last, on HOLD with a revisit trigger.

## Candidates at a glance

- **R77-RS-1. Unmatchable safe-sender patterns: validator check and seed fix (~45m) Priority 10**
- **R77-RS-2. Rule evaluation harness: score candidate rules against your own history, read only (~150m) Priority 20**
- **R77-RS-3. PC-side rule miner: deleted-mail history to candidate delete rules (YAML) (~180m) Priority 22**
- **R77-RS-4. YAML import merge mode (add without replacing) (~90m) Priority 24**
- **R77-RS-5. Safe-sender discovery: propose safe senders from history for review (~150m) Priority 30**
- **R77-RS-6. Heuristic reasons and rule suggestions on No Rule Review (~210m) Priority 32**
- **R77-RS-8. Privacy policy and Data safety revision for the content history and learning (~60m) Priority 40**
- **R77-RS-7. Per-user on-device spam classifier (pure Dart) ranking No Rule Review (~300m) Priority 42**
- R77-RS-9. On-device GenAI rule explanations (~240m) Priority HOLD
- R77-RS-10. Cloud GenAI classification (~360m) Priority HOLD

### Spam Identification

**R77-RS-1. Unmatchable safe-sender patterns: validator check and seed fix (~45m) Priority 10**
- Phase: Spam Identification
- Platform: All
- Value: safe senders the user believes are protected are not protected; 23 of 426 seed patterns can never match.
- Prevention first: extend `PatternCompiler.validatePattern` with an "unmatchable" check (a second `@` after the
  local part, and similar impossible shapes) so the quick-add screen, the import path and any future generator
  share one gate; then fix the 23 seed patterns and check Harold's live database (a DB data migration if they are
  there).
- Control and screen: existing Safe Senders management screen and Import / Export YAML (warning shown on import).
- Privacy precondition: none. Parity: shared Dart.
- Depends on: none.

**R77-RS-2. Rule evaluation harness: score candidate rules against your own history, read only (~150m) Priority 20**
- Phase: Spam Identification
- Platform: All (Windows DEV for the dry run)
- Value: no proposed rule or score acts on mail until measured; the bar is zero safe-sender hits and precision of
  at least 0.99 (Section 4.8).
- Scope: a Dart CLI in `scripts/` that loads candidate YAML plus an exported database copy and reports precision,
  safe-sender false positives and recall; reuses `RuleEvaluator` and `PatternCompiler` unchanged.
- Control and screen: developer tool (no app UI); results feed RS-3 to RS-7.
- Privacy precondition: none (reads data already on Harold's PC). Parity: N/A (developer tool), engine code shared.
- Depends on: none.

**R77-RS-3. PC-side rule miner: deleted-mail history to candidate delete rules (YAML) (~180m) Priority 22**
- Phase: Spam Identification
- Platform: N/A (developer tool on Harold's PC); output imported on All
- Value: closes the corpus gap (zero subject and body rules today) with known bad domains, subject regex and body
  regex mined from Harold's partial deleted-mail history, without the app storing any new content.
- Scope: script in `scripts/` reads Harold's exported deleted-mail history, mines recurring domains, subject
  phrases and body phrases, writes candidate YAML in `docs/RULE_FORMAT.md` shape, validated by RS-1 and scored by
  RS-2 before import.
- Control and screen: Settings > Import / Export YAML (merge via RS-4, or export-merge-import until RS-4 ships).
- Privacy precondition: content stays on Harold's PC; rules derived from his Gmail data must not be bundled into
  the shipped seed until the open legal question in Section 4.7 is settled (Class-1 if bundling is proposed).
- Depends on: RS-1, RS-2.

**R77-RS-4. YAML import merge mode (add without replacing) (~90m) Priority 24**
- Phase: Spam Identification
- Platform: All
- Value: mined or shared rule files can be added without wiping the user's rules (import today replaces all).
- Scope: a "Merge" choice beside "Replace" on import; duplicates resolved by the existing
  `manual_rule_duplicate_checker` / `rule_conflict_detector` services; every new pattern passes RS-1.
- Control and screen: Settings > Import / Export YAML, import confirmation dialog.
- Decision class: Class-2 (changes import semantics; replace stays the default).
- Privacy precondition: none. Parity: shared Dart.
- Depends on: RS-1.

**R77-RS-5. Safe-sender discovery: propose safe senders from history for review (~150m) Priority 30**
- Phase: Spam Identification
- Platform: All
- Value: fewer false positives; senders the user trusts are protected before a broad rule catches them.
- Scope: v1 uses stored data only -- repeated No Rule senders that pass DMARC and were never deleted; v2 adds
  Sent-folder recipients (reply pairs). Candidates are listed for accept or reject; nothing is added silently.
  Device contacts are excluded (new permission, platform exception).
- Control and screen: a "Suggested safe senders" list on the Safe Senders management screen.
- Privacy precondition: v1 none; v2 adds the Sent folder to "What the app accesses" in the privacy policy.
- Parity: shared Dart. Depends on: RS-1, RS-2.

**R77-RS-6. Heuristic reasons and rule suggestions on No Rule Review (~210m) Priority 32**
- Phase: Spam Identification
- Platform: All
- Value: the user sees why an email looks like spam (Reply-To differs from From, auth failed, lookalike domain,
  bad TLD, bulk mail without unsubscribe) and gets a one-tap candidate rule.
- Scope: header-only signals computed at scan time from headers already fetched (no body fetch); shown as reason
  chips; "Create rule" opens the existing quick-add screen prefilled. Signals never act on mail by themselves.
  Two-header comparisons are computed in Dart, not added to the YAML grammar (a grammar change would be Class-2).
- Control and screen: No Rule Review screen, per-email reason chips and a "Create rule" action.
- Privacy precondition: none if signals are computed and shown, not stored; storing them is R76-4.
- Parity: shared Dart. Depends on: RS-2.

**R77-RS-8. Privacy policy and Data safety revision for the content history and learning (~60m) Priority 40**
- Phase: Spam Identification
- Platform: All (one policy; Play and Microsoft Store)
- Value: keeps the published policy true before any build stores more content or learns from it.
- Scope: the rewrites listed in Section 4.7 "Exactly what would change"; cite the Workspace policy; re-run
  `data_safety_declarations_test.dart`; Play Data safety stays "No" while nothing leaves the device.
- Control and screen: N/A (documents and the website).
- Depends on: Harold's Class-1 decision on R76-4 (and on RS-7 if it is selected); it is written before
  either ships.

**R77-RS-7. Per-user on-device spam classifier (pure Dart) ranking No Rule Review (~300m) Priority 42**
- Phase: Spam Identification
- Platform: All
- Value: learns each user's own spam from their own decisions and sorts likely spam to the top of review.
- Scope: hashed-token naive Bayes over From domain, subject and header tokens (body optional and off by default);
  trained incrementally on the device from the user's own actions; about 2 MiB of state; no new dependency
  (probe: about 161 microseconds per 1.2 kB text on the development laptop; Fold timing to measure first). The
  score ranks and suggests; it does not delete until it passes the RS-2 bar and Harold approves acting.
- Control and screen: Settings > General switch "Learn from my decisions" (off by default) and the No Rule Review
  sort order.
- Policy: inside the Workspace policy's "specific user's personalized model" carve-out; never trained on one
  user's data for another user.
- Privacy precondition: RS-8 published before a shipped build carries it. Parity: shared Dart.
- Depends on: R76-4 (labels), RS-2, RS-8. Decision class: Class-1 (new derived data store).
### HOLD Items (no viable runtime or contradicts the privacy posture)

**R77-RS-9. On-device GenAI rule explanations (~240m) Priority HOLD**
- Phase: Spam Identification
- Platform: All (would be two platform exceptions today)
- Why HOLD: Android ML Kit GenAI is foreground-only, Beta and absent from the Galaxy S24 family; Windows Phi
  Silica needs a Copilot+ NPU or a Developer Mode GPU path and is removed in January 2027; a bundled LLM costs a
  100+ MB download (size UNVERIFIED) under the Gemma pass-through terms.
- Revisit trigger: a GenAI API available to Store users on both platforms that runs in background work, or the
  Windows successor model (Aion Instruct) reaching retail with a non-Developer-Mode path.

**R77-RS-10. Cloud GenAI classification (~360m) Priority HOLD**
- Phase: Spam Identification
- Platform: All
- Why HOLD: sends personal mail content to a third party; contradicts four sentences of the privacy policy; flips
  Play Data safety to "Emails collected and shared"; Gmail data transfer limits; no server for key management.
  About $0.0002-$0.0006 per email (Section 4.4).
- Revisit trigger: Harold decides the product posture changes (Class-1), with an explicit per-user opt-in design.

---

## 6. R76-4 data-field recommendation

**Identity and de-duplication** [O]: one row per email per account, keyed on a SHA-256 hash of the RFC 5322
Message-ID (already captured as `email_actions.rfc5322_message_id`, F91) plus the account; fall back to provider
identifier + folder when the Message-ID is absent. This gives "no duplicate emails" across Windows and Android
scans and across folder moves.

**Store** (all already handled today in some table, so the privacy delta is retention, not kind):
- From address, From display name, Reply-To address, Return-Path domain
- Subject (normalized as `PatternNormalization.normalizeSubject` does)
- Received date, folder at first sight, account
- Auth classification (F96) and the presence (yes/no) of `List-Unsubscribe` / `List-Unsubscribe-Post`
- Outcome label: matched rule and pattern, action, and the user's final decision (deleted / kept / marked safe /
  rule created) with its date
- Source: scan type and platform (for Windows/Android parity analysis)
- Optional, Class-1 middle path: **hashed token counts** of the body (no text), which feed RS-7 without storing
  readable content. This still changes the privacy-policy wording (Section 4.7).

**Never store**:
- Full body text or HTML; attachments; images
- URLs with paths or query strings (they carry tracking tokens and personal identifiers); at most the URL domain
- Phone numbers, postal addresses, account or order numbers found in content
- Other recipients (To/Cc beyond the account owner), except the Sent-folder recipients RS-5 v2 needs, stored as
  candidate safe senders, not as message history
- Raw `Authentication-Results` header text (store the parsed class only)

**Retention** [O]: rows expire on a rolling window (365 days proposed), counted from the last time a scan saw the
email (the same rule Harold chose for No Rule rows, plan Q22); user deletion through "Remove an account" and
uninstall as today; model state (RS-7) is derived and deletable with the account.

**Seeding** (R76-4 text): from existing delete and safe-sender rules -- these give labeled *patterns*, not
emails, so they seed RS-2's expectations rather than R76-4 rows; Harold's deleted-mail history is processed on
his PC by RS-3 and enters the app as rules, not as stored messages.

---

## 7. ADR candidates

1. **Content history store and retention** (R76-4): fields, identity hash, retention, deletion; Class-1; requires
   RS-8 before shipping.
2. **Candidate-rule pipeline**: heuristics, miners and classifiers only *propose* YAML rules or rank review; only
   rules act on mail; one validator gate (RS-1) for every generated pattern. Records the prevention-first choice
   of extending the regex engine over a parallel scoring engine.
3. **On-device learning and the personalized-model boundary**: per-user, on-device, never shared; cites the
   Workspace AI/ML clause.
4. **Off-device processing and third-party lookups**: records that RDAP, DNSBL and cloud LLM calls are excluded
   under the current posture, and what would have to change to allow them.
5. **On-device model runtime as a platform exception** (only if RS-9 leaves HOLD): ADR-0042 exception text for
   Android ML Kit GenAI and Windows AI APIs.

---

## 8. Decision-class flags for later

- **Class-1**: R76-4 content store beyond the 100-character preview; RS-7 derived model state; any off-device
  processing (RS-10, RDAP/DNSBL lookups); any new OAuth scope; bundling rules derived from Gmail data into the
  shipped seed.
- **Class-2**: RS-4 import merge semantics; any change to the YAML grammar (for example a two-header comparison
  condition or a score threshold condition); how generated rules are named and ordered.

## 9. Open questions (with the source that would settle each)

1. Do the 23 unmatchable safe-sender patterns exist in Harold's live database? -- export via Settings > Import /
   Export YAML and count.
2. Real per-email classifier time on the Fold8 Ultra -- run the probe in an Android debug build.
3. Does the Gmail API return every header with `format: 'metadata'` and no `metadataHeaders`? -- the
   `users.messages.get` reference page.
4. May a publicly distributed personal email client use Spamhaus public mirrors? -- written answer from Spamhaus.
5. Does a sender-domain-only lookup count as "Emails" collected for Play Data safety? -- Play Console help or
   support.
6. Were any bundled seed rules derived from Gmail API data, and does a domain pattern count as user data under
   Limited Use? -- Harold's history of the seed plus Google's Limited Use FAQ.
7. Gemma 3 270M INT4 file size and Windows LiteRT-LM performance -- the model card on Kaggle or Hugging Face and
   a probe (only if RS-9 leaves HOLD).
8. RTX 4070 Laptop VRAM on the development laptop -- `nvidia-smi`.
