import 'package:flutter/material.dart';
import '../../core/storage/settings_store.dart';
import '../../core/providers/email_scan_provider.dart';
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
  const SettingsScreen({super.key});

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

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
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
                _buildManualScanTab(),
                _buildBackgroundScanTab(),
              ],
            ),
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
}
