import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../core/services/background_scan_manager.dart' show ScanFrequency;
import '../../core/services/windows_task_scheduler_service.dart';
import '../../core/storage/settings_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../../adapters/email_providers/email_provider.dart' show Credentials;
import '../widgets/app_bar_with_exit.dart';
import 'folder_selection_screen.dart';
import 'background_scan_log_screen.dart';
import 'rules_management_screen.dart';
import 'safe_senders_management_screen.dart';

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
  bool _backgroundScanDebugCsv = SettingsStore.defaultBackgroundScanDebugCsv;
  String? _csvExportDirectory;
  int _manualDaysBack = SettingsStore.defaultManualScanDaysBack;
  int _backgroundDaysBack = SettingsStore.defaultBackgroundScanDaysBack;

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

      _backgroundScanDebugCsv = await _settingsStore.getBackgroundScanDebugCsv();
      _csvExportDirectory = await _settingsStore.getCsvExportDirectory();

      // [NEW] ISSUE #153: Load days-back settings (per-account with app-wide fallback)
      final accountManualDays = await _settingsStore.getAccountManualDaysBack(widget.accountId);
      _manualDaysBack = accountManualDays ?? await _settingsStore.getManualScanDaysBack();

      final accountBgDays = await _settingsStore.getAccountBackgroundDaysBack(widget.accountId);
      _backgroundDaysBack = accountBgDays ?? await _settingsStore.getBackgroundScanDaysBack();
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

            const SizedBox(height: 24),

            // Data management section
            Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View and manage safe sender patterns and block rules',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Manage Safe Senders button
            OutlinedButton.icon(
              icon: const Icon(Icons.security_outlined),
              label: const Text('Manage Safe Senders'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SafeSendersManagementScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),

            // Manage Rules button
            OutlinedButton.icon(
              icon: const Icon(Icons.rule_outlined),
              label: const Text('Manage Rules'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RulesManagementScreen(),
                  ),
                );
              },
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
        // [NEW] ISSUE #153: Scan range (days back / all emails)
        _buildSectionHeader('Scan Range'),
        _buildScanRangeSelector(
          daysBack: _manualDaysBack,
          onChanged: (daysBack) async {
            setState(() => _manualDaysBack = daysBack);
            await _settingsStore.setAccountManualDaysBack(widget.accountId, daysBack);
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
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select CSV Export Directory',
        initialDirectory: _csvExportDirectory,
      );

      if (selectedDirectory != null) {
        // Validate the directory exists and is writable
        final dir = Directory(selectedDirectory);
        if (!await dir.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Selected directory does not exist')),
            );
          }
          return;
        }

        setState(() => _csvExportDirectory = selectedDirectory);
        await _settingsStore.setCsvExportDirectory(selectedDirectory);
      }
    } catch (e) {
      _logger.e('Failed to open directory picker', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open directory browser: $e')),
        );
      }
    }
  }

  /// Create, update, or delete the Windows Task Scheduler task
  Future<void> _updateWindowsScheduledTask({required bool enabled}) async {
    try {
      bool success;
      if (enabled) {
        final frequency = ScanFrequency.fromMinutes(_backgroundScanFrequency);
        if (frequency == ScanFrequency.disabled) return;

        final exists = await WindowsTaskSchedulerService.taskExists();
        if (exists) {
          success = await WindowsTaskSchedulerService.updateScheduledTask(
              frequency: frequency);
        } else {
          success = await WindowsTaskSchedulerService.createScheduledTask(
              frequency: frequency);
        }

        if (success) {
          _logger.i('Windows scheduled task updated: ${frequency.label}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Background scan scheduled every ${frequency.label}')),
            );
          }
        } else {
          _logger.e('Windows scheduled task creation returned false');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to create Windows scheduled task')),
            );
          }
        }
      } else {
        success = await WindowsTaskSchedulerService.deleteScheduledTask();
        if (success) {
          _logger.i('Windows scheduled task deleted');
        }
      }
    } catch (e) {
      _logger.e('Failed to update Windows scheduled task', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to update Windows scheduled task: $e')),
        );
      }
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
            // On Windows, create or delete the Task Scheduler task
            if (Platform.isWindows) {
              await _updateWindowsScheduledTask(enabled: value);
            }
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
            // On Windows, update the Task Scheduler frequency if enabled
            if (Platform.isWindows && _backgroundScanEnabled) {
              await _updateWindowsScheduledTask(enabled: true);
            }
          },
        ),
        const SizedBox(height: 24),
        // [NEW] ISSUE #153: Scan range (days back / all emails)
        _buildSectionHeader('Scan Range'),
        _buildScanRangeSelector(
          daysBack: _backgroundDaysBack,
          onChanged: (daysBack) async {
            setState(() => _backgroundDaysBack = daysBack);
            await _settingsStore.setAccountBackgroundDaysBack(widget.accountId, daysBack);
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
        const SizedBox(height: 24),
        _buildSectionHeader('Debug'),
        SwitchListTile(
          title: const Text('Export CSV After Each Scan'),
          subtitle: const Text('Write scan results CSV for debugging'),
          value: _backgroundScanDebugCsv,
          onChanged: (value) async {
            setState(() => _backgroundScanDebugCsv = value);
            await _settingsStore.setBackgroundScanDebugCsv(value);
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('History'),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('View Scan History'),
          subtitle: const Text('View past background scan runs and results'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BackgroundScanLogScreen(),
              ),
            );
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

  /// [NEW] ISSUE #153: Build scan range selector (days back / all emails)
  Widget _buildScanRangeSelector({
    required int daysBack,
    required Future<void> Function(int) onChanged,
  }) {
    final bool scanAll = daysBack == 0;
    // Use a local slider value that is independent of the "scan all" toggle
    // When scanAll is true, show 7 as the visual slider default
    final int sliderValue = scanAll ? 7 : daysBack;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Scan all emails'),
              subtitle: const Text('No date filter - scans entire mailbox'),
              value: scanAll,
              onChanged: (value) async {
                if (value == true) {
                  await onChanged(0); // 0 = all emails
                } else {
                  await onChanged(7); // Default to 7 days when unchecking
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (!scanAll) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('1'),
                  Expanded(
                    child: Slider(
                      value: sliderValue.toDouble().clamp(1, 90),
                      min: 1,
                      max: 90,
                      divisions: 89,
                      label: '$sliderValue day${sliderValue == 1 ? "" : "s"}',
                      onChanged: (value) async {
                        await onChanged(value.round());
                      },
                    ),
                  ),
                  const Text('90'),
                ],
              ),
              Center(
                child: Text(
                  'Scan last $sliderValue day${sliderValue == 1 ? "" : "s"}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    scanAll ? Icons.all_inbox : Icons.date_range,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scanAll
                        ? 'Will scan all emails in selected folders'
                        : 'Will scan emails from the last $sliderValue day${sliderValue == 1 ? "" : "s"}',
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

  /// Configure safe sender folder for account using email folder picker
  /// [UPDATED] Sprint 14: Use FolderSelectionScreen instead of Windows file picker
  Future<void> _configureSafeSenderFolder(String platform, String email) async {
    // Get current setting
    final currentFolder = await _settingsStore.getAccountSafeSenderFolder(widget.accountId);

    // [FIX] Sprint 14: Get platformId from credentials store
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

    // [UPDATED] Sprint 14: Use FolderSelectionScreen with singleSelect mode
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderSelectionScreen(
          platformId: platformId,
          accountId: widget.accountId,
          accountEmail: widget.accountId,
          initialSelectedFolders: currentFolder != null ? [currentFolder] : null,
          singleSelect: true,
          title: 'Select Safe Sender Folder',
          buttonLabel: 'Select Folder',
          onFoldersSelected: (selectedFolders) async {
            if (selectedFolders.isNotEmpty) {
              final folderName = selectedFolders.first;
              try {
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
                setState(() {}); // Refresh UI
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
          },
        ),
      ),
    );
  }

  /// Configure deleted rule folder for account using email folder picker
  /// [UPDATED] Sprint 14: Use FolderSelectionScreen instead of Windows file picker
  Future<void> _configureDeletedRuleFolder(String platform, String email) async {
    // Get current setting
    final currentFolder = await _settingsStore.getAccountDeletedRuleFolder(widget.accountId);

    // [FIX] Sprint 14: Get platformId from credentials store
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

    // [UPDATED] Sprint 14: Use FolderSelectionScreen with singleSelect mode
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderSelectionScreen(
          platformId: platformId,
          accountId: widget.accountId,
          accountEmail: widget.accountId,
          initialSelectedFolders: currentFolder != null ? [currentFolder] : null,
          singleSelect: true,
          title: 'Select Deleted Rule Folder',
          buttonLabel: 'Select Folder',
          onFoldersSelected: (selectedFolders) async {
            if (selectedFolders.isNotEmpty) {
              final folderName = selectedFolders.first;
              try {
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
                setState(() {}); // Refresh UI
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
          },
        ),
      ),
    );
  }
}
