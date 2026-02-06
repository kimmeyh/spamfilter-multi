import 'package:flutter/material.dart';
import '../../core/storage/settings_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../widgets/app_bar_with_exit.dart';

/// Settings screen for app-wide and per-account configuration
///
/// Provides:
/// - Manual Scan Defaults (scan mode, folders, confirmation dialogs)
/// - Background Scan Defaults (enabled, frequency, mode, folders)
/// - Per-account overrides (accessible from account list or account detail)
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const SettingsScreen()),
/// );
/// ```
class SettingsScreen extends StatefulWidget {
  /// Optional account ID for per-account settings
  final String? accountId;

  const SettingsScreen({super.key, this.accountId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final SettingsStore _settingsStore = SettingsStore();
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

  // Per-account overrides (if accountId provided)
  bool _hasAccountOverrides = false;
  List<String>? _accountFolders;
  ScanMode? _accountScanMode;
  bool? _accountBackgroundEnabled;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.accountId != null ? 3 : 2,
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

      // Load per-account overrides if accountId provided
      if (widget.accountId != null) {
        _hasAccountOverrides = await _settingsStore.hasAccountOverrides(widget.accountId!);
        _accountFolders = await _settingsStore.getAccountFolders(widget.accountId!);
        _accountScanMode = await _settingsStore.getAccountScanMode(widget.accountId!);
        _accountBackgroundEnabled = await _settingsStore.getAccountBackgroundEnabled(widget.accountId!);
      }
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
        title: Text(widget.accountId != null
            ? 'Account Settings'
            : 'Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Manual Scan'),
            const Tab(text: 'Background'),
            if (widget.accountId != null)
              const Tab(text: 'Account'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildManualScanTab(),
                _buildBackgroundScanTab(),
                if (widget.accountId != null)
                  _buildAccountTab(),
              ],
            ),
    );
  }

  Widget _buildManualScanTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasAccountOverrides ? Icons.tune : Icons.settings_suggest,
                      color: _hasAccountOverrides ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasAccountOverrides
                          ? 'Account has custom settings'
                          : 'Using global defaults',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (_hasAccountOverrides) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Global Defaults'),
                    onPressed: _resetAccountOverrides,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Scan Mode Override'),
        _buildAccountScanModeSelector(),
        const SizedBox(height: 24),
        _buildSectionHeader('Folders Override'),
        _buildAccountFolderSelector(),
        const SizedBox(height: 24),
        _buildSectionHeader('Background Scan Override'),
        _buildAccountBackgroundToggle(),
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

  Widget _buildAccountScanModeSelector() {
    return Column(
      children: [
        RadioListTile<ScanMode?>(
          title: const Text('Use Global Default'),
          subtitle: Text('Currently: ${_manualScanMode.name}'),
          value: null,
          groupValue: _accountScanMode,
          onChanged: (v) async {
            setState(() => _accountScanMode = null);
            await _settingsStore.setAccountScanMode(widget.accountId!, null);
            _checkAccountOverrides();
          },
        ),
        RadioListTile<ScanMode?>(
          title: const Text('Read-Only'),
          value: ScanMode.readonly,
          groupValue: _accountScanMode,
          onChanged: (v) async {
            setState(() => _accountScanMode = v);
            await _settingsStore.setAccountScanMode(widget.accountId!, v);
            _checkAccountOverrides();
          },
        ),
        RadioListTile<ScanMode?>(
          title: const Text('Process Rules'),
          value: ScanMode.fullScan,
          groupValue: _accountScanMode,
          onChanged: (v) async {
            setState(() => _accountScanMode = v);
            await _settingsStore.setAccountScanMode(widget.accountId!, v);
            _checkAccountOverrides();
          },
        ),
      ],
    );
  }

  Widget _buildAccountFolderSelector() {
    final isUsingOverride = _accountFolders != null;
    final folders = _accountFolders ?? _manualScanFolders;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Override folder selection'),
          value: isUsingOverride,
          onChanged: (enabled) async {
            if (enabled) {
              // Copy current global folders as starting point
              _accountFolders = List.from(_manualScanFolders);
            } else {
              _accountFolders = null;
            }
            setState(() {});
            await _settingsStore.setAccountFolders(widget.accountId!, _accountFolders);
            _checkAccountOverrides();
          },
        ),
        if (isUsingOverride)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: _buildFolderSelector(
              folders: folders,
              onChanged: (newFolders) async {
                setState(() => _accountFolders = newFolders);
                await _settingsStore.setAccountFolders(widget.accountId!, newFolders);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAccountBackgroundToggle() {
    return Column(
      children: [
        RadioListTile<bool?>(
          title: const Text('Use Global Default'),
          subtitle: Text('Currently: ${_backgroundScanEnabled ? "Enabled" : "Disabled"}'),
          value: null,
          groupValue: _accountBackgroundEnabled,
          onChanged: (v) async {
            setState(() => _accountBackgroundEnabled = null);
            await _settingsStore.setAccountBackgroundEnabled(widget.accountId!, null);
            _checkAccountOverrides();
          },
        ),
        RadioListTile<bool?>(
          title: const Text('Enabled'),
          value: true,
          groupValue: _accountBackgroundEnabled,
          onChanged: (v) async {
            setState(() => _accountBackgroundEnabled = v);
            await _settingsStore.setAccountBackgroundEnabled(widget.accountId!, v);
            _checkAccountOverrides();
          },
        ),
        RadioListTile<bool?>(
          title: const Text('Disabled'),
          value: false,
          groupValue: _accountBackgroundEnabled,
          onChanged: (v) async {
            setState(() => _accountBackgroundEnabled = v);
            await _settingsStore.setAccountBackgroundEnabled(widget.accountId!, v);
            _checkAccountOverrides();
          },
        ),
      ],
    );
  }

  Future<void> _checkAccountOverrides() async {
    final hasOverrides = await _settingsStore.hasAccountOverrides(widget.accountId!);
    if (mounted) {
      setState(() => _hasAccountOverrides = hasOverrides);
    }
  }

  Future<void> _resetAccountOverrides() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Account Settings'),
        content: const Text('This will remove all custom settings for this account and use global defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsStore.clearAccountOverrides(widget.accountId!);
      _accountFolders = null;
      _accountScanMode = null;
      _accountBackgroundEnabled = null;
      _hasAccountOverrides = false;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account settings reset to defaults')),
        );
      }
    }
  }
}
