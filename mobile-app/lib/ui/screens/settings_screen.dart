import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/storage/settings_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/email_providers/email_provider.dart' show Credentials;
import '../widgets/app_bar_with_exit.dart';

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
  final String? accountId;

  const SettingsScreen({super.key, this.accountId});

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
      // Load app-wide settings
      _manualScanMode = await _settingsStore.getManualScanMode();
      _manualScanFolders = await _settingsStore.getManualScanFolders();
      _confirmDialogsEnabled = await _settingsStore.getConfirmDialogsEnabled();
      _backgroundScanEnabled = await _settingsStore.getBackgroundScanEnabled();
      _backgroundScanFrequency = await _settingsStore.getBackgroundScanFrequency();
      _backgroundScanMode = await _settingsStore.getBackgroundScanMode();
      _backgroundScanFolders = await _settingsStore.getBackgroundScanFolders();
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
    // If no account selected, show message
    if (widget.accountId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Account Selected',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Please select an email account first to configure account-specific settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Account selected - show folder configuration buttons
    return FutureBuilder<Credentials?>(
      future: _credStore.getCredentials(widget.accountId!),
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
        final platform = widget.accountId!.split('-')[0]; // Extract platform from accountId

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
            await _settingsStore.setManualScanMode(mode);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Default Folders'),
        _buildFolderSelector(
          folders: _manualScanFolders,
          onChanged: (folders) async {
            setState(() => _manualScanFolders = folders);
            await _settingsStore.setManualScanFolders(folders);
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
        if (_backgroundScanEnabled) ...[
          _buildSectionHeader('Frequency'),
          _buildFrequencySelector(
            value: _backgroundScanFrequency,
            onChanged: (freq) async {
              setState(() => _backgroundScanFrequency = freq);
              await _settingsStore.setBackgroundScanFrequency(freq);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Scan Mode'),
          _buildScanModeSelector(
            value: _backgroundScanMode,
            onChanged: (mode) async {
              setState(() => _backgroundScanMode = mode);
              await _settingsStore.setBackgroundScanMode(mode);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Folders'),
          _buildFolderSelector(
            folders: _backgroundScanFolders,
            onChanged: (folders) async {
              setState(() => _backgroundScanFolders = folders);
              await _settingsStore.setBackgroundScanFolders(folders);
            },
          ),
        ],
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

  Widget _buildScanModeSelector({
    required ScanMode value,
    required Future<void> Function(ScanMode) onChanged,
  }) {
    return Column(
      children: [
        RadioListTile<ScanMode>(
          title: const Text('Read-Only'),
          subtitle: const Text('Scan only, no modifications'),
          value: ScanMode.readonly,
          groupValue: value,
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
        RadioListTile<ScanMode>(
          title: const Text('Process Safe Senders'),
          subtitle: const Text('Mark safe sender emails, no deletions'),
          value: ScanMode.testAll,
          groupValue: value,
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
        RadioListTile<ScanMode>(
          title: const Text('Process Rules'),
          subtitle: const Text('Apply rules (delete/move emails)'),
          value: ScanMode.fullScan,
          groupValue: value,
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }

  Widget _buildFolderSelector({
    required List<String> folders,
    required Future<void> Function(List<String>) onChanged,
  }) {
    final availableFolders = ['INBOX', 'Junk', 'Spam', 'Bulk Mail', 'All Folders'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableFolders.map((folder) {
        final isSelected = folders.contains(folder);
        return FilterChip(
          label: Text(folder),
          selected: isSelected,
          onSelected: (selected) {
            final newFolders = List<String>.from(folders);
            if (selected) {
              if (folder == 'All Folders') {
                newFolders.clear();
                newFolders.add('All Folders');
              } else {
                newFolders.remove('All Folders');
                if (!newFolders.contains(folder)) {
                  newFolders.add(folder);
                }
              }
            } else {
              newFolders.remove(folder);
              if (newFolders.isEmpty) {
                newFolders.add('INBOX');
              }
            }
            onChanged(newFolders);
          },
        );
      }).toList(),
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

  /// Configure safe sender folder for account
  Future<void> _configureSafeSenderFolder(String platform, String email) async {
    if (widget.accountId == null) return;

    // Get current setting
    final currentFolder = await _settingsStore.getAccountSafeSenderFolder(widget.accountId!);

    // Show dialog to select folder
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        String? selectedFolder = currentFolder;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Move Safe Senders to Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When an email matches a safe sender rule, it will be moved to this folder:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: selectedFolder ?? ''),
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'INBOX',
                    helperText: platform == 'gmail'
                        ? 'Gmail labels (e.g., INBOX, SPAM, or custom label)'
                        : 'IMAP folder (e.g., INBOX, Junk)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    selectedFolder = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leave empty to use default (INBOX)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: Emails already in the target folder will not be moved.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedFolder),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null || result == '') {
      try {
        await _settingsStore.setAccountSafeSenderFolder(
          widget.accountId!,
          result?.isEmpty ?? true ? null : result,
        );

        final folderName = result?.isEmpty ?? true ? 'INBOX (default)' : result!;

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

  /// Configure deleted rule folder for account
  Future<void> _configureDeletedRuleFolder(String platform, String email) async {
    if (widget.accountId == null) return;

    // Get current setting
    final currentFolder = await _settingsStore.getAccountDeletedRuleFolder(widget.accountId!);

    // Show dialog to select folder
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        String? selectedFolder = currentFolder;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Move Deleted by Rule to Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When a rule deletes an email, it will be moved to this folder:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: selectedFolder ?? ''),
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    hintText: platform == 'gmail' ? 'TRASH' : 'Trash',
                    helperText: platform == 'gmail'
                        ? 'Gmail labels (e.g., TRASH, SPAM, or custom label)'
                        : 'IMAP folder (e.g., Trash, Deleted, Junk)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    selectedFolder = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Leave empty to use default (${platform == "gmail" ? "TRASH" : "Trash"})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedFolder),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null || result == '') {
      try {
        await _settingsStore.setAccountDeletedRuleFolder(
          widget.accountId!,
          result?.isEmpty ?? true ? null : result,
        );

        final folderName = result?.isEmpty ?? true
            ? (platform == 'gmail' ? 'TRASH (default)' : 'Trash (default)')
            : result!;

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
