Safe senders bypass all rules. Entries are regex patterns matched against the full sender string. Common shapes:
- Exact email: `^user@example\.com$`
- Domain + subdomains: `^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$`

Ordering does not matter; safe senders are checked before any block rule. ReDoS-vulnerable patterns are rejected on save.
