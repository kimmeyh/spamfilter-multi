// ignore_for_file: avoid_print

/// Unit tests for Sprint 40 F37 folder-tree and single-select reorder logic.
///
/// Tests:
///   Part A -- groupFoldersForTree (depth-2 tree grouping)
///   Part B -- reorderForSingleSelect (canonical default first)
///   Part C -- FolderInfo.hierarchyDelimiter field (default + explicit)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';
import 'package:my_email_spam_filter/ui/screens/folder_selection_screen.dart';

/// Helper to build a [FolderInfo] with minimal required fields.
FolderInfo _folder({
  required String id,
  required String displayName,
  CanonicalFolder canonicalName = CanonicalFolder.custom,
  String hierarchyDelimiter = '/',
}) {
  return FolderInfo(
    id: id,
    displayName: displayName,
    canonicalName: canonicalName,
    hierarchyDelimiter: hierarchyDelimiter,
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // Part C -- FolderInfo.hierarchyDelimiter field
  // ---------------------------------------------------------------------------
  group('FolderInfo - hierarchyDelimiter field (Part C)', () {
    test('Default delimiter is "/" for backward compatibility', () {
      final folder = FolderInfo(
        id: 'inbox',
        displayName: 'Inbox',
        canonicalName: CanonicalFolder.inbox,
      );
      expect(folder.hierarchyDelimiter, equals('/'),
          reason: 'FolderInfo must default to "/" so existing callers are not broken');
    });

    test('Explicit delimiter is preserved', () {
      final folder = FolderInfo(
        id: 'work.projects',
        displayName: 'Work.Projects',
        canonicalName: CanonicalFolder.custom,
        hierarchyDelimiter: '.',
      );
      expect(folder.hierarchyDelimiter, equals('.'));
    });

    test('Colon delimiter is preserved (some Dovecot servers)', () {
      final folder = FolderInfo(
        id: 'personal:archive',
        displayName: 'personal:archive',
        canonicalName: CanonicalFolder.archive,
        hierarchyDelimiter: ':',
      );
      expect(folder.hierarchyDelimiter, equals(':'));
    });

    test('isWritable still defaults to true when hierarchyDelimiter added', () {
      final folder = FolderInfo(
        id: 'test',
        displayName: 'Test',
        canonicalName: CanonicalFolder.custom,
      );
      expect(folder.isWritable, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Part A -- groupFoldersForTree
  // ---------------------------------------------------------------------------
  group('groupFoldersForTree - two-level tree grouping (Part A)', () {
    test('Root-level folders (no delimiter) are placed under empty-string key', () {
      final folders = [
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk),
        _folder(id: 'trash', displayName: 'Trash', canonicalName: CanonicalFolder.trash),
      ];
      final groups = groupFoldersForTree(folders);

      expect(groups.containsKey(''), isTrue,
          reason: 'Root-level folders must be in the "" bucket');
      expect(groups['']!.length, equals(3));
      expect(groups.keys.where((k) => k != ''), isEmpty,
          reason: 'No parent buckets should exist when all folders are root-level');
    });

    test('Nested folder is placed under its parent key', () {
      final folders = [
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: '[Gmail]/Spam', displayName: '[Gmail]/Spam'),
        _folder(id: '[Gmail]/Trash', displayName: '[Gmail]/Trash'),
        _folder(id: '[Gmail]/Sent', displayName: '[Gmail]/Sent'),
      ];
      final groups = groupFoldersForTree(folders);

      // Inbox is root-level
      expect(groups['']!.map((f) => f.displayName), contains('Inbox'));

      // Gmail children are grouped under '[Gmail]'
      expect(groups.containsKey('[Gmail]'), isTrue);
      final gmailChildren = groups['[Gmail]']!.map((f) => f.displayName).toList();
      expect(gmailChildren, containsAll(['[Gmail]/Spam', '[Gmail]/Trash', '[Gmail]/Sent']));
    });

    test('Mixed root and nested folders are grouped correctly', () {
      final folders = [
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: 'bulk', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk),
        _folder(id: 'work/reports', displayName: 'Work/Reports'),
        _folder(id: 'work/invoices', displayName: 'Work/Invoices'),
        _folder(id: 'personal/family', displayName: 'Personal/Family'),
      ];
      final groups = groupFoldersForTree(folders);

      // Root-level: Inbox, Bulk Mail
      expect(groups['']!.length, equals(2));
      // Work children
      expect(groups['Work']!.length, equals(2));
      // Personal children
      expect(groups['Personal']!.length, equals(1));
    });

    test('Non-default delimiter (dot) is used for splitting', () {
      final folders = [
        _folder(id: 'INBOX', displayName: 'INBOX', canonicalName: CanonicalFolder.inbox, hierarchyDelimiter: '.'),
        _folder(id: 'INBOX.Spam', displayName: 'INBOX.Spam', hierarchyDelimiter: '.'),
        _folder(id: 'INBOX.Drafts', displayName: 'INBOX.Drafts', hierarchyDelimiter: '.'),
        _folder(id: 'Archive', displayName: 'Archive', hierarchyDelimiter: '.'),
      ];
      final groups = groupFoldersForTree(folders);

      // INBOX (root level, no dot) goes into '' bucket
      expect(groups['']!.any((f) => f.displayName == 'INBOX'), isTrue);
      // INBOX.Spam and INBOX.Drafts go under 'INBOX'
      expect(groups.containsKey('INBOX'), isTrue);
      expect(groups['INBOX']!.length, equals(2));
      // Archive (root level, no dot) also goes into '' bucket
      expect(groups['']!.any((f) => f.displayName == 'Archive'), isTrue);
    });

    test('Empty folder list returns empty map', () {
      final groups = groupFoldersForTree([]);
      expect(groups, isEmpty);
    });

    test('Single root-level folder maps to "" bucket with one entry', () {
      final folders = [
        _folder(id: 'inbox', displayName: 'INBOX', canonicalName: CanonicalFolder.inbox),
      ];
      final groups = groupFoldersForTree(folders);
      expect(groups.keys.length, equals(1));
      expect(groups['']!.length, equals(1));
    });

    test('Folder with delimiter only at end does not create spurious parent', () {
      // displayName that ends with delimiter but has no slash before end
      // Should still split: 'Work/' -> parent='Work', rest=''
      // This is an edge case from malformed server responses; the function
      // uses indexOf so it will find the first '/' and split there.
      final folder = _folder(id: 'work/', displayName: 'Work/');
      final groups = groupFoldersForTree([folder]);
      // 'Work/' has a '/' at index 4, so parent = 'Work'
      expect(groups.containsKey('Work'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Part B -- reorderForSingleSelect
  // ---------------------------------------------------------------------------
  group('reorderForSingleSelect - canonical default first (Part B)', () {
    test('INBOX appears first for Safe Sender use-case', () {
      final folders = [
        _folder(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk),
        _folder(id: 'sent', displayName: 'Sent', canonicalName: CanonicalFolder.sent),
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: 'drafts', displayName: 'Drafts', canonicalName: CanonicalFolder.drafts),
      ];
      final reordered = reorderForSingleSelect(folders);

      expect(reordered.first.canonicalName, equals(CanonicalFolder.inbox),
          reason: 'INBOX must be first in singleSelect mode (Safe Sender default)');
    });

    test('TRASH appears immediately after INBOX for Deleted Rule use-case', () {
      final folders = [
        _folder(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk),
        _folder(id: 'trash', displayName: 'Trash', canonicalName: CanonicalFolder.trash),
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: 'sent', displayName: 'Sent', canonicalName: CanonicalFolder.sent),
      ];
      final reordered = reorderForSingleSelect(folders);

      expect(reordered[0].canonicalName, equals(CanonicalFolder.inbox));
      expect(reordered[1].canonicalName, equals(CanonicalFolder.trash),
          reason: 'TRASH must follow INBOX (Deleted Rule default)');
    });

    test('Remaining folders are sorted alphabetically after INBOX and TRASH', () {
      final folders = [
        _folder(id: 'z', displayName: 'Zzz', canonicalName: CanonicalFolder.custom),
        _folder(id: 'a', displayName: 'Aaa', canonicalName: CanonicalFolder.custom),
        _folder(id: 'trash', displayName: 'Trash', canonicalName: CanonicalFolder.trash),
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
        _folder(id: 'm', displayName: 'Mmm', canonicalName: CanonicalFolder.custom),
      ];
      final reordered = reorderForSingleSelect(folders);

      expect(reordered[0].displayName, equals('Inbox'));
      expect(reordered[1].displayName, equals('Trash'));
      expect(reordered[2].displayName, equals('Aaa'));
      expect(reordered[3].displayName, equals('Mmm'));
      expect(reordered[4].displayName, equals('Zzz'));
    });

    test('No INBOX in list -- TRASH appears first, rest alphabetical', () {
      final folders = [
        _folder(id: 'z', displayName: 'Zzz', canonicalName: CanonicalFolder.custom),
        _folder(id: 'trash', displayName: 'Trash', canonicalName: CanonicalFolder.trash),
        _folder(id: 'a', displayName: 'Aaa', canonicalName: CanonicalFolder.custom),
      ];
      final reordered = reorderForSingleSelect(folders);

      expect(reordered[0].canonicalName, equals(CanonicalFolder.trash));
      expect(reordered[1].displayName, equals('Aaa'));
      expect(reordered[2].displayName, equals('Zzz'));
    });

    test('No INBOX and no TRASH -- all folders sorted alphabetically', () {
      final folders = [
        _folder(id: 'z', displayName: 'Zzz', canonicalName: CanonicalFolder.custom),
        _folder(id: 'a', displayName: 'Aaa', canonicalName: CanonicalFolder.custom),
        _folder(id: 'm', displayName: 'Mmm', canonicalName: CanonicalFolder.sent),
      ];
      final reordered = reorderForSingleSelect(folders);

      expect(reordered[0].displayName, equals('Aaa'));
      expect(reordered[1].displayName, equals('Mmm'));
      expect(reordered[2].displayName, equals('Zzz'));
    });

    test('Empty list returns empty list', () {
      expect(reorderForSingleSelect([]), isEmpty);
    });

    test('Single INBOX folder returns list with that folder', () {
      final folders = [
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
      ];
      final reordered = reorderForSingleSelect(folders);
      expect(reordered.length, equals(1));
      expect(reordered.first.canonicalName, equals(CanonicalFolder.inbox));
    });

    test('Reorder does not mutate the original list', () {
      final original = [
        _folder(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk),
        _folder(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox),
      ];
      final copy = List<FolderInfo>.from(original);
      reorderForSingleSelect(original);
      // Original should be unchanged
      expect(original[0].displayName, equals(copy[0].displayName));
      expect(original[1].displayName, equals(copy[1].displayName));
    });
  });
}
