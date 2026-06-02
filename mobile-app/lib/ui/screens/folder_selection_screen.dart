/// Folder Selection Screen for multi-folder email scanning
///
/// [NEW] PHASE 3.3: Dynamic folder discovery (Issue #37)
/// - Dynamically fetches all folders/labels from email account
/// - Multi-select picker with search/filter
/// - Pre-selects typical junk folders (inbox, spam, trash)
/// - Persists selections per account
///
/// [UPDATED] Sprint 40 F37:
/// - Part A: Multi-select mode renders two-level collapsible folder tree
///   (ExpansionTile for parent folders; flat CheckboxListTile for root-level)
/// - Part B: Single-select mode reorders list so canonical default appears first
/// - Part C: Uses FolderInfo.hierarchyDelimiter for path splitting (not hardcoded '/')
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// [NEW] PHASE 3.3: Dynamic folder discovery (Issue #37)
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/auth/google_auth_service.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// Groups folders into a two-level tree structure for multi-select display.
///
/// Returns a map from parent-key (the portion before the first delimiter) to
/// the list of [FolderInfo] entries that share that parent.  Root-level folders
/// (no delimiter in [FolderInfo.displayName]) are stored under the empty-string
/// key '' to indicate they render as flat rows, not inside an ExpansionTile.
///
/// The delimiter is read from each folder's [FolderInfo.hierarchyDelimiter]
/// field; the delimiter of the FIRST folder in a group is used for the group
/// (all siblings share the same provider delimiter).
///
/// Public for unit-testing.
Map<String, List<FolderInfo>> groupFoldersForTree(List<FolderInfo> folders) {
  final result = <String, List<FolderInfo>>{};
  for (final folder in folders) {
    final delimiter = folder.hierarchyDelimiter;
    final idx = folder.displayName.indexOf(delimiter);
    if (idx == -1) {
      // Root-level folder -- no parent group
      result.putIfAbsent('', () => []).add(folder);
    } else {
      final parent = folder.displayName.substring(0, idx);
      result.putIfAbsent(parent, () => []).add(folder);
    }
  }
  return result;
}

