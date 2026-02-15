import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/providers/email_scan_provider.dart' show EmailActionType, EmailActionResult;
import '../../core/providers/rule_set_provider.dart';
import '../../core/services/email_scanner.dart';
import '../../core/storage/settings_store.dart'; // [NEW] ISSUE #138: Load scan mode from settings
import '../widgets/app_bar_with_exit.dart';
import 'results_display_screen.dart';
import 'settings_screen.dart';

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
  final String accountEmail;

  const ScanProgressScreen({
    super.key,
    required this.platformId,
    required this.platformDisplayName,
    required this.accountId,
    required this.accountEmail,
  });

  @override
  State<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends State<ScanProgressScreen> {
  ScanStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    
    // [NEW] PHASE 3.2: Initialize _previousStatus to prevent auto-navigation on first build
    // This ensures we only auto-navigate when a scan ACTUALLY completes, not when
    // returning to a screen that already has completed status from a previous scan
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    _previousStatus = scanProvider.status;
    
    // [NEW] ISSUE #41 FIX: Set current account for per-account folder storage
    scanProvider.setCurrentAccount(widget.accountId);
    
    // Auto-reset scan state when navigating to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scanProvider.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();

    // [NEW] PHASE 3.1: Auto-navigate to Results when scan completes (Issue #33)
    // [NEW] ISSUE #39 FIX: Update _previousStatus INSIDE the if block to prevent
    // multiple navigation callbacks if build() is called multiple times
    if (_previousStatus != ScanStatus.completed && 
        scanProvider.status == ScanStatus.completed) {
      _previousStatus = scanProvider.status;  // Update immediately to prevent re-scheduling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResultsDisplayScreen(
                platformId: widget.platformId,
                platformDisplayName: widget.platformDisplayName,
                accountId: widget.accountId,
                accountEmail: widget.accountEmail,
              ),
            ),
          );
        }
      });
    } else {
      _previousStatus = scanProvider.status;
    }

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
        appBar: AppBarWithExit(
          title: Text('Manual Scan - ${widget.platformDisplayName}'),
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
                      accountEmail: widget.accountEmail,
                    ),
                  ),
                );
              },
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(scanProvider),
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

    // [NEW] ISSUE #125: Show demo mode indicator if using demo platform
    final isDemoMode = widget.platformId == 'demo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                statusText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (isDemoMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  border: Border.all(color: Colors.amber.shade700),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'DEMO MODE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          scanProvider.statusMessage ?? 'Waiting to begin...',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// [NEW] PHASE 3.1: Removed redundant progress bar and text (Issue #33)
  /// Progress info now shown only in bubble row

  Widget _buildStats(EmailScanProvider scanProvider) {
    // [NEW] PHASE 3.1: Updated bubble row with Found, Processed, Deleted, Moved, Safe, No rule, Errors
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatChip('Found', scanProvider.totalEmails, const Color(0xFF2196F3), Colors.white), // Blue
        _buildStatChip('Processed', scanProvider.processedCount, const Color(0xFF9C27B0), Colors.white), // Purple
        _buildStatChip('Deleted', scanProvider.deletedCount, const Color(0xFFF44336), Colors.white), // Red
        _buildStatChip('Moved', scanProvider.movedCount, const Color(0xFFFF9800), Colors.white), // Orange
        _buildStatChip('Safe', scanProvider.safeSendersCount, const Color(0xFF4CAF50), Colors.white), // Green
        _buildStatChip('No rule', scanProvider.noRuleCount, const Color(0xFF757575), Colors.white), // Grey
        _buildStatChip('Errors', scanProvider.errorCount, const Color(0xFFD32F2F), Colors.white), // Dark Red
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
    
    // [NEW] PHASE 3.1: Re-enable buttons after scan completes (Issue #33)
    final canStartScan = scanProvider.status == ScanStatus.idle || 
                         scanProvider.status == ScanStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // [REMOVED] ISSUE #151: Folder selection removed - use Settings > Manual > Default Folders
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Live Scan'),
                onPressed: canStartScan
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
          onPressed: canStartScan
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
                  accountEmail: widget.accountEmail,
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

  /// [NEW] PHASE 3.1: Show scan mode selection dialog
  /// Start a real IMAP scan
  Future<void> _startRealScan(
    BuildContext context,
    EmailScanProvider scanProvider,
    RuleSetProvider ruleProvider,
  ) async {
    // Show options dialog - [UPDATED] ISSUE #150: Pass accountId for persistent settings
    final daysBack = await showDialog<int>(
      context: context,
      builder: (ctx) => _ScanOptionsDialog(accountId: widget.accountId),
    );

    if (daysBack == null) return; // User cancelled

    // [NEW] ISSUE #138: Load scan mode from account settings BEFORE starting scan
    final settingsStore = SettingsStore();
    final scanMode = await settingsStore.getAccountManualScanMode(widget.accountId) ?? ScanMode.readonly;
    scanProvider.initializeScanMode(mode: scanMode);
    
    final logger = Logger();
    logger.i('[ISSUE #138] Loaded scan mode for manual scan: $scanMode');

    // Immediately update UI to show scan is starting
    scanProvider.startScan(totalEmails: 0);

    // [NEW] SPRINT 12: Navigate to Results immediately after starting scan
    // User feedback: "Start Scan should immediately go to View Results page"
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsDisplayScreen(
            platformId: widget.platformId,
            platformDisplayName: widget.platformDisplayName,
            accountId: widget.accountId,
            accountEmail: widget.accountEmail,
          ),
        ),
      );
    }

    try {
      // Create scanner
      final scanner = EmailScanner(
        platformId: widget.platformId,
        accountId: widget.accountId,
        ruleSetProvider: ruleProvider,
        scanProvider: scanProvider,
      );

      // [FIXED] ISSUE #123+#124: Use saved default folders from Manual Scan tab
      // The Settings screen saves folders per-account; we always use those
      final scanLogger = Logger();
      List<String> foldersToScan;

      // Load saved default folders from Settings > Manual Scan tab
      final savedFolders = await settingsStore.getAccountManualScanFolders(widget.accountId);
      if (savedFolders != null && savedFolders.isNotEmpty) {
        foldersToScan = savedFolders;
        scanLogger.i('[FOLDERS] Using saved default folders from Manual Scan tab: $foldersToScan');
      } else {
        // Fallback to INBOX if no folders configured
        foldersToScan = ['INBOX'];
        scanLogger.i('[FOLDERS] No folders configured in Settings, using default: $foldersToScan');
      }

      scanLogger.i('[LAUNCH] Starting scan of folders: $foldersToScan for $daysBack days back');

      // Start scan in background (will call startScan again with real count)
      await scanner.scanInbox(daysBack: daysBack, folderNames: foldersToScan);
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

  /// [UPDATED] ISSUE #125: Use MockEmailProvider with 50+ sample emails
  Future<void> _startDemoScan(EmailScanProvider scanProvider) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    
    // Create scanner with MockEmailProvider (50+ sample emails)
    final scanner = EmailScanner(
      platformId: 'demo',  // Use demo platform
      accountId: 'demo@example.com',
      ruleSetProvider: ruleProvider,
      scanProvider: scanProvider,
    );
    
    try {
      // Run scan with MockEmailProvider (will load 50+ sample emails)
      await scanner.scanInbox(
        daysBack: 30,
        folderNames: ['INBOX', 'Spam', 'Bulk'],
        scanType: 'demo',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demo scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
/// [UPDATED] ISSUE #150: Loads defaults from SettingsStore and persists selection
class _ScanOptionsDialog extends StatefulWidget {
  final String accountId;

  const _ScanOptionsDialog({required this.accountId});

  @override
  State<_ScanOptionsDialog> createState() => _ScanOptionsDialogState();
}

class _ScanOptionsDialogState extends State<_ScanOptionsDialog> {
  int _daysBack = 7;
  bool _scanAll = true; // [UPDATED] ISSUE #150: Default to "Scan all emails"
  bool _isLoading = true;
  final SettingsStore _settingsStore = SettingsStore();

  @override
  void initState() {
    super.initState();
    _loadSavedSetting();
  }

  Future<void> _loadSavedSetting() async {
    final savedDaysBack = await _settingsStore.getEffectiveDaysBack(
      widget.accountId,
      isBackground: false,
    );
    if (mounted) {
      setState(() {
        if (savedDaysBack == 0) {
          _scanAll = true;
          _daysBack = 7; // Visual slider default when scanning all
        } else {
          _scanAll = false;
          _daysBack = savedDaysBack.clamp(1, 90);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Scan Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How many days back to scan?'),
          const SizedBox(height: 24),

          // "Scan All" checkbox - [UPDATED] ISSUE #150: shown first, checked by default
          CheckboxListTile(
            title: const Text('Scan all emails (no date filter)'),
            value: _scanAll,
            onChanged: (value) {
              setState(() {
                _scanAll = value ?? false;
                if (!_scanAll && _daysBack < 1) {
                  _daysBack = 7; // Reset to 7 when unchecking
                }
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          // Continuous slider (1-90 days) - only visible when not scanning all
          if (!_scanAll) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('1'),
                Expanded(
                  child: Slider(
                    value: _daysBack.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    label: '$_daysBack day${_daysBack == 1 ? "" : "s"}',
                    onChanged: (value) {
                      setState(() {
                        _daysBack = value.round();
                        _scanAll = false; // Slider interaction unchecks scan all
                      });
                    },
                  ),
                ),
                const Text('90'),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Scan last $_daysBack day${_daysBack == 1 ? "" : "s"}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final result = _scanAll ? 0 : _daysBack;
            // [NEW] ISSUE #150: Persist selection for next time
            await _settingsStore.setAccountManualDaysBack(widget.accountId, result);
            if (context.mounted) {
              Navigator.of(context).pop(result);
            }
          },
          child: const Text('Start Scan'),
        ),
      ],
    );
  }
}
