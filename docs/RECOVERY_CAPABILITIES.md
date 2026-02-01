# Recovery Capabilities Audit

**Purpose**: Documents recovery capabilities for all destructive email operations

**Audience**: Developers, QA testers, users concerned about data safety

**Last Updated**: February 1, 2026

---

## Executive Summary

**All destructive operations (delete, moveToJunk) are recoverable** - no permanent data loss occurs during spam filtering.

### Safety Summary

| Operation | Gmail | IMAP | Recoverable | Recovery Method |
|-----------|-------|------|-------------|-----------------|
| **Delete** | ✅ Trash API | ✅ Move to Trash | ✅ Yes | Restore from Trash folder within 30 days (Gmail) or provider retention period |
| **Move to Junk** | ✅ Label API | ✅ Move to Junk | ✅ Yes | Move email back from Junk folder to Inbox |
| **Mark as Read** | ✅ Modify API | ✅ STORE command | ✅ Yes | Mark as unread in email client |
| **Mark as Spam** | ✅ Modify API | ✅ STORE flag | ✅ Yes | Remove spam flag in email client |

---

## Delete Operation

### Gmail API Adapter

**File**: `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart:288`

**Implementation**:
```dart
await _gmailApi!.users.messages.trash('me', message.id);
```

**Safety Features**:
- Uses Gmail `trash()` API (NOT permanent delete API)
- Emails moved to Gmail Trash folder
- Recoverable for 30 days (Gmail default retention)
- User can restore from Trash via Gmail UI or API

**Critical Note**: The Gmail API provides two methods:
- `users.messages.trash()` - Moves to Trash (recoverable) ✅ USED
- `users.messages.delete()` - Permanent delete (NOT recoverable) ❌ NOT USED

### IMAP Adapter

**File**: `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:270-278`

**Implementation**:
```dart
case FilterAction.delete:
  // Move to Trash instead of permanent delete
  // This allows recovery if spam filter makes a mistake
  _logger.i('Moving message ${message.id} to Trash');
  await _imapClient!.move(
    sequence,
    targetMailboxPath: 'Trash',
  );
  break;
```

**Safety Features**:
- Uses IMAP `MOVE` command (NOT EXPUNGE)
- Emails moved to Trash folder
- Recoverable until user empties Trash
- No automatic permanent deletion

**Critical Note**: The IMAP protocol provides two approaches:
- `MOVE` command - Moves to Trash (recoverable) ✅ USED
- `EXPUNGE` command - Permanent delete (NOT recoverable) ❌ NOT USED

---

## Move to Junk Operation

### Gmail API Adapter

**File**: `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart`

**Implementation**:
```dart
// Adds "SPAM" label (Gmail's junk folder)
await _gmailApi!.users.messages.modify('me', message.id, ModifyMessageRequest()
  ..addLabelIds = ['SPAM']
);
```

**Safety Features**:
- Uses Gmail label API (adds SPAM label)
- Emails moved to Gmail Spam folder
- Recoverable indefinitely (until user deletes)
- User can restore by removing SPAM label

### IMAP Adapter

**File**: `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:280-286`

**Implementation**:
```dart
case FilterAction.moveToJunk:
  _logger.i('Moving message ${message.id} to Junk');
  await _imapClient!.move(
    sequence,
    targetMailboxPath: 'Junk',
  );
  break;
```

**Safety Features**:
- Uses IMAP `MOVE` command
- Emails moved to Junk folder
- Recoverable until user deletes from Junk
- No permanent data loss

---

## Mark as Read Operation

### Gmail API Adapter

**Safety**: Fully reversible - user can mark as unread in Gmail UI

### IMAP Adapter

**File**: `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:298-305`

**Implementation**:
```dart
case FilterAction.markAsRead:
  _logger.i('Marking message ${message.id} as read');
  await _imapClient!.store(
    sequence,
    [MessageFlags.seen],
    action: StoreAction.add,
  );
  break;
```

**Safety**: Fully reversible - user can mark as unread in email client

---

## Mark as Spam Operation

### IMAP Adapter

**File**: `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart:307-315`

