import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/providers/rule_set_provider.dart';
import '../../core/providers/selected_account_provider.dart';
import '../../core/services/auth_results_parser.dart';
import '../../core/services/content_history.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/services/rule_evaluator.dart';
import '../../core/services/rule_quick_action_service.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/settings_store.dart';
import '../../core/storage/unmatched_email_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/provider_sender_grouping.dart';
import '../../core/utils/result_ordering.dart';
import '../../util/redact.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/auth_warning_dialog.dart';
import '../widgets/email_detail_popup.dart';
import '../widgets/empty_state.dart';
import '../widgets/provider_group_markers.dart';
import '../widgets/result_list_pieces.dart';
import '../widgets/screen_version_line.dart'; // F229 (Sprint 73)
import '../widgets/standard_app_bar_actions.dart';
import '../widgets/system_inset_wrapper.dart'; // F209 (Sprint 69)
import 'help_screen.dart' show HelpSection;

/// F39 (Sprint 46): cross-account "No rule" review screen.
///
/// Lists every unprocessed "No rule" email of every saved account (F245), one
/// row per email, filterable down to one account.
///
/// **F283 (Sprint 78): looks and works like the Results screen.** It is built
/// from the SAME pieces (`result_list_pieces.dart`, `email_detail_popup.dart`):
/// a summary card with a fixed "No rule (N)" chip, then the account, Folders
/// and Sort chips; Ctrl+F / the search icon; the "Showing X of Y" bar; the
/// Results row; and a tap opens the Results pop-up, naming the row's account.
/// A quick action creates the rule or safe sender, marks the row handled, and
/// opens the next row the new rule does not cover (Results' auto-advance).
/// Multi-select and the bulk-action menu were removed (MV-Q16).
///
/// ADR-0042: one shared screen, identical on Windows and Android.
class NoRuleReviewScreen extends StatefulWidget {
  const NoRuleReviewScreen({super.key});

  @override
  State<NoRuleReviewScreen> createState() => _NoRuleReviewScreenState();
}

/// A "No rule" row paired with the account it came from. [result] is the
/// shared row model (F283): the row converted to an [EmailActionResult] with
/// no action and no match, so the shared tile, sort, search and pop-up take it
/// unchanged.
class _NoRuleItem {
  final UnmatchedEmail email;
  final String accountId;
  final String accountEmail;
  final EmailActionResult result;

  _NoRuleItem({
    required this.email,
    required this.accountId,
    required this.accountEmail,
  }) : result = EmailActionResult(
          email: noRuleRowToMessage(email),
          evaluationResult: EvaluationResult.noMatch(),
          action: EmailActionType.none,
          success: true,
        );
}

/// F283: a stored No Rule row as an [EmailMessage] -- the same shape the
/// covered-item sweep has always evaluated (id `unmatched-<row id>`, From and
/// Subject headers, the received date or, without one, the first-seen date),
/// plus the F96 authentication class for the RED safe-sender warning.
@visibleForTesting
EmailMessage noRuleRowToMessage(UnmatchedEmail email) => EmailMessage(
      id: 'unmatched-${email.id}',
      from: email.fromEmail,
      subject: email.subject ?? '',
      body: email.bodyPreview ?? '',
      headers: {
        'from': email.fromEmail,
        'subject': email.subject ?? '',
      },
      receivedDate: email.emailDate ?? email.createdAt,
      folderName: email.folderName,
      authClassificationOverride: email.authClassification,
    );

class _NoRuleReviewScreenState extends State<NoRuleReviewScreen> {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late final UnmatchedEmailStore _unmatchedStore;

  bool _isLoading = true;
  List<_NoRuleItem> _allItems = [];
  String _accountFilter = 'all';
  List<String> _distinctAccounts = [];
  Map<String, String> _accountEmails = {};

  // F283: the Results filters.
  Set<String> _selectedFolders = {};
  ResultSortOrder _sortOrder = ResultSortOrder.folderDomainAddress;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSearch = false;

  /// Provider-sender group size within the visible list (Sprint 46 IMP-1).
  int _providerGroupCount = 0;

  /// F284 R-1: lets the account face's semantics action open its menu.
  final GlobalKey<PopupMenuButtonState<String>> _accountMenuKey = GlobalKey();

  /// MT-2b (Sprint 50): how many already-covered items the most recent
  /// [_loadItems] sweep resolved (see [_sweepCoveredItems]).
  int _lastSweepCount = 0;

