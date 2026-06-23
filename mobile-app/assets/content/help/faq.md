Short answers to the questions that come up most often. Each entry below is independent; skim the headings and read the one you need.

## What is a TLD (Top-Level Domain)?

A TLD is the last label of a domain name -- the part after the final dot. Examples are `.com`, `.uk`, and `.xyz`. In an email address such as `sales@store.example.xyz`, the TLD is `xyz`.

A Top-Level Domain block rule matches every sender whose address ends in that TLD. For example, a rule for `.xyz` generates the pattern `@.*\.xyz$`, which blocks `a@anything.xyz`, `b@store.xyz`, and so on.

Blocking a whole TLD is heavy-handed because it stops mail from every domain that uses it, including legitimate senders you have never seen. Use it only for a TLD that is overwhelmingly spam in your inbox. When a single bad domain is the problem, prefer an Entire Domain rule instead, which blocks only that domain and its subdomains.

## What is the IANA TLD list and why does the app use it?

IANA (the Internet Assigned Numbers Authority) is the body that maintains the official registry of valid top-level domains. The app ships a copy of that list and checks any domain or TLD you enter against it.

This rejects fake TLDs such as `.com444` or a typo like `.cmo` before they ever reach the rule engine, so you do not silently create a rule that can never match. The app does not contact IANA at runtime; the list is bundled in the app and refreshed when the app is updated.

If a genuinely new TLD is rejected because the bundled list predates it, the app simply needs an update that refreshes the list. You can report the missing TLD at github.com/kimmeyh/spamfilter-multi/issues.

## What is the difference between Entire Domain, Exact Domain, Exact Email, and Top-Level Domain?

These are the four rule types on the Add Block Rule screen. Each builds a different pattern from your input.

- Entire Domain (input `example.com`): blocks the domain and all of its subdomains. Matches `a@example.com` and `a@mail.example.com`. Does not match `a@notexample.com`.
- Exact Domain (input `example.com`): blocks only that exact domain. Matches `a@example.com`. Does not match `a@mail.example.com`.
- Exact Email (input `spam@example.com`): blocks one specific address. Matches `spam@example.com`. Does not match `other@example.com`.
- Top-Level Domain (input `.xyz`): blocks every sender ending in that TLD. Matches `a@anything.xyz` and `b@store.xyz`. Does not match `a@example.com`.

Choose the narrowest type that stops the unwanted mail. Most of the time Entire Domain is the right balance.

## What is a Safe Sender?

A safe sender is an address or domain you always want to receive. Safe senders are a whitelist: they are checked before any block rule, and a match bypasses every block rule. Ordering among safe senders does not matter.

Use a safe sender when a block rule is too broad and catches mail you want. For example, if you block an Entire Domain but one address on that domain is legitimate, add that address as an Exact Email safe sender; it wins over the block rule. Manage these on the Manage Safe Senders screen.

## Why does the scanner skip some emails?

Three settings control what the scanner touches:

- Scan mode: the default is read-only (a dry run). In read-only mode the scanner reports what it would delete or move but changes nothing. Switch to an action mode in Settings to actually delete or move matched emails.
- Folders: the scanner only reads the folders configured for the account. Mail in folders you have not selected is not scanned.
- Date window (daysBack): the scan only looks back a configured number of days. Emails older than that window are skipped. A value of 0 means scan all emails regardless of age.

If mail you expected to be acted on was untouched, check these three settings first.

## What does "ReDoS" mean and why was my pattern rejected?

ReDoS stands for "Regular expression Denial of Service". Certain regex shapes -- especially nested quantifiers such as `(a+)+` or overlapping alternation -- can make the matching engine try an explosive number of combinations on some inputs. This is called catastrophic backtracking, and it can freeze the scanner for seconds or longer on a single email.

To prevent that, the app checks every pattern you save and rejects ones that match these dangerous shapes. If your pattern was rejected, simplify it: remove a nested quantifier, tighten the part that can repeat, or replace a broad `.*` inside a group with something more specific. The rules created through the guided Add Block Rule screen are always safe, so use that screen if you are unsure.

## Where is my data stored?

Everything stays on your own device. The app keeps no servers and sends no telemetry; your rules, credentials, and scan history never leave your machine.

On Windows the data lives under your AppData folder:

- Production: `C:\Users\<you>\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter\`
- Development: `C:\Users\<you>\AppData\Roaming\MyEmailSpamFilter\MyEmailSpamFilter_Dev\`

That directory holds the database (`spam_filter.db`), your rules, saved credentials, scan logs, and settings. The "Delete All App Data" button in Settings wipes all of it. On other platforms the app uses the equivalent per-user application-support directory.

## How do I export and re-import my rules?

Open Settings, go to the General tab, and tap "Import / Export YAML". That screen lets you export your current block rules and safe senders to a YAML file, and import rules from a YAML file back into the app.

Use export to back up your rules or move them to another device, and import to restore them or to load a shared rule set. Exported files are plain text in the documented YAML rule format, so you can review or edit them before importing.
