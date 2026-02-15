# ADR-0024: Canonical Folder Mapping

## Status

Accepted

## Date

~2026-01 (Sprint 3-4, expanded through Sprint 14)

## Context

Email providers use inconsistent names for equivalent folders:

| Folder Type | Gmail | AOL | Yahoo | Outlook | iCloud |
|-------------|-------|-----|-------|---------|--------|
| Junk/Spam | [Gmail]/Spam | Bulk Mail | Bulk | Junk Email | Junk |
| Trash | [Gmail]/Trash | Trash | Trash | Deleted Items | Trash |

The spam filter needs to identify junk/spam folders across all providers for two purposes:

1. **Default scan targets**: When a user adds an account, the app should automatically suggest which folders to scan for spam (INBOX + junk folders)
2. **Folder classification**: The results screen and settings need to distinguish between inbox, junk, and other folder types

If each adapter hardcodes its own folder names, adding or modifying folder mappings requires changes across multiple files. A centralized mapping provides a single source of truth.

## Decision

Implement a `JunkFolderConfig` class that maps 8 email providers to their canonical junk folder names, with support for alternative (legacy) folder names.

### Configuration Per Provider

Each provider has:
- **`providerId`**: Provider identifier (e.g., `'aol'`, `'gmail'`, `'outlook'`)
- **`defaultJunkFolders`**: Primary canonical names for junk-type folders
- **`alternativeFolderNames`**: Legacy or variant names for the same folder types

### Provider Mappings

| Provider | Default Junk Folders | Alternative Names |
|----------|---------------------|-------------------|
| AOL | Bulk Mail, Spam | Junk, Spam Folder, Bulk |
| Gmail | Spam, Trash | [Gmail]/Spam, [Gmail]/Trash, SPAM, TRASH |
| Yahoo | Bulk, Spam | Junk, Bulk Mail, Junk E-mail |
| Outlook | Junk Email, Spam, Trash | Junk, Deleted Items, [Outlook]/Junk |
| iCloud | Junk, Trash | Spam, Junk Mail, JUNK |
| ProtonMail | Spam, Trash | (none) |
| Generic IMAP | Spam, Junk, Trash | (none) |
| Custom IMAP | Spam, Junk, Trash | (none) |

### Lookup Behavior

`getCanonicalFolderName(providerId, folderName)`:
1. Case-insensitive match against `defaultJunkFolders` first
2. If no match, case-insensitive match against `alternativeFolderNames`
3. If matched via alternative name, returns the corresponding canonical name
4. If no match, returns null (folder is not a junk folder)

`isJunkFolder(providerId, folderName)`: Returns true if the folder matches any default or alternative name.

`getDefaultFoldersToScan(providerId)`: Always includes INBOX first, then the provider's default junk folders.

## Alternatives Considered

### User-Configured Folder Lists Only
- **Description**: No built-in mapping; users manually select which folders to scan from a dynamically fetched folder list
- **Pros**: Maximum flexibility; works with any provider; no maintenance of folder name mappings; users know their own folder structure
- **Cons**: Poor first-run experience (new users do not know which folders contain spam); every new account requires manual configuration; users may miss important junk folders they did not know existed
- **Why Rejected**: A reasonable default is essential for first-run experience. Users should see their junk folders pre-selected when adding an account, with the ability to override. The mapping provides sensible defaults while dynamic folder discovery (Issue #37) lets users add custom folders

### IMAP SPECIAL-USE Detection (RFC 6154)
- **Description**: Use the IMAP `SPECIAL-USE` extension to detect folder types (\Junk, \Trash, \Sent) directly from the server
- **Pros**: Authoritative; server declares folder purposes; no name-based guessing; works with renamed folders
- **Cons**: Not all IMAP servers support RFC 6154; Gmail's IMAP interface does not expose SPECIAL-USE attributes; requires an active IMAP connection (not available at configuration time); the extension was optional and adoption was inconsistent
- **Why Rejected**: SPECIAL-USE support is inconsistent across providers. Gmail (the primary provider) uses its native REST API, not IMAP, making SPECIAL-USE unavailable. The name-based mapping provides a reliable fallback that works for all providers regardless of IMAP extension support

### Hardcoded Per Adapter
- **Description**: Each adapter (GmailApiAdapter, GenericImapAdapter) maintains its own list of junk folder names
- **Pros**: Each adapter knows its own provider best; no shared configuration class; folder names co-located with provider logic
- **Cons**: Duplicate folder name lists across adapters (AOL adapter and Yahoo adapter may list "Spam" independently); adding a new folder name requires finding and modifying the right adapter; no unified lookup API for the UI; inconsistent behavior if adapters drift
- **Why Rejected**: Centralizing the mapping in `JunkFolderConfig` provides a single source of truth, a unified API for the UI (folder picker, default selection), and prevents drift between adapters

## Consequences

### Positive
- **Sensible defaults**: New accounts automatically suggest the right folders to scan, reducing configuration friction
- **Centralized maintenance**: Adding or modifying folder names for a provider requires changes in one file, not across multiple adapters
- **Alternative name support**: Legacy or variant folder names (e.g., Yahoo "Junk E-mail" vs "Bulk") are recognized without user intervention
- **Case-insensitive matching**: Folder names from different servers with different capitalization are handled correctly

### Negative
- **Static mapping**: New folder names from providers (e.g., if AOL renames "Bulk Mail") require a code update. There is no automatic discovery of name changes
- **8 providers to maintain**: Each provider's mapping must be verified and updated as providers evolve their folder naming
- **Does not handle custom folders**: User-created folders (e.g., "My Spam Filter Results") are not recognized by the mapping. Users must manually add these to their scan configuration

### Neutral
- **Dynamic folder discovery complements mapping**: Issue #37 added dynamic folder fetching from the server. The canonical mapping provides defaults; dynamic discovery shows the user all available folders. Together they cover both automatic and manual folder selection

## References

- `mobile-app/lib/adapters/email_providers/junk_folder_config.dart` - Canonical folder configuration (lines 1-181): provider mappings (49-102), canonical lookup (131-156), default folders to scan (165-169)
- ADR-0002 (Adapter Pattern) - Provider-agnostic interface that uses canonical folder types
- GitHub Issue #37 - Dynamic folder discovery (fetches real folders from server)
- GitHub Issue #48 - AOL Bulk/Bulk Email folder recognition
