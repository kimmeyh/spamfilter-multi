import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/auth_warning_dialog.dart';
import 'help_screen.dart';
import 'scan_history_screen.dart';
import 'scan_progress_screen.dart';
import 'settings_screen.dart';

import '../../core/providers/email_scan_provider.dart' show EmailScanProvider, EmailActionResult, EmailActionType, ScanStatus, ScanMode;
import '../../core/providers/rule_set_provider.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/services/auth_results_parser.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/services/rule_evaluator.dart';
import '../../core/services/rule_quick_action_service.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/data/common_email_providers.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart' show SpamFilterPlatform, FilterAction;
import '../../adapters/storage/secure_credentials_store.dart';
import '../widgets/empty_state.dart';

/// Displays summary of scan results bound to EmailScanProvider.
class ResultsDisplayScreen extends StatefulWidget {
  final String platformId;
  final String platformDisplayName;
  final String accountId;
  final String accountEmail;

  /// Optional: load a specific historical scan by ID (from Scan History screen)
  final int? historicalScanId;

  const ResultsDisplayScreen({
    super.key,
    required this.platformId,
    required this.platformDisplayName,
    required this.accountId,
    required this.accountEmail,
    this.historicalScanId,
  });

  @override
  State<ResultsDisplayScreen> createState() => _ResultsDisplayScreenState();
}

/// Special filter types beyond EmailActionType
enum SpecialFilter {
  found,      // All emails (Found)
  processed,  // All processed emails (Processed)
  error,      // Only emails with errors
}

class _ResultsDisplayScreenState extends State<ResultsDisplayScreen> {
  // Filter state: null means show all, otherwise filter by this action type or special filter
  EmailActionType? _filter;
  SpecialFilter? _specialFilter;

  // Search state (Item 8: Ctrl-F search)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // Issue 2a: Auto-focus on Ctrl+F
  String _searchQuery = '';
  bool _showSearch = false;

  // Folder filter state (Item 6: folder dropdown)
  Set<String> _selectedFolders = {};

  // Issue 3: Cache folders for performance
  List<String>? _cachedFolders;

  // [NEW] Testing feedback FB-4/FB-5: Historical scan result data
  ScanResult? _lastCompletedScan;
  bool _hasEverScanned = false;
  bool _historicalLoaded = false;
  List<EmailActionResult> _historicalResults = [];

  // F21: Track re-evaluated results for emails modified during this session.
  // Key is email.from + email.subject (unique enough for a single scan session).
  // When a user adds a rule inline, the email is re-evaluated against current
  // rules and the new EvaluationResult is stored here. This persists during
  // the review session so the user can see which items they have assigned rules to.
  final Map<String, EvaluationResult> _evaluationOverrides = {};

  // F38: Track emails that have been re-processed via IMAP to avoid duplicate actions.
  // Key is the same email key used by _evaluationOverrides.
  final Set<String> _reProcessedEmailKeys = {};

  // Track emails to hide from the list after rule change (removed immediately
  // before IMAP action completes for instant visual feedback).
  final Set<String> _hiddenEmailKeys = {};

  // F38: Non-blocking re-processing state
  bool _isReProcessing = false;
  int _reProcessTotal = 0;
  int _reProcessCompleted = 0;

  // Sprint 38 F82 (Issue #252): the "no-rules" count at first display of
  // this screen for this scan. Captured once via _captureInitialNoRuleCount
  // and unchanged for the session, so the footer can show
  // "M addressed / N initial no-rules" cumulatively.
  int? _initialNoRuleCount;

