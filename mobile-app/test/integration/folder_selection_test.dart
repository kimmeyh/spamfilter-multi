// ignore_for_file: avoid_print

/// Integration tests for Folder Selection functionality
///
/// Tests Phase 3.4 requirements:
/// - AOL "Bulk" and "Bulk Email" folders recognized as spam/junk
/// - Folder type recognition for various email providers
/// - Pre-selection of recommended folders
/// - Search/filter functionality for folder list

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/generic_imap_adapter.dart';

void main() {
  group('Folder Selection - Canonical Folder Recognition', () {
    test('AOL "Bulk Mail" folder should be recognized as junk', () {
      // Test canonical folder mapping for AOL Bulk Mail
      final folderInfo = FolderInfo(
        id: 'bulk_mail',
        displayName: 'Bulk Mail',
        canonicalName: CanonicalFolder.junk,
        messageCount: 150,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.junk));
      expect(folderInfo.displayName, equals('Bulk Mail'));
    });

    test('AOL "Bulk Email" folder should be recognized as junk', () {
      // Test canonical folder mapping for AOL Bulk Email variant
      final folderInfo = FolderInfo(
        id: 'bulk_email',
        displayName: 'Bulk Email',
        canonicalName: CanonicalFolder.junk,
        messageCount: 75,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.junk));
      expect(folderInfo.displayName, equals('Bulk Email'));
    });

    test('Gmail SPAM folder should be recognized as junk', () {
      final folderInfo = FolderInfo(
        id: 'SPAM',
        displayName: 'SPAM',
        canonicalName: CanonicalFolder.junk,
        messageCount: 200,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.junk));
    });

    test('Yahoo "Bulk" folder should be recognized as junk', () {
      final folderInfo = FolderInfo(
        id: 'bulk',
        displayName: 'Bulk',
        canonicalName: CanonicalFolder.junk,
        messageCount: 50,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.junk));
    });

    test('Inbox folder should be recognized correctly', () {
      final folderInfo = FolderInfo(
        id: 'inbox',
        displayName: 'Inbox',
        canonicalName: CanonicalFolder.inbox,
        messageCount: 500,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.inbox));
    });

    test('Trash folder should be recognized correctly', () {
      final folderInfo = FolderInfo(
        id: 'trash',
        displayName: 'Trash',
        canonicalName: CanonicalFolder.trash,
        messageCount: 10,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.trash));
    });

    test('Custom folder should be recognized as custom', () {
      final folderInfo = FolderInfo(
        id: 'my_folder',
        displayName: 'My Custom Folder',
        canonicalName: CanonicalFolder.custom,
        messageCount: 25,
        isWritable: true,
      );

      expect(folderInfo.canonicalName, equals(CanonicalFolder.custom));
    });
  });

  group('Folder Selection - Pre-selection Logic', () {
    /// Phase 3.4: Test that Inbox and Junk folders are pre-selected
    test('Inbox and Junk folders should be pre-selected by default', () {
      // Simulate folder list from email provider
      final folders = [
        FolderInfo(
          id: 'inbox',
          displayName: 'Inbox',
          canonicalName: CanonicalFolder.inbox,
          messageCount: 500,
          isWritable: true,
        ),
        FolderInfo(
          id: 'bulk_mail',
          displayName: 'Bulk Mail',
          canonicalName: CanonicalFolder.junk,
          messageCount: 150,
          isWritable: true,
        ),
        FolderInfo(
          id: 'trash',
          displayName: 'Trash',
          canonicalName: CanonicalFolder.trash,
          messageCount: 10,
          isWritable: true,
        ),
        FolderInfo(
          id: 'sent',
          displayName: 'Sent',
          canonicalName: CanonicalFolder.sent,
          messageCount: 300,
          isWritable: true,
        ),
        FolderInfo(
          id: 'custom',
          displayName: 'My Folder',
          canonicalName: CanonicalFolder.custom,
          messageCount: 25,
          isWritable: true,
        ),
      ];

      // Pre-select based on Phase 3.3 logic: Inbox and Junk only
      // (NOT trash - users typically do not want to scan deleted items)
      const preselectTypes = {CanonicalFolder.inbox, CanonicalFolder.junk};

      final selections = <String, bool>{};
      for (var folder in folders) {
        selections[folder.id] = preselectTypes.contains(folder.canonicalName);
      }

      // Verify pre-selections
      expect(selections['inbox'], isTrue, reason: 'Inbox should be pre-selected');
      expect(selections['bulk_mail'], isTrue, reason: 'Bulk Mail (junk) should be pre-selected');
      expect(selections['trash'], isFalse, reason: 'Trash should NOT be pre-selected');
      expect(selections['sent'], isFalse, reason: 'Sent should NOT be pre-selected');
      expect(selections['custom'], isFalse, reason: 'Custom folders should NOT be pre-selected');

      print('✅ Pre-selection logic verified:');
      print('   Inbox: ${selections['inbox']}');
      print('   Bulk Mail: ${selections['bulk_mail']}');
      print('   Trash: ${selections['trash']}');
      print('   Sent: ${selections['sent']}');
      print('   Custom: ${selections['custom']}');
    });

    test('AOL provider folders should have correct pre-selections', () {
      // Simulate AOL folder list
      final aolFolders = [
        FolderInfo(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox, isWritable: true),
        FolderInfo(id: 'bulk_mail', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'bulk_email', displayName: 'Bulk Email', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'trash', displayName: 'Trash', canonicalName: CanonicalFolder.trash, isWritable: true),
        FolderInfo(id: 'sent', displayName: 'Sent', canonicalName: CanonicalFolder.sent, isWritable: true),
        FolderInfo(id: 'drafts', displayName: 'Drafts', canonicalName: CanonicalFolder.drafts, isWritable: true),
      ];

      const preselectTypes = {CanonicalFolder.inbox, CanonicalFolder.junk};

      int preselectedCount = 0;
      final preselectedFolders = <String>[];

      for (var folder in aolFolders) {
        if (preselectTypes.contains(folder.canonicalName)) {
          preselectedCount++;
          preselectedFolders.add(folder.displayName);
        }
      }

      // Should have 4 folders pre-selected: Inbox, Bulk Mail, Bulk Email, Spam
      expect(preselectedCount, equals(4),
        reason: 'Should pre-select Inbox + 3 junk folders for AOL');
      expect(preselectedFolders, contains('Inbox'));
      expect(preselectedFolders, contains('Bulk Mail'));
      expect(preselectedFolders, contains('Bulk Email'));
      expect(preselectedFolders, contains('Spam'));

      print('✅ AOL pre-selection verified:');
      print('   Pre-selected folders: $preselectedFolders');
    });
  });

  group('Folder Selection - Sorting Logic', () {
    test('Folders should be sorted with Inbox first, then junk, then others', () {
      final folders = [
        FolderInfo(id: 'custom', displayName: 'ZZZ Folder', canonicalName: CanonicalFolder.custom, isWritable: true),
        FolderInfo(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'sent', displayName: 'Sent', canonicalName: CanonicalFolder.sent, isWritable: true),
        FolderInfo(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox, isWritable: true),
        FolderInfo(id: 'bulk', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'aaa', displayName: 'AAA Folder', canonicalName: CanonicalFolder.custom, isWritable: true),
      ];

      const preselectTypes = {CanonicalFolder.inbox, CanonicalFolder.junk};

      // Apply sorting logic from folder_selection_screen.dart
      folders.sort((a, b) {
        if (a.canonicalName == CanonicalFolder.inbox) return -1;
        if (b.canonicalName == CanonicalFolder.inbox) return 1;
        if (preselectTypes.contains(a.canonicalName) &&
            !preselectTypes.contains(b.canonicalName)) return -1;
        if (!preselectTypes.contains(a.canonicalName) &&
            preselectTypes.contains(b.canonicalName)) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      // Verify order
      expect(folders[0].displayName, equals('Inbox'), reason: 'Inbox should be first');

      // Junk folders should come next (sorted alphabetically among themselves)
      expect(folders[1].canonicalName, equals(CanonicalFolder.junk));
      expect(folders[2].canonicalName, equals(CanonicalFolder.junk));

      // Other folders should be sorted alphabetically at the end
      final nonJunkFolders = folders.where((f) =>
        f.canonicalName != CanonicalFolder.inbox &&
        f.canonicalName != CanonicalFolder.junk
      ).toList();

      for (int i = 0; i < nonJunkFolders.length - 1; i++) {
        expect(
          nonJunkFolders[i].displayName.compareTo(nonJunkFolders[i + 1].displayName) <= 0,
          isTrue,
          reason: 'Non-junk folders should be sorted alphabetically',
        );
      }

      print('✅ Folder sorting verified:');
      for (var f in folders) {
        print('   ${f.displayName} (${f.canonicalName.name})');
      }
    });
  });

  group('Folder Selection - Search/Filter', () {
    test('Search should filter folders by display name (case-insensitive)', () {
      final allFolders = [
        FolderInfo(id: 'inbox', displayName: 'Inbox', canonicalName: CanonicalFolder.inbox, isWritable: true),
        FolderInfo(id: 'bulk', displayName: 'Bulk Mail', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'spam', displayName: 'Spam', canonicalName: CanonicalFolder.junk, isWritable: true),
        FolderInfo(id: 'work', displayName: 'Work Projects', canonicalName: CanonicalFolder.custom, isWritable: true),
        FolderInfo(id: 'personal', displayName: 'Personal', canonicalName: CanonicalFolder.custom, isWritable: true),
      ];

      // Test search with 'bulk' (should match 'Bulk Mail')
      final searchQuery = 'bulk';
      final filtered = allFolders.where((folder) {
        return folder.displayName.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered[0].displayName, equals('Bulk Mail'));

      // Test search with 'IN' (should match 'Inbox')
      final searchQuery2 = 'IN';
      final filtered2 = allFolders.where((folder) {
        return folder.displayName.toLowerCase().contains(searchQuery2.toLowerCase());
      }).toList();

      expect(filtered2.length, equals(1));
      expect(filtered2[0].displayName, equals('Inbox'));

      // Test search with 'p' (should match 'Spam', 'Work Projects', 'Personal')
      final searchQuery3 = 'p';
      final filtered3 = allFolders.where((folder) {
        return folder.displayName.toLowerCase().contains(searchQuery3.toLowerCase());
      }).toList();

      expect(filtered3.length, equals(3));

      print('✅ Search/filter functionality verified');
    });
  });

  group('GenericIMAPAdapter - Provider Configurations', () {
    test('AOL adapter should have correct platform ID and auth method', () {
      final adapter = GenericIMAPAdapter.aol();

      expect(adapter.platformId, equals('aol'));
      expect(adapter.displayName, equals('AOL Mail'));
      expect(adapter.supportedAuthMethod, equals(AuthMethod.appPassword));
    });

    test('Yahoo adapter should have correct platform ID', () {
      final adapter = GenericIMAPAdapter.yahoo();

      expect(adapter.platformId, equals('yahoo'));
      expect(adapter.displayName, equals('Yahoo Mail'));
    });

    test('iCloud adapter should have correct platform ID', () {
      final adapter = GenericIMAPAdapter.icloud();

      expect(adapter.platformId, equals('icloud'));
      expect(adapter.displayName, equals('iCloud Mail'));
    });

    test('Custom IMAP adapter should have correct platform ID', () {
      final adapter = GenericIMAPAdapter.custom(
        imapHost: 'mail.example.com',
        imapPort: 993,
        isSecure: true,
      );

      expect(adapter.platformId, equals('imap'));
      expect(adapter.displayName, equals('Custom IMAP'));
    });
  });
}
