/// Folder Selection Screen for multi-folder email scanning
/// 
/// Allows users to select which folders to scan in their email account.
/// Supports:
/// - "Select All" checkbox for convenience
/// - Individual folder selection with checkboxes
/// - Provider-specific junk folder names
/// - One-time scan vs. scheduled recurring scans (future)
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Folder selection screen for email account
/// 
/// Displays available folders for the email account and allows user
/// to select which ones to scan. Supports multi-selection with "Select All" option.
class FolderSelectionScreen extends StatefulWidget {
  /// Email provider ID (e.g., 'aol', 'gmail', 'outlook')
  final String platformId;

  /// Account ID used for credential retrieval (e.g., 'aol-a@aol.com')
  final String accountId;

  /// Email address for display (e.g., 'a@aol.com')
  final String? accountEmail;

  /// Callback when folders are selected
  /// Returns list of selected folder names
  final Function(List<String>) onFoldersSelected;

  const FolderSelectionScreen({
    super.key,
    required this.platformId,
    required this.accountId,
    this.accountEmail,
    required this.onFoldersSelected,
  });

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  final Logger _logger = Logger();

  /// Provider-specific junk folder names
  /// ✨ PHASE 2 SPRINT 3: Multi-folder support per provider
  static const Map<String, List<String>> JUNK_FOLDERS_BY_PROVIDER = {
    'aol': ['Bulk Mail', 'Spam'],
    'gmail': ['Spam', 'Trash'],
    'outlook': ['Junk Email', 'Spam'],
    'yahoo': ['Bulk', 'Spam'],
    'icloud': ['Junk', 'Trash'],
  };

  late Map<String, bool> _selectedFolders;
  late List<String> _availableFolders;
  bool _selectAllChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeFolders();
  }

  /// Initialize folder list with provider-specific junk folders
  void _initializeFolders() {
    // Always include Inbox first
    _availableFolders = ['Inbox'];

    // Add provider-specific junk folders
    final junkFolders = JUNK_FOLDERS_BY_PROVIDER[widget.platformId] ?? ['Spam'];
    _availableFolders.addAll(junkFolders);

    // Initialize selection: Inbox selected by default, others unchecked
    _selectedFolders = {
      for (var folder in _availableFolders)
        folder: folder == 'Inbox'  // Only Inbox selected by default
    };

    _logger.i(
      'Initialized folders for ${widget.platformId}: $_availableFolders',
    );
  }

  /// Toggle all folders on/off
  void _toggleAll(bool value) {
    setState(() {
      _selectAllChecked = value;
      _selectedFolders.updateAll((_, __) => value);
    });

    _logger.d('Toggle all folders: $value');
  }

  /// Toggle individual folder
  void _toggleFolder(String folder, bool value) {
    setState(() {
      _selectedFolders[folder] = value;

      // Update "Select All" checkbox based on individual selections
      _selectAllChecked = _selectedFolders.values.every((v) => v);
    });

    _logger.d('Toggle folder "$folder": $value');
  }

  /// Get human-readable description for a folder
  String? _getFolderDescription(String folder) {
    if (folder == 'Inbox') {
      return 'Primary inbox for ${widget.platformId}';
    }

    // Check if this is a junk folder for the current provider
    final providerJunkFolders =
        JUNK_FOLDERS_BY_PROVIDER[widget.platformId] ?? [];
    if (providerJunkFolders.contains(folder)) {
      return 'Junk/Spam folder for ${widget.platformId}';
    }

    return null;
  }

  /// Get icon for folder type
  IconData _getFolderIcon(String folder) {
    if (folder == 'Inbox') {
      return Icons.inbox;
    }
    if (['Spam', 'Junk Email', 'Junk', 'Bulk Mail', 'Bulk', 'Spam'].
        contains(folder)) {
      return Icons.delete;
    }
    return Icons.folder;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Folders to Scan'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Account info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.email, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.platformId.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    if (widget.accountEmail != null)
                      Text(
                        widget.accountEmail!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // "Select All" checkbox
          CheckboxListTile(
            title: const Text(
              'Select All Folders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            value: _selectAllChecked,
            onChanged: (value) => _toggleAll(value ?? false),
            activeColor: Colors.blue,
          ),

          const Divider(),

          // Individual folder list
          Expanded(
            child: ListView.builder(
              itemCount: _availableFolders.length,
              itemBuilder: (context, index) {
                final folder = _availableFolders[index];
                final isSelected = _selectedFolders[folder] ?? false;

                return CheckboxListTile(
                  title: Row(
                    children: [
                      Icon(
                        _getFolderIcon(folder),
                        size: 20,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(folder),
                    ],
                  ),
                  subtitle: _getFolderDescription(folder) != null
                      ? Text(
                          _getFolderDescription(folder)!,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  value: isSelected,
                  onChanged: (value) =>
                      _toggleFolder(folder, value ?? false),
                  activeColor: Colors.blue,
                );
              },
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _selectedFolders.values.any((v) => v)
                      ? () {
                          // Get selected folders
                          final selected = _selectedFolders.entries
                              .where((e) => e.value)
                              .map((e) => e.key)
                              .toList();

                          _logger.i(
                            '✅ Selected folders for scan: $selected',
                          );

                          // Return selection to caller
                          widget.onFoldersSelected(selected);
                          Navigator.pop(context, selected);
                        }
                      : null,
                  child: const Text('Scan Selected Folders'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
