/// YAML Import/Export screen for rules and safe senders
///
/// [ISSUE #179] Sprint 19: Provides UI for exporting rules/safe senders
/// to YAML files and importing them back from YAML files.
///
/// Features:
/// - Export rules to user-selected file location
/// - Export safe senders to user-selected file location
/// - Import rules from user-selected YAML file (replaces existing)
/// - Import safe senders from user-selected YAML file (replaces existing)
/// - Validation and error reporting for malformed YAML
/// - Confirmation dialog before destructive import operations
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/local_rule_store.dart';
import '../../core/models/rule_set.dart';
import '../../core/models/safe_sender_list.dart';
import '../../core/services/yaml_service.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/rule_database_store.dart';
import '../widgets/app_bar_with_exit.dart';
import 'help_screen.dart';
import '../widgets/standard_app_bar_actions.dart';

/// Screen for importing and exporting YAML rule files
class YamlImportExportScreen extends StatefulWidget {
  const YamlImportExportScreen({super.key});

  /// F208 (Sprint 69): the extensions a YAML rule/safe-sender file may carry.
  ///
  /// Lower-case, no dot. Compared against a lower-cased path, so a file saved
  /// as `Rules.YAML` is accepted -- Android's Downloads and Documents pickers
  /// hand back whatever casing the file was created with.
  static const _yamlExtensions = ['.yaml', '.yml'];

  /// Does [path] name a YAML file?
  ///
  /// Public so the invariant is testable without a file picker: this is the
  /// only thing standing between a wrongly-chosen file and an import that
  /// REPLACES every rule of its type.
  @visibleForTesting
  static bool isYamlPath(String path) {
    final lower = path.toLowerCase();
    return _yamlExtensions.any(lower.endsWith);
  }

  @override
  State<YamlImportExportScreen> createState() => _YamlImportExportScreenState();
}