  @override
  void initState() {
    super.initState();
    // Item 4: Set Processed filter on by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _specialFilter = SpecialFilter.processed;
      });
    });
    // Load last completed scan for historical display
    _loadLastCompletedScan();
  }

  /// Load the most recent completed scan and its email actions from database
  /// If historicalScanId is provided, loads that specific scan instead
  Future<void> _loadLastCompletedScan() async {
    try {
      final dbHelper = DatabaseHelper();
      final scanResultStore = ScanResultStore(dbHelper);

      // Load specific scan if historicalScanId provided, otherwise latest
      final ScanResult? lastScan;
      if (widget.historicalScanId != null) {
        lastScan = await scanResultStore.getScanResultById(widget.historicalScanId!);
      } else {
        lastScan = await scanResultStore.getLatestCompletedScan(widget.accountId);
      }

      List<EmailActionResult> historicalResults = [];
      if (lastScan != null && lastScan.id != null) {
        // Load individual email actions for this scan
        final actionMaps = await dbHelper.queryEmailActions(
          scanResultId: lastScan.id,
        );
        historicalResults = actionMaps.map((map) {
          final emailFrom = map['email_from'] as String? ?? '';
          final emailSubject = map['email_subject'] as String? ?? '';
          // Sprint 38 Round 5 fix (2026-05-17): populate a minimal headers
          // map so header-based block rules ('header' conditions targeting
          // the From: header, which is what the entire_domain /
          // exact_domain inline-add types generate) match historical
          // emails. Round 4 had headers={} which made
          // RuleEvaluator._matchesHeaderList iterate an empty entries
          // list and return no match -- this caused the F82 footer
          // counter to stay at 0 and rows not to hide after inline
          // rule-add on the Scan History > Scan Results path (Image 9
          // from Round 4 testing). Subject header included for parity
          // with subject-targeting rules.
          // Use 'From' / 'Subject' case to match what the IMAP and Gmail
          // adapters populate (raw RFC822 header names). The evaluator's
          // _matchesHeaderList compares keys case-insensitively, so this
          // is just for parity, but if any future code does a case-
          // sensitive header lookup it should see the same shape that
          // live scans produce.
          final email = EmailMessage(
            id: map['email_id'] as String? ?? '',
            from: emailFrom,
            subject: emailSubject,
            body: '',
            headers: {
              'From': emailFrom,
              'Subject': emailSubject,
            },
            receivedDate: DateTime.fromMillisecondsSinceEpoch(
              (map['email_received_date'] as int?) ?? 0,
            ),
            folderName: map['email_folder'] as String? ?? '',
            // F91 (Sprint 39): carry the persisted RFC 5322 Message-ID
            // (nullable; older rows predating the v6 migration are null).
            messageIdHeader: map['rfc5322_message_id'] as String?,
            // F96 (Sprint 43): re-hydrate the SPF/DKIM/DMARC classification
            // captured at scan time. The reconstructed headers above carry only
            // From/Subject, so a fresh parse would always classify GREY; this
            // override lets the inline safe-sender add fire the RED
            // anti-phishing warning. Nullable: rows scanned before v8 are null
            // and fall back to GREY (pre-F96 behavior).
            authClassificationOverride:
                map['auth_classification'] as String?,
          );
          final actionStr = map['action_type'] as String? ?? 'none';
          final action = EmailActionType.values.firstWhere(
            (e) => e.name == actionStr,
            orElse: () => EmailActionType.none,
          );
          // Reconstruct EvaluationResult from stored database fields
          // so historical scans show matched rule names and popup highlighting
          final matchedRuleName = map['matched_rule_name'] as String? ?? '';
          final matchedPattern = map['matched_pattern'] as String? ?? '';
          final isSafeSender = (map['is_safe_sender'] as int?) == 1;
          final hasEvaluation = matchedRuleName.isNotEmpty || isSafeSender;
          final evaluationResult = hasEvaluation
              ? EvaluationResult(
                  shouldDelete: action == EmailActionType.delete,
                  shouldMove: action == EmailActionType.moveToJunk,
                  matchedRule: matchedRuleName,
                  matchedPattern: matchedPattern,
                  isSafeSender: isSafeSender,
                )
              : null;

          return EmailActionResult(
            email: email,
            action: action,
            success: (map['success'] as int?) == 1,
            error: map['error_message'] as String?,
            evaluationResult: evaluationResult,
          );
        }).toList();
      }

      // Stage historical results into the field before re-evaluation so
      // _reEvaluateNoRuleEmails / _updateOldestNoRuleCursorsFromResults /
      // _reProcessAffectedEmails all see the freshly-loaded set. We
      // intentionally do NOT call setState yet -- we want the FIRST paint
      // of this screen to already reflect any cross-screen rule-adds.
      _lastCompletedScan = lastScan;
      _hasEverScanned = lastScan != null;
      _historicalResults = historicalResults;

      // Sprint 38 Round 7 fix (2026-05-17, revised Round 8 same day): when
      // re-entering Scan History > Scan Results for a historical scan,
      // mirror the inline-rule-add sibling sequence so rules added/changed
      // via Settings > Manage Rules (or any other cross-screen path) are
      // reflected on the FIRST paint, before _initialNoRuleCount is
      // captured and before the user toggles any filter.
      //
      // Round 7's mistake: this block ran AFTER setState({_historicalLoaded
      // = true}), so the first paint cached _initialNoRuleCount and
      // populated the chip count from the pre-eval state; only the
      // subsequent rebuild (triggered by the user selecting the "No rule"
      // filter) saw the post-eval overrides.
      //
      // Round 8 corrects ordering: run the full reload + re-eval +
      // re-process sequence FIRST, then commit _historicalLoaded = true
      // in a single setState so the initial paint shows the correct
      // chip count, hidden rows, and footer denominator.
      //
      // Gated on historicalScanId != null so the live-scan-open path is
      // untouched.
      if (widget.historicalScanId != null && historicalResults.isNotEmpty) {
        try {
          final ruleProvider =
              Provider.of<RuleSetProvider>(context, listen: false);
          await ruleProvider.loadRules();
          await ruleProvider.loadSafeSenders();
          await _reEvaluateNoRuleEmails();
          await _updateOldestNoRuleCursorsFromResults();
          await _reProcessAffectedEmails();
          // Sprint 38 Round 9 fix (2026-05-17): _reProcessAffectedEmails
          // returns early when scanProvider.scanMode == readOnly, which is
          // the default state on app launch when no scan has been
          // initiated in the current session. That leaves _hiddenEmailKeys
          // empty even though _evaluationOverrides now contains
          // newly-matched cross-screen rule entries -- the user sees the
          // chip count and footer update (those read from overrides) but
          // the matched rows still appear in the unfiltered list. The
          // visual hiding is purely UI cleanup of addressed no-rules and
          // is safe regardless of scanMode (no IMAP side effects). Apply
          // it here as an unconditional pass so the unfiltered list shows
          // the same final state the "No rule" filter would show.
          for (final result in historicalResults) {
            final key = _getEmailKey(result.email);
            final override = _evaluationOverrides[key];
            if (override == null) continue;
            if (result.action != EmailActionType.none) continue;
            if (override.matchedRule.isEmpty && !override.isSafeSender) continue;
            _hiddenEmailKeys.add(key);
          }
        } catch (_) {
          // Non-fatal: stale view falls back to last-known evaluation.
          // Inline rule-adds on this screen still pick up correctly.
        }
      }

      if (mounted) {
        setState(() {
          _historicalLoaded = true;
        });
      }
    } catch (e) {
      // If loading fails, continue with empty state
      if (mounted) {
        setState(() {
          _historicalLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Issue 2a: Dispose focus node
    super.dispose();
  }

  /// Export scan results to CSV file
  Future<void> _exportResults(
    BuildContext context,
    EmailScanProvider scanProvider,
  ) async {
    final logger = Logger();

    try {
      // Generate CSV content
      final csvContent = scanProvider.exportResultsToCSV();

      // Get configured export directory from Settings, or use default
      final settingsStore = SettingsStore();
      final configuredDir = await settingsStore.getCsvExportDirectory();

      String exportPath;
      if (configuredDir != null && configuredDir.isNotEmpty) {
        // Use configured directory
        final dir = Directory(configuredDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        exportPath = configuredDir;
      } else {
        // Use default directory (downloads on mobile, documents on desktop)
        final directory = Platform.isAndroid || Platform.isIOS
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        if (directory == null) {
          throw Exception('Could not access storage directory');
        }
        exportPath = directory.path;
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'scan_results_$timestamp.csv';
      // Normalize export path - remove trailing slashes to avoid double separators
      String normalizedPath = exportPath;
      while (normalizedPath.endsWith('/') || normalizedPath.endsWith('\\')) {
        normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
      }
      // Use platform-appropriate path separator
      final pathSeparator = Platform.isWindows ? '\\' : '/';
      final filePath = '$normalizedPath$pathSeparator$filename';

      // Write CSV to file
      final file = File(filePath);
      await file.writeAsString(csvContent);

      logger.i('[OK] Exported scan results to: $filePath');

      if (context.mounted) {
        // Show success dialog with selectable file path for copy support
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Results exported to:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the path above to copy it.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      logger.e('[FAIL] Export failed: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Filter results based on current filter state, search query, and folder filter
  List<EmailActionResult> _getFilteredResults(List<EmailActionResult> allResults) {
    var results = allResults;

    // Remove emails hidden after rule change (instant visual removal)
    if (_hiddenEmailKeys.isNotEmpty) {
      results = results.where((r) => !_hiddenEmailKeys.contains(_getEmailKey(r.email))).toList();
    }

    // Apply special filter first (Found, Processed, Error)
    if (_specialFilter != null) {
      switch (_specialFilter!) {
        case SpecialFilter.found:
          // Show all emails (no filtering)
          break;
        case SpecialFilter.processed:
          // Show only successfully processed emails
          results = results.where((result) => result.success).toList();
          break;
        case SpecialFilter.error:
          // Show only emails with errors
          results = results.where((result) => !result.success).toList();
          break;
      }
    }
    
    // Apply action type filter using effective action (accounts for re-evaluation overrides)
    if (_filter != null) {
      results = results.where((result) => _getEffectiveAction(result) == _filter).toList();
    }
    
    // Apply search filter (Item 8: Ctrl-F search)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((result) {
        final from = result.email.from.toLowerCase();
        final subject = result.email.subject.toLowerCase();
        final folder = result.email.folderName.toLowerCase();
        // F21: Use effective evaluation for search
        final effectiveEval = _getEffectiveEvaluation(result);
        final rule = (effectiveEval?.matchedRule ?? '').toLowerCase();
        return from.contains(query) ||
               subject.contains(query) ||
               folder.contains(query) ||
               rule.contains(query);
      }).toList();
    }
    
    // Apply folder filter (Item 6: folder dropdown)
    if (_selectedFolders.isNotEmpty) {
      results = results.where((result) {
        return _selectedFolders.contains(result.email.folderName);
      }).toList();
    }
    
    // Item 5: Sort by folder → domain.tld → email
    results.sort((a, b) {
      // First sort by folder
      final folderCompare = a.email.folderName.compareTo(b.email.folderName);
      if (folderCompare != 0) return folderCompare;
      
      // Then sort by domain
      final bodyParser = EmailBodyParser();
      final domainA = bodyParser.extractDomainFromEmail(a.email.from) ?? '';
      final domainB = bodyParser.extractDomainFromEmail(b.email.from) ?? '';
      final domainCompare = domainA.compareTo(domainB);
      if (domainCompare != 0) return domainCompare;
      
      // Finally sort by email
      final emailA = bodyParser.extractEmailAddress(a.email.from);
      final emailB = bodyParser.extractEmailAddress(b.email.from);
      return emailA.compareTo(emailB);
    });
    
    return results;
  }

  /// Toggle filter when stat chip is clicked
  void _toggleFilter(EmailActionType? filterType) {
    setState(() {
      // If clicking the same filter, clear it (show all)
      if (_filter == filterType) {
        _filter = null;
      } else {
        _filter = filterType;
        _specialFilter = null; // Clear special filter when action filter is set
      }
    });
  }
  
  /// Toggle special filter (Found, Processed, Error)
  void _toggleSpecialFilter(SpecialFilter filterType) {
    setState(() {
      // If clicking the same filter, clear it (show all)
      if (_specialFilter == filterType) {
        _specialFilter = null;
      } else {
        _specialFilter = filterType;
        _filter = null; // Clear action filter when special filter is set
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<EmailScanProvider>();
    final summary = scanProvider.getSummary();
    final liveResults = scanProvider.results;

    // When viewing from Scan History (historicalScanId provided), always use
    // the historically-loaded results, not stale provider results from a
    // previous live scan. Only use live provider results for active scans.
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    final allResults = (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);
    final filteredResults = _getFilteredResults(allResults);

    // Issue 3: Cache folders list for performance (only extract once per results set)
    if (_cachedFolders == null || _cachedFolders!.length != allResults.map((r) => r.email.folderName).toSet().length) {
      _cachedFolders = allResults.map((r) => r.email.folderName).toSet().toList()..sort();
    }

    // Issue 2: Wrap with Focus to detect Ctrl+F keyboard shortcut
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Detect Ctrl+F (or Cmd+F on macOS)
        if (event is KeyDownEvent) {
          final isFPressed = event.logicalKey == LogicalKeyboardKey.keyF;

          // Check if Ctrl/Cmd + F is pressed
          if ((HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) && isFPressed) {
            setState(() {
              _showSearch = true;
            });
            // Issue 2a: Auto-focus the search field after opening
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      appBar: AppBarWithExit(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // Issue 2a: Connect focus node
                autofocus: true,
                style: const TextStyle(color: Colors.black), // Issue 2b: Black text
                decoration: const InputDecoration(
                  hintText: 'Search emails...',
                  hintStyle: TextStyle(color: Colors.black54), // Issue 2b: Dark gray hint
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text('Results - ${widget.accountEmail} - ${widget.platformDisplayName}'),
        // Add explicit back button that returns to account selection
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close Search',
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: widget.historicalScanId != null
                    ? 'Back to Scan History'
                    : 'Back to Manual Scan',
                onPressed: () {
                  // Dismiss any showing snackbar before navigating
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  // F55 (Sprint 33, v3): pop to Manual Scan (ScanProgress).
                  // ScanProgress subscribes to routeObserver and resets its
                  // scan provider on didPopNext, so the user lands on a
                  // clean "Ready to Scan" screen -- no partial results.
                  Navigator.pop(context);
                },
              ),
        // F55 (Sprint 33, v3): standardized icon order --
        // Download, Search, History, Accounts, Help, Settings, [X auto].
        actions: [
          if (!_showSearch) ...[
            IconButton(
              tooltip: 'Export Results to CSV',
              icon: const Icon(Icons.file_download),
              onPressed: () => _exportResults(context, scanProvider),
            ),
            IconButton(
              tooltip: 'Search (Ctrl+F)',
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
            ),
            IconButton(
              tooltip: 'View Scan History',
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScanHistoryScreen(
                      accountId: widget.accountId,
                      accountEmail: widget.accountEmail,
                      platformId: widget.platformId,
                      platformDisplayName: widget.platformDisplayName,
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
                // Use demo-scan section when this screen is showing a demo
                // scan, otherwise the default live-scan Results section.
                widget.platformId == 'demo'
                    ? HelpSection.demoScan
                    : HelpSection.resultsDisplay,
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
        ],
      ),
      body: SelectionArea(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(summary, scanProvider, allResults),
            // F38: Non-blocking re-processing banner
            if (_isReProcessing) ...[
              const SizedBox(height: 8),
              _buildReProcessingBanner(),
            ],
            const SizedBox(height: 16),
            // Show filter status if active
            if (_filter != null || _specialFilter != null || _selectedFolders.isNotEmpty) ...[
              _buildFilterStatus(filteredResults.length, allResults.length),
              const SizedBox(height: 8),
            ],
            // Sprint 38 F82 (Issue #252): "M of N no-rules addressed" indicator
            // when there were any no-rule emails to triage. Hidden when the
            // initial count was zero (clean scan, nothing for the user to do).
            _buildNoRuleProgressFooter(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Trigger a rebuild to refresh the results display
                  // Results are already in scan provider, just refresh UI
                  setState(() {});
                  // Small delay to show refresh animation
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: filteredResults.isEmpty
                    ? ListView( // Wrap empty state in ListView for pull-to-refresh gesture
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            // [UPDATED] Testing feedback FB-5: Only show "No Results Yet"
                            // if no scan has EVER been run for this account
                            child: scanProvider.status == ScanStatus.scanning
                                ? const ScanStartedEmptyState()
                                : scanProvider.status == ScanStatus.completed && _filter == null
                                    ? const ScanCompleteNoEmailsEmptyState()
                                    : _filter != null
                                        ? const NoMatchingEmailsEmptyState()
                                        : (_historicalLoaded && !_hasEverScanned)
                                            ? const NoResultsEmptyState()
                                            : const ScanCompleteNoEmailsEmptyState(),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: filteredResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) => _buildResultTile(filteredResults[index]),
                      ),
              ),
            ),
            // Action buttons at bottom
            const SizedBox(height: 16),
            if (widget.historicalScanId != null)
              // [FIX] FB-1: When viewing from Scan History, show single back button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Scan History'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Dismiss any showing snackbar before navigating
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        // Pop back to Account Selection Screen (past Scan Progress)
                        Navigator.popUntil(
                          context,
                          (route) => route.isFirst,
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Accounts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // [NEW] SPRINT 12 FIX: Push replacement to Scan screen directly
                        // This avoids navigation state issues with pop() and ensures
                        // reliable navigation to the scan screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanProgressScreen(
                              platformId: widget.platformId,
                              platformDisplayName: widget.platformDisplayName,
                              accountId: widget.accountId,
                              accountEmail: widget.accountEmail,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      ), // Close SelectionArea
    ),
    ); // Close Focus widget for Issue 2: Ctrl+F shortcut
  }

  Widget _buildFilterStatus(int filteredCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing $filteredCount of $totalCount emails • Tap chip again to clear filter',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: () => _toggleFilter(null),
            tooltip: 'Clear filter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build the Summary title including scan mode and folder names
  String _buildSummaryTitle(
    bool hasLiveResults,
    bool showingHistorical,
    EmailScanProvider scanProvider,
    List<EmailActionResult> allResults,
  ) {
    String title;
    if (hasLiveResults) {
      title = 'Summary - ${scanProvider.getScanModeDisplayName()}';
    } else if (showingHistorical) {
      title = 'Scan Results';
    } else {
      title = 'Summary';
    }

    // Append folder names - use provider's selected folders (available before
    // results arrive), historical scan's folders, or derive from results
    List<String> folders;
    if (hasLiveResults || scanProvider.status == ScanStatus.scanning) {
      folders = List.from(scanProvider.getSelectedFoldersForAccount(widget.accountId))..sort();
    } else if (showingHistorical && _lastCompletedScan != null && _lastCompletedScan!.foldersScanned.isNotEmpty) {
      folders = List.from(_lastCompletedScan!.foldersScanned)..sort();
    } else {
      folders = allResults.map((r) => r.email.folderName).toSet().toList()..sort();
    }
    if (folders.isNotEmpty) {
      title += ' - Folder(s): ${folders.join(', ')}';
    }

    return title;
  }

  Widget _buildSummary(Map<String, dynamic> summary, EmailScanProvider scanProvider, List<EmailActionResult> allResults) {
    // Determine if showing live or historical results.
    // When historicalScanId is set (viewing from Scan History), always treat as historical
    // regardless of stale provider state.
    final isViewingHistory = widget.historicalScanId != null;
    final hasLiveResults = !isViewingHistory &&
        (scanProvider.results.isNotEmpty || scanProvider.status == ScanStatus.scanning);
    final showingHistorical = !hasLiveResults && _lastCompletedScan != null;

    // [UPDATED] FB-2a: Use historical scan's mode when showing historical results,
    // not the live provider's mode (which defaults to readonly when idle)
    final bool isReadOnly;
    final bool isSafeSendersOnly;
    final bool isRulesOnly;
    if (showingHistorical && _lastCompletedScan != null) {
      final historicalMode = _lastCompletedScan!.scanMode;
      isReadOnly = historicalMode == 'readOnly' || historicalMode == 'readonly';
      isSafeSendersOnly = historicalMode == 'safeSendersOnly' || historicalMode == 'testAll';
      isRulesOnly = historicalMode == 'rulesOnly' || historicalMode == 'testLimit';
    } else {
      final scanMode = scanProvider.scanMode;
      isReadOnly = scanMode == ScanMode.readOnly;
      isSafeSendersOnly = scanMode == ScanMode.safeSendersOnly;
      isRulesOnly = scanMode == ScanMode.rulesOnly;
    }

    // Build scan type and time info
    String? scanTypeLabel;
    String? scanTimeLabel;
    if (hasLiveResults) {
      scanTypeLabel = 'Live Scan';
    } else if (showingHistorical && _lastCompletedScan != null) {
      scanTypeLabel = _lastCompletedScan!.scanType == 'background' ? 'Background Scan' : 'Live Scan';
      if (_lastCompletedScan!.completedAt != null) {
        final completedDate = DateTime.fromMillisecondsSinceEpoch(_lastCompletedScan!.completedAt!);
        scanTimeLabel = 'Completed: ${completedDate.toString().substring(0, 16)}';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _buildSummaryTitle(hasLiveResults, showingHistorical, scanProvider, allResults),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (scanTypeLabel != null || scanTimeLabel != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  if (scanTypeLabel != null)
                    Text(
                      scanTypeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (scanTimeLabel != null)
                    Text(
                      scanTimeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
            // [NEW] F34: Scan status indicator (in-progress or completed)
            if (hasLiveResults) ...[
              const SizedBox(height: 8),
              _buildScanStatusIndicator(scanProvider),
            ],
            const SizedBox(height: 8),
            // [UPDATED] FB-2a: Use same interactive filter chips for both live and historical
            Builder(builder: (_) {
              // Compute counts from allResults (works for both live and historical)
              final foundCount = showingHistorical
                  ? (_lastCompletedScan?.totalEmails ?? allResults.length)
                  : scanProvider.totalEmails;
              final processedCount = showingHistorical
                  ? allResults.length
                  : scanProvider.processedCount;
              // Use effective action to account for inline re-evaluation overrides
              final deletedCount = _evaluationOverrides.isNotEmpty || showingHistorical
                  ? allResults.where((r) => _getEffectiveAction(r) == EmailActionType.delete).length
                  : scanProvider.deletedCount;
              final movedCount = _evaluationOverrides.isNotEmpty || showingHistorical
                  ? allResults.where((r) => _getEffectiveAction(r) == EmailActionType.moveToJunk).length
                  : scanProvider.movedCount;
              final safeCount = _evaluationOverrides.isNotEmpty || showingHistorical
                  ? allResults.where((r) => _getEffectiveAction(r) == EmailActionType.safeSender).length
                  : scanProvider.safeSendersCount;
              final noRuleCount = _evaluationOverrides.isNotEmpty || showingHistorical
                  ? allResults.where((r) => _getEffectiveAction(r) == EmailActionType.none).length
                  : scanProvider.noRuleCount;
              final errorCount = showingHistorical
                  ? allResults.where((r) => !r.success).length
                  : scanProvider.errorCount;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSpecialStatChip('Found', foundCount, const Color(0xFF2196F3), Colors.white, SpecialFilter.found),
                  _buildSpecialStatChip('Processed', processedCount, const Color(0xFF9C27B0), Colors.white, SpecialFilter.processed),
                  _buildStatChipWithMode(
                    isSafeSendersOnly || isReadOnly ? 'Deleted (not processed)' : 'Deleted',
                    deletedCount,
                    isSafeSendersOnly || isReadOnly ? const Color(0xFFEF9A9A) : const Color(0xFFF44336),
                    isSafeSendersOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.delete,
                  ),
                  _buildStatChipWithMode(
                    isSafeSendersOnly || isReadOnly ? 'Moved (not processed)' : 'Moved',
                    movedCount,
                    isSafeSendersOnly || isReadOnly ? const Color(0xFFFFCC80) : const Color(0xFFFF9800),
                    isSafeSendersOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.moveToJunk,
                  ),
                  _buildStatChipWithMode(
                    isRulesOnly || isReadOnly ? 'Safe (not processed)' : 'Safe',
                    safeCount,
                    isRulesOnly || isReadOnly ? const Color(0xFFA5D6A7) : const Color(0xFF4CAF50),
                    isRulesOnly || isReadOnly ? Colors.black54 : Colors.white,
                    EmailActionType.safeSender,
                  ),
                  // F91 (Sprint 39): informational chip for source-folder
                  // duplicates removed during post-safe-sender-move dedup
                  // (AOL copy-not-move reconciliation). Shown only when the
                  // count is greater than zero so it does not clutter the
                  // summary for non-AOL providers.
                  if (scanProvider.safeSenderDedupCount > 0)
                    Tooltip(
                      message: 'Source-folder duplicates removed (AOL re-injected '
                          'copies of rescued safe-sender emails, moved to Trash).',
                      child: Chip(
                        label: Text(
                          '+${scanProvider.safeSenderDedupCount} dup removed',
                        ),
                        backgroundColor: const Color(0xFF2E7D32),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  _buildStatChip('No rule', noRuleCount, const Color(0xFF757575), Colors.white, EmailActionType.none),
                  _buildSpecialStatChip('Errors', errorCount, const Color(0xFFD32F2F), Colors.white, SpecialFilter.error),
                  _buildFolderFilterChip(allResults),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// [NEW] F34: Build scan status indicator showing in-progress or completed state
  Widget _buildScanStatusIndicator(EmailScanProvider scanProvider) {
    final isScanning = scanProvider.status == ScanStatus.scanning;
    final isPaused = scanProvider.status == ScanStatus.paused;
    final isCompleted = scanProvider.status == ScanStatus.completed;
    final hasError = scanProvider.status == ScanStatus.error;

    if (isScanning || isPaused) {
      // In-progress: show linear progress bar with processed/total count
      final processed = scanProvider.processedCount;
      final total = scanProvider.totalEmails;
      final folder = scanProvider.currentFolder;
      final progressText = total > 0
          ? '$processed of $total emails'
          : '$processed emails';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: isPaused
                    ? Icon(Icons.pause_circle_outline, size: 14, color: Colors.orange[700])
                    : const CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                isPaused ? 'Paused' : 'Scanning...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPaused ? Colors.orange[700] : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressText,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (folder != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    folder,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: total > 0 ? scanProvider.progress : null,
              minHeight: 3,
              backgroundColor: Colors.grey[200],
            ),
          ),
        ],
      );
    }

    if (isCompleted) {
      // Completed: show checkmark with summary
      final duration = scanProvider.scanStartTime != null
          ? DateTime.now().difference(scanProvider.scanStartTime!)
          : null;
      final durationText = duration != null
          ? _formatDuration(duration)
          : null;

      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
          const SizedBox(width: 6),
          Text(
            'Scan complete',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.green[700],
            ),
          ),
          if (durationText != null) ...[
            const SizedBox(width: 8),
            Text(
              durationText,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      );
    }

    if (hasError) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              scanProvider.statusMessage ?? 'Scan error',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// Format a Duration into a human-readable string (e.g., "1m 23s")
  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }

  /// Build stat chip with mode-aware styling
  Widget _buildStatChipWithMode(String label, int value, Color bg, Color fg, EmailActionType? filterType) {
    final isActive = _filter == filterType;

    return GestureDetector(
      onTap: () {
        if (filterType != null) {
          _toggleFilter(filterType);
        }
      },
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: isActive ? bg.withValues(alpha: 0.7) : bg,
        labelStyle: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
          fontSize: label.contains('not processed') ? 11 : 14,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color bg, Color fg, EmailActionType? filterType) {
    // Determine if this chip is currently the active filter
    final isActive = _filter == filterType;

    return GestureDetector(
      onTap: () {
        if (filterType != null) {
          _toggleFilter(filterType);
        }
      },
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: isActive ? bg.withValues(alpha: 0.7) : bg,
        labelStyle: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
  
  /// Build stat chip for special filters (Found, Processed, Error)
  Widget _buildSpecialStatChip(String label, int value, Color bg, Color fg, SpecialFilter filterType) {
    final isActive = _specialFilter == filterType;

    return GestureDetector(
      onTap: () {
        _toggleSpecialFilter(filterType);
      },
      child: Chip(
        label: Text('$label: $value'),
        backgroundColor: isActive ? bg.withValues(alpha: 0.7) : bg,
        labelStyle: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
  
  /// Build folder filter dropdown chip (Item 6)
  Widget _buildFolderFilterChip(List<EmailActionResult> allResults) {
    // Issue 3: Use cached folders for performance
    final folders = _cachedFolders ?? [];
    final isActive = _selectedFolders.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        // Show folder selection dialog
        final selected = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => _buildFolderSelectionDialog(folders),
        );
        
        if (selected != null) {
          setState(() {
            _selectedFolders = selected;
          });
        }
      },
      child: Chip(
        label: Text(_selectedFolders.isEmpty 
            ? 'Folders: All' 
            : 'Folders: ${_selectedFolders.length}'),
        avatar: const Icon(Icons.folder, size: 18),
        backgroundColor: isActive ? Colors.indigo.withValues(alpha: 0.7) : Colors.indigo,
        labelStyle: TextStyle(
          color: Colors.white,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
        ),
        side: isActive
            ? const BorderSide(color: Colors.black, width: 2)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
  
  /// Build folder selection dialog
  Widget _buildFolderSelectionDialog(List<String> folders) {
    final tempSelected = Set<String>.from(_selectedFolders);
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Select Folders'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                CheckboxListTile(
                  title: const Text('All Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: tempSelected.isEmpty,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        tempSelected.clear();
                      }
                    });
                  },
                ),
                const Divider(),
                ...folders.map((folder) {
                  return CheckboxListTile(
                    title: Text(folder),
                    value: tempSelected.contains(folder),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelected.add(folder);
                        } else {
                          tempSelected.remove(folder);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempSelected),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultTile(EmailActionResult result) {
    // Issue #47: Title shows sender email, subtitle shows folder • subject • rule
    // Decode Punycode domains for display
    final rawFrom = result.email.from;
    final decodedFrom = PatternNormalization.normalizeAndDecodeEmail(rawFrom);
    final title = decodedFrom.isNotEmpty
        ? decodedFrom
        : 'Unknown sender';
    final folder = result.email.folderName;
    // Clean subject for display (remove tabs, extra spaces, repeated punctuation)
    final rawSubject = result.email.subject;
    final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(rawSubject);
    final subject = cleanedSubject.isNotEmpty ? cleanedSubject : 'No subject';
    // Issue #51: Display matched rule name or "No rule" if empty/null
    // F21: Use effective evaluation (includes inline assignment overrides)
    final effectiveEval = _getEffectiveEvaluation(result);
    final matchedRule = effectiveEval?.matchedRule ?? '';
    final rule = matchedRule.isNotEmpty ? matchedRule : 'No rule';
    final subtitle = '$folder • $subject • $rule';
    final trailing = result.success
        ? const Icon(Icons.check, color: Colors.green)
        : const Icon(Icons.error, color: Colors.red);

    // Issue 6: Wrap with Container to capture position for popup
    final tileKey = GlobalKey();

    return Container(
      key: tileKey,
      child: ListTile(
        leading: _actionIcon(result.action),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: () => _showEmailDetailSheet(result, itemKey: tileKey),
      ),
    );
  }

  /// Show positioned popup with email details and inline quick actions
  /// Issue 6: CSS-like positioning - show popup below/above email item
  void _showEmailDetailSheet(EmailActionResult result, {GlobalKey? itemKey}) {
    final email = result.email;
    final bodyParser = EmailBodyParser();
    // Extract raw email and domain (Punycode format) - used for block rule creation
    final rawSenderEmail = bodyParser.extractEmailAddress(email.from);
    final rawSenderDomain = bodyParser.extractDomainFromEmail(email.from);
    // Normalized email (plus-sign stripped) - used for safe sender pattern creation
    // This matches how SafeSenderList.findMatch() normalizes emails during evaluation
    final normalizedSenderEmail = PatternNormalization.normalizeFromHeader(email.from);
    // Decode for display only
    final displaySenderEmail = PatternNormalization.normalizeAndDecodeEmail(rawSenderEmail);
    final displaySenderDomain = rawSenderDomain != null
        ? PatternNormalization.decodePunycodeDomain(rawSenderDomain)
        : null;
    // Extract root domain from RAW domain (for rule creation)
    final rawRootDomain = PatternNormalization.extractRootDomain(rawSenderDomain);
    // Decode root domain for display
    final displayRootDomain = rawRootDomain != null
        ? PatternNormalization.decodePunycodeDomain(rawRootDomain)
        : null;
    // F21: Use effective evaluation (re-evaluated after inline rule assignment)
    final effectiveEval = _getEffectiveEvaluation(result);
    final matchedRule = effectiveEval?.matchedRule ?? '';
    final isDeleted = effectiveEval?.shouldDelete == true;
    final isSafeSender = effectiveEval?.isSafeSender == true;

    // Clean subject for display
    final cleanedSubject = PatternNormalization.cleanSubjectForDisplay(email.subject);
    final displaySubject = cleanedSubject.isNotEmpty ? cleanedSubject : '(No subject)';

    // Format date/time
    final dateStr = email.receivedDate.toString().substring(0, 16);

    // Issue 6: Calculate position for CSS-like popup positioning
    Offset? itemPosition;
    Size? itemSize;
    if (itemKey != null) {
      final RenderBox? renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        itemPosition = renderBox.localToGlobal(Offset.zero);
        itemSize = renderBox.size;
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        // Get screen dimensions
        final screenSize = MediaQuery.of(context).size;
        final screenHeight = screenSize.height;
        final popupHeight = screenHeight * 0.6; // Approximate popup height

        // Calculate position
        double? top;
        double? bottom;

        if (itemPosition != null && itemSize != null) {
          final itemBottom = itemPosition.dy + itemSize.height;
          final spaceBelow = screenHeight - itemBottom;
          final spaceAbove = itemPosition.dy;
          // Sprint 46 manual-testing feedback (Harold 2026-07-11): when the
          // screen has room, drop the popup one additional email-height lower
          // (the clicked tile's own height is the best available estimate of
          // one list item) so the NEXT item in the list stays visible above
          // the popup -- after acting on this email the user can immediately
          // click the next one instead of it being covered.
          final oneItemGap = itemSize.height;

          if (spaceBelow >= popupHeight + oneItemGap) {
            // Show one email lower, keeping the next list item clickable
            top = itemBottom + oneItemGap + 8; // 8px gap
          } else if (spaceBelow >= popupHeight) {
            // Show directly below email (no room to also expose the next item)
            top = itemBottom + 8; // 8px gap
          } else if (spaceAbove >= popupHeight) {
            // Show above email
            bottom = screenHeight - itemPosition.dy + 8; // 8px gap
          } else {
            // Not enough room above or below - align with first email
            top = itemPosition.dy;
          }
        }

        return Stack(
          children: [
            Positioned(
              top: top,
              bottom: bottom,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: SelectionArea(
                  child: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // One-line summary matching Results screen format
                Row(
                  children: [
                    _actionIcon(result.action),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displaySenderEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    result.success
                        ? const Icon(Icons.check, color: Colors.green, size: 18)
                        : const Icon(Icons.error, color: Colors.red, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                // Subtitle line: folder • subject • rule
                Text(
                  '${email.folderName} • $displaySubject • ${matchedRule.isNotEmpty ? matchedRule : "No rule"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Date/time
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (displaySenderDomain != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.domain, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        displaySenderDomain,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Action result badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getActionColor(result.action).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getActionDescription(result),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getActionColor(result.action),
                    ),
                  ),
                ),
                const Divider(height: 20),

                // === SHARED PROVIDER HINT ===
                if (rawSenderDomain != null &&
                    CommonEmailProviders.isCommonProvider(rawSenderDomain)) ...[
                  Builder(builder: (_) {
                    final providerName = CommonEmailProviders.getProviderName(rawSenderDomain) ?? 'Unknown';
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$providerName is a shared email provider. '
                              'Use "Exact Email" when adding rules for this sender.',
                              style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // === SAFE SENDER SECTION ===
                // Issue 5: Always show Safe Sender options for all emails
                Text(
                  isSafeSender ? 'Update Safe Sender' : 'Add to Safe Senders',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInlineActionButton(
                        icon: Icons.person,
                        label: 'Exact Email',
                        subtitle: displaySenderEmail,
                        color: Colors.green,
                        isMatched: isSafeSender && effectiveEval?.matchedPatternType == 'exact_email',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          // Use normalized email (plus-signs stripped) to match SafeSenderList evaluation
                          _addSafeSender(normalizedSenderEmail, 'exact', email: email);
                        },
                      ),
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain,
                          label: 'Exact Domain',
                          subtitle: '@$displaySenderDomain',
                          color: Colors.green,
                          isMatched: isSafeSender && effectiveEval?.matchedPatternType == 'exact_domain',
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            // F47: Check for email provider domain
                            if (!await _checkProviderDomainWarning(domain: rawSenderDomain, isBlockRule: false)) return;
                            _addSafeSender('@$rawSenderDomain', 'exactDomain', email: email);
                          },
                        ),
                      // Always show Entire Domain option (uses root domain or full domain if no subdomain)
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public,
                          label: 'Entire Domain',
                          subtitle: '@*.${displayRootDomain ?? displaySenderDomain}',
                          color: Colors.green,
                          isMatched: isSafeSender && effectiveEval?.matchedPatternType == 'entire_domain',
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            // F47: Check for email provider domain
                            if (!await _checkProviderDomainWarning(domain: rawRootDomain ?? rawSenderDomain, isBlockRule: false)) return;
                            _addSafeSender(rawRootDomain ?? rawSenderDomain, 'entireDomain', email: email);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                // === BLOCK RULE SECTION ===
                // Issue 5: Always show Block Rule options for all emails
                const Text(
                  'Create Block Rule',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInlineActionButton(
                        icon: Icons.person_off,
                        label: 'Block Email',
                        subtitle: displaySenderEmail,
                        color: Colors.red,
                        isMatched: isDeleted && effectiveEval?.matchedPatternType == 'exact_email',
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _createBlockRule('from', rawSenderEmail, email: email);
                        },
                      ),
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.domain_disabled,
                          label: 'Block Exact Domain',
                          subtitle: '@$displaySenderDomain',
                          color: Colors.red,
                          isMatched: isDeleted && effectiveEval?.matchedPatternType == 'exact_domain',
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            // F47: Check for email provider domain
                            if (!await _checkProviderDomainWarning(domain: rawSenderDomain, isBlockRule: true)) return;
                            _createBlockRule('exactDomain', '@$rawSenderDomain', email: email);
                          },
                        ),
                      // Always show Block Entire Domain option (uses root domain or full domain if no subdomain)
                      if (rawSenderDomain != null)
                        _buildInlineActionButton(
                          icon: Icons.public_off,
                          label: 'Block Entire Domain',
                          subtitle: '@*.${displayRootDomain ?? displaySenderDomain}',
                          color: Colors.red,
                          isMatched: isDeleted && effectiveEval?.matchedPatternType == 'entire_domain',
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            // F47: Check for email provider domain
                            if (!await _checkProviderDomainWarning(domain: rawRootDomain ?? rawSenderDomain, isBlockRule: true)) return;
                            _createBlockRule('entireDomain', rawRootDomain ?? rawSenderDomain, email: email);
                          },
                        ),
                      if (cleanedSubject.isNotEmpty && cleanedSubject != '(No subject)')
                        _buildInlineActionButton(
                          icon: Icons.subject,
                          label: 'Block Subject',
                          subtitle: cleanedSubject.length > 20
                              ? '${cleanedSubject.substring(0, 20)}...'
                              : cleanedSubject,
                          color: Colors.orange,
                          isMatched: isDeleted && effectiveEval?.matchedPatternType == 'subject',
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _createBlockRule('subject', cleanedSubject, email: email);
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
                ),
              ), // Close SelectionArea
              ),
            ),
          ],
        );
      },
    );
  }

  /// F47: Show warning when adding domain-level rule for a known email provider.
  ///
  /// Returns true if the user confirms they want to proceed, false to cancel.
  /// Returns true immediately (no warning) if the domain is not a known provider.
  Future<bool> _checkProviderDomainWarning({
    required String domain,
    required bool isBlockRule,
  }) async {
    // Extract bare domain (remove leading @ and subdomain wildcard patterns)
    final bareDomain = domain
        .replaceAll('@', '')
        .replaceAll('*.', '')
        .toLowerCase()
        .trim();

    final providerName = CommonEmailProviders.getProviderName(bareDomain);
    if (providerName == null) return true; // Not a provider domain, proceed

    final ruleType = isBlockRule ? 'Block Rule' : 'Safe Sender';

    final content = isBlockRule
        ? 'The domain "$bareDomain" belongs to $providerName, a major email '
          'provider used by millions of individual and business accounts.\n\n'
          'Blocking this entire domain would prevent all emails from '
          '$providerName users from reaching your inbox.\n\n'
          'Recommendation: Use "Exact Email" to block a specific sender '
          'instead. If you do block the domain, you can add individual Safe '
          'Sender exceptions, but those emails would need to be rescued after '
          'being deleted.'
        : 'The domain "$bareDomain" belongs to $providerName, a major email '
          'provider used by millions of individual and business accounts.\n\n'
          'Adding this domain as a Safe Sender means all emails from any '
          '$providerName user will bypass your spam rules. Since Safe Sender '
          'rules override Block Rules, you would not be able to block specific '
          'senders from this domain.\n\n'
          'Recommendation: Use "Exact Email" to add specific trusted senders '
          'instead.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Flexible(child: Text('$ruleType for Email Provider')),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isBlockRule ? Colors.red : Colors.green,
            ),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Widget _buildInlineActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isMatched = false, // Item 2: Visual indicator for current rule match
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isMatched ? color : color.withValues(alpha: 0.3),
            width: isMatched ? 2 : 1, // Thicker border for matched rule
          ),
          borderRadius: BorderRadius.circular(8),
          color: isMatched 
              ? color.withValues(alpha: 0.15) // Darker shade for matched
              : color.withValues(alpha: 0.05),
        ),
        child: Stack(
          children: [
            Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          // Item 2: Green checkmark in top-right corner for matched rule
          if (isMatched)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(EmailActionType action) {
    switch (action) {
      case EmailActionType.delete:
        return Colors.red;
      case EmailActionType.moveToJunk:
        return Colors.orange;
      case EmailActionType.safeSender:
        return Colors.green;
      case EmailActionType.markAsRead:
        return Colors.blueGrey;
      case EmailActionType.none:
        return Colors.grey;
    }
  }

  /// Generate a stable key for an email to track evaluation overrides.
  String _getEmailKey(EmailMessage email) {
    return '${email.from}|${email.subject}|${email.receivedDate.toIso8601String()}';
  }

  /// Get the effective EvaluationResult for an email, checking overrides first.
  EvaluationResult? _getEffectiveEvaluation(EmailActionResult result) {
    final key = _getEmailKey(result.email);
    return _evaluationOverrides[key] ?? result.evaluationResult;
  }

  /// Get the effective action type, accounting for re-evaluation overrides.
  /// After inline rule assignment, the original action (e.g., none) may no longer
  /// reflect the current evaluation (e.g., should now be delete or safeSender).
  EmailActionType _getEffectiveAction(EmailActionResult result) {
    final eval = _getEffectiveEvaluation(result);
    if (eval == null) return result.action;
    // Only override if there is an evaluation override for this email
    final key = _getEmailKey(result.email);
    if (!_evaluationOverrides.containsKey(key)) return result.action;
    // Derive action from the override evaluation
    if (eval.isSafeSender) return EmailActionType.safeSender;
    if (eval.shouldDelete) return EmailActionType.delete;
    if (eval.shouldMove) return EmailActionType.moveToJunk;
    if (eval.matchedRule.isEmpty) return EmailActionType.none;
    return result.action;
  }

  /// Shared PatternCompiler for re-evaluation.
  /// Reused across all re-evaluations to preserve compiled pattern cache,
  /// avoiding recompilation of the same patterns for each email.
  final PatternCompiler _sharedCompiler = PatternCompiler();

  /// Re-evaluate an email against the current rules and safe senders.
  ///
  /// Uses [_sharedCompiler] to benefit from pattern cache across evaluations.
  /// Stores the result in [_evaluationOverrides] so subsequent displays
  /// (list tile, popup) reflect the current rule state.
  Future<EvaluationResult> _reEvaluateEmail(EmailMessage email) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final evaluator = RuleEvaluator(
      ruleSet: ruleProvider.rules,
      safeSenderList: ruleProvider.safeSenders,
      compiler: _sharedCompiler,
    );
    final result = await evaluator.evaluate(email);
    final key = _getEmailKey(email);
    _evaluationOverrides[key] = result;
    return result;
  }

  /// Sprint 38 F82 (Issue #252): compute current "no-rule" and addressed
  /// counts for the F82 progress indicator footer and snackbar wording.
  ///
  /// `remaining` is the count of emails whose effective action (override
  /// or original) is still `EmailActionType.none`. `addressed` is the
  /// count of emails that originally had `none` but now have an override
  /// to a non-none action -- i.e., the user-progress in this session.
  ///
  /// Operates over the same `allResults` set the rest of the screen uses,
  /// so live scans and historical-scan reviews both work.
  ({int remaining, int addressed, int initial}) _computeNoRuleStats() {
    // Sprint 38 Round 4 fix (2026-05-17): historical-scan views must
    // always use _historicalResults, even when a prior Live Scan left
    // stale results in EmailScanProvider. Matches the build() resolver
    // and _reEvaluateNoRuleEmails.
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final liveResults = scanProvider.results;
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    final allResults = (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);

    var remaining = 0;
    var addressed = 0;
    for (final result in allResults) {
      final originalAction = result.action;
      final effectiveAction = _getEffectiveAction(result);
      if (effectiveAction == EmailActionType.none) {
        remaining++;
      } else if (originalAction == EmailActionType.none &&
          effectiveAction != EmailActionType.none) {
        addressed++;
      }
    }
    final initial = _initialNoRuleCount ?? (remaining + addressed);
    return (remaining: remaining, addressed: addressed, initial: initial);
  }

  /// Sprint 38 Round 4 (2026-05-17): after the user adds a rule or safe
  /// sender that makes a previously-no-rule email match (its override is
  /// set and effective action != none), recompute the oldest UID that is
  /// still unaddressed-no-rule per folder, and write the per-folder
  /// cursor so the next IMAP scan re-fetches from that point forward.
  ///
  /// Walks the current `allResults` set (live or historical) plus the
  /// in-memory `_evaluationOverrides`. For each folder, finds the
  /// smallest UID whose effective action is still `none`. If a folder
  /// has zero unaddressed no-rules, the cursor is cleared so the next
  /// scan falls back to the configured `daysBack` window.
  ///
  /// Only IMAP UIDs (parseable as int) are eligible. Gmail OAuth message
  /// IDs are opaque strings; they're skipped here (Gmail uses a separate
  /// historyId cursor, not yet redesigned in Round 4).
  ///
  /// Caller invokes this after every rule-add and safe-sender-add in
  /// Scan Results, so the cursor stays current as the user works
  /// through the backlog.
  Future<void> _updateOldestNoRuleCursorsFromResults() async {
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final liveResults = scanProvider.results;
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    final allResults = (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);
    if (allResults.isEmpty) return;

    final dbHelper = DatabaseHelper();
    final foldersTouched = <String>{};
    final oldestPerFolder = <String, int>{};
    for (final result in allResults) {
      foldersTouched.add(result.email.folderName);
      if (_getEffectiveAction(result) != EmailActionType.none) continue;
      final uid = int.tryParse(result.email.id);
      if (uid == null) continue; // non-IMAP id (Gmail OAuth opaque)
      final current = oldestPerFolder[result.email.folderName];
      if (current == null || uid < current) {
        oldestPerFolder[result.email.folderName] = uid;
      }
    }

    for (final folder in foldersTouched) {
      final oldest = oldestPerFolder[folder];
      // Pass null to clear when the folder has zero unaddressed no-rules.
      await dbHelper.setFolderCursor(
        widget.accountId,
        folder,
        oldest?.toString(),
      );
    }
  }

  /// Sprint 38 F82: capture the initial no-rule count once per scan view so
  /// the F82 footer can show cumulative progress ("M of N addressed") rather
  /// than just the current remaining count.
  ///
  /// Sprint 38 Round 1 fix (post-retro 2026-05-16): only capture once
  /// `allResults` is non-empty. On historical-scan navigation, the first
  /// render fires BEFORE `_loadLastCompletedScan` completes (async), so
  /// `_historicalResults` is briefly empty and a naive capture would cache
  /// `_initialNoRuleCount = 0`, which then hides the footer permanently
  /// (footer's `initial <= 0` returns SizedBox.shrink). Skipping the empty
  /// case lets the capture fire on the next rebuild after the async load.
  void _captureInitialNoRuleCount() {
    if (_initialNoRuleCount != null) return;
    final stats = _computeNoRuleStats();
    final total = stats.remaining + stats.addressed;
    if (total == 0) return; // wait for async load (or genuinely empty scan)
    _initialNoRuleCount = total;
  }

  /// Re-evaluate all emails that currently have no matching rule.
  ///
  /// Called after adding a new block rule or safe sender so that
  /// remaining "No rule" items are updated if the new rule matches them.
  /// Uses [_sharedCompiler] so patterns are compiled once and cached
  /// for all subsequent email evaluations.
  ///
  /// Sprint 38 Round 4 fix (2026-05-17): now uses the same result-set
  /// resolution as the build method (preferring `_historicalResults`
  /// when `widget.historicalScanId != null`). The previous logic
  /// skipped historical-scan emails when a prior Live Scan left stale
  /// results in EmailScanProvider, causing inline rule-adds on the Scan
  /// History > Scan Results page to silently fail to update the
  /// `_evaluationOverrides` map -- which in turn made the F82 footer
  /// counter stay at 0 and the addressed rows never hide.
  Future<void> _reEvaluateNoRuleEmails() async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final evaluator = RuleEvaluator(
      ruleSet: ruleProvider.rules,
      safeSenderList: ruleProvider.safeSenders,
      compiler: _sharedCompiler,
    );

    // Match build()'s resolution: historical-scan views always use
    // _historicalResults, regardless of any stale liveResults in the
    // provider.
    final liveResults = scanProvider.results;
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    final allResults = (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);

    // Find all emails with effective action "none" (No rule)
    for (final result in allResults) {
      if (_getEffectiveAction(result) == EmailActionType.none) {
        final evalResult = await evaluator.evaluate(result.email);
        // Only store override if the new evaluation found a match
        if (evalResult.matchedRule.isNotEmpty || evalResult.isSafeSender) {
          final key = _getEmailKey(result.email);
          _evaluationOverrides[key] = evalResult;
        }
      }
    }
  }

  /// Sprint 38 F82 (Issue #252): "M of N no-rules addressed" progress footer.
  /// Shows under the chip strip when the scan had any no-rule emails. Renders
  /// nothing if the user has nothing to triage (clean scan). Updates as the
  /// user adds rules / safe senders inline -- `addressed` increments and
  /// `remaining` decrements at the same time.
  Widget _buildNoRuleProgressFooter() {
    // Capture the initial no-rule count on the first render where any
    // results are available. Subsequent renders use the cached value so
    // the "addressed" count climbs as the user adds rules.
    _captureInitialNoRuleCount();
    final stats = _computeNoRuleStats();
    if (stats.initial <= 0) return const SizedBox.shrink();

    final addressed = stats.addressed;
    final initial = stats.initial;
    final remaining = stats.remaining;
    final isComplete = remaining == 0 && initial > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isComplete
              ? Colors.green.shade50
              : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isComplete ? Colors.green.shade300 : Colors.amber.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isComplete ? Icons.check_circle : Icons.flag_outlined,
              size: 18,
              color: isComplete ? Colors.green.shade700 : Colors.amber.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isComplete
                    ? 'All $initial "No rule" emails addressed.'
                    : '$addressed of $initial "No rule" emails addressed -- $remaining remaining.',
                style: TextStyle(
                  fontSize: 13,
                  color: isComplete
                      ? Colors.green.shade900
                      : Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (initial > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 80,
                  height: 6,
                  child: LinearProgressIndicator(
                    value: addressed / initial,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? Colors.green.shade600 : Colors.amber.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// F38: Non-blocking re-processing banner widget
  Widget _buildReProcessingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _reProcessTotal > 0
                  ? _reProcessCompleted / _reProcessTotal
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Re-processing $_reProcessCompleted of $_reProcessTotal...',
            style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  /// F38: Re-process affected emails via IMAP after rule changes.
  ///
  /// After re-evaluation updates [_evaluationOverrides], this method collects
  /// emails whose action changed and executes the corresponding IMAP actions
  /// (delete, move to safe sender folder) on the server.
  ///
  /// Runs in the background without blocking the UI. Shows a non-blocking
  /// banner during processing and updates the results list in real-time.
  /// Emails already re-processed (tracked in [_reProcessedEmailKeys]) are skipped.
  Future<void> _reProcessAffectedEmails() async {
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final logger = Logger();

    // Only re-process in modes that allow actions
    final scanMode = scanProvider.scanMode;
    if (scanMode == ScanMode.readOnly) {
      logger.i('[F38] Skipping re-process: scan mode is readOnly');
      return;
    }

    // Sprint 38 Round 4 fix (2026-05-17): historical-scan views must
    // always use _historicalResults. See _reEvaluateNoRuleEmails for
    // the matching fix and rationale.
    final liveResults = scanProvider.results;
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    final allResults = (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);

    final toDelete = <EmailMessage>[];
    final toMoveSafe = <EmailMessage>[];

    for (final result in allResults) {
      final key = _getEmailKey(result.email);
      if (!_evaluationOverrides.containsKey(key)) continue;
      if (_reProcessedEmailKeys.contains(key)) continue;

      final newAction = _getEffectiveAction(result);
      final originalAction = result.action;

      // Only act if the action changed
      if (newAction == originalAction) continue;

      // Determine which IMAP action to execute based on new evaluation and scan mode
      final canExecuteRules = scanMode == ScanMode.rulesOnly || scanMode == ScanMode.safeSendersAndRules;
      final canExecuteSafeSenders = scanMode == ScanMode.safeSendersOnly || scanMode == ScanMode.safeSendersAndRules;

      if (newAction == EmailActionType.delete && canExecuteRules) {
        toDelete.add(result.email);
      } else if (newAction == EmailActionType.safeSender && canExecuteSafeSenders) {
        toMoveSafe.add(result.email);
      }
    }

    if (toDelete.isEmpty && toMoveSafe.isEmpty) {
      logger.i('[F38] No emails need IMAP re-processing');
      return;
    }

    // Immediately hide affected emails from the list (instant visual feedback)
    // This lets the user see only remaining unaddressed emails while IMAP
    // actions execute in the background.
    if (mounted) {
      setState(() {
        for (final email in toDelete) {
          _hiddenEmailKeys.add(_getEmailKey(email));
        }
        for (final email in toMoveSafe) {
          _hiddenEmailKeys.add(_getEmailKey(email));
        }
      });
    }

    final total = toDelete.length + toMoveSafe.length;
    logger.i('[F38] Re-processing ${toDelete.length} deletes, ${toMoveSafe.length} safe sender moves');

    // Show non-blocking banner
    if (mounted) {
      setState(() {
        _isReProcessing = true;
        _reProcessTotal = total;
        _reProcessCompleted = 0;
      });
    }

    SpamFilterPlatform? platform;
    var successCount = 0;
    var failCount = 0;

    try {
      // Create platform connection
      platform = PlatformRegistry.getPlatform(widget.platformId);
      if (platform == null) {
        throw Exception('Platform ${widget.platformId} not supported');
      }

      // Load credentials and connect
      if (widget.platformId != 'demo') {
        final credStore = SecureCredentialsStore();
        final credentials = await credStore.getCredentials(widget.accountId);
        if (credentials == null) {
          throw Exception('No credentials found for account ${widget.accountId}');
        }
        await platform.loadCredentials(credentials);
      }

      final settingsStore = SettingsStore();

      // Execute delete actions
      if (toDelete.isNotEmpty) {
        final deletedRuleFolder = await settingsStore.getAccountDeletedRuleFolder(widget.accountId);
        if (deletedRuleFolder != null) {
          platform.setDeletedRuleFolder(deletedRuleFolder);
        }

        try {
          final result = await platform.takeActionBatch(toDelete, FilterAction.delete);
          successCount += result.successCount;
          failCount += result.failureCount;
          logger.i('[F38] Delete batch: ${result.successCount} succeeded, ${result.failureCount} failed');
        } catch (e) {
          logger.e('[F38] Delete batch failed: $e');
          failCount += toDelete.length;
        }

        // Mark as re-processed and update banner
        for (final email in toDelete) {
          _reProcessedEmailKeys.add(_getEmailKey(email));
        }
        if (mounted) {
          setState(() {
            _reProcessCompleted += toDelete.length;
          });
        }
      }

      // Execute safe sender move actions
      if (toMoveSafe.isNotEmpty) {
        final safeSenderFolder = await settingsStore.getAccountSafeSenderFolder(widget.accountId);
        final targetFolder = safeSenderFolder ?? 'INBOX';

        try {
          final result = await platform.moveToFolderBatch(toMoveSafe, targetFolder);
          successCount += result.successCount;
          failCount += result.failureCount;
          logger.i('[F38] Safe sender move batch: ${result.successCount} succeeded, ${result.failureCount} failed');
        } catch (e) {
          logger.e('[F38] Safe sender move batch failed: $e');
          failCount += toMoveSafe.length;
        }

        // Mark as re-processed and update banner
        for (final email in toMoveSafe) {
          _reProcessedEmailKeys.add(_getEmailKey(email));
        }
        if (mounted) {
          setState(() {
            _reProcessCompleted += toMoveSafe.length;
          });
        }
      }
    } catch (e) {
      logger.e('[F38] Re-processing failed: $e');
      failCount = toDelete.length + toMoveSafe.length;
    } finally {
      // Close platform connection
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (e) {
          logger.w('[F38] Failed to disconnect platform: $e');
        }
      }
    }

    // Hide banner and show result snackbar
    if (mounted) {
      setState(() {
        _isReProcessing = false;
      });

      final message = failCount == 0
          ? 'Re-processed $successCount email${successCount == 1 ? '' : 's'}'
          : 'Re-processed $successCount of $total ($failCount failed)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }

  /// Add sender to safe senders list
  /// Types: 'exact' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com)
  Future<void> _addSafeSender(String value, String type, {EmailMessage? email}) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final logger = Logger();

    // F96 (Sprint 43): on the Scan History reload path the source email is
    // reconstructed from the database, so we re-hydrate the SPF/DKIM/DMARC
    // classification captured at scan time (authClassificationOverride) rather
    // than parsing the now-absent Authentication-Results headers. When that
    // snapshot is RED (a confident spoof signal), warn before whitelisting --
    // matching the quick-add screen's behavior. This closes the F89 gap where
    // historical adds could never surface the warning. Older rows (pre-v8) and
    // GREEN/YELLOW/GREY snapshots do not gate the add.
    if (email != null) {
      final classification =
          AuthResultsParser.classificationFromName(email.authClassificationOverride);
      if (classification == AuthClassification.red) {
        final senderEmail =
            PatternNormalization.normalizeFromHeader(email.from);
        final proceed = await AuthWarningDialog.showSafeSenderWarning(
          context,
          senderEmail: senderEmail,
          authResult:
              AuthResultsParser.syntheticResultFor(AuthClassification.red),
        );
        if (!proceed) {
          // User chose Cancel -- do not whitelist.
          return;
        }
        if (!mounted) return;
      }
    }

    // F39 (Sprint 46): rule-persistence core is shared with the
    // cross-account "No rule" review screen via RuleQuickActionService.
    // The re-evaluate/re-process/notify tail below stays here -- it is
    // specific to this screen's in-memory scan-session state.
    final service = RuleQuickActionService(ruleProvider: ruleProvider);
    final senderEmail = email != null
        ? EmailBodyParser().extractEmailAddress(email.from).toLowerCase().trim()
        : value;
    final result = await service.addSafeSender(
      value: value,
      type: type,
      senderEmailForConflictCheck: senderEmail,
    );

    if (!result.success) {
      logger.e('[FAIL] Failed to add safe sender: ${result.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
      return;
    }

    // F21: Re-evaluate email against updated rules and refresh list
    if (email != null) {
      await _reEvaluateEmail(email);
    }

    // Re-evaluate all remaining "No rule" emails against the new safe sender
    final preStats = _computeNoRuleStats();
    await _reEvaluateNoRuleEmails();
    final postStats = _computeNoRuleStats();

    // Sprint 38 Round 4 (2026-05-17): advance the oldest-unaddressed-no-rule
    // UID cursor per folder so the next IMAP scan resumes from the
    // remaining backlog (or clears the cursor and falls back to daysBack
    // if all are addressed). Non-IMAP rows are skipped inside the helper.
    await _updateOldestNoRuleCursorsFromResults();

    // F38: Execute IMAP actions for affected emails
    await _reProcessAffectedEmails();

    if (mounted) {
      setState(() {}); // Refresh list to show updated rule assignment
      // Sprint 38 F82 (Issue #252): append "N removed, M remaining" so the
      // user sees concrete progress against the no-rules pool.
      final removedNow = preStats.remaining - postStats.remaining;
      final remaining = postStats.remaining;
      final progressSuffix = removedNow > 0
          ? ' -- $removedNow removed, $remaining "No rule" remaining'
          : (remaining > 0 ? ' -- $remaining "No rule" remaining' : '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayMessage}$progressSuffix'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }

  /// Create a block rule (persists to database and YAML)
  /// Types: 'from' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com), 'subject'
  Future<void> _createBlockRule(String type, String value, {EmailMessage? email}) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final logger = Logger();

    // F39 (Sprint 46): rule-persistence core is shared with the
    // cross-account "No rule" review screen via RuleQuickActionService.
    final service = RuleQuickActionService(ruleProvider: ruleProvider);
    final senderEmailForConflictCheck = type != 'subject' && email != null
        ? EmailBodyParser().extractEmailAddress(email.from).toLowerCase().trim()
        : null;
    final result = await service.createBlockRule(
      type: type,
      value: value,
      senderEmailForConflictCheck: senderEmailForConflictCheck,
    );

    if (!result.success) {
      logger.e('[FAIL] Failed to create block rule: ${result.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
      return;
    }

    // F21: Re-evaluate email against updated rules and refresh list
    if (email != null) {
      await _reEvaluateEmail(email);
    }

    // Re-evaluate all remaining "No rule" emails against the new rule
    final preStats = _computeNoRuleStats();
    await _reEvaluateNoRuleEmails();
    final postStats = _computeNoRuleStats();

    // Sprint 38 Round 4 (2026-05-17): advance the oldest-unaddressed-no-rule
    // UID cursor per folder so the next IMAP scan resumes from the
    // remaining backlog. See companion call site in safe-sender-add
    // handler above.
    await _updateOldestNoRuleCursorsFromResults();

    // F38: Execute IMAP actions for affected emails
    await _reProcessAffectedEmails();

    if (mounted) {
      setState(() {}); // Refresh list to show updated rule assignment
      // Sprint 38 F82 (Issue #252): append "N removed, M remaining" so the
      // user sees concrete progress against the no-rules pool.
      final removedNow = preStats.remaining - postStats.remaining;
      final remaining = postStats.remaining;
      final progressSuffix = removedNow > 0
          ? ' -- $removedNow removed, $remaining "No rule" remaining'
          : (remaining > 0 ? ' -- $remaining "No rule" remaining' : '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayMessage}$progressSuffix'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }

  String _getActionDescription(EmailActionResult result) {
    switch (result.action) {
      case EmailActionType.delete:
        return result.success ? 'Deleted' : 'Delete failed';
      case EmailActionType.moveToJunk:
        return result.success ? 'Moved to junk' : 'Move failed';
      case EmailActionType.safeSender:
        return 'Safe sender - no action';
      case EmailActionType.markAsRead:
        return result.success ? 'Marked as read' : 'Mark as read failed';
      case EmailActionType.none:
        return 'No matching rule';
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
