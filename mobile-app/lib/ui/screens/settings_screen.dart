import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/storage/settings_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/email_providers/email_provider.dart' show Credentials;
import '../widgets/app_bar_with_exit.dart';
import 'folder_selection_screen.dart';

/// Settings screen for app-wide configuration
///
/// Provides:
/// - Manual Scan Defaults (scan mode, folders, confirmation dialogs)
/// - Background Scan Defaults (enabled, frequency, mode, folders)
/// - CSV Export Directory
///
/// Note: Folder settings are account-specific. Select an account first,
/// then configure folders in Account Details > Folders.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const SettingsScreen()),
/// );
/// ```
class SettingsScreen extends StatefulWidget {
  final String accountId;

  const SettingsScreen({super.key, required this.accountId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final SettingsStore _settingsStore = SettingsStore();
  final SecureCredentialsStore _credStore = SecureCredentialsStore();
  late TabController _tabController;

  // App-wide settings
  ScanMode _manualScanMode = SettingsStore.defaultManualScanMode;
  List<String> _manualScanFolders = List.from(SettingsStore.defaultManualScanFolders);
  bool _confirmDialogsEnabled = SettingsStore.defaultConfirmDialogsEnabled;
  bool _backgroundScanEnabled = SettingsStore.defaultBackgroundScanEnabled;
  int _backgroundScanFrequency = SettingsStore.defaultBackgroundScanFrequency;
  ScanMode _backgroundScanMode = SettingsStore.defaultBackgroundScanMode;
  List<String> _backgroundScanFolders = List.from(SettingsStore.defaultBackgroundScanFolders);
  String? _csvExportDirectory;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,  // Account, Manual Scan, Background
      vsync: this,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // [UPDATED] ISSUE #123: Load per-account settings (with app-wide fallback)
      final accountManualMode = await _settingsStore.getAccountManualScanMode(widget.accountId);
      _manualScanMode = accountManualMode ?? await _settingsStore.getManualScanMode();

      final accountManualFolders = await _settingsStore.getAccountManualScanFolders(widget.accountId);
      _manualScanFolders = accountManualFolders ?? await _settingsStore.getManualScanFolders();

      _confirmDialogsEnabled = await _settingsStore.getConfirmDialogsEnabled();
      _backgroundScanEnabled = await _settingsStore.getBackgroundScanEnabled();
      _backgroundScanFrequency = await _settingsStore.getBackgroundScanFrequency();

      final accountBgMode = await _settingsStore.getAccountBackgroundScanMode(widget.accountId);
      _backgroundScanMode = accountBgMode ?? await _settingsStore.getBackgroundScanMode();

      final accountBgFolders = await _settingsStore.getAccountBackgroundScanFolders(widget.accountId);
      _backgroundScanFolders = accountBgFolders ?? await _settingsStore.getBackgroundScanFolders();

      _csvExportDirectory = await _settingsStore.getCsvExportDirectory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Account'),
            Tab(text: 'Manual Scan'),
            Tab(text: 'Background'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAccountTab(),
                _buildManualScanTab(),
                _buildBackgroundScanTab(),
              ],
            ),
    );
  }

  Widget _buildAccountTab() {
    // [UPDATED] ISSUE #123: accountId now required, no null check needed
    return FutureBuilder<Credentials?>(
      future: _credStore.getCredentials(widget.accountId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text(
              'Failed to load account information',
              style: TextStyle(color: Colors.red.shade700),
            ),
          );
        }

        final credentials = snapshot.data!;
        final email = credentials.email;
        final platform = widget.accountId.split('-')[0]; // Extract platform from accountId

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account info header
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Settings',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Folder configuration section
            Text(
              'Folder Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure where emails are moved based on rules and safe senders',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Safe Sender Folder button
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_special_outlined),
              label: const Text('Safe Sender Folder'),
              onPressed: () => _configureSafeSenderFolder(platform, email),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),

            // Deleted Rule Folder button
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_delete_outlined),
              label: const Text('Deleted Rule Folder'),
              onPressed: () => _configureDeletedRuleFolder(platform, email),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualScanTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Default folders are account-specific. Select an account first, '
                    'then configure in Account Details > Folders.',
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Scan Mode'),
        _buildScanModeSelector(
          value: _manualScanMode,
          onChanged: (mode) async {
            setState(() => _manualScanMode = mode);
            // [UPDATED] ISSUE #123: Save per-account manual scan mode
            await _settingsStore.setAccountManualScanMode(widget.accountId, mode);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Default Folders'),
        _buildFolderSelector(
          folders: _manualScanFolders,
          onChanged: (folders) async {
            setState(() => _manualScanFolders = folders);
            // [UPDATED] ISSUE #123: Save per-account manual scan folders
            await _settingsStore.setAccountManualScanFolders(widget.accountId, folders);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Confirmation'),
        SwitchListTile(
          title: const Text('Show confirmation dialogs'),
          subtitle: const Text('Prompt before destructive actions'),
          value: _confirmDialogsEnabled,
          onChanged: (value) async {
            setState(() => _confirmDialogsEnabled = value);
            await _settingsStore.setConfirmDialogsEnabled(value);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Export Settings'),
        _buildCsvExportDirectorySelector(),
      ],
    );
  }

  Widget _buildCsvExportDirectorySelector() {
    final displayPath = _csvExportDirectory ?? 'Downloads folder (default)';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('CSV Export Directory'),
        subtitle: Text(
          displayPath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_csvExportDirectory != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Reset to default',
                onPressed: () async {
                  setState(() => _csvExportDirectory = null);
                  await _settingsStore.setCsvExportDirectory(null);
                },
              ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Browse for folder',
              onPressed: _selectCsvExportDirectory,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCsvExportDirectory() async {
    // Note: file_picker package required for full implementation
    // For now, show a dialog to enter path manually
    final controller = TextEditingController(text: _csvExportDirectory ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV Export Directory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the full path where CSV exports should be saved:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Directory Path',
                hintText: 'C:\\Users\\YourName\\Documents\\SpamFilter',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty to use the system Downloads folder.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final directory = result.isEmpty ? null : result;
      setState(() => _csvExportDirectory = directory);
      await _settingsStore.setCsvExportDirectory(directory);
    }
  }

  Widget _buildBackgroundScanTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Enable Background Scanning'),
          subtitle: const Text('Automatically scan for spam periodically'),
          value: _backgroundScanEnabled,
          onChanged: (value) async {
            setState(() => _backgroundScanEnabled = value);
            await _settingsStore.setBackgroundScanEnabled(value);
          },
        ),
        const Divider(),
        // [UPDATED] ISSUE #123+#124: Show UI sections even when Background Scan is OFF
        _buildSectionHeader('Frequency'),
        _buildFrequencySelector(
          value: _backgroundScanFrequency,
          onChanged: (freq) async {
            setState(() => _backgroundScanFrequency = freq);
            await _settingsStore.setBackgroundScanFrequency(freq);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Default Folders'),
        _buildFolderSelector(
          folders: _backgroundScanFolders,
          onChanged: (folders) async {
            setState(() => _backgroundScanFolders = folders);
            // [UPDATED] ISSUE #123: Save per-account background scan folders
            await _settingsStore.setAccountBackgroundScanFolders(widget.accountId, folders);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Scan Mode'),
        _buildScanModeSelector(
          value: _backgroundScanMode,
          onChanged: (mode) async {
            setState(() => _backgroundScanMode = mode);
            // [UPDATED] ISSUE #123: Save per-account background scan mode
            await _settingsStore.setAccountBackgroundScanMode(widget.accountId, mode);
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// [NEW] ISSUE #123: Get provider-specific default junk folders
  List<String> _getProviderDefaultFolders(String platformId) {
    // Based on EmailScanProvider.JUNK_FOLDERS_BY_PROVIDER
    const providerFolders = {
      'aol': ['Bulk Mail', 'Spam'],
      'gmail': ['Spam', 'Trash'],
      'outlook': ['Junk Email', 'Spam'],
      'yahoo': ['Bulk', 'Spam'],
      'icloud': ['Junk', 'Trash'],
    };
    return providerFolders[platformId] ?? ['Spam', 'Junk'];
  }

  Widget _buildScanModeSelector({
    required ScanMode value,
    required Future<void> Function(ScanMode) onChanged,
  }) {
    // [UPDATED] ISSUE #123+#124: New scan mode UI with checkboxes
    // Scan mode mapping:
    // - readonly: neither safe senders nor rules
    // - testAll: safe senders only
    // - testLimit: rules only (repurposed)
    // - fullScan: both safe senders and rules
    final bool isReadOnly = value == ScanMode.readonly;
    final bool processSafeSenders = value == ScanMode.testAll || value == ScanMode.fullScan;
    final bool processRules = value == ScanMode.testLimit || value == ScanMode.fullScan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Read-Only Mode Toggle
            SwitchListTile(
              title: const Text('Read-Only Mode'),
              subtitle: const Text(
                'NO changes to emails, but rules can be added/changed',
              ),
              value: isReadOnly,
              onChanged: (enabled) async {
                if (enabled) {
                  // Switch to read-only mode
                  await onChanged(ScanMode.readonly);
                } else {
                  // Switch to testAll (safe senders only) as default when disabling read-only
                  await onChanged(ScanMode.testAll);
                }
              },
            ),
            
            const Divider(),
            
            // Process Safe Senders Checkbox (disabled if Read-Only)
            CheckboxListTile(
              title: const Text('Process Safe Senders'),
              subtitle: const Text(
                'Move safe sender emails to configured folder',
              ),
              value: processSafeSenders && !isReadOnly,
              onChanged: isReadOnly ? null : (enabled) async {
                if (enabled == true) {
                  // [UPDATED] ISSUE #123+#124: Enable safe senders
                  if (processRules) {
                    await onChanged(ScanMode.fullScan); // Both enabled
                  } else {
                    await onChanged(ScanMode.testAll); // Safe senders only
                  }
                } else {
                  // [FIXED] ISSUE #123+#124: Disable safe senders - use testLimit for rules only
                  if (processRules) {
                    await onChanged(ScanMode.testLimit); // Rules only, no safe senders
                  } else {
                    await onChanged(ScanMode.readonly); // Neither
                  }
                }
              },
            ),
            
            // Process Rules Checkbox (disabled if Read-Only)
            CheckboxListTile(
              title: const Text('Process all other Rules'),
              subtitle: const Text(
                'Delete/move emails, mark as read, add tags for matched rules',
              ),
              value: processRules && !isReadOnly,
              onChanged: isReadOnly ? null : (enabled) async {
                if (enabled == true) {
                  // [UPDATED] ISSUE #123+#124: Enable rules
                  if (processSafeSenders) {
                    await onChanged(ScanMode.fullScan); // Both enabled
                  } else {
                    await onChanged(ScanMode.testLimit); // Rules only
                  }
                } else {
                  // [UPDATED] ISSUE #123+#124: Disable rules
                  if (processSafeSenders) {
                    await onChanged(ScanMode.testAll); // Safe senders only
                  } else {
                    await onChanged(ScanMode.readonly); // Neither
                  }
                }
              },
            ),
            
            const SizedBox(height: 8),
            
            // Current mode indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isReadOnly ? Icons.visibility : Icons.play_arrow,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isReadOnly
                        ? 'Read-Only: No changes will be made'
                        : processSafeSenders && processRules
                          ? 'Active: Processing safe senders and rules'
                          : processSafeSenders
                            ? 'Active: Processing safe senders only'
                            : processRules
                              ? 'Active: Processing rules only'
                              : 'Inactive: No processing enabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSelector({
    required List<String> folders,
    required Future<void> Function(List<String>) onChanged,
  }) {
    // [UPDATED] ISSUE #123+#124: Show "Select Folders" button to open folder selection dialog
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Selected Folders'),
            subtitle: Text(
              folders.isEmpty
                ? 'No folders selected (defaults will be used)'
                : folders.join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: FilledButton.icon(
              onPressed: () => _openFolderSelection(folders, onChanged),
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Select Folders'),
            ),
          ),
          if (folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: folders.map((folder) => Chip(
                  label: Text(folder, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    final newFolders = List<String>.from(folders)..remove(folder);
                    onChanged(newFolders);
                  },
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// [NEW] ISSUE #123+#124: Open folder selection screen
  Future<void> _openFolderSelection(
    List<String> currentFolders,
    Future<void> Function(List<String>) onChanged,
  ) async {
    // [FIX] ISSUE #123+#124: Get platformId from credentials store
    // accountId in Settings is just the email address, not platform-email format
    final credStore = SecureCredentialsStore();
    final platformId = await credStore.getPlatformId(widget.accountId);
    
    if (platformId == null || platformId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine email platform')),
        );
      }
      return;
    }

    // [UPDATED] ISSUE #123+#124: Pass current folders as initial selection
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderSelectionScreen(
          platformId: platformId,
          accountId: widget.accountId,
          accountEmail: widget.accountId, // accountId IS the email
          initialSelectedFolders: currentFolders, // Pre-populate with saved folders
          onFoldersSelected: (selectedFolders) async {
            await onChanged(selectedFolders);
            setState(() {
              // Update will happen via onChanged callback
            });
          },
        ),
      ),
    );
  }

  Widget _buildFrequencySelector({
    required int value,
    required Future<void> Function(int) onChanged,
  }) {
    final frequencies = [15, 30, 60, 120, 240];

    return DropdownButtonFormField<int>(
      value: frequencies.contains(value) ? value : 15,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Scan every',
      ),
      items: frequencies.map((freq) {
        final label = freq < 60 ? '$freq minutes' : '${freq ~/ 60} hour${freq > 60 ? "s" : ""}';
        return DropdownMenuItem(value: freq, child: Text(label));
      }).toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }

  /// Configure safe sender folder for account using Windows folder picker
  Future<void> _configureSafeSenderFolder(String platform, String email) async {
    // Get current setting
    final currentFolder = await _settingsStore.getAccountSafeSenderFolder(widget.accountId);

    // Show informational dialog first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Safe Senders to Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When an email matches a safe sender rule, it will be moved to the selected folder.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              'Current folder: ${currentFolder ?? "INBOX (default)"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: Emails already in the target folder will not be moved.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              platform == 'gmail'
                  ? 'You will select a folder name (e.g., INBOX, SPAM, or custom label).'
                  : 'You will select an IMAP folder name (e.g., INBOX, Junk).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select Folder'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Open Windows folder picker (directory mode)
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Safe Sender Folder',
      initialDirectory: currentFolder,
    );

    if (result != null) {
      try {
        // Extract just the folder name (last component of path)
        final folderName = result.split('\\').last;

        await _settingsStore.setAccountSafeSenderFolder(
          widget.accountId,
          folderName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Safe sender emails will be moved to: $folderName'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _logger.i('Set safe sender folder for $email to: $folderName');
      } catch (e) {
        _logger.e('Failed to set safe sender folder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save setting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Configure deleted rule folder for account using Windows folder picker
  Future<void> _configureDeletedRuleFolder(String platform, String email) async {
    // Get current setting
    final currentFolder = await _settingsStore.getAccountDeletedRuleFolder(widget.accountId);

    // Show informational dialog first
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Deleted by Rule to Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When a rule deletes an email, it will be moved to the selected folder.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              'Current folder: ${currentFolder ?? (platform == "gmail" ? "TRASH (default)" : "Trash (default)")}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              platform == 'gmail'
                  ? 'You will select a folder name (e.g., TRASH, SPAM, or custom label).'
                  : 'You will select an IMAP folder name (e.g., Trash, Deleted, Junk).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select Folder'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Open Windows folder picker (directory mode)
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Deleted Rule Folder',
      initialDirectory: currentFolder,
    );

    if (result != null) {
      try {
        // Extract just the folder name (last component of path)
        final folderName = result.split('\\').last;

        await _settingsStore.setAccountDeletedRuleFolder(
          widget.accountId,
          folderName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted emails will be moved to: $folderName'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _logger.i('Set deleted rule folder for $email to: $folderName');
      } catch (e) {
        _logger.e('Failed to set deleted rule folder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save setting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
