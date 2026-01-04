import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/providers/email_scan_provider.dart' show EmailActionType, EmailActionResult;
import '../../core/providers/rule_set_provider.dart';
import '../../core/services/email_scanner.dart';
import '../screens/folder_selection_screen.dart';
import 'results_display_screen.dart';

/// Displays live scan progress bound to EmailScanProvider.
/// Provides controls to start/pause/resume/reset a scan and
/// view results. Uses demo helpers to exercise the UI without
/// requiring live IMAP connectivity yet.
/// 
/// Auto-resets scan state when navigating to this screen.
class ScanProgressScreen extends StatefulWidget {
  final String platformId;
  final String platformDisplayName;
  final String accountId;
  final String? accountEmail;

  const ScanProgressScreen({
    super.key,
    required this.platformId,
    required this.platformDisplayName,
    required this.accountId,
    this.accountEmail,
  });

  @override
  State<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends State<ScanProgressScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-reset scan state when navigating to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
      scanProvider.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();

    return PopScope(
      // Handle back button to return to account selection with confirmation during scan
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (scanProvider.status == ScanStatus.scanning) {
          // Confirm before leaving during active scan
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Scan?'),
              content: const Text('A scan is in progress. Are you sure you want to go back?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Continue Scanning'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  child: const Text('Cancel Scan'),
                ),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) {
            Navigator.pop(context);
          }
        } else {
          // No scan active, allow back
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scan Progress - ${widget.platformDisplayName}'),
          // Add explicit back button that returns to account selection
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Account Selection',
            onPressed: () async {
              if (scanProvider.status == ScanStatus.scanning) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel Scan?'),
                    content: const Text('A scan is in progress. Are you sure you want to go back?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Continue Scanning'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                        child: const Text('Cancel Scan'),
                      ),
                    ],
                  ),
                );
                if (shouldPop == true && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'View results',
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResultsDisplayScreen(
                      platformId: widget.platformId,
                      platformDisplayName: widget.platformDisplayName,
                      accountId: widget.accountId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(scanProvider),
              const SizedBox(height: 16),
              _buildProgressBar(scanProvider),
              const SizedBox(height: 16),
              _buildStats(scanProvider),
              const SizedBox(height: 16),
              _buildControls(context, scanProvider),
              const SizedBox(height: 16),
              Expanded(child: _buildRecentActivity(scanProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(EmailScanProvider scanProvider) {
    final modeName = scanProvider.getScanModeDisplayName();
    final statusText = switch (scanProvider.status) {
      ScanStatus.idle => scanProvider.results.isEmpty
          ? 'Ready to scan - $modeName'
          : 'Idle',
      ScanStatus.scanning => 'Scanning in progress',
      ScanStatus.paused => 'Paused',
      ScanStatus.completed => 'Scan complete - $modeName',
      ScanStatus.error => 'Scan failed',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          scanProvider.statusMessage ?? 'Waiting to begin...',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgressBar(EmailScanProvider scanProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: scanProvider.progress),
        const SizedBox(height: 8),
        Text('${scanProvider.processedCount} / ${scanProvider.totalEmails} processed'),
      ],
    );
  }

  Widget _buildStats(EmailScanProvider scanProvider) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatChip('Deleted', scanProvider.deletedCount, Colors.red.shade100, Colors.red.shade800),
        _buildStatChip('Moved', scanProvider.movedCount, Colors.orange.shade100, Colors.orange.shade800),
        _buildStatChip('Safe', scanProvider.safeSendersCount, Colors.green.shade100, Colors.green.shade800),
        _buildStatChip('Errors', scanProvider.errorCount, Colors.grey.shade200, Colors.grey.shade800),
      ],
    );
  }

  Widget _buildStatChip(String label, int value, Color bg, Color fg) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildControls(BuildContext context, EmailScanProvider scanProvider) {
    final ruleProvider = context.watch<RuleSetProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // ✨ PHASE 3.1: Scan Mode button
          OutlinedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text('Scan Mode: ${scanProvider.getScanModeDisplayName()}'),
            onPressed: scanProvider.status == ScanStatus.idle
                ? () => _showScanModeDialog(context, scanProvider)
                : null,
          ),
          const SizedBox(height: 12),
          // Folder selection button (Phase 2 Sprint 3)
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Folders to Scan'),
            onPressed: scanProvider.status == ScanStatus.idle
                ? () => _showFolderSelection(context, scanProvider)
                : null,
          ),
          const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Live Scan'),
                onPressed: scanProvider.status == ScanStatus.idle
                    ? () => _startRealScan(context, scanProvider, ruleProvider)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(scanProvider.status == ScanStatus.paused ? Icons.play_arrow : Icons.pause),
                label: Text(scanProvider.status == ScanStatus.paused ? 'Resume' : 'Pause'),
                onPressed: scanProvider.status == ScanStatus.scanning
                    ? scanProvider.pauseScan
                    : scanProvider.status == ScanStatus.paused
                        ? scanProvider.resumeScan
                        : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
                onPressed: scanProvider.status == ScanStatus.scanning ? scanProvider.completeScan : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.science),
          label: const Text('Start Demo Scan (Testing)'),
          onPressed: scanProvider.status == ScanStatus.idle
              ? () => _startDemoScan(scanProvider)
              : null,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('View results'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultsDisplayScreen(
                  platformId: widget.platformId,
                  platformDisplayName: widget.platformDisplayName,
                  accountId: widget.accountId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity(EmailScanProvider scanProvider) {
    // Show status message while scanning but before results appear
    if (scanProvider.status == ScanStatus.scanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              scanProvider.statusMessage ?? 'Scan in progress...',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show "no results" message only when idle with empty results
    if (scanProvider.results.isEmpty && scanProvider.status == ScanStatus.idle) {
      return Center(
        child: Text(
          'No results yet. Start a scan to see activity.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Show empty state for completed/error states with no results
    if (scanProvider.results.isEmpty) {
      return Center(
        child: Text(
          'No emails processed.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    final recent = scanProvider.results.reversed.take(20).toList();
    return ListView.separated(
      itemCount: recent.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final item = recent[index];
        return ListTile(
          leading: _actionIcon(item.action),
          title: Text(item.email.subject),
          subtitle: Text('${item.email.from} • ${item.evaluationResult?.matchedRule ?? 'No rule'}'),
          trailing: item.success
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.error, color: Colors.red),
        );
      },
    );
  }

    /// Show folder selection screen (Phase 2 Sprint 3)
    Future<void> _showFolderSelection(
      BuildContext context,
      EmailScanProvider scanProvider,
    ) async {
      final logger = Logger();

      final selected = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => FolderSelectionScreen(
          platformId: widget.platformId,
          accountId: widget.accountId,
          accountEmail: widget.accountEmail,
          onFoldersSelected: (folders) {
            logger.i('📁 Folders selected for scan: $folders');
            // Store selected folders in scanProvider for use during scan
            // Will be available as scanProvider.selectedFolders
          },
        ),
      );

      if (selected != null && context.mounted) {
        logger.i('✅ User confirmed folders: $selected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ready to scan: ${selected.join(", ")}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

  /// ✨ PHASE 3.1: Show scan mode selection dialog
  Future<void> _showScanModeDialog(
    BuildContext context,
    EmailScanProvider scanProvider,
  ) async {
    ScanMode selectedMode = scanProvider.scanMode;
    int testLimit = scanProvider.emailTestLimit ?? 50;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Scan Mode'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Read-Only
                RadioListTile<ScanMode>(
                  value: ScanMode.readonly,
                  groupValue: selectedMode,
                  title: const Text('Read-Only'),
                  subtitle: const Text('Safe testing - no emails modified'),
                  onChanged: (value) {
                    setState(() => selectedMode = value!);
                  },
                ),
                // Test Limited Emails
                RadioListTile<ScanMode>(
                  value: ScanMode.testLimit,
                  groupValue: selectedMode,
                  title: const Text('Test Limited Emails'),
                  subtitle: Text('Modify up to $testLimit emails'),
                  onChanged: (value) {
                    setState(() => selectedMode = value!);
                  },
                ),
                // Full Scan with Revert
                RadioListTile<ScanMode>(
                  value: ScanMode.testAll,
                  groupValue: selectedMode,
                  title: const Text('Full Scan with Revert'),
                  subtitle: const Text('All changes (can revert)'),
                  onChanged: (value) {
                    setState(() => selectedMode = value!);
                  },
                ),
                // Full Scan (PERMANENT)
                RadioListTile<ScanMode>(
                  value: ScanMode.fullScan,
                  groupValue: selectedMode,
                  title: const Text('Full Scan'),
                  subtitle: const Text('PERMANENT delete/move (cannot revert)', 
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onChanged: (value) {
                    setState(() => selectedMode = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Show warning for Full Scan mode
                if (selectedMode == ScanMode.fullScan) {
                  final confirmed = await showDialog<bool>(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Warning: Full Scan Mode'),
                        ],
                      ),
                      content: const Text(
                        'Full Scan mode will PERMANENTLY delete or move emails based on your rules.\n\n'
                        'This action CANNOT be undone.\n\n'
                        'Are you sure you want to enable Full Scan mode?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Enable Full Scan'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed != true) {
                    return; // User cancelled
                  }
                }

                // Apply the mode
                scanProvider.initializeScanMode(
                  mode: selectedMode,
                  testLimit: selectedMode == ScanMode.testLimit ? testLimit : null,
                );
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  /// Start a real IMAP scan
  Future<void> _startRealScan(
    BuildContext context,
    EmailScanProvider scanProvider,
    RuleSetProvider ruleProvider,
  ) async {
    // Show options dialog
    final daysBack = await showDialog<int>(
      context: context,
      builder: (ctx) => const _ScanOptionsDialog(),
    );

    if (daysBack == null) return; // User cancelled

    // Immediately update UI to show scan is starting
    scanProvider.startScan(totalEmails: 0);

    try {
      // Create scanner
      final scanner = EmailScanner(
        platformId: widget.platformId,
        accountId: widget.accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
      );

      // Start scan in background (will call startScan again with real count)
      await scanner.scanInbox(daysBack: daysBack);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startDemoScan(EmailScanProvider scanProvider) {
    scanProvider.startScan(totalEmails: 10);
    
    // Record some sample results
    for (int i = 0; i < 10; i++) {
      final email = EmailMessage(
        id: 'msg_$i',
        from: 'sender$i@example.com',
        subject: 'Sample subject $i',
        body: 'Body of sample email $i',
        headers: const {},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      final action = switch (i % 3) {
        0 => EmailActionType.delete,
        1 => EmailActionType.moveToJunk,
        _ => EmailActionType.safeSender,
      };

      scanProvider.updateProgress(
        email: email,
        message: 'Demo processing ${email.subject}',
      );
      scanProvider.recordResult(
        EmailActionResult(
          email: email,
          evaluationResult: null,
          action: action,
          success: true,
        ),
      );
    }
    
    scanProvider.completeScan();
  }

  Widget _actionIcon(EmailActionType action) {
    switch (action) {
      case EmailActionType.delete:
        return const Icon(Icons.delete, color: Colors.red);
      case EmailActionType.moveToJunk:
        return const Icon(Icons.archive, color: Colors.orange);
      case EmailActionType.safeSender:
        return const Icon(Icons.check_circle, color: Colors.green);
      case EmailActionType.markAsRead:
        return const Icon(Icons.mark_email_read, color: Colors.blueGrey);
      case EmailActionType.none:
        return const Icon(Icons.mail_outline, color: Colors.grey);
    }
  }
}

/// Dialog for scan options
class _ScanOptionsDialog extends StatefulWidget {
  const _ScanOptionsDialog();

  @override
  State<_ScanOptionsDialog> createState() => _ScanOptionsDialogState();
}

class _ScanOptionsDialogState extends State<_ScanOptionsDialog> {
  int _daysBack = 7;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How many days back to scan?'),
          const SizedBox(height: 16),
          Slider(
            value: _daysBack.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_daysBack days',
            onChanged: (value) {
              setState(() => _daysBack = value.round());
            },
          ),
          Text(
            'Scan last $_daysBack days',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_daysBack),
          child: const Text('Start Scan'),
        ),
      ],
    );
  }
}
