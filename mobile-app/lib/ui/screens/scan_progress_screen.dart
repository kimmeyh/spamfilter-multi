import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../../core/providers/email_scan_provider.dart';
import '../../core/providers/rule_set_provider.dart';
import '../../core/services/email_scanner.dart';
import '../../core/storage/settings_store.dart'; // [NEW] ISSUE #138: Load scan mode from settings
import '../../main.dart' show routeObserver;
import '../widgets/app_bar_with_exit.dart';
import 'results_display_screen.dart';
import 'scan_history_screen.dart';
import 'help_screen.dart';
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

class _ScanProgressScreenState extends State<ScanProgressScreen> with RouteAware {
  List<String> _configuredFolders = ['INBOX'];
  ScanMode _configuredMode = ScanMode.readOnly;

  @override
  void initState() {
    super.initState();

    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);

    // [NEW] ISSUE #41 FIX: Set current account for per-account folder storage
    scanProvider.setCurrentAccount(widget.accountId);

    // Auto-reset scan state when navigating to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scanProvider.reset();
    });

    // Load configured scan settings for display in header
    _loadConfiguredSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // F55 (Sprint 33, v3): subscribe to route events so we can reset the
    // scan provider when Results is popped back to us. Without this, the
    // "Ready to Scan" screen would still show the completed scan state.
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when Results is popped and this screen becomes visible again.
  /// Resets scan state so the screen returns to its "Ready to Scan" view
  /// and the user can kick off another scan.
  @override
  void didPopNext() {
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    scanProvider.reset();
  }

  Future<void> _loadConfiguredSettings() async {
    final settingsStore = SettingsStore();
    // F113 (Sprint 47) + Copilot review: resolve via getEffectiveFolders so a
    // new account with no saved override gets its PROVIDER-specific default
    // folders (AOL Bulk / Gmail Spam, ...) instead of INBOX-only. This is the
    // scan-time path; getAccountManualScanFolders() alone bypassed the provider
    // default and made F113 a settings-display-only change.
    final resolvedFolders =
        await settingsStore.getEffectiveFolders(widget.accountId);
    final mode = await settingsStore.getAccountManualScanMode(widget.accountId);
    if (mounted) {
      setState(() {
        _configuredFolders = resolvedFolders;
        _configuredMode = mode ?? ScanMode.readOnly;
      });
      // Store in provider so results_display_screen shows correct folders
      final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
      scanProvider.setSelectedFolders(resolvedFolders, accountId: widget.accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();

    // F55 (Sprint 33, round 4): Removed the auto-push-on-completion that
    // used to live here. It was causing a DOUBLE push of Results on every
    // live scan: _startRealScan pushes Results once on scan-start, then
    // this build() would push a SECOND Results when status hit completed.
    // User would tap back, pop the top Results, and land on the older
    // Results underneath -- looking like a "refresh".
    //
    // Results now observes scanProvider status directly and renders its
    // own live progress UI during scanning -> completed, so no second
    // push is needed. Scan Progress stays alive underneath Results so
    // back from Results returns here (didPopNext resets to clean state).

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
          title: Text('Manual Scan - ${widget.accountEmail}'),
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
          // F55 (Sprint 33, v3): standardized icon order --
          // History, Accounts, Help, Settings, [X auto].
          actions: [
            IconButton(
              tooltip: 'View Scan History',
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScanHistoryScreen(
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
              tooltip: 'Select Account',
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
            IconButton(
              tooltip: 'Help',
              icon: const Icon(Icons.help_outline),
              onPressed: () => openHelp(
                context,
                // Demo mode deep-links to a different help section.
                widget.platformId == 'demo'
                    ? HelpSection.demoScan
                    : HelpSection.manualScan,
                accountId: widget.accountId,
                accountEmail: widget.accountEmail,
                platformId: widget.platformId,
                platformDisplayName: widget.platformDisplayName,
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectionArea(
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
      ),
    );
  }

  Widget _buildHeader(EmailScanProvider scanProvider) {
    final modeName = scanProvider.getScanModeDisplayName();
    final isReady = scanProvider.status == ScanStatus.idle && scanProvider.results.isEmpty;

    final statusText = switch (scanProvider.status) {
      ScanStatus.idle => isReady ? 'Ready to Scan' : 'Idle',
      ScanStatus.scanning => 'Scanning in progress',
      ScanStatus.paused => 'Paused',
      ScanStatus.completed => 'Scan complete - $modeName',
      ScanStatus.error => 'Scan failed',
    };

    // [NEW] ISSUE #125: Show demo mode indicator if using demo platform
    final isDemoMode = widget.platformId == 'demo';

    // [NEW] ISSUE #156: Display configured mode name from settings
    final configuredModeName = _scanModeDisplayName(_configuredMode);

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
        // [NEW] ISSUE #156: Show scan mode and folders when ready to scan
        if (isReady) ...[
          Text(
            'Mode: $configuredModeName',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            'Folders: ${_configuredFolders.join(", ")}',
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ] else
          Text(
            scanProvider.statusMessage ?? 'Waiting to begin...',
            style: const TextStyle(color: Colors.grey),
          ),
      ],
    );
  }

  /// [NEW] PHASE 3.1: Removed redundant progress bar and text (Issue #33)
  /// Progress info now shown only in bubble row

  /// [UPDATED] Testing feedback: Removed stat bubbles from Manual Scan screen.
  /// During active scan, shows a simple progress indicator.
  Widget _buildStats(EmailScanProvider scanProvider) {
    if (scanProvider.status == ScanStatus.scanning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Scanning... ${scanProvider.processedCount} emails processed',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
    // When not scanning, show nothing (no stat bubbles)
    return const SizedBox.shrink();
  }

  /// [UPDATED] Testing feedback: Simplified controls - removed pause, complete buttons.
  /// Start Live Scan now uses Settings directly (no dialog popup).
  Widget _buildControls(BuildContext context, EmailScanProvider scanProvider) {
    final ruleProvider = context.watch<RuleSetProvider>();

    final canStartScan = scanProvider.status == ScanStatus.idle ||
                         scanProvider.status == ScanStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Live Scan'),
          onPressed: canStartScan
              ? () => _startRealScan(context, scanProvider, ruleProvider)
              : null,
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
          icon: const Icon(Icons.history),
          label: const Text('View Scan History'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScanHistoryScreen(
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

  /// [UPDATED] Testing feedback: Removed Scan Options dialog - uses Settings directly.
  /// Start a real IMAP scan using Settings > Manual > Scan Range
  Future<void> _startRealScan(
    BuildContext context,
    EmailScanProvider scanProvider,
    RuleSetProvider ruleProvider,
  ) async {
    // Load scan configuration directly from Settings (no dialog popup)
    final settingsStore = SettingsStore();
    final daysBack = await settingsStore.getEffectiveDaysBack(
      widget.accountId,
      isBackground: false,
    );

    // Load scan mode from account settings
    final scanMode = await settingsStore.getAccountManualScanMode(widget.accountId) ?? ScanMode.readOnly;
    scanProvider.initializeScanMode(mode: scanMode);

    final logger = Logger();
    logger.i('[SCAN_SCREEN] accountId=${widget.accountId}, platformId=${widget.platformId}');
    logger.i('[SCAN_SCREEN] Loaded settings: scanMode=$scanMode, daysBack=$daysBack');

    // Sprint 38 F86 (Issue #254): if the user added/edited a rule or safe
    // sender right before tapping Start Scan and the rule set is still
    // loading from disk, show a brief "Applying rule(s)..." snackbar and
    // await readiness BEFORE starting the scan. The opportunistic-async
    // mid-scan path handles changes made DURING a scan; this check handles
    // the narrow window between save and re-scan trigger.
    if (ruleProvider.isLoading && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applying new rule(s) before scan starts...'),
          duration: Duration(seconds: 2),
        ),
      );
      // Poll briefly for rule-set readiness (max ~2s). The provider's
      // isLoading flag transitions to false once loadRules() completes.
      // If the deadline expires while still loading (e.g., slow disk + very
      // large rule set), surface a warning rather than silently starting
      // with a stale evaluator -- the user can cancel and retry.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (ruleProvider.isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (ruleProvider.isLoading) {
        logger.w('[SCAN_SCREEN] F86: rule-set still loading after 2s deadline; scan will start with previously-loaded rules');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New rules still loading -- scan will use previously-loaded rules. Re-scan when ready to apply the new rules.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        logger.i('[SCAN_SCREEN] F86: rule-set ready (isLoading=false)');
      }
    }

    // Immediately update UI to show scan is starting (no database record -
    // the EmailScanner.executeScan() will create the real persisted record)
    scanProvider.startScan(totalEmails: 0, persist: false);

    // [NEW] SPRINT 12: Navigate to Results immediately after starting scan
    // User feedback: "Start Scan should immediately go to View Results page"
    // F55 (Sprint 33, v3): push (not pushReplacement) -- back from Results
    // must return to Manual Scan. Staleness fixed by didPopNext reset below.
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

      // [FIXED] ISSUE #123+#124: Use saved default folders from Manual Scan tab.
      // F113 (Sprint 47) + Copilot review: resolve via getEffectiveFolders so a
      // saved per-account override wins, but a new account with no override gets
      // its PROVIDER-specific defaults (AOL Bulk / Gmail Spam, ...) rather than
      // INBOX-only. getEffectiveFolders never returns empty, so no separate
      // INBOX fallback is needed here.
      final scanLogger = Logger();
      final foldersToScan =
          await settingsStore.getEffectiveFolders(widget.accountId);
      scanLogger.i('[FOLDERS] Effective scan folders (override or provider '
          'default): $foldersToScan');

      // Store selected folders in provider so results_display_screen can show them
      scanProvider.setSelectedFolders(foldersToScan, accountId: widget.accountId);

      scanLogger.i('[SCAN_SCREEN] Starting scan: folders=$foldersToScan, daysBack=$daysBack');

      // Start scan in background (will call startScan again with real count)
      await scanner.scanInbox(daysBack: daysBack, folderNames: foldersToScan);
      scanLogger.i('[SCAN_SCREEN] scanInbox() completed successfully');
    } catch (e, st) {
      logger.e('[SCAN_SCREEN] SCAN EXCEPTION: $e\n$st');
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

      // F116 (Sprint 47): match Live Scan -- on completion, navigate to the
      // Results screen (chip/button summary) instead of leaving the demo
      // results as an inline ListView on this screen. This also removes the
      // confusing intermediate progress counts (Harold: those do not need to
      // be shown once the summary buttons are present). ResultsDisplayScreen
      // reads scanProvider.results, which the demo scan just populated.
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultsDisplayScreen(
              platformId: 'demo',
              platformDisplayName: 'Demo',
              accountId: 'demo@example.com',
              accountEmail: 'demo@example.com',
            ),
          ),
        );
      }
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

  String _scanModeDisplayName(ScanMode mode) {
    switch (mode) {
      case ScanMode.readOnly:
        return 'Read-Only';
      case ScanMode.rulesOnly:
        return 'Process Rules Only';
      case ScanMode.safeSendersOnly:
        return 'Process Safe Senders Only';
      case ScanMode.safeSendersAndRules:
        return 'Process Safe Senders + Rules';
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

// [REMOVED] Testing feedback: _ScanOptionsDialog removed.
// Scan now starts directly using Settings > Manual > Scan Range configuration.