**Implementation**:
```dart
case FilterAction.markAsSpam:
  // Some servers support custom flags
  _logger.i('Marking message ${message.id} as spam');
  await _imapClient!.store(
    sequence,
    [r'$Junk'],
    action: StoreAction.add,
  );
  break;
```

**Safety**: Fully reversible - user can remove spam flag in email client

---

## Test Coverage

### Integration Tests

**File**: `mobile-app/test/integration/delete_to_trash_test.dart`

**Coverage**:
- ✅ IMAP adapter moves to Trash (not EXPUNGE)
- ✅ Gmail adapter uses trash API (not permanent delete)
- ✅ Move to Junk uses move command (not copy+delete)

**File**: `mobile-app/test/integration/email_scanner_readonly_mode_test.dart`

**Coverage**:
- ✅ Readonly mode prevents all takeAction() calls
- ✅ Full scan mode allows takeAction() calls
- ✅ Test limit mode respects email limit

---

## Recovery Procedures

### Gmail

**Restore from Trash**:
1. Open Gmail web interface
2. Click "Trash" folder in left sidebar
3. Select deleted emails
4. Click "Move to Inbox" button
5. Emails restored to Inbox

**Restore from Spam**:
1. Open Gmail web interface
2. Click "Spam" folder in left sidebar
3. Select emails
4. Click "Not spam" button
5. Emails restored to Inbox

### IMAP Providers (AOL, Yahoo, etc.)

**Restore from Trash**:
1. Open email client (webmail or desktop)
2. Navigate to Trash folder
3. Select deleted emails
4. Move to Inbox (drag-and-drop or right-click menu)

**Restore from Junk**:
1. Open email client
2. Navigate to Junk/Spam folder
3. Select emails
4. Move to Inbox (drag-and-drop or right-click menu)

---

## Risk Assessment

### Current Risk Level: **LOW** ✅

**Reasons**:
1. All delete operations use recoverable methods (Trash/trash API)
2. No permanent delete operations (EXPUNGE, messages.delete()) in codebase
3. Integration tests verify safety features
4. Readonly mode prevents accidental execution during testing

### Historical Issues

**Issue #9 (Sprint 11)**: Readonly mode bypass
- **Problem**: Readonly mode was bypassed, causing 526 emails to be deleted during testing
- **Impact**: Emails moved to Trash (recoverable), not permanently deleted
- **Resolution**: Fixed in Sprint 11, integration test added to prevent regression
- **Key Learning**: Even with safety features (Trash vs permanent delete), readonly mode is critical for testing

---

## Recommendations

### Completed (Sprint 11)

1. ✅ **Integration Tests**: Created `delete_to_trash_test.dart` to verify safety features
2. ✅ **Readonly Mode Test**: Created `email_scanner_readonly_mode_test.dart` to prevent Issue #9 regression

### Future Enhancements

1. **User Confirmation**: Add confirmation dialog before full scan mode (already implemented in Sprint 11)
2. **Action Logging**: Log all destructive operations to database for audit trail
3. **Undo Functionality**: Add "Undo last scan" feature to restore all affected emails
4. **Trash Auto-Empty Prevention**: Warn user if provider is set to auto-empty Trash (Gmail 30-day retention)

---

## Conclusion

**All destructive operations in the spam filter are recoverable**. The application uses safe deletion methods (Trash folders, trash API) instead of permanent deletion (EXPUNGE, delete API). Users have 30 days (Gmail) or indefinite time (IMAP) to restore accidentally deleted emails from Trash.

**Critical Safety Features**:
- ✅ Gmail uses `trash()` API (not `delete()`)
- ✅ IMAP uses `MOVE` to Trash (not `EXPUNGE`)
- ✅ Integration tests verify safety
- ✅ Readonly mode prevents execution during testing
- ✅ Full scan mode has confirmation dialog

**Confidence Level**: **HIGH** - All code paths reviewed, tests passing, no permanent delete operations found.

---

## Version History

**Version**: 1.0
**Date**: February 1, 2026
**Author**: Claude Sonnet 4.5
**Status**: Active

**Updates**:
- 1.0 (2026-02-01): Initial recovery capabilities audit (Sprint 11 retrospective recommendation)
