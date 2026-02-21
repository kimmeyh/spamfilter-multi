# Issue #138: Provider API Research for Email Flagging

**Date**: February 9, 2026
**Sprint**: 14
**Task**: Research provider-specific flagging/labeling methods for deleted emails

## Summary

This document outlines how each email provider supports flagging, tagging, or labeling emails with custom metadata (specifically rule names that triggered deletion).

---

## Gmail (Labels API)

### Current Implementation
- **File**: `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`
- **Package**: `googleapis/gmail/v1.dart`
- **Method**: Gmail Labels API

### Flagging Mechanism: Labels
Gmail uses **labels** (not traditional IMAP flags) as its primary organization method.

### API Operations
- **Modify Message**: `messages.modify()` endpoint
- **Add Labels**: `addLabelIds: ['LABEL_ID']`
- **Remove Labels**: `removeLabelIds: ['LABEL_ID']`
- **List Labels**: `users.labels.list()`
- **Create Label**: `users.labels.create()`

### Current Usage in Codebase
```dart
// Line 305-306: Moving to trash
addLabelIds: [targetLabel],
removeLabelIds: ['INBOX', 'UNREAD'],

// Line 634: Mark as read
removeLabelIds: ['UNREAD'],
```

### Implementation Plan for Rule Flagging
1. **Create Label** (if not exists):
   ```dart
   final label = gmail.Label()
     ..name = 'SpamFilter/$ruleName'
     ..labelListVisibility = 'labelShow'
     ..messageListVisibility = 'show';
   await _gmailApi!.users.labels.create(label, 'me');
   ```

2. **Apply Label** to deleted email:
   ```dart
   await _gmailApi!.users.messages.modify(
     gmail.ModifyMessageRequest(addLabelIds: [labelId]),
     'me',
     messageId,
   );
   ```

### Limitations
- **Label Name**: Max 225 characters
- **Nested Labels**: Supported via `/` separator (e.g., `SpamFilter/RuleName`)
- **Special Characters**: Alphanumeric, spaces, `_`, `-`, `/` allowed
- **Rate Limits**: 250 quota units per second per user

### User Experience
- Labels appear in Gmail sidebar
- Can filter emails by label
- Color-coded labels supported

---

## Generic IMAP (Keywords/Flags)

### Current Implementation
- **File**: `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart`
- **Package**: `enough_mail` (pub.dev)
- **Method**: IMAP protocol

### Flagging Mechanism: Keywords
IMAP supports **custom keywords** via the `STORE` command.

### Standard IMAP Flags
- `\Seen` - Mark as read
- `\Flagged` - Star/flag message
- `\Deleted` - Mark for deletion
- `\Draft` - Draft message
- `\Answered` - Replied to

### Custom Keywords
IMAP allows custom keywords (server-dependent):
```
STORE <message-id> +FLAGS ($CustomKeyword)
```

### Implementation Plan for Rule Flagging
1. **Mark as Read**:
   ```dart
   await _imapClient!.store(
     MessageSequence.fromId(messageId),
     [MessageFlags.seen],
     action: StoreAction.add,
   );
   ```

2. **Add Custom Keyword**:
   ```dart
   final keyword = 'SpamFilter-${ruleName.replaceAll(' ', '_')}';
   await _imapClient!.store(
     MessageSequence.fromId(messageId),
     [keyword],
     action: StoreAction.add,
     silent: false,
   );
   ```

### Limitations
- **Server Support**: Not all IMAP servers support custom keywords
- **Keyword Format**: Usually `$Keyword` or just `Keyword` (server-dependent)
- **Name Restrictions**: No spaces (use underscores or hyphens)
- **Max Length**: Server-dependent (typically 32-64 characters)
- **Detection**: Check PERMANENTFLAGS response for `\*` (indicates custom keywords allowed)

### User Experience
- Keywords visible in IMAP clients (Thunderbird, Outlook via IMAP)
- Not visible in webmail for most providers
- Some clients show keywords as tags

---

## AOL (IMAP Keywords)

### Current Implementation
- **File**: Same as Generic IMAP (`generic_imap_adapter.dart`)
- **Package**: `enough_mail`
- **Method**: IMAP protocol

### Flagging Mechanism
AOL uses IMAP protocol, so same as Generic IMAP above.

### AOL-Specific Considerations
- **Webmail UI**: AOL webmail may not show custom IMAP keywords
- **Categories**: AOL does not have a public "Categories API" (unlike Outlook)
- **Best Approach**: Use IMAP keywords (works in desktop clients)

### Implementation Plan
Same as Generic IMAP - use custom keywords via IMAP `STORE` command.

---

## Outlook/Office 365 (Categories - Future)

### Current Status
Outlook adapter not yet implemented in this project.