/// Returns a reordered folder list for single-select mode.
///
/// The canonical default folder for the current operation appears first:
/// - [CanonicalFolder.inbox] is placed at position 0 (Safe Sender default)
/// - [CanonicalFolder.trash] is placed next (Deleted Rule default)
/// - All remaining folders are sorted alphabetically by display name.
///
/// Public for unit-testing.
List<FolderInfo> reorderForSingleSelect(List<FolderInfo> folders) {
  final inbox = folders
      .where((f) => f.canonicalName == CanonicalFolder.inbox)
      .toList();
  final trash = folders
      .where((f) => f.canonicalName == CanonicalFolder.trash)
      .toList();
  final rest = folders
      .where((f) =>
          f.canonicalName != CanonicalFolder.inbox &&
          f.canonicalName != CanonicalFolder.trash)
      .toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  return [...inbox, ...trash, ...rest];
}

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

  /// [NEW] ISSUE #123+#124: Initial selected folders to pre-populate
  final List<String>? initialSelectedFolders;

  /// [NEW] Sprint 14: Single select mode for Safe Sender / Deleted Rule folder
  /// When true, only one folder can be selected (radio button style)
  final bool singleSelect;

  /// [NEW] Sprint 14: Custom title for the screen
  final String? title;

  /// [NEW] Sprint 14: Custom button label
  final String? buttonLabel;

  const FolderSelectionScreen({
    super.key,
    required this.platformId,
    required this.accountId,
    this.accountEmail,
    required this.onFoldersSelected,
    this.initialSelectedFolders,
    this.singleSelect = false,
    this.title,
    this.buttonLabel,
  });

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  final Logger _logger = Logger();

  // [NEW] PHASE 3.3: Dynamic folder discovery state (Issue #37)
  bool _isLoading = true;
  String? _errorMessage;
  List<FolderInfo> _allFolders = [];
  Map<String, bool> _selectedFolders = {};
  bool _selectAllChecked = false;

  // [NEW] PHASE 3.3: Search/filter functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// [NEW] PHASE 3.3: Canonical folder types to pre-select
  static const Set<CanonicalFolder> PRESELECT_FOLDER_TYPES = {
    CanonicalFolder.inbox,
    CanonicalFolder.junk,
    // Note: NOT trash - users typically do not want to scan deleted items
  };

  @override
  void initState() {
    super.initState();
    _fetchFoldersDynamically();  // [NEW] PHASE 3.3: Dynamic discovery

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

  /// [NEW] PHASE 3.3: Fetch folders dynamically from email provider (Issue #37)
  Future<void> _fetchFoldersDynamically() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credStore = SecureCredentialsStore();
      List<FolderInfo> folders;

      if (widget.platformId == 'gmail') {
        // [NEW] Gmail: Use GoogleAuthService to get valid token (handles expiration & refresh)
        _logger.i('[INVESTIGATION] Fetching Gmail folders for accountId: ${widget.accountId}');

        final authService = GoogleAuthService();

        // getValidAccessToken() handles:
        // - Token expiration checking
        // - Automatic refresh if expired
        // - Re-authentication if refresh fails
        final accessToken = await authService.getValidAccessToken();

        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('Unable to get valid Gmail access token for account ${widget.accountId}. Please sign in again.');
        }

        _logger.i('[OK] Got valid access token (${accessToken.length} chars)');

        final authClient = _GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
        final gmailApi = gmail.GmailApi(authClient);

        folders = await _fetchGmailLabels(gmailApi);
      } else {
        // IMAP providers (AOL, Gmail IMAP, Yahoo, iCloud, custom)
        // Use PlatformRegistry to get the correct adapter for each platformId
        final provider = PlatformRegistry.getPlatform(widget.platformId);
        if (provider == null) {
          throw Exception('Unsupported platform: ${widget.platformId}');
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

      if (widget.singleSelect) {
        // [NEW] Sprint 40 F37 Part B: Single-select mode -- canonical default first
        // INBOX appears first (Safe Sender default), TRASH next (Deleted Rule default),
        // remaining folders sorted alphabetically.
        folders = reorderForSingleSelect(folders);
      } else {
        // Multi-select mode: existing sort -- Inbox first, then junk, then alphabetical
        folders.sort((a, b) {
          if (a.canonicalName == CanonicalFolder.inbox) return -1;
          if (b.canonicalName == CanonicalFolder.inbox) return 1;
          if (PRESELECT_FOLDER_TYPES.contains(a.canonicalName) &&
              !PRESELECT_FOLDER_TYPES.contains(b.canonicalName)) {
            return -1;
          }
          if (!PRESELECT_FOLDER_TYPES.contains(a.canonicalName) &&
              PRESELECT_FOLDER_TYPES.contains(b.canonicalName)) {
            return 1;
          }
          return a.displayName.compareTo(b.displayName);
        });
      }

      // [UPDATED] ISSUE #123+#124: Pre-select folders based on initial selection or canonical type
      final selections = <String, bool>{};
      for (var folder in folders) {
        // If initialSelectedFolders provided, use that; otherwise use canonical type
        if (widget.initialSelectedFolders != null) {
          selections[folder.id] = widget.initialSelectedFolders!.contains(folder.displayName);
        } else {
          selections[folder.id] = PRESELECT_FOLDER_TYPES.contains(folder.canonicalName);
        }
      }

      setState(() {
        _allFolders = folders;
        _selectedFolders = selections;
        _selectAllChecked = selections.values.every((v) => v);
        _isLoading = false;
      });

      _logger.i('[OK] Fetched ${folders.length} folders for ${widget.platformId}');
    } catch (e) {
      _logger.e('[FAIL] Failed to fetch folders: $e');
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
    // [NEW] Sprint 19 F27: Save immediately on toggle in multi-select mode
    if (!widget.singleSelect) {
      _saveSelection();
    }
  }

  /// Toggle individual folder
  void _toggleFolder(String folderId, bool value) {
    setState(() {
      // [NEW] Sprint 14: Single select mode - deselect all others first
      if (widget.singleSelect && value) {
        _selectedFolders.updateAll((_, __) => false);
      }
      _selectedFolders[folderId] = value;
      // Update "Select All" checkbox based on individual selections (not applicable in single select)
      if (!widget.singleSelect) {
        _selectAllChecked = _selectedFolders.values.every((v) => v);
      }
    });
    _logger.d('Toggle folder "$folderId": $value (singleSelect: ${widget.singleSelect})');
    // [UPDATED] F43: Save immediately on toggle for both single and multi-select modes
    _saveSelection();
    // F43: In single-select mode, auto-navigate back after selection
    if (widget.singleSelect && value) {
      Navigator.pop(context);
    }
  }

  /// [NEW] Sprint 19 F27: Save current selection immediately
  void _saveSelection() {
    final selectedFolderIds = _selectedFolders.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    final selectedFolderNames = _allFolders
        .where((f) => selectedFolderIds.contains(f.id))
        .map((f) => f.displayName)
        .toList();

    _logger.i('[OK] Auto-saved folder selection: $selectedFolderNames');
    widget.onFoldersSelected(selectedFolderNames);
  }

  /// [NEW] PHASE 3.3: Get filtered folder list based on search query
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

  /// [NEW] PHASE 3.3: Helper to fetch Gmail labels via API
  Future<List<FolderInfo>> _fetchGmailLabels(gmail.GmailApi gmailApi) async {
    try {
      final labelsResponse = await gmailApi.users.labels.list('me');

      final folders = <FolderInfo>[];
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
            hierarchyDelimiter: '/',  // Gmail labels use '/' for nesting
          ));
        }
      }

      _logger.i('[OK] Fetched ${folders.length} Gmail labels');
      return folders;
    } catch (e) {
      _logger.e('[FAIL] Failed to list Gmail labels: $e');
      throw Exception('Failed to list Gmail labels: $e');
    }
  }

  /// [NEW] Sprint 40 F37 Part A: Build a CheckboxListTile for a single folder
  /// Used for root-level folders and child folders inside an ExpansionTile.
  Widget _buildFolderCheckbox(FolderInfo folder) {
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
          // [NEW] PHASE 3.3: Show pre-selected badge
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
      onChanged: (value) => _toggleFolder(folder.id, value ?? false),
      activeColor: Colors.blue,
    );
  }

  /// [NEW] Sprint 40 F37 Part A: Build the two-level collapsible folder tree
  /// for multi-select mode.
  ///
  /// Algorithm:
  /// 1. Group folders into parent buckets using [groupFoldersForTree].
  /// 2. Root-level folders (bucket key == '') render as flat CheckboxListTiles.
  /// 3. Each non-root bucket renders as an ExpansionTile (expand-only; the
  ///    parent header is NOT independently selectable -- it is a navigation
  ///    affordance only). Children inside the tile are CheckboxListTiles.
  ///
  /// Parent folders are expand-only by design: IMAP parent containers such as
  /// [Gmail] or Work are often non-selectable on the server (isNotSelectable
  /// flag); making them expand-only prevents the user from selecting a folder
  /// that cannot be scanned.
  List<Widget> _buildTreeItems(List<FolderInfo> folders) {
    final groups = groupFoldersForTree(folders);
    final widgets = <Widget>[];

    // Determine iteration order: root-level first, then parent groups alphabetically
    final parentKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '') return -1;  // root-level rows first
        if (b == '') return 1;
        return a.compareTo(b);
      });

    for (final key in parentKeys) {
      final members = groups[key]!;
      if (key == '') {
        // Root-level folders -- flat CheckboxListTile rows
        for (final folder in members) {
          widgets.add(_buildFolderCheckbox(folder));
        }
      } else {
        // Parent group -- ExpansionTile with children
        // Determine whether any child is selected for the subtitle count
        final selectedCount =
            members.where((f) => _selectedFolders[f.id] == true).length;
        widgets.add(
          ExpansionTile(
            leading: const Icon(Icons.folder_open, size: 20),
            title: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: selectedCount > 0
                ? Text(
                    '$selectedCount of ${members.length} selected',
                    style: const TextStyle(fontSize: 11),
                  )
                : Text(
                    '${members.length} sub-folders',
                    style: const TextStyle(fontSize: 11),
                  ),
            children: members.map(_buildFolderCheckbox).toList(),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Select Folders to Scan'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => openHelp(
              context,
              HelpSection.folderSelection,
              accountId: widget.accountId,
              platformId: widget.platformId,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(accountId: widget.accountId),
                ),
              );
            },
          ),
        ],
      ),
      body: SelectionArea(child: Column(
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

          // [NEW] PHASE 3.3: Show loading/error states (Issue #37)
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
              // [NEW] PHASE 3.3: Search/filter box (Issue #37)
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

              // "Select All" checkbox (hidden in single select mode)
              if (!widget.singleSelect) ...[
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
              ] else ...[
                // [NEW] Sprint 14: Single select mode instruction
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Select one folder (${_allFolders.length} available)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Divider(),
              ],

              // [UPDATED] Sprint 40 F37:
              // - Single-select: flat list (RadioListTile), canonical default first (Part B)
              // - Multi-select: two-level collapsible tree (ExpansionTile, Part A)
              Expanded(
                child: widget.singleSelect
                    ? ListView.builder(
                        itemCount: _filteredFolders.length,
                        itemBuilder: (context, index) {
                          final folder = _filteredFolders[index];
                          final isSelected = _selectedFolders[folder.id] ?? false;
                          return RadioListTile<String>(
                            title: Row(
                              children: [
                                Icon(
                                  _getFolderIcon(folder),
                                  size: 20,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(folder.displayName)),
                              ],
                            ),
                            subtitle: _getFolderDescription(folder) != null
                                ? Text(
                                    _getFolderDescription(folder)!,
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
                            value: folder.id,
                            groupValue: _selectedFolders.entries
                                .where((e) => e.value)
                                .map((e) => e.key)
                                .firstOrNull,
                            onChanged: (value) {
                              if (value != null) {
                                _toggleFolder(value, true);
                              }
                            },
                            activeColor: Colors.blue,
                          );
                        },
                      )
                    : ListView(
                        children: _buildTreeItems(_filteredFolders),
                      ),
              ),
            ],

          // [UPDATED] F43: Both single and multi-select save on each toggle
          if (!_isLoading && _errorMessage == null)
            // [NEW] Sprint 19 F27: Selection count summary for multi-select
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedFolders.values.where((v) => v).length} of ${_allFolders.length} folders selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Changes saved automatically',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      )),
    );
  }
}

/// [NEW] PHASE 3.3: HTTP client with Google auth headers for direct Gmail API calls
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
