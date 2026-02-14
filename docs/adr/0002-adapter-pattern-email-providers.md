# ADR-0002: Adapter Pattern for Email Providers

## Status

Accepted

## Date

~2025-10 (project inception, evolved through Sprint 8-11)

## Context

The spam filter must support multiple email providers that use fundamentally different protocols and APIs:

- **Gmail**: REST API with OAuth 2.0, uses labels instead of folders, batch operations via API
- **AOL/Yahoo/iCloud**: Standard IMAP protocol with app passwords, traditional folder hierarchy
- **Outlook.com**: Microsoft Graph API with MSAL authentication (deferred)
- **Custom IMAP servers**: User-configured IMAP with varying capabilities

Each provider has different authentication methods (OAuth, app passwords, basic auth), different folder semantics (labels vs. mailboxes), different message identifiers (Gmail message IDs vs. IMAP UIDs), and different batch operation capabilities.

The core spam filtering logic (rule evaluation, pattern matching, safe sender checking) must remain completely independent of these provider-specific details.

## Decision

Implement the Adapter pattern with a common `SpamFilterPlatform` abstract interface and provider-specific adapter implementations. A `PlatformRegistry` static factory manages adapter instantiation and discovery.

**Interface contract** (`SpamFilterPlatform`):
- **Metadata**: `platformId`, `displayName`, `supportedAuthMethod`
- **Connection**: `loadCredentials()`, `testConnection()`, `disconnect()`
- **Messaging**: `fetchMessages()`, `listFolders()`, `takeAction()`, `moveToFolder()`, `markAsRead()`, `applyFlag()`
- **Batch operations**: `markAsReadBatch()`, `moveToFolderBatch()`, `takeActionBatch()` (with `BatchOperationsMixin` fallback)
- **Rule evaluation**: `applyRules()` (defaults to client-side, platforms can override for server-side)

**Adapter implementations**:
- `GmailApiAdapter` - Gmail REST API with Google OAuth
- `GenericIMAPAdapter` - Shared IMAP implementation with factory constructors for AOL, Yahoo, iCloud, and custom servers
- `MockEmailProvider` - Demo mode with synthetic emails for testing

**Registry** (`PlatformRegistry`):
- Maps platform IDs to factory constructors
- Provides metadata (display name, auth method, setup instructions, phase)
- Supports phase-based feature rollout (Phase 1: Gmail+AOL, Phase 2: Yahoo, Phase 3: iCloud, Phase 4: Custom IMAP)

**Standardized exceptions**: `AuthenticationException`, `ConnectionException`, `FetchException`, `ActionException` provide consistent error handling across providers.

**Normalized data model**: `EmailMessage` with common fields (id, from, subject, body, headers, receivedDate, folderName) and `CanonicalFolder` enum (INBOX, JUNK, TRASH, SENT, DRAFTS, ARCHIVE, CUSTOM) abstract away provider-specific representations.

## Alternatives Considered

### IMAP-Only Implementation
- **Description**: Use IMAP protocol for all providers, including Gmail (which supports IMAP access)
- **Pros**: Single protocol implementation; simpler codebase; fewer dependencies
- **Cons**: Gmail IMAP has limitations compared to native API (no label management, slower, less reliable batch operations); loses Gmail-specific optimizations; OAuth for Gmail IMAP is more complex than REST API OAuth
- **Why Rejected**: Gmail is the primary provider and benefits significantly from its native REST API (label support, efficient batch operations, better OAuth integration). Forcing Gmail through IMAP would degrade the user experience for the majority of users

### Provider-Specific Code Paths Without Abstraction
- **Description**: Use if/else or switch statements throughout the codebase to handle provider differences
- **Pros**: Quick to implement initially; no abstraction overhead
- **Cons**: Business logic becomes tightly coupled to provider details; every new provider requires changes throughout the codebase; testing becomes harder (cannot mock a specific provider); violates Open/Closed Principle
- **Why Rejected**: As the number of providers grew from 1 (Gmail) to 5+ (Gmail, AOL, Yahoo, iCloud, custom IMAP), scattered provider-specific code would become unmaintainable. The adapter pattern isolates changes to a single adapter class

### Plugin/Module Architecture
- **Description**: Each email provider is a separately loadable plugin with dynamic registration
- **Pros**: Maximum extensibility; providers can be developed independently; could support community-contributed providers
- **Cons**: Significantly more complex infrastructure (dynamic loading, versioning, API stability guarantees); overkill for a known, bounded set of providers; Flutter does not have a mature plugin-at-runtime system
- **Why Rejected**: The set of email providers is well-known and bounded. A static factory registry (`PlatformRegistry`) provides the right level of extensibility without the complexity overhead of a full plugin system

## Consequences

### Positive
- **Provider-agnostic business logic**: RuleEvaluator, PatternCompiler, and EmailScanner work with normalized `EmailMessage` objects and never reference provider-specific APIs
- **Easy provider addition**: Adding a new email provider requires implementing the `SpamFilterPlatform` interface and registering it in `PlatformRegistry` - no changes to core logic
- **Per-provider optimization**: Gmail uses its native REST API with label management and batch operations; IMAP providers use UID-based operations with sequence sets for efficiency; each adapter can optimize for its protocol
- **Testability**: `MockEmailProvider` enables testing the entire scanning workflow without real email accounts; adapters can be individually unit tested
- **Phase-based rollout**: `PlatformRegistry` manages which providers are available in which development phase, enabling incremental delivery

### Negative
- **Interface breadth**: The `SpamFilterPlatform` interface must accommodate different authentication methods, folder semantics, and batch capabilities, making the interface broader than any single provider needs
- **Folder normalization complexity**: Mapping between provider-specific folder names (Gmail labels, AOL "Bulk Mail", Yahoo "Bulk", iCloud "Junk") and canonical folder types requires ongoing maintenance as providers change conventions
- **Batch operation inconsistency**: IMAP supports native batch operations via sequence sets, while Gmail API uses individual requests by default. The `BatchOperationsMixin` provides fallback but optimal batch strategies differ by provider

### Neutral
- **GenericIMAPAdapter serves multiple providers**: A single IMAP implementation with factory constructors (`aol()`, `yahoo()`, `icloud()`, `custom()`) reduces code duplication but means IMAP-provider-specific quirks must be handled with configuration rather than separate implementations
- **UID vs. sequence ID design**: GenericIMAPAdapter uses IMAP UIDs exclusively (not sequence IDs) to prevent the "100-delete bug" where sequence IDs shift after operations - this is a correctness decision within the adapter, not visible to the interface

## References

- `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart` - Abstract interface
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail implementation
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - IMAP implementation (AOL, Yahoo, iCloud, custom)
- `mobile-app/lib/adapters/email_providers/mock_email_provider.dart` - Demo/testing implementation
- `mobile-app/lib/adapters/email_providers/platform_registry.dart` - Factory registry
- `mobile-app/lib/core/models/email_message.dart` - Normalized email model
- `docs/ARCHITECTURE.md` - Architecture overview
- GitHub Issue #144 - Batch operations
- GitHub Issue #145 - IMAP UID stability
- GitHub Issue #138 - Enhanced actions (markAsRead, applyFlag)