### Flagging Mechanism: Categories
Outlook uses **Categories** for custom tagging.

### API
- **Microsoft Graph API**: `/messages/{id}/categories`
- **Add Category**: POST to `/messages/{id}/categories` with category name
- **List Categories**: GET `/me/outlook/masterCategories`

### Implementation (Future Sprint)
When Outlook adapter is added:
```dart
// Microsoft Graph API call
await graphClient.users['me'].messages[messageId].categories.add({
  'displayName': 'SpamFilter - $ruleName'
});
```

### Limitations
- **Category Name**: Max 255 characters
- **Predefined Categories**: 25 default categories (can be customized)
- **Custom Categories**: Unlimited

---

## Comparison Table

| Provider | Mechanism | Max Name Length | Special Chars | Webmail Visible | Desktop Client Visible |
|----------|-----------|----------------|---------------|-----------------|----------------------|
| **Gmail** | Labels | 225 chars | Yes (most) | ✅ Yes | ✅ Yes (via IMAP) |
| **IMAP** | Keywords | 32-64 chars* | Limited | ❌ No (usually) | ✅ Yes (some clients) |
| **AOL** | IMAP Keywords | 32-64 chars* | Limited | ❌ No | ✅ Yes (Thunderbird, etc.) |
| **Outlook** | Categories | 255 chars | Yes | ✅ Yes (future) | ✅ Yes (future) |

*Server-dependent

---

## Recommendations

### Gmail
✅ **Use Labels API** - Full featured, well supported, visible in all Gmail clients.

**Implementation**:
- Create nested label: `SpamFilter/{RuleName}`
- Apply label when moving to deleted folder
- Label persists with email

### Generic IMAP
⚠️ **Use Keywords with Fallback** - Limited server support, may not work everywhere.

**Implementation**:
- Check `PERMANENTFLAGS` for `\*` (custom keywords supported)
- If supported: Add keyword `SpamFilter-{RuleName}`
- If not supported: Log warning, skip flagging (mark-as-read still works)
- Sanitize rule name: Replace spaces with underscores, limit length to 32 chars

### AOL
⚠️ **Same as Generic IMAP** - Use IMAP keywords, limited webmail visibility.

**Implementation**:
- Same as Generic IMAP (AOL uses standard IMAP)
- Works in desktop clients (Thunderbird, Apple Mail)
- May not show in AOL webmail

---

## Edge Cases

### Long Rule Names
- **Gmail**: Truncate to 200 chars (leave room for `SpamFilter/` prefix)
- **IMAP**: Truncate to 30 chars (safe for most servers)

### Special Characters
- **Gmail**: Replace `/` with `-` in rule name (avoid nested label confusion)
- **IMAP**: Replace spaces with `_`, remove special chars

### Multiple Rules Match
- Current design: Only first matched rule captured
- Solution: Use first matched delete rule name

### Server Doesn't Support Keywords (IMAP)
- Detect via PERMANENTFLAGS response
- Log warning to user
- Continue with mark-as-read only
- Do not fail the operation

---

## Implementation Priority

1. **Task B**: Mark as Read (all providers) - 2-3h
2. **Task C**: Capture Rule Name - 1-2h
3. **Task D**: Implement Flagging
   - Gmail Labels - 2-3h
   - IMAP Keywords (with detection) - 2-3h

**Total**: 7-11 hours

---

## Testing Strategy

### Gmail
- Create test rule "TestSpamRule"
- Trigger deletion
- Verify in Gmail webmail:
  - Email moved to trash (or custom folder)
  - Email marked as read
  - Label "SpamFilter/TestSpamRule" applied
  - Label visible in sidebar

### IMAP (AOL, Generic)
- Create test rule "TestSpamRule"
- Trigger deletion
- Check IMAP capabilities first
- Verify in Thunderbird:
  - Email moved to folder
  - Email marked as read
  - Keyword visible as tag (if supported)

---

## References

- **Gmail API**: https://developers.google.com/gmail/api/reference/rest/v1/users.messages/modify
- **Gmail Labels**: https://developers.google.com/gmail/api/reference/rest/v1/users.labels
- **IMAP RFC 3501**: https://tools.ietf.org/html/rfc3501 (Section 6.4.6 STORE)
- **enough_mail package**: https://pub.dev/packages/enough_mail
- **Microsoft Graph**: https://learn.microsoft.com/en-us/graph/api/message-post-categories

---

## Next Steps

1. ✅ Task A Complete - Research documented
2. ⏭️ Task B - Implement mark-as-read for all providers
3. ⏭️ Task C - Ensure rule name captured in evaluation
4. ⏭️ Task D - Implement flagging (Gmail labels, IMAP keywords)
5. ⏭️ Task E - Integration testing