  @override
  void initState() {
    super.initState();
    _unmatchedStore = UnmatchedEmailStore(_dbHelper);
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// F135 (Sprint 52): resolve an account for the account-scoped Settings
  /// destination that F134 adds to this screen's AppBar.
  ///
  /// This screen is CROSS-ACCOUNT by design, so it must never PROMPT. It only
  /// resolves: 1. the session selection, if that account still appears here,
  /// else 2. the account currently filtered to, else 3. the first known
  /// account. Returns null when no account is known, which correctly DISABLES
  /// the Settings icon rather than pushing Settings with a bogus id.
  String? _resolveAccountIdForSettings() {
    // The session selection is an OPTIONAL input: reading it defensively
    // keeps the screen constructible in any widget-test harness that has not
    // registered the provider.
    String? selected;
    try {
      selected = context.read<SelectedAccountProvider>().accountId;
    } on ProviderNotFoundException {
      // Missing provider is the ONLY tolerated case (Copilot, PR #292).
      selected = null;
    }
    if (selected != null && _distinctAccounts.contains(selected)) {
      return selected;
    }
    if (_accountFilter != 'all' && _distinctAccounts.contains(_accountFilter)) {
      return _accountFilter;
    }
    if (_distinctAccounts.isNotEmpty) return _distinctAccounts.first;
    return null;
  }

  /// Opens the Manual Scan screen for the resolved account (Harold,
  /// 2026-07-31, MV-1), then reloads, because a scan can resolve items shown
  /// here. The account comes from [_resolveAccountIdForSettings], so the
  /// Settings and Manual Scan icons always mean the same account.
  Future<void> _openManualScan() async {
    final accountId = _resolveAccountIdForSettings();
    if (accountId == null) {
      // Report rather than silently return (PR #292 re-review): the icon is
      // visible even with zero accounts.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an email account first -- there is no account to '
              'scan yet.'),
        ),
      );
      return;
    }

    await StandardAppBarActions.openManualScan(
      context,
      accountId: accountId,
      accountEmail: _accountEmails[accountId] ?? accountId,
    );

    if (mounted) await _loadItems();
  }

  /// The AppBar Refresh action (Harold, 2026-07-31: "what does the refresh
  /// icon do"): re-reads the stored rows and re-runs the coverage sweep, then
  /// SAYS what changed, because the local work finishes too fast to see.
  Future<void> _refreshFromUserAction() async {
    final before = _allItems.length;
    final ok = await _loadItems();
    if (!mounted) return;

    // Load failed and already showed its error.
    if (!ok) return;

    final swept = _lastSweepCount;
    final removed = before - _allItems.length;

    final String message;
    if (swept > 0) {
      message = swept == 1
          ? '1 item is now covered by rules -- removed'
          : '$swept items are now covered by rules -- removed';
    } else if (removed > 0) {
      // Defensive: the list shrank for a reason other than the sweep. Report
      // honestly rather than claiming rules covered them.
      message = removed == 1
          ? '1 item no longer applies -- removed'
          : '$removed items no longer apply -- removed';
    } else {
      message = 'No changes -- list is up to date';
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  /// Returns true when the load SUCCEEDED, false when it failed (PR #292
  /// review). [showSpinner] is false for the reload after a quick action, so
  /// the list does not blank while the next pop-up is open.
  Future<bool> _loadItems({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    var ok = true;

    try {
      final credStore = SecureCredentialsStore();
      final configuredAccounts = await credStore.getSavedAccounts();
      final sortedAccounts = List<String>.from(configuredAccounts)..sort();

      final emailMap = <String, String>{};
      for (final accountId in sortedAccounts) {
        final dashIndex = accountId.indexOf('-');
        emailMap[accountId] = (dashIndex > 0 && dashIndex < accountId.length - 1)
            ? accountId.substring(dashIndex + 1)
            : accountId;
      }

      final items = <_NoRuleItem>[];
      for (final accountId in sortedAccounts) {
        // F245 (Sprint 77, Harold Q21): every UNPROCESSED row for the account,
        // across scans; the upsert keeps ONE row per email (ADR-0045).
        final unmatched = await _unmatchedStore.getUnprocessedForAccount(accountId);

        for (final email in unmatched) {
          items.add(_NoRuleItem(
            email: email,
            accountId: accountId,
            accountEmail: emailMap[accountId] ?? accountId,
          ));
        }
      }

      // MT-2b (Sprint 50, Harold): sweep EVERY load -- items already covered
      // by the CURRENT rules / safe senders are marked processed and dropped
      // before display.
      final kept = await _sweepCoveredItems(items);

      if (mounted) {
        setState(() {
          _allItems = kept;
          _distinctAccounts = sortedAccounts;
          _accountEmails = emailMap;
          // An account that is gone falls back to All.
          if (_accountFilter != 'all' &&
              !sortedAccounts.contains(_accountFilter)) {
            _accountFilter = 'all';
          }
          _isLoading = false;
        });
      }
    } catch (e, s) {
      ok = false;
      _logger.e('Failed to load No Rule review items', error: e, stackTrace: s);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not load review items. Please try again or check the '
                'log for details.'),
          ),
        );
      }
    }
    return ok;
  }

  /// MT-2/MT-2b (Sprint 50, Harold): evaluates every loaded item against the
  /// FULL current rule set + safe senders; covered items are marked
  /// processed (their covering rule addresses them -- Live Scan parity) and
  /// dropped from the returned list. Runs on EVERY load so covered rows can
  /// never (re)surface. Time-based event-loop yields per the F120 pattern keep
  /// the UI responsive on large rule sets.
  Future<List<_NoRuleItem>> _sweepCoveredItems(
      List<_NoRuleItem> items) async {
    _lastSweepCount = 0;
    if (items.isEmpty || !mounted) return items;
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    // F128 (Copilot review, PR #278): use the explicit loaded-state getters.
    if (!ruleProvider.isRulesLoaded) {
      await ruleProvider.loadRules();
    }
    if (!ruleProvider.isSafeSendersLoaded) {
      await ruleProvider.loadSafeSenders();
    }
    if (ruleProvider.rules.rules.isEmpty &&
        ruleProvider.safeSenders.safeSenders.isEmpty) {
      return items; // Genuinely nothing to match -- keep all.
    }
    final evaluator = RuleEvaluator(
      ruleSet: ruleProvider.rules,
      safeSenderList: ruleProvider.safeSenders,
      compiler: PatternCompiler(),
      // Copilot review (PR #278): no per-item eval logging on the sweep.
      silent: true,
    );

    final kept = <_NoRuleItem>[];
    final yieldClock = Stopwatch()..start();
    for (final item in items) {
      if (yieldClock.elapsedMilliseconds >= 100) {
        await Future<void>.delayed(Duration.zero);
        yieldClock.reset();
      }
      final id = item.email.id;
      if (id == null) {
        kept.add(item);
        continue;
      }
      try {
        final eval = await evaluator.evaluate(item.result.email);
        if (eval.matchedRule.isNotEmpty || eval.isSafeSender) {
          // Log the rule's TYPE, never its name: an exact-sender rule is named
          // Block_<address> and a subject rule Block_Subject_<subject text>.
          await _unmatchedStore.markAsProcessed(id, true,
              reason: NoRuleMarkReason.coveredByRule,
              detail: coveredByRuleDetail(eval));
          _lastSweepCount++;
        } else {
          kept.add(item);
        }
      } catch (e, s) {
        // A malformed pattern must not abort the load; keep the item listed.
        _logger.e('Covered-item sweep evaluation failed for an item',
            error: e, stackTrace: s);
        kept.add(item);
      }
    }
    if (_lastSweepCount > 0) {
      _logger.i('Swept $_lastSweepCount item(s) already covered by current '
          'rules/safe senders from the No Rule pool');
    }
    return kept;
  }

  // --- Filters (F283: the Results filters) ---

  /// Rows in the current ACCOUNT scope -- what the fixed "No rule (N)" chip
  /// counts and the "of Y" in the filter bar.
  List<_NoRuleItem> get _scopedItems => _accountFilter == 'all'
      ? _allItems
      : _allItems.where((i) => i.accountId == _accountFilter).toList();

  /// The rows shown: account scope, then search and folders, then the Sort
  /// chip's order, with email-provider senders grouped at the top (Sprint 46
  /// retro IMP-1).
  List<_NoRuleItem> _visibleItems() {
    var items = _scopedItems;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      // Every row is "No rule", so there is no rule name to search.
      items = items.where((i) => resultMatchesSearch(i.result, '', query)).toList();
    }
    if (_selectedFolders.isNotEmpty) {
      items = items
          .where((i) => _selectedFolders.contains(i.email.folderName))
          .toList();
    }
    final byResult = {for (final i in items) i.result: i};
    final ordered = orderResultsForDisplay(
      items.map((i) => i.result).toList(),
      order: _sortOrder,
    ).map((r) => byResult[r]!).toList();
    final partitioned = ProviderSenderGrouping.partitionProviderFirst(
        ordered, (i) => i.email.fromEmail);
    _providerGroupCount = partitioned.providerCount;
    return partitioned.items;
  }

  bool get _filtersActive =>
      _searchQuery.isNotEmpty || _selectedFolders.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _selectedFolders = {};
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _openSearch() {
    setState(() => _showSearch = true);
    // MV-1 (Sprint 58): an explicit post-frame focus request on every open
    // path (the TextField's own autofocus loses to the outer Focus).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _onAccountFilterChanged(String value) {
    setState(() => _accountFilter = value);
  }

  // --- Pop-up and quick actions (F283) ---

  void _openPopup(_NoRuleItem item,
      {GlobalKey? itemKey, Offset? anchorPosition, Size? anchorSize}) {
    showEmailDetailPopup(
      context,
      result: item.result,
      effectiveEval: item.result.evaluationResult,
      accountEmail: item.accountEmail,
      // Every row here is unaddressed, so Skip always applies.
      showSkip: true,
      itemKey: itemKey,
      anchorPosition: anchorPosition,
      anchorSize: anchorSize,
      onQuickAction: (request, position, size) => _actThenAdvance(
        item,
        request: request,
        anchorPosition: position,
        anchorSize: size,
      ),
      onSkip: (position, size) => _actThenAdvance(
        item,
        anchorPosition: position,
        anchorSize: size,
      ),
    );
  }

  /// Results' auto-advance, on this screen: choose the next row the action
  /// does NOT cover BEFORE running it, run the action in the background, and
  /// open the next row's pop-up at once in the same place. [request] null is
  /// Skip: nothing is changed and nothing counts as covered.
  void _actThenAdvance(
    _NoRuleItem current, {
    QuickActionRequest? request,
    Offset? anchorPosition,
    Size? anchorSize,
  }) {
    final visible = _visibleItems();
    final idx = visible.indexWhere((i) => i.email.id == current.email.id);
    _NoRuleItem? next;
    if (idx >= 0) {
      for (final candidate in visible.skip(idx + 1)) {
        if (request == null || !request.covers(candidate.result.email)) {
          next = candidate;
          break;
        }
      }
    }

    if (request != null) {
      unawaited(_applyQuickAction(current, request).catchError((Object e, StackTrace s) {
        _logger.e('Review quick action failed', error: e, stackTrace: s);
      }));
    }

    if (next != null && mounted) {
      _openPopup(next, anchorPosition: anchorPosition, anchorSize: anchorSize);
    }
  }

  /// Creates the rule or safe sender for [item], marks its row handled, and
  /// reloads (the reload's sweep marks every other row the new rule covers).
  Future<void> _applyQuickAction(
      _NoRuleItem item, QuickActionRequest request) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final service = RuleQuickActionService(ruleProvider: ruleProvider);
    final senderEmail =
        EmailBodyParser().extractEmailAddress(item.email.fromEmail);

    final RuleQuickActionResult result;
    if (request.kind == QuickActionKind.safeSender) {
      // F96: a RED authentication result warns before whitelisting
      // (mirrors ResultsDisplayScreen._addSafeSender).
      if (AuthResultsParser.classificationFromName(
              item.email.authClassification) ==
          AuthClassification.red) {
        final proceed = await AuthWarningDialog.showSafeSenderWarning(
          context,
          senderEmail: PatternNormalization.normalizeFromHeader(
              item.email.fromEmail),
          authResult:
              AuthResultsParser.syntheticResultFor(AuthClassification.red),
        );
        if (!proceed || !mounted) return;
      }
      result = await service.addSafeSender(
        value: request.value,
        type: request.type,
        senderEmailForConflictCheck: senderEmail,
      );
    } else {
      result = await service.createBlockRule(
        type: request.type,
        value: request.value,
        senderEmailForConflictCheck:
            request.type == 'subject' ? null : senderEmail,
        sourceDescription: 'No Rule Review screen',
      );
    }

    if (!result.success) {
      // F110: mask the sender when it is the user's own address.
      _logger.w('Review quick action failed for '
          '${Redact.senderForLog(item.email.fromEmail, {item.accountId})}: '
          '${result.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.displayMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // R76-4 (ADR-0047, R-6): the user's decision on the stored email, when
    // the dev-only content history is on. A stored No Rule row has no
    // Message-ID, so the provider id finds it. Best effort, never throws.
    unawaited(ContentHistory.recordDecision(
      settings: SettingsStore(),
      accountId: item.accountId,
      email: item.result.email,
      providerId: item.email.providerIdentifierValue,
      decision: request.kind == QuickActionKind.safeSender
          ? 'safe_sender:${request.type}'
          : 'block:${request.type}',
    ));

    final id = item.email.id;
    if (id != null) {
      await _unmatchedStore.markAsProcessed(id, true,
          reason: NoRuleMarkReason.popupAction,
          detail: '${request.kind.name} ${request.type}');
    }
    if (!mounted) return;
    final reloaded = await _loadItems(showSpinner: false);
    if (!mounted) return;
    final parts = <String>[result.displayMessage];
    // Gated on the reload succeeding (PR #292 re-review): a failed reload
    // never ran the sweep, so its count would be stale.
    if (reloaded && _lastSweepCount > 0) {
      parts.add('$_lastSweepCount more covered by it');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(parts.join(' -- ')),
      backgroundColor:
          request.kind == QuickActionKind.safeSender ? Colors.green : Colors.blue,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return SystemInsetWrapper(
      child: Focus(
        autofocus: true,
        // Ctrl+F opens search; Escape closes it (Results, Sprint 58 MV-3).
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if ((HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed) &&
                event.logicalKey == LogicalKeyboardKey.keyF) {
              _openSearch();
              return KeyEventResult.handled;
            }
            if (_showSearch && event.logicalKey == LogicalKeyboardKey.escape) {
              _closeSearch();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: AppBarWithExit(
            title: _showSearch
                ? TextField(
                    key: const Key('review_search_field'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Search emails...',
                      hintStyle: TextStyle(color: Colors.black54),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  )
                : const Text('Review No Rule Items'),
            leading: _showSearch
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Close Search',
                    onPressed: _closeSearch,
                  )
                : null,
            // F134 (Sprint 52): canonical order from the ONE shared builder --
            // Refresh and Search (screen-specific, first), then View Scan
            // History, Accounts, Settings, Help, then the auto-appended Exit.
            // includeNoRuleReview: false -- this IS the Review screen.
            // Hidden while the search field takes over the AppBar (Results).
            actions: _showSearch
                ? const []
                : StandardAppBarActions.build(
                    context: context,
                    helpSection: HelpSection.reviewNoRuleItems,
                    accountId: _resolveAccountIdForSettings(),
                    includeNoRuleReview: false,
                    // Own handler so this screen can RELOAD when the scan
                    // returns; zero accounts get an explicit message.
                    onManualScan: _openManualScan,
                    leading: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        // Harold 2026-07-31: this re-reads the stored list;
                        // only a Manual Scan contacts the mail server.
                        tooltip: 'Re-check the last scan (does not fetch new mail)',
                        onPressed: _refreshFromUserAction,
                      ),
                      IconButton(
                        tooltip: 'Search (Ctrl+F)',
                        icon: const Icon(Icons.search),
                        onPressed: _openSearch,
                      ),
                    ],
                  ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: [
              const ScreenVersionLine(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SelectionArea(child: _buildBody()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final scoped = _scopedItems;
    final visible = _visibleItems();
    final folders = scoped.map((i) => i.email.folderName).toSet().toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummary(scoped.length, folders),
          if (_filtersActive) ...[
            const SizedBox(height: 8),
            ResultFilterStatusBar(
              filteredCount: visible.length,
              totalCount: scoped.length,
              onClear: _clearFilters,
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: visible.isEmpty ? _buildEmptyState() : _buildList(visible),
          ),
        ],
      ),
    );
  }

  /// The Results summary card: title, then the chip row -- the fixed
  /// "No rule (N)" chip (F4 = 1: it shows the count and is not a drop-down),
  /// the account drop-down (always shown, MV-Q14), Folders, then Sort.
  Widget _buildSummary(int scopedCount, List<String> folders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unaddressed "No rule" emails',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  container: true,
                  label: 'No rule: $scopedCount emails',
                  excludeSemantics: true,
                  child: Chip(
                    key: const Key('review_no_rule_chip'),
                    label: Text('No rule ($scopedCount)'),
                    backgroundColor: const Color(0xFF757575),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide.none,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                _buildAccountFilter(),
                FolderFilterChip(
                  folders: folders,
                  selected: _selectedFolders,
                  onChanged: (s) => setState(() => _selectedFolders = s),
                ),
                ResultSortChip(
                  order: _sortOrder,
                  onToggle: () => setState(() {
                    _sortOrder = _sortOrder == ResultSortOrder.newestFirst
                        ? ResultSortOrder.folderDomainAddress
                        : ResultSortOrder.newestFirst;
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// F169 (Sprint 61) / F283: the single-select account drop-down, styled like
  /// the Folders chip and ALWAYS shown (MV-Q14), with each account's count.
  /// A drop-down is width-independent, so no account can clip off a phone
  /// screen (Harold, 2026-08-16: "All account must be viewable"). Carries
  /// button semantics (F284 R-1).
  Widget _buildAccountFilter() {
    final countsByAccount = <String, int>{};
    for (final item in _allItems) {
      countsByAccount.update(item.accountId, (c) => c + 1, ifAbsent: () => 1);
    }

    // (label, value) in display order: All Accounts first, then each account.
    final options = <(String, String)>[
      ('All Accounts (${_allItems.length})', 'all'),
      for (final accountId in _distinctAccounts)
        (
          '${_accountEmails[accountId] ?? accountId} '
              '(${countsByAccount[accountId] ?? 0})',
          accountId,
        ),
    ];

    final activeLabel = options
        .firstWhere((o) => o.$2 == _accountFilter, orElse: () => options.first)
        .$1;
    final isFiltered = _accountFilter != 'all';

    // F284 R-1: ONE button node with its own tap action (the Sort chip
    // pattern), so a screen reader and UI Automation can open the menu
    // without the mouse.
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: activeLabel,
      hint: 'Filter by account',
      onTap: () => _accountMenuKey.currentState?.showButtonMenu(),
      child: PopupMenuButton<String>(
        key: _accountMenuKey,
        tooltip: 'Filter by account',
        onSelected: _onAccountFilterChanged,
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<String>(
              value: option.$2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Check the active entry so the current selection is
                  // obvious inside the menu, not only on the face.
                  SizedBox(
                    width: 24,
                    child: option.$2 == _accountFilter
                        ? const Icon(Icons.check, size: 18)
                        : null,
                  ),
                  // Flexible + ellipsis: a long account label must not
                  // overflow the menu at phone width (F169, 411px).
                  Flexible(
                    child: Text(option.$1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        child: Chip(
          key: const Key('review_account_chip'),
          avatar: const Icon(Icons.account_circle, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(activeLabel, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
            ],
          ),
          backgroundColor:
              isFiltered ? Colors.indigo.withValues(alpha: 0.7) : Colors.indigo,
          labelStyle: TextStyle(
            color: Colors.white,
            fontWeight: isFiltered ? FontWeight.w900 : FontWeight.bold,
          ),
          side: isFiltered
              ? const BorderSide(color: Colors.black, width: 2)
              : BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_allItems.isNotEmpty) {
      return const EmptyState(
        icon: Icons.filter_list_off,
        title: 'No matching items',
        message: 'No "No rule" email matches the current filters.',
      );
    }
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: 'No unaddressed items',
      message: 'All "No rule" emails have been reviewed.',
    );
  }

  Widget _buildList(List<_NoRuleItem> visible) {
    final n = _providerGroupCount;
    final showAccount = _distinctAccounts.length > 1;
    Widget tile(_NoRuleItem item) => EmailResultTile(
          key: ValueKey('review_row_${item.email.id}'),
          result: item.result,
          ruleName: '',
          accountLabel: showAccount ? item.accountEmail : null,
          onTap: (tileKey) => _openPopup(item, itemKey: tileKey),
        );
    return ListView.builder(
      itemCount: visible.length + (n > 0 ? 2 : 0),
      itemBuilder: (context, index) {
        // IMP-1 (Sprint 46 retro): provider-group heading + end indicator
        // wrap the first n rows; without provider senders the list renders
        // plainly.
        if (n <= 0) return tile(visible[index]);
        if (index == 0) return ProviderGroupHeader(count: n);
        if (index <= n) return tile(visible[index - 1]);
        if (index == n + 1) return const ProviderGroupEnd();
        return tile(visible[index - 2]);
      },
    );
  }
}
