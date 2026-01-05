/// Folder Selection Screen for multi-folder email scanning
/// 
/// ✨ PHASE 3.3: Dynamic folder discovery (Issue #37)
/// - Dynamically fetches all folders/labels from email account
/// - Multi-select picker with search/filter
/// - Pre-selects typical junk folders (inbox, spam, trash)
/// - Persists selections per account
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// ✨ PHASE 3.3: Dynamic folder discovery (Issue #37)
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../adapters/email_providers/generic_imap_adapter.dart';
import '../../adapters/storage/secure_credentials_store.dart';

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
  
  // ✨ PHASE 3.3: Dynamic folder discovery state (Issue #37)
  bool _isLoading = true;
  String? _errorMessage;
  List<FolderInfo> _allFolders = [];
  Map<String, bool> _selectedFolders = {};
  bool _selectAllChecked = false;
  
  // ✨ PHASE 3.3: Search/filter functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  /// ✨ PHASE 3.3: Canonical folder types to pre-select
  static const Set<CanonicalFolder> PRESELECT_FOLDER_TYPES = {
    CanonicalFolder.inbox,
    CanonicalFolder.junk,
    // Note: NOT trash - users typically don't want to scan deleted items
  };

  @override
  void initState() {
    super.initState();
    _fetchFoldersDynamically();  // ✨ PHASE 3.3: Dynamic discovery
    
    // Listen for search query changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✨ PHASE 3.3: Fetch folders dynamically from email provider (Issue #37)
  Future<void> _fetchFoldersDynamically() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credStore = SecureCredentialsStore();
      List<FolderInfo> folders;
      
      if (widget.platformId == 'gmail') {
        // ✨ Gmail: Use stored tokens to call Labels API directly
        // This avoids creating a new adapter and triggering re-authentication
        final tokens = await credStore.getGmailTokens(widget.accountId);
        if (tokens == null || tokens.accessToken.isEmpty) {
          throw Exception('No Gmail credentials found for account ${widget.accountId}');
        }
        
        // Import googleapis for direct API call
        final authClient = _GoogleAuthClient({'Authorization': 'Bearer ${tokens.accessToken}'});
        final gmailApi = gmail.GmailApi(authClient);
        
        try {
          final labelsResponse = await gmailApi.users.labels.list('me');
          
          folders = [];
          if (labelsResponse.labels != null) {
            for (var label in labelsResponse.labels!) {
              final name = label.name ?? 'Unknown';
              // Map common Gmail labels to canonical names
              CanonicalFolder canonical;
              switch (name.toUpperCase()) {
                case 'INBOX':
                  canonical = CanonicalFolder.inbox;
                  break;
                case 'SPAM':
                case 'JUNK':
                  canonical = CanonicalFolder.junk;
                  break;
                case 'TRASH':
                  canonical = CanonicalFolder.trash;
                  break;
                case 'SENT':
                  canonical = CanonicalFolder.sent;
                  break;
                case 'DRAFTS':
                case 'DRAFT':
                  canonical = CanonicalFolder.drafts;
                  break;
                case 'ARCHIVE':
                case 'ALL MAIL':
                  canonical = CanonicalFolder.archive;
                  break;
                default:
                  canonical = CanonicalFolder.custom;
              }

              folders.add(FolderInfo(
                id: label.id ?? name,
                displayName: name,
                canonicalName: canonical,
                messageCount: label.messagesTotal,
                isWritable: true,
              ));
            }
          }
        } catch (e) {
          throw Exception('Failed to list Gmail labels: $e');
        }
      } else {
        // IMAP providers (AOL, Yahoo, iCloud, ProtonMail, custom)
        final SpamFilterPlatform provider;
        
        if (widget.platformId == 'aol') {
          provider = GenericIMAPAdapter.aol();
        } else if (widget.platformId == 'yahoo') {
          provider = GenericIMAPAdapter.yahoo();
        } else if (widget.platformId == 'icloud') {
          provider = GenericIMAPAdapter.icloud();
        } else {
          provider = GenericIMAPAdapter.custom();
        }
        
        // Load credentials and fetch folders
        final credentials = await credStore.getCredentials(widget.accountId);
        if (credentials == null) {
          throw Exception('No credentials found for account ${widget.accountId}');
        }
        
        await provider.loadCredentials(credentials);
        folders = await provider.listFolders();
        await provider.disconnect();
      }
      
      // Sort folders: Inbox first, then junk folders, then others
      folders.sort((a, b) {
        if (a.canonicalName == CanonicalFolder.inbox) return -1;
        if (b.canonicalName == CanonicalFolder.inbox) return 1;
        if (PRESELECT_FOLDER_TYPES.contains(a.canonicalName) &&
            !PRESELECT_FOLDER_TYPES.contains(b.canonicalName)) return -1;
        if (!PRESELECT_FOLDER_TYPES.contains(a.canonicalName) &&
            PRESELECT_FOLDER_TYPES.contains(b.canonicalName)) return 1;
        return a.displayName.compareTo(b.displayName);
      });
      
      // Pre-select folders based on canonical type
      final selections = <String, bool>{};
      for (var folder in folders) {
        selections[folder.id] = PRESELECT_FOLDER_TYPES.contains(folder.canonicalName);
      }
      
      setState(() {
        _allFolders = folders;
        _selectedFolders = selections;
        _selectAllChecked = selections.values.every((v) => v);
        _isLoading = false;
      });
      
      _logger.i('✅ Fetched ${folders.length} folders for ${widget.platformId}');
    } catch (e) {
      _logger.e('❌ Failed to fetch folders: $e');
      setState(() {
        _errorMessage = 'Failed to load folders: $e';
        _isLoading = false;
      });
    }
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
  void _toggleFolder(String folderId, bool value) {
    setState(() {
      _selectedFolders[folderId] = value;
      // Update "Select All" checkbox based on individual selections
      _selectAllChecked = _selectedFolders.values.every((v) => v);
    });
    _logger.d('Toggle folder "$folderId": $value');
  }

  /// ✨ PHASE 3.3: Get filtered folder list based on search query
  List<FolderInfo> get _filteredFolders {
    if (_searchQuery.isEmpty) {
      return _allFolders;
    }
    return _allFolders.where((folder) {
      return folder.displayName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  /// Get human-readable description for a folder
  String? _getFolderDescription(FolderInfo folder) {
    switch (folder.canonicalName) {
      case CanonicalFolder.inbox:
        return 'Primary inbox';
      case CanonicalFolder.junk:
        return 'Spam/Junk folder';
      case CanonicalFolder.trash:
        return 'Deleted items';
      case CanonicalFolder.sent:
        return 'Sent messages';
      case CanonicalFolder.drafts:
        return 'Draft messages';
      case CanonicalFolder.archive:
        return 'Archived messages';
      case CanonicalFolder.custom:
        final count = folder.messageCount;
        return count != null ? '$count messages' : null;
    }
  }

  /// Get icon for folder type
  IconData _getFolderIcon(FolderInfo folder) {
    switch (folder.canonicalName) {
      case CanonicalFolder.inbox:
        return Icons.inbox;
      case CanonicalFolder.junk:
        return Icons.delete_outline;
      case CanonicalFolder.trash:
        return Icons.delete;
      case CanonicalFolder.sent:
        return Icons.send;
      case CanonicalFolder.drafts:
        return Icons.drafts;
      case CanonicalFolder.archive:
        return Icons.archive;
      case CanonicalFolder.custom:
        return Icons.folder;
    }
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

          // ✨ PHASE 3.3: Show loading/error states (Issue #37)
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching folders from email account...'),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchFoldersDynamically,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...[
              // ✨ PHASE 3.3: Search/filter box (Issue #37)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search folders...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // "Select All" checkbox
              CheckboxListTile(
                title: const Text(
                  'Select All Folders',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${_allFolders.length} folders available',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _selectAllChecked,
                onChanged: (value) => _toggleAll(value ?? false),
                activeColor: Colors.blue,
              ),

              const Divider(),

              // Individual folder list with dynamic folders
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredFolders.length,
                  itemBuilder: (context, index) {
                    final folder = _filteredFolders[index];
                    final isSelected = _selectedFolders[folder.id] ?? false;

                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Icon(
                            _getFolderIcon(folder),
                            size: 20,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(folder.displayName)),
                          // ✨ PHASE 3.3: Show pre-selected badge
                          if (PRESELECT_FOLDER_TYPES.contains(folder.canonicalName))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                          _toggleFolder(folder.id, value ?? false),
                      activeColor: Colors.blue,
                    );
                  },
                ),
              ),
            ],

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
                          // ✨ PHASE 3.3: Get selected folder names (not IDs)
                          final selectedFolderIds = _selectedFolders.entries
                              .where((e) => e.value)
                              .map((e) => e.key)
                              .toSet();
                          
                          final selectedFolderNames = _allFolders
                              .where((f) => selectedFolderIds.contains(f.id))
                              .map((f) => f.displayName)
                              .toList();

                          _logger.i(
                            '✅ Selected folders for scan: $selectedFolderNames',
                          );

                          // Return selection to caller (using folder names for compatibility)
                          widget.onFoldersSelected(selectedFolderNames);
                          Navigator.pop(context, selectedFolderNames);
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

/// ✨ PHASE 3.3: HTTP client with Google auth headers for direct Gmail API calls
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
