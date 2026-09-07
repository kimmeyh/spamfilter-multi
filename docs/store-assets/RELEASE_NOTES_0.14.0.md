# Store release notes -- 0.14.0

Paste into Partner Center: **Store listings -> English (United States) -> "What's new in this version"**.
The field only appears once a package is attached, so upload the MSIX and let validation finish first.

Written for Store users: user-visible behavior only. Internal work (the Android release chain,
build tooling, rule-database cleanup, test gates) is deliberately omitted as listing noise.

---

Block spam by phrase, not just by sender.

New in this version:

- Block by phrase. Manage Rules can now create a rule that matches a phrase anywhere in the message body, alongside the existing sender and domain rules. Type the phrase in plain language and the app builds the matching pattern for you.
- Body rules edit properly. Opening a phrase rule to change it now keeps it a phrase rule, and your edits save as you intend.
- Better duplicate detection. The app now recognises when you already have a rule for the same phrase, and no longer blocks a genuinely new rule that merely contains an underscore or a percent sign.
- Clearer rule health. A rule whose saved conditions are damaged is now flagged in Manage Rules instead of silently matching nothing.