class _YamlImportExportScreenState extends State<YamlImportExportScreen> {
  final Logger _logger = Logger();
  final YamlService _yamlService = YamlService();
  late final RuleDatabaseStore _ruleDbStore;
  late final LocalRuleStore _localRuleStore;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    final dbHelper = DatabaseHelper();
    _ruleDbStore = RuleDatabaseStore(dbHelper);
    final appPaths = AppPaths();
    _localRuleStore = LocalRuleStore(appPaths);
    _initializeAppPaths(appPaths);
  }

  Future<void> _initializeAppPaths(AppPaths appPaths) async {
    await appPaths.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _showStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWithExit(
        title: const Text('Import / Export YAML'),
        // F134 (Sprint 52): declared via the ONE shared builder.
        actions: StandardAppBarActions.build(
          context: context,
          helpSection: HelpSection.yamlImportExport,
          includeNoRuleReview: false,
          includeScanHistory: false,
          includeAccounts: false,
          includeSettings: false,
        ),
      ),
      body: SelectionArea(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export your rules and safe senders as YAML files for backup '
                      'or version control. Import YAML files to replace current data.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Export section
          Text(
            'Export',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save current rules or safe senders to a YAML file',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),

          _buildActionCard(
            icon: Icons.upload_file,
            iconColor: Colors.green.shade700,
            title: 'Export Rules',
            subtitle: 'Save all block rules to a YAML file',
            onPressed: _isProcessing || !_isInitialized ? null : _exportRules,
          ),
          const SizedBox(height: 8),
          _buildActionCard(
            icon: Icons.upload_file,
            iconColor: Colors.green.shade700,
            title: 'Export Safe Senders',
            subtitle: 'Save all safe sender patterns to a YAML file',
            onPressed: _isProcessing || !_isInitialized ? null : _exportSafeSenders,
          ),

          const SizedBox(height: 32),

          // Import section
          Text(
            'Import',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Load rules or safe senders from a YAML file. '
            'This will replace all existing data of that type.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),

          _buildActionCard(
            icon: Icons.download,
            iconColor: Colors.orange.shade700,
            title: 'Import Rules',
            subtitle: 'Replace all block rules from a YAML file',
            onPressed: _isProcessing || !_isInitialized ? null : _importRules,
          ),
          const SizedBox(height: 8),
          _buildActionCard(
            icon: Icons.download,
            iconColor: Colors.orange.shade700,
            title: 'Import Safe Senders',
            subtitle: 'Replace all safe sender patterns from a YAML file',
            onPressed: _isProcessing || !_isInitialized ? null : _importSafeSenders,
          ),

          // Status message
          if (_statusMessage != null) ...[
            const SizedBox(height: 24),
            Card(
              color: _statusIsError ? Colors.red.shade50 : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _statusIsError ? Icons.error_outline : Icons.check_circle_outline,
                      color: _statusIsError ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusIsError ? Colors.red.shade900 : Colors.green.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Processing indicator
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onPressed,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }

  // --- Export Operations ---

  Future<void> _exportRules() async {
    setState(() => _isProcessing = true);
    try {
      _logger.i('Starting rules export');

      // Load rules from database
      final ruleSet = await _ruleDbStore.loadRules();
      if (ruleSet.rules.isEmpty) {
        _showStatus('No rules to export', isError: true);
        return;
      }

      // Let user pick save location
      // F208: saveFile is deliberately LEFT as FileType.custom. The Android
      // MIME failure is in the OPEN path, where the picker must resolve a
      // filter against existing files; a save dialog takes a typed name and
      // has nothing to match. Export was verified working on the S24+ while
      // import was broken, which is the evidence for that split.
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Rules YAML',
        fileName: 'rules.yaml',
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
      );

      if (outputPath == null) {
        _showStatus('Export cancelled');
        return;
      }

      // Export to selected file
      await _yamlService.exportRules(ruleSet, outputPath);

      _logger.i('Exported ${ruleSet.rules.length} rules to $outputPath');
      _showStatus('Exported ${ruleSet.rules.length} rules to ${_shortenPath(outputPath)}');
    } catch (e) {
      _logger.e('Failed to export rules', error: e);
      _showStatus('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportSafeSenders() async {
    setState(() => _isProcessing = true);
    try {
      _logger.i('Starting safe senders export');

      // Load safe senders from the YAML file (kept in sync by dual-write)
      SafeSenderList safeSenders;
      try {
        safeSenders = await _localRuleStore.loadSafeSenders();
      } catch (e) {
        _logger.w('Could not load safe senders from YAML file', error: e);
        safeSenders = SafeSenderList(safeSenders: []);
      }

      if (safeSenders.safeSenders.isEmpty) {
        _showStatus('No safe senders to export', isError: true);
        return;
      }

      // Let user pick save location
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Safe Senders YAML',
        fileName: 'rules_safe_senders.yaml',
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
      );

      if (outputPath == null) {
        _showStatus('Export cancelled');
        return;
      }

      // Export to selected file
      await _yamlService.exportSafeSenders(safeSenders, outputPath);

      _logger.i('Exported ${safeSenders.safeSenders.length} safe senders to $outputPath');
      _showStatus(
        'Exported ${safeSenders.safeSenders.length} safe senders to ${_shortenPath(outputPath)}',
      );
    } catch (e) {
      _logger.e('Failed to export safe senders', error: e);
      _showStatus('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- Import Operations ---

  /// Pick a YAML file to import.
  ///
  /// **DECLARED PLATFORM EXCEPTION (ADR-0042) -- resolved by REMOVING the
  /// difference rather than forking on it.**
  ///
  /// `FileType.custom` + `allowedExtensions` is resolved by EXTENSION on
  /// Windows and by MIME TYPE on Android. `.yaml` and `.yml` have no registered
  /// MIME mapping on Android, so the picker rejected the filter outright,
  /// before any file was chosen:
  ///
  /// ```
  /// PlatformException(FilePicker, Unsupported filter. Make sure that you are
  /// only using the extension without the dot, (ie., jpg instead of .jpg) ...
  /// ```
  ///
  /// **That message is a red herring** and cost real time when this was first
  /// read. The call already passed dotless `['yaml', 'yml']`, exactly as the
  /// text demands. The extensions were never the problem; the MIME lookup was.
  ///
  /// So the fix is `FileType.any` plus validation HERE, on both platforms:
  ///
  /// - A MIME filter cannot be trusted to keep a wrong file out, so the
  ///   validation is needed regardless of platform. Adding it means the
  ///   platforms no longer need to differ at all.
  /// - One code path is verifiable on both platforms. A fork would leave the
  ///   Android branch exercised only on a device.
  ///
  /// The cost is that the picker no longer greys out non-YAML files, so a user
  /// can select one. That is what the check below is for -- and it fails with a
  /// sentence a person can act on, instead of a PlatformException.
  ///
  /// Returns the chosen path, or null when the user cancelled or picked a file
  /// that is not YAML (the status message is shown here in that case).
  Future<String?> _pickYamlFile(String dialogTitle) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) {
      _showStatus('Could not read the selected file.', isError: true);
      return null;
    }

    if (!YamlImportExportScreen.isYamlPath(path)) {
      final name = path.split(Platform.pathSeparator).last;
      _showStatus(
        'Not a YAML file: $name. Select a file ending in .yaml or .yml -- '
        'the file this app exports.',
        isError: true,
      );
      return null;
    }

    return path;
  }

  Future<void> _importRules() async {
    setState(() => _isProcessing = true);
    try {
      _logger.i('Starting rules import');

      // Let user pick a YAML file. F208: _pickYamlFile validates the
      // extension itself -- see its doc for why FileType.custom cannot be
      // used on Android.
      final filePath = await _pickYamlFile('Select Rules YAML File');

      if (filePath == null) {
        // Cancelled, or not a YAML file -- _pickYamlFile has already said
        // which.
        setState(() => _isProcessing = false);
        return;
      }

      // Validate the YAML file first
      RuleSet importedRules;
      try {
        importedRules = await _yamlService.loadRules(filePath);
      } catch (e) {
        _showStatus('Invalid YAML file: $e', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final confirmed = await _showImportConfirmation(
        title: 'Import Rules',
        itemCount: importedRules.rules.length,
        itemType: 'rules',
        filePath: filePath,
      );

      if (confirmed != true) {
        _showStatus('Import cancelled');
        setState(() => _isProcessing = false);
        return;
      }

      // Save to database (atomic replace)
      await _ruleDbStore.saveRules(importedRules);

      // Also update YAML file in app storage (dual-write)
      await _localRuleStore.saveRules(importedRules);

      _logger.i('Imported ${importedRules.rules.length} rules from $filePath');
      _showStatus('Imported ${importedRules.rules.length} rules successfully');
    } catch (e) {
      _logger.e('Failed to import rules', error: e);
      _showStatus('Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importSafeSenders() async {
    setState(() => _isProcessing = true);
    try {
      _logger.i('Starting safe senders import');

      // Let user pick a YAML file. F208: see _pickYamlFile.
      final filePath = await _pickYamlFile('Select Safe Senders YAML File');

      if (filePath == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Validate the YAML file first
      SafeSenderList importedSafeSenders;
      try {
        importedSafeSenders = await _yamlService.loadSafeSenders(filePath);
      } catch (e) {
        _showStatus('Invalid YAML file: $e', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final confirmed = await _showImportConfirmation(
        title: 'Import Safe Senders',
        itemCount: importedSafeSenders.safeSenders.length,
        itemType: 'safe senders',
        filePath: filePath,
      );

      if (confirmed != true) {
        _showStatus('Import cancelled');
        setState(() => _isProcessing = false);
        return;
      }

      // Save to database (atomic replace)
      await _ruleDbStore.saveSafeSenders(importedSafeSenders);

      // Also update YAML file in app storage (dual-write)
      await _localRuleStore.saveSafeSenders(importedSafeSenders);

      _logger.i('Imported ${importedSafeSenders.safeSenders.length} safe senders from $filePath');
      _showStatus(
        'Imported ${importedSafeSenders.safeSenders.length} safe senders successfully',
      );
    } catch (e) {
      _logger.e('Failed to import safe senders', error: e);
      _showStatus('Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- Dialogs ---

  Future<bool?> _showImportConfirmation({
    required String title,
    required int itemCount,
    required String itemType,
    required String filePath,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will replace ALL existing $itemType with '
              '$itemCount $itemType from the selected file.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // F210: was Colors.grey.shade100 under a colourless
                // TextStyle -- the file path being imported was unreadable in
                // dark mode, in the dialog that asks you to confirm it.
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _shortenPath(filePath),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A backup of the current data will be created automatically.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone (except by re-importing).',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Import $itemCount $itemType'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  String _shortenPath(String path) {
    // Show just the file name if the path is very long
    final separator = Platform.isWindows ? '\\' : '/';
    final parts = path.split(separator);
    if (parts.length > 3) {
      return '...${separator}${parts.sublist(parts.length - 2).join(separator)}';
    }
    return path;
  }
}