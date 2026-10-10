import 'dart:async' show unawaited;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../widgets/app_bar_with_exit.dart';
import '../widgets/standard_app_bar_actions.dart';
import '../widgets/auth_warning_dialog.dart';
import 'help_screen.dart';
import 'scan_progress_screen.dart';

import '../../core/providers/email_scan_provider.dart'
    show
        EmailScanProvider,
        EmailActionResult,
        EmailActionType,
        ScanStatus,
        ScanMode;
import '../../core/providers/rule_set_provider.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/models/rule_set.dart' show Rule, RuleSet;
import '../../core/models/safe_sender_list.dart' show SafeSenderList;
import '../../core/services/auth_results_parser.dart';
import '../../core/services/content_history.dart';
import '../../core/services/diagnostic_logger.dart';
import '../../core/services/email_scanner.dart' show safeSenderAlreadyInTarget;
import '../../core/services/app_version.dart';
import '../../util/redact.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/services/rule_evaluator.dart';
import '../../core/services/rule_quick_action_service.dart';
import '../../core/storage/database_helper.dart';
import '../../core/services/scan_coordinator.dart'; // F212 (Sprint 70)
import '../../core/storage/scan_result_store.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/provider_sender_grouping.dart';
import '../../core/utils/result_ordering.dart';
import '../widgets/provider_group_markers.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart'
    show SpamFilterPlatform, FilterAction;
import '../../adapters/storage/secure_credentials_store.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_version_line.dart'; // F229 (Sprint 73)
import '../widgets/system_inset_wrapper.dart'; // F209 (Sprint 69)
import '../widgets/result_list_pieces.dart';
import '../widgets/email_detail_popup.dart';
export '../widgets/result_list_pieces.dart'
    show
        orderResultsForDisplay,
        formatReceivedDateForDisplay,
        formatReceivedDayForRow;
import '../../core/services/export_directories.dart';

/// Displays summary of scan results bound to EmailScanProvider.
///
/// F283 (Sprint 78): the display order, the date formats and the list
/// pieces this screen shares with Review No Rule Items live in
/// `../widgets/result_list_pieces.dart`, re-exported below so existing
/// imports of [orderResultsForDisplay], [formatReceivedDateForDisplay] and
/// [formatReceivedDayForRow] from this file keep resolving.
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
  // PR #335 cowork review: `found` removed -- the F166 dropdown represents
  // all-results as all-null filters; the deleted Found chip was its only
  // setter.
  processed, // All processed emails (Processed)
  error, // Only emails with errors
}

/// F228 (Sprint 72): what a re-process attempt actually did.
///
/// **Why this type exists.** The per-action toast was hardcoded
/// `backgroundColor: Colors.green` and fired AFTER `_reProcessAffectedEmails()`
/// -- so the IMAP failure had already happened and the count was already known,
/// and the code did not use it. Harold reproduced it on demand in airplane
/// mode: a GREEN toast per item ("...rule to block entire domain ... -- 9 No
/// rule remaining") while the batch summary for the SAME actions was ORANGE
/// ("Re-processed 0 of 6 (6 failed)"). Three surfaces, two verdicts.
///
/// Returning the counts is what lets the caller tell the truth. The method
/// used to return void and report only through its own snackbar.
/// F234 (Sprint 73), review C-2: which list an email belongs in.
enum ReProcessBucket { delete, moveSafe, none }

/// The per-email re-processing decision, as a PURE function.
///
/// **Why this is extracted.** It was inline, and the version that shipped was
/// inert: the read-only preview passed `ScanMode.readOnly` into gates that test
/// for `rulesOnly`/`safeSendersOnly`/`safeSendersAndRules`. `readOnly` matches
/// none of them, so both lists stayed empty and the preview could never report
/// anything but zero. Nine tests passed, because they asserted the SHAPE of the
/// code (its text and statement order) rather than its RESULT.
///
/// Pulling the decision out costs nothing at runtime and makes the defect
/// directly assertable with no platform, credentials or database -- which is
/// the whole difference between a test that would have caught it and the ones
/// that did not.
///
/// Callers that must not touch the mailbox pass the mode they WOULD have acted
/// under and suppress execution separately; this function answers "what would
/// happen", never "may I".
@visibleForTesting
ReProcessBucket classifyForReProcess({
  required EmailActionType newAction,
  required ScanMode scanMode,
}) {
  final canExecuteRules = scanMode == ScanMode.rulesOnly ||
      scanMode == ScanMode.safeSendersAndRules;
  final canExecuteSafeSenders = scanMode == ScanMode.safeSendersOnly ||
      scanMode == ScanMode.safeSendersAndRules;

  if (newAction == EmailActionType.delete && canExecuteRules) {
    return ReProcessBucket.delete;
  }
  if (newAction == EmailActionType.safeSender && canExecuteSafeSenders) {
    return ReProcessBucket.moveSafe;
  }
  return ReProcessBucket.none;
}

/// Sprint 76 (0.17.2 Fold log): WHY a rule update's mailbox actions failed,
/// grouped by reason, for the diagnostic log.
///
/// The log read "acted on 0 of 29 (failed 29): moveSafe=29" with no cause --
/// the batch result carried each id's reason and nothing wrote it down.
/// Grouped so 29 identical failures are one line, not 29; capped at
/// [maxReasons] distinct reasons; each reason scrubbed of addresses and capped
/// at 200 characters. Message ids are never written.
@visibleForTesting
List<String> summarizeBatchFailureReasons(
  Map<String, String> failedIds, {
  int maxReasons = 3,
}) {
  final counts = <String, int>{};
  for (final reason in failedIds.values) {
    final scrubbed = DiagnosticLogger.scrub(reason);
    final capped =
        scrubbed.length > 200 ? '${scrubbed.substring(0, 200)}...' : scrubbed;
    counts[capped] = (counts[capped] ?? 0) + 1;
  }
  final ordered = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final lines = [
    for (final e in ordered.take(maxReasons)) '${e.value} x ${e.key}',
  ];
  final more = ordered.length - maxReasons;
  if (more > 0) lines.add('... and $more other reason(s)');
  return lines;
}

class ReProcessOutcome {
  const ReProcessOutcome({
    required this.attempted,
    required this.succeeded,
    required this.failed,
    this.skippedReadOnly = false,
    this.wouldHaveDeleted = 0,
    this.wouldHaveMoved = 0,
  }) : busy = null;

  /// Nothing needed doing -- not a failure, and not a success worth claiming.
  const ReProcessOutcome.nothingToDo()
      : attempted = 0,
        succeeded = 0,
        failed = 0,
        skippedReadOnly = false,
        wouldHaveDeleted = 0,
        wouldHaveMoved = 0,
        busy = null;

  /// The account is configured read-only; the mailbox was deliberately not
  /// touched. Distinct from a failure, and the user is told.
  ///
  /// F234 (Sprint 73): [wouldHaveDeleted] and [wouldHaveMoved] carry what the
  /// rule WOULD have done. Harold, during Sprint 72 validation: *"if Manual >
  /// Scan mode is readonly then add the rule, but don't delete the email, but
  /// add it to 'would have been deleted'."*
  ///
  /// This turns read-only from a refusal into a REHEARSAL -- a broad rule's
  /// blast radius can be seen before anything is removed. Most valuable on
  /// Windows, which is configured read-only, so it is the platform that could
  /// never see a rule's effect at all.
  const ReProcessOutcome.readOnly({
    this.wouldHaveDeleted = 0,
    this.wouldHaveMoved = 0,
  })  : attempted = 0,
        succeeded = 0,
        failed = 0,
        skippedReadOnly = true,
        busy = null;

  final int attempted;
  final int succeeded;
  final int failed;
  final bool skippedReadOnly;

  /// F234: what a read-only run WOULD have deleted / moved. Zero on every
  /// other path -- these describe an action that did NOT happen, and nothing
  /// may read them as one that did.
  final int wouldHaveDeleted;
  final int wouldHaveMoved;

  /// Harold Q4 (Sprint 74 MV): another scan held the account, so the mailbox
  /// was NOT touched. The rule or safe sender itself is already saved.
  const ReProcessOutcome.busy(ScanAccountBusyException this.busy)
      : attempted = 0,
        succeeded = 0,
        failed = 0,
        skippedReadOnly = false,
        wouldHaveDeleted = 0,
        wouldHaveMoved = 0;

  /// Non-null only for [ReProcessOutcome.busy].
  final ScanAccountBusyException? busy;

  /// True when a read-only run had something it would have acted on.
  bool get hasPreview =>
      skippedReadOnly && (wouldHaveDeleted + wouldHaveMoved) > 0;

  /// True only when work was attempted and none of it failed.
  ///
  /// Deliberately NOT true for "nothing to do": a toast that says the mailbox
  /// was changed when no action ran is the same class of lie this card closes.
  ///
  /// **No production caller, and that is deliberate -- do not "simplify"
  /// `_showActionOutcome` to use it.** (Phase 7 review, Sprint 72.) That method
  /// branches `skippedReadOnly` -> `anyFailed` -> else, so its success branch
  /// is ALSO reached by `nothingToDo()`, where showing the progress suffix is
  /// correct: the rule was created, no mailbox action was needed, and the
  /// message makes no mailbox claim. Swapping in `allSucceeded` would exclude
  /// that case and suppress a legitimate message.
  ///
  /// It is kept because it pins the SEMANTIC the tests assert -- that
  /// `attempted == 0` is not success -- which is the distinction this whole
  /// card exists to protect.
  @visibleForTesting
  bool get allSucceeded => attempted > 0 && failed == 0;

  bool get anyFailed => failed > 0;
}

/// PR #440 test review: the action toast's wording and color, pulled out of
/// `_showActionOutcome` so the BRANCH ORDER is testable -- a busy or read-only
/// outcome has attempted = 0 and failed = 0, so if its branch moved below the
/// failure check it would fall into the success branch and report a change
/// that did not happen (the F228 defect).
@visibleForTesting
({String message, Color background}) describeActionOutcome({
  required String baseMessage,
  required String progressSuffix,
  required ReProcessOutcome outcome,
  required Color successColor,
}) {
  final String message;
  final Color background;

  if (outcome.busy != null) {
    final holder = outcome.busy!.blockingScan;
    message = holder == null
        ? '$baseMessage -- saved. The app could not check whether another '
            'scan is running on this account, so your mailbox was not '
            'changed. The next scan applies it.'
        : '$baseMessage -- saved. A '
            '${ScanAccountBusyException.describeScanType(holder.scanType)} '
            'is running on this account, so your mailbox was not changed '
            'yet. The next scan applies it.';
    background = Colors.blueGrey;
  } else if (outcome.skippedReadOnly) {
    // F234: when there is something to preview, SAY WHAT IT WOULD HAVE DONE.
    // "would have" is stated twice and the mailbox is named as unchanged --
    // the wording carries the whole risk of this card, because a preview
    // misread as a completed action is the F228 defect wearing a new hat.
    if (outcome.hasPreview) {
      final parts = <String>[];
      if (outcome.wouldHaveDeleted > 0) {
        parts.add('${outcome.wouldHaveDeleted} would have been filed');
      }
      if (outcome.wouldHaveMoved > 0) {
        parts.add('${outcome.wouldHaveMoved} would have been moved');
      }
      message = '$baseMessage -- saved. Preview only: ${parts.join(', ')}. '
          'This account is read-only, so your mailbox was NOT changed.';
    } else {
      message = '$baseMessage -- saved. This account is read-only, so your '
          'mailbox was not changed.';
    }
    background = Colors.blueGrey;
  } else if (outcome.anyFailed) {
    // Name the number. "Something went wrong" is what sent Harold to Scan
    // History to work out what had actually happened.
    message = '$baseMessage -- saved, but ${outcome.failed} of '
        '${outcome.attempted} could not be applied to your mailbox.';
    background = Colors.orange;
  } else {
    message = '$baseMessage$progressSuffix';
    background = successColor;
  }
  return (message: message, background: background);
}

class _ResultsDisplayScreenState extends State<ResultsDisplayScreen> {
  /// F231 (Sprint 72): every action outcome from this session, newest last.
  ///
  /// **Why a list and not a longer toast.** Harold: *"I did a few and it went
  /// past faster than I could see it"*, and he TIMED it at about one second
  /// each -- the nominal 3s includes enter/exit animation, and each new action
  /// REPLACES the current SnackBar rather than queueing, so in a burst every
  /// toast but the last is cut short. Worse, acting from the top of the list
  /// auto-advances into the NEXT item's dialog, which covers the toast
  /// entirely: *"you don't see any of them."*
  ///
  /// So lengthening the timeout cannot be the fix -- at three actions in four
  /// seconds the user still only ever sees the last one, however long it
  /// lives. The toast was ALSO the only place the per-action outcome existed:
  /// not in any log, not in the CSV, and the footer carries only aggregate
  /// counts. A missed toast meant the information was gone for good, which is
  /// why Harold had to open Scan History to reconstruct what had happened.
  ///
  /// This list is the durable record. It survives a missed toast, a covered
  /// toast, and a burst.
  final List<String> _sessionActivity = [];

  // Filter state: null means show all, otherwise filter by this action type or special filter
  EmailActionType? _filter;
  SpecialFilter? _specialFilter;

  // Search state (Item 8: Ctrl-F search)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode =
      FocusNode(); // Issue 2a: Auto-focus on Ctrl+F
  String _searchQuery = '';
  bool _showSearch = false;

  /// MV-2/MV-3 (Sprint 58 Manual Validation): single close-search path shared
  /// by the leading back-arrow button and the Escape key, so both exits
  /// behave identically (clear the query, clear the field, restore the
  /// normal AppBar).
  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // Folder filter state (Item 6: folder dropdown)
  Set<String> _selectedFolders = {};

  /// F222 (Sprint 74 MV): the Scan Results order, switched by the Sort chip.
  /// Screen state only -- every visit starts on the default, which is what
  /// Harold asked to keep.
  ResultSortOrder _sortOrder = ResultSortOrder.folderDomainAddress;

  // Issue 3: Cache folders for performance
  List<String>? _cachedFolders;

  // [NEW] Testing feedback FB-4/FB-5: Historical scan result data
  ScanResult? _lastCompletedScan;
  bool _hasEverScanned = false;
  bool _historicalLoaded = false;
  List<EmailActionResult> _historicalResults = [];

  /// I-3 (Phase 5.1.1 review, Sprint 72): when the loaded scan actually ran.
  ///
  /// The CSV export stamps a "Scan Date" into every row. Without this it used
  /// the provider's LIVE `_scanStartTime`, so exporting a saved scan wrote
  /// either 'Unknown' or today's timestamp onto rows from days ago. Prefers the
  /// completion time and falls back to the start time for a scan that never
  /// recorded one.
  DateTime? _historicalScanCompletedAt;

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

  // F212 R-4 (Sprint 70): emails whose IMAP action FAILED.
  //
  // Before this, "addressed" was computed purely from rule EVALUATION -- an
  // email counted as addressed the moment a matching rule existed, whether or
  // not the server accepted the action. So a batch that failed 100% still
  // produced the green "All N 'No rule' emails addressed." banner. R-4 is
  // explicit that this must be fixed regardless of the underlying cause,
  // because a success message beside a failed batch is its own defect: it
  // tells the user their mail is filed when it is not.
  final Set<String> _reProcessFailedKeys = {};

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
    // Sprint 60 MV (F166, Harold): the DEFAULT filter is now "No rule" --
    // the triage workflow is the screen's primary use, and with this default
    // an item leaves the (filtered) list the moment a rule/safe sender
    // addresses it. (Replaced the original Item-4 Processed default.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filter = EmailActionType.none;
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
        lastScan =
            await scanResultStore.getScanResultById(widget.historicalScanId!);
      } else {
        lastScan =
            await scanResultStore.getLatestCompletedScan(widget.accountId);
      }

      // I-3: remember WHEN this scan ran, for the CSV export's Scan Date.
      final scanMillis = lastScan?.completedAt ?? lastScan?.startedAt;
      _historicalScanCompletedAt = scanMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(scanMillis)
          : null;

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
            authClassificationOverride: map['auth_classification'] as String?,
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
          // C-1 (Phase 5.1.1 review, Sprint 72): NEVER act on the mailbox
          // from screen load. See the parameter's own documentation --
          // before F232 this was safe by accident, and F232 removed the
          // accident.
          await _reProcessAffectedEmails(userInitiated: false);
          // Sprint 38 Round 9 fix (2026-05-17), REWRITTEN Sprint 72: this
          // call does not act on the mailbox -- it never should have, and
          // since C-1 it cannot. (The original text explained that
          // `scanMode == readOnly` made it inert here by default; that
          // reasoning is gone, replaced by the explicit flag above.) The
          // visual pass below is still needed: it leaves _hiddenEmailKeys
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
            if (override.matchedRule.isEmpty && !override.isSafeSender) {
              continue;
            }
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
      // Generate CSV content.
      //
      // F233 (Sprint 72): pass `_currentResults()` -- the SAME live-vs-
      // historical selector every display path on this screen already uses.
      // This call previously took no argument, so it read the provider's
      // `_results` (the live session) even while the screen was showing a
      // HISTORICAL scan, and wrote a header with zero rows while reporting
      // success. Three of five CSVs pulled off Harold's phone were exactly 108
      // bytes. Reusing `_currentResults()` rather than re-deriving the
      // selection is deliberate: a second copy of that logic is how the two
      // drift apart again.
      final appVersion = await AppVersion.get();
      final redact = await SettingsStore().getExportRedacted();
      final csvContent = scanProvider.exportResultsToCSV(
        rows: _currentResults(),
        appVersion: appVersion,
        redact: redact,
        // I-3: a historical view must stamp the SCAN's date, not the live
        // session's. Null on a live view, where the provider's own
        // _scanStartTime is the right answer.
        scanDate: widget.historicalScanId != null
            ? _historicalScanCompletedAt
            : null,
      );

      // F206 (Sprint 74): ONE resolver for every export (configured folder,
      // else the platform default) -- this block used to be a local copy.
      final exportPath = await ExportDirectories.resolve();

      // Create filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
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
                    // F210: was Colors.grey[200] -- a fixed near-white surface
                    // under text with NO colour, so the path rendered
                    // near-white on near-white in dark mode.
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    filePath,
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the path above to copy it.',
                  style: TextStyle(
                    fontSize: 11,
                    // F210: was Colors.grey[600] on the theme surface of the
                    // dialog -- the inverse pairing, dark-on-dark in dark mode.
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
  List<EmailActionResult> _getFilteredResults(
      List<EmailActionResult> allResults) {
    var results = allResults;

    // Remove emails hidden after rule change (instant visual removal)
    if (_hiddenEmailKeys.isNotEmpty) {
      results = results
          .where((r) => !_hiddenEmailKeys.contains(_getEmailKey(r.email)))
          .toList();
    }

    // Apply special filter first (Found, Processed, Error)
    if (_specialFilter != null) {
      switch (_specialFilter!) {
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
      results = results
          .where((result) => _getEffectiveAction(result) == _filter)
          .toList();
    }

    // Apply search filter (Item 8: Ctrl-F search)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      // F21: the effective evaluation supplies the rule name searched.
      results = results
          .where((result) => resultMatchesSearch(result,
              _getEffectiveEvaluation(result)?.matchedRule ?? '', query))
          .toList();
    }

    // Apply folder filter (Item 6: folder dropdown)
    if (_selectedFolders.isNotEmpty) {
      results = results.where((result) {
        return _selectedFolders.contains(result.email.folderName);
      }).toList();
    }

    // F222 (Sprint 74, reworked at MV): the user's chosen order -- default
    // folder -> domain -> address, or newest first -- from the Sort chip.
    // Returns a NEW list, so the provider's own list is never reordered in
    // place (the old in-place sort was safe only when a filter above had
    // already copied it).
    results = orderResultsForDisplay(results, order: _sortOrder);

    // Sprint 46 retro IMP-1 (Harold): email-provider senders group at the
    // TOP (stable partition -- the F222 order above is kept within both
    // groups). Applies under every filter; the heading / end
    // indicator are rendered by the list builder only when the group is
    // non-empty. Boundary index is exposed via _providerGroupCount.
    final partitioned = ProviderSenderGrouping.partitionProviderFirst(
        results, (r) => r.email.from);
    _providerGroupCount = partitioned.providerCount;
    return partitioned.items;
  }

  /// Provider-sender group size within the CURRENT filtered list -- set by
  /// _getFilteredResults on every recompute; consumed by the list builder to
  /// place the group heading and end indicator (IMP-1, Sprint 46 retro).
  int _providerGroupCount = 0;

  /// Toggle filter when stat chip is clicked
  /// Sprint 60 MV (Harold, Android re-validation): the filter banner's X.
  /// It used to call _toggleFilter(null), which only clears the ACTION
  /// filter -- with just the DEFAULT Processed special filter active (the
  /// initState default), `_filter == null` already, so the call was a no-op
  /// and the X was dead. Clear every filter dimension the banner reports.
  void _clearAllFilters() {
    setState(() {
      _filter = null;
      _specialFilter = null;
      _selectedFolders = {};
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
    if (_cachedFolders == null ||
        _cachedFolders!.length !=
            allResults.map((r) => r.email.folderName).toSet().length) {
      _cachedFolders =
          allResults.map((r) => r.email.folderName).toSet().toList()..sort();
    }

    // Issue 2: Wrap with Focus to detect Ctrl+F keyboard shortcut
    // F209: SystemInsetWrapper goes OUTSIDE Focus so the inset applies to the
    // whole screen. This file returns a WRAPPER rather than a bare Scaffold,
    // which is the exact shape the first wiring gate could not see -- it
    // matched `return Scaffold(`, so this screen and scan_progress_screen.dart
    // were skipped while the gate reported green. The last row of the results
    // list sat under the navigation buttons, on the screen the feature exists
    // to serve.
    return SystemInsetWrapper(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Detect Ctrl+F (or Cmd+F on macOS)
          if (event is KeyDownEvent) {
            final isFPressed = event.logicalKey == LogicalKeyboardKey.keyF;

            // Check if Ctrl/Cmd + F is pressed
            if ((HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed) &&
                isFPressed) {
              setState(() {
                _showSearch = true;
              });
              // Issue 2a: Auto-focus the search field after opening
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocusNode.requestFocus();
              });
              return KeyEventResult.handled;
            }

            // MV-3 (Sprint 58 Manual Validation): Escape closes the search box
            // when it is open -- standard Windows desktop convention (Escape
            // dismisses transient UI). Key events bubble from the focused
            // TextField up through this ancestor Focus, so this fires while
            // typing in the search field. Only handled when search is open;
            // otherwise Escape is ignored and does nothing else on this screen.
            if (_showSearch &&
                event.logicalKey == LogicalKeyboardKey.escape) {
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
                    controller: _searchController,
                    focusNode: _searchFocusNode, // Issue 2a: Connect focus node
                    autofocus: true,
                    style: const TextStyle(
                        color: Colors.black), // Issue 2b: Black text
                    decoration: const InputDecoration(
                      hintText: 'Search emails...',
                      hintStyle: TextStyle(
                          color: Colors.black54), // Issue 2b: Dark gray hint
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  )
                : Text(
                    'Results - ${widget.accountEmail} - ${widget.platformDisplayName}'),
            // Add explicit back button that returns to account selection
            // MV-2 (Sprint 58 Manual Validation): close-search icon changed
            // from Icons.close (X) to Icons.arrow_back -- the X visually
            // collided with the app-exit X on the opposite end of the AppBar.
            // Back-arrow is the standard Material convention for leaving an
            // in-AppBar search mode (Gmail et al.): "go back from search" on
            // the left edge, matching this screen's own non-search leading
            // back-arrow semantics (leave the current mode/screen).
            leading: _showSearch
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Close Search',
                    onPressed: _closeSearch,
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
            // F134 (Sprint 52): canonical order from the ONE shared builder --
            // Download, Find (screen-specific, leading), then Review No Rule
            // Items, View Scan History, Accounts, Settings, Help, then the
            // auto-appended Exit. Exactly Harold's spec for this screen.
            // Previously this ran Download, Search, No-Rule, History, Accounts,
            // HELP, Settings -- Help and Settings inverted. Change the order in
            // StandardAppBarActions, never here.
            //
            // The whole block stays gated on !_showSearch: when the search field
            // is open it takes over the AppBar, so every action is hidden.
            actions: [
              if (!_showSearch)
                ...StandardAppBarActions.build(
                  context: context,
                  // Demo scans deep-link to a different help section.
                  helpSection: widget.platformId == 'demo'
                      ? HelpSection.demoScan
                      : HelpSection.resultsDisplay,
                  accountId: widget.accountId,
                  accountEmail: widget.accountEmail,
                  platformId: widget.platformId,
                  platformDisplayName: widget.platformDisplayName,
                  leading: [
                    // F231 (Sprint 72): the durable view of what this session
                    // did. Shown only once there IS something to show, so it
                    // never adds a dead control to an already-crowded row --
                    // the same row F172 measured at ~81px of overflow at 411px.
                    if (_sessionActivity.isNotEmpty)
                      IconButton(
                        tooltip: 'What happened in this session',
                        icon: const Icon(Icons.history_toggle_off),
                        onPressed: _showSessionActivity,
                      ),
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
                        // MV-1 (Sprint 58 Manual Validation): the icon path was
                        // missing the focus request the Ctrl+F path already had,
                        // so the user had to click the text box before typing.
                        // The TextField's own autofocus loses the race against
                        // this screen's outer Focus(autofocus: true) wrapper --
                        // an explicit post-frame request is required on BOTH
                        // open paths.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _searchFocusNode.requestFocus();
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          const ScreenVersionLine(),
          Expanded(child: SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(builder: (context) {
                // Sprint 60 MV (Harold, Android re-validation): on a phone the
                // fixed header stack (summary card + banners) consumed nearly
                // the whole height, leaving a ~one-row list viewport ("not
                // enough room to scroll"). On COMPACT widths the header items
                // scroll WITH the list (folded into the same ListView), giving
                // the list the full screen; desktop keeps the fixed header
                // exactly as before (600px threshold: phones fold, the 1600px
                // default Windows window never does).
                final isCompact = MediaQuery.of(context).size.width < 600;
                final headerItems = <Widget>[
                  _buildSummary(summary, scanProvider, allResults),
                  // F38: Non-blocking re-processing banner
                  if (_isReProcessing) ...[
                    const SizedBox(height: 8),
                    _buildReProcessingBanner(),
                  ],
                  const SizedBox(height: 16),
                  // Show filter status if active
                  if (_filter != null ||
                      _specialFilter != null ||
                      _selectedFolders.isNotEmpty) ...[
                    _buildFilterStatus(filteredResults.length, allResults.length),
                    const SizedBox(height: 8),
                  ],
                  // Sprint 38 F82 (Issue #252): "M of N no-rules addressed"
                  // indicator when there were any no-rule emails to triage.
                  _buildNoRuleProgressFooter(),
                ];
                final headerLen = isCompact ? headerItems.length : 0;
                return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isCompact) ...headerItems,
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
                          ? ListView(
                              // Wrap empty state in ListView for pull-to-refresh gesture
                              children: [
                                if (isCompact) ...headerItems,
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  // [UPDATED] Testing feedback FB-5: Only show "No Results Yet"
                                  // if no scan has EVER been run for this account
                                  // PR #335 cowork review: this chain predated
                                  // the F166 "No rule" DEFAULT filter, which
                                  // made `_filter != null` true on every idle
                                  // screen -- so never-scanned and found-zero
                                  // states wrongly showed "No Matching Emails".
                                  // Filters only explain an empty list when
                                  // there was something to filter: branch on
                                  // allResults, not on the filter fields.
                                  child: scanProvider.status ==
                                          ScanStatus.scanning
                                      ? const ScanStartedEmptyState()
                                      : allResults.isNotEmpty
                                          ? const NoMatchingEmailsEmptyState()
                                          // Sprint 77 MV step 2: _hasEverScanned
                                          // is read once, at screen load. A
                                          // first-ever scan that completes
                                          // after that read must not show
                                          // "No Results Yet", so a live scan
                                          // of THIS account completing also
                                          // counts as having scanned.
                                          : (_historicalLoaded &&
                                                  !_hasEverScanned &&
                                                  !(widget.historicalScanId ==
                                                          null &&
                                                      scanProvider.status ==
                                                          ScanStatus
                                                              .completed &&
                                                      scanProvider
                                                              .currentAccountId ==
                                                          widget.accountId))
                                              ? const NoResultsEmptyState()
                                              // F203: pass the skip count so
                                              // the state can distinguish
                                              // "fetched nothing" from
                                              // "fetched, all already filed".
                                              : ScanCompleteNoEmailsEmptyState(
                                                  skippedAlreadyFiled:
                                                      scanProvider
                                                          .skippedAlreadyFiledCount,
                                                ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: headerLen +
                                  filteredResults.length +
                                  (_providerGroupCount > 0 ? 2 : 0),
                              // No dividers between the folded-in header items,
                              // dividers between email rows as before.
                              separatorBuilder: (_, index) => index < headerLen
                                  ? const SizedBox.shrink()
                                  : const Divider(height: 1),
                              itemBuilder: (_, index) => index < headerLen
                                  ? headerItems[index]
                                  : _buildGroupedRow(
                                      filteredResults, index - headerLen),
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
                          // F224 (Sprint 73): the SAME button becomes Cancel
                          // while the scan it started is running.
                          //
                          // "Scan Again" uses useReplacement: true, so the scan
                          // runs with the user still on THIS screen -- the
                          // ScanProgressScreen where the Cancel control lives is
                          // never shown on this path, and it is the way testers
                          // actually restart scans (the same navigation quirk
                          // F220 had to account for). Without this, the most
                          // common route to a long scan has no way out.
                          //
                          // One button rather than two: while scanning, "Scan
                          // Again" is disabled anyway, so a second control would
                          // add a permanently-dead widget to the row.
                          child: scanProvider.status == ScanStatus.scanning
                              ? ElevatedButton.icon(
                                  onPressed: () => _cancelRunningScan(
                                      context, scanProvider),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Cancel Scan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              : ElevatedButton.icon(
                            onPressed: () {
                              // Testing feedback (Sprint 57): "Scan Again"
                              // used to return to the "Ready to Scan" screen,
                              // requiring a second tap on "Start Live Scan".
                              // Trigger the Live Scan directly instead --
                              // useReplacement: true so repeated taps replace
                              // the current Results screen rather than
                              // stacking a new one on the Navigator each time.
                              final ruleProvider = Provider.of<RuleSetProvider>(
                                  context,
                                  listen: false);
                              startRealScan(
                                context: context,
                                scanProvider: scanProvider,
                                ruleProvider: ruleProvider,
                                platformId: widget.platformId,
                                platformDisplayName: widget.platformDisplayName,
                                accountId: widget.accountId,
                                accountEmail: widget.accountEmail,
                                useReplacement: true,
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
              );
              }),
            ),
          )),
        ],
      ), // Close SelectionArea
        ),
      ),
    );
  }

  Widget _buildFilterStatus(int filteredCount, int totalCount) =>
      ResultFilterStatusBar(
        filteredCount: filteredCount,
        totalCount: totalCount,
        onClear: _clearAllFilters,
      );

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
      folders =
          List.from(scanProvider.getSelectedFoldersForAccount(widget.accountId))
            ..sort();
    } else if (showingHistorical &&
        _lastCompletedScan != null &&
        _lastCompletedScan!.foldersScanned.isNotEmpty) {
      folders = List.from(_lastCompletedScan!.foldersScanned)..sort();
    } else {
      folders = allResults.map((r) => r.email.folderName).toSet().toList()
        ..sort();
    }
    if (folders.isNotEmpty) {
      title += ' - Folder(s): ${folders.join(', ')}';
    }

    return title;
  }

  Widget _buildSummary(Map<String, dynamic> summary,
      EmailScanProvider scanProvider, List<EmailActionResult> allResults) {
    // Determine if showing live or historical results.
    // When historicalScanId is set (viewing from Scan History), always treat as historical
    // regardless of stale provider state.
    final isViewingHistory = widget.historicalScanId != null;
    final hasLiveResults = !isViewingHistory &&
        (scanProvider.results.isNotEmpty ||
            scanProvider.status == ScanStatus.scanning);
    final showingHistorical = !hasLiveResults && _lastCompletedScan != null;
    // Sprint 75 (Harold Q3 at Manual Validation): a REFUSED scan clears the
    // results before its claim is refused, so hasLiveResults alone made the
    // "another scan is running" row unreachable on exactly the path that
    // produces it. Used by BOTH the status row and the block that holds it.
    final showLiveRefusal = !isViewingHistory &&
        scanProvider.status == ScanStatus.error &&
        scanProvider.wasRefused;

    // [UPDATED] FB-2a: Use historical scan's mode when showing historical results,
    // not the live provider's mode (which defaults to readonly when idle)
    final bool isReadOnly;
    final bool isSafeSendersOnly;
    final bool isRulesOnly;
    if (showingHistorical && _lastCompletedScan != null) {
      final historicalMode = _lastCompletedScan!.scanMode;
      isReadOnly = historicalMode == 'readOnly' || historicalMode == 'readonly';
      isSafeSendersOnly =
          historicalMode == 'safeSendersOnly' || historicalMode == 'testAll';
      // F181 DELIBERATE KEEP: 'testLimit' is a legacy persisted value on old
      // scan records; the option itself is removed.
      isRulesOnly =
          historicalMode == 'rulesOnly' || historicalMode == 'testLimit';
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
      scanTypeLabel = _lastCompletedScan!.scanType == 'background'
          ? 'Background Scan'
          : 'Live Scan';
      if (_lastCompletedScan!.completedAt != null) {
        final completedDate = DateTime.fromMillisecondsSinceEpoch(
            _lastCompletedScan!.completedAt!);
        scanTimeLabel =
            'Completed: ${completedDate.toString().substring(0, 16)}';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sprint 74 MV (Harold): the account email appears ONCE on this
            // screen, in the "Results - <email>" title. F176 (Sprint 62) had
            // added a second copy here; the Manual Scan screen keeps its own.
            Text(
              _buildSummaryTitle(
                  hasLiveResults, showingHistorical, scanProvider, allResults),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (scanTypeLabel != null ||
                scanTimeLabel != null ||
                hasLiveResults ||
                showLiveRefusal) ...[
              const SizedBox(height: 4),
              // F166 (Sprint 60 MV, Harold): the scan status indicator
              // ("Scan complete <duration>" / progress) renders INLINE on
              // the same line as "Live Scan" instead of its own row.
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  // Sprint 75 (Harold Q3 at Manual Validation): a REFUSED scan
                  // clears the results before its claim is refused, so
                  // hasLiveResults alone made the "another scan is running"
                  // row unreachable on exactly the path that produces it.
                  if (hasLiveResults || showLiveRefusal)
                    _buildScanStatusIndicator(scanProvider),
                ],
              ),
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
              final deletedCount =
                  _evaluationOverrides.isNotEmpty || showingHistorical
                      ? allResults
                          .where((r) =>
                              _getEffectiveAction(r) == EmailActionType.delete)
                          .length
                      : scanProvider.deletedCount;
              // F151c (Sprint 58): the "Moved" summary chip was removed --
              // move-on-match is not yet implemented, so this count always
              // read 0 alongside real, populated chips, confirmed via live
              // walkthrough as reading like a bug rather than an intentional
              // zero. scanProvider.movedCount itself is untouched (still
              // used by background-scan logging/notifications and
              // ScanHistoryScreen's own separate "Moved" display).
              final safeCount = _evaluationOverrides.isNotEmpty ||
                      showingHistorical
                  ? allResults
                      .where((r) =>
                          _getEffectiveAction(r) == EmailActionType.safeSender)
                      .length
                  : scanProvider.safeSendersCount;
              final noRuleCount = _evaluationOverrides.isNotEmpty ||
                      showingHistorical
                  ? allResults
                      .where(
                          (r) => _getEffectiveAction(r) == EmailActionType.none)
                      .length
                  : scanProvider.noRuleCount;
              final errorCount = showingHistorical
                  ? allResults.where((r) => !r.success).length
                  : scanProvider.errorCount;

              // F166 (Sprint 60 MV, Harold): the six stat chips replaced by
              // ONE single-select filter dropdown + the Folders chip on a
              // single line. Counts live in the dropdown entries; the
              // mode-adaptive "(not processed)" labels carry over. The
              // dup-removed informational chip (F91) stays, shown only when
              // non-zero.
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFilterDropdownChip(
                    foundCount: foundCount,
                    processedCount: processedCount,
                    deletedCount: deletedCount,
                    safeCount: safeCount,
                    noRuleCount: noRuleCount,
                    errorCount: errorCount,
                    deletedLabel: isSafeSendersOnly || isReadOnly
                        ? 'Deleted (not processed)'
                        : 'Deleted',
                    safeLabel: isRulesOnly || isReadOnly
                        ? 'Safe (not processed)'
                        : 'Safe',
                  ),
                  // F203 (Sprint 69): emails that were FETCHED and then
                  // skipped because they already sit in the safe-sender
                  // folder. Correct behaviour -- "do not count, do not
                  // display, do not process" -- but it was invisible, so a
                  // scan that fetched 40 and skipped all 40 reported
                  // "Found 40, evaluated 0" with no way to learn why.
                  //
                  // Shown only when non-zero and only for a LIVE scan:
                  // historical rows carry no skip count, and rendering a
                  // hard zero would read like a bug (the F151c lesson that
                  // removed the always-zero "Moved" chip).
                  if (!showingHistorical &&
                      scanProvider.skippedAlreadyFiledCount > 0)
                    Tooltip(
                      message:
                          'Safe senders already in your safe sender folder. '
                          'They were found, but needed no action, so they are '
                          'not processed or listed.',
                      child: Chip(
                        label: Text(
                          '${scanProvider.skippedAlreadyFiledCount} already filed',
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  if (scanProvider.safeSenderDedupCount > 0)
                    Tooltip(
                      message:
                          'Source-folder duplicates removed (AOL re-injected '
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  _buildFolderFilterChip(allResults),
                  _buildSortChip(),
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
      final progressText =
          total > 0 ? '$processed of $total emails' : '$processed emails';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: isPaused
                    ? Icon(Icons.pause_circle_outline,
                        size: 14, color: Colors.orange[700])
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
      // PR #335 cowork review: measure to the FROZEN end time -- computing
      // to DateTime.now() at build time made the displayed duration grow
      // with every rebuild during triage (a 30s scan read "12m 30s" after
      // 12 minutes on the screen).
      final duration = (scanProvider.scanStartTime != null &&
              scanProvider.scanEndTime != null)
          ? scanProvider.scanEndTime!.difference(scanProvider.scanStartTime!)
          : null;
      final durationText = duration != null ? _formatDuration(duration) : null;

      return Row(
        mainAxisSize: MainAxisSize.min,
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

    if (hasError && scanProvider.wasRefused) {
      // Harold Q4 (Sprint 74 MV): another scan holds this account, so this one
      // did not start. Information, not a failure -- neutral colors, and the
      // whole sentence wraps instead of being cut off.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              scanProvider.statusMessage ?? 'Another scan is running',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
    }

    if (hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
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

  /// Build folder filter dropdown chip (Item 6)
  /// F166 (Sprint 60 MV, Harold): the single-select filter dropdown that
  /// replaced the six stat chips. Each entry carries its live count; choosing
  /// one sets the corresponding filter (action or special) and clears the
  /// other dimension -- single-select by construction. The chip face shows
  /// the ACTIVE selection; when the user clears all filters (the banner X),
  /// it falls back to an "All" face with the Found total, so the total-found
  /// information the old Found chip carried remains visible.
  Widget _buildFilterDropdownChip({
    required int foundCount,
    required int processedCount,
    required int deletedCount,
    required int safeCount,
    required int noRuleCount,
    required int errorCount,
    required String deletedLabel,
    required String safeLabel,
  }) {
    // (label, count, apply-callback, explanation) per Harold's specified
    // option order. PR #335 cowork review: the explanation strings are the
    // F151c (Sprint 58) plain-language chip tooltips VERBATIM -- the chips
    // they were attached to are gone, but the explanations were a Harold-
    // validated first-run-UX deliverable and now ride the dropdown entries
    // instead of being silently dropped with the chips.
    final options = <(String, int, VoidCallback, String)>[
      ('No rule', noRuleCount, () {
        _filter = EmailActionType.none;
        _specialFilter = null;
      }, 'No existing rule or safe sender matched these emails. '
          'Review them to add a rule or safe sender.'),
      (safeLabel, safeCount, () {
        _filter = EmailActionType.safeSender;
        _specialFilter = null;
      }, 'These emails matched a safe sender.'),
      (deletedLabel, deletedCount, () {
        _filter = EmailActionType.delete;
        _specialFilter = null;
      }, 'These emails matched a delete rule.'),
      ('Errors', errorCount, () {
        _specialFilter = SpecialFilter.error;
        _filter = null;
      }, 'Emails that could not be processed due to an error.'),
      ('Processed', processedCount, () {
        _specialFilter = SpecialFilter.processed;
        _filter = null;
      }, 'Emails evaluated against your rules so far.'),
    ];

    String face;
    if (_filter == EmailActionType.none) {
      face = 'No rule: $noRuleCount';
    } else if (_filter == EmailActionType.safeSender) {
      face = '$safeLabel: $safeCount';
    } else if (_filter == EmailActionType.delete) {
      face = '$deletedLabel: $deletedCount';
    } else if (_specialFilter == SpecialFilter.error) {
      face = 'Errors: $errorCount';
    } else if (_specialFilter == SpecialFilter.processed) {
      face = 'Processed: $processedCount';
    } else {
      face = 'All: $foundCount';
    }

    return PopupMenuButton<int>(
      // F151c 'Found' explanation preserved on the chip face, which is
      // what the removed Found chip's tooltip described.
      tooltip: 'Filter the email list. '
          'Total emails found in the scanned folder(s): $foundCount.',
      onSelected: (index) => setState(() => options[index].$3()),
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${options[i].$1}: ${options[i].$2}'),
                Text(
                  options[i].$4,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
      ],
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(face),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
        backgroundColor: const Color(0xFF757575),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  /// F222 (Sprint 74 MV, Harold): the Sort chip (shared with Review, F283).
  Widget _buildSortChip() =>
      ResultSortChip(order: _sortOrder, onToggle: _toggleSortOrder);

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == ResultSortOrder.newestFirst
          ? ResultSortOrder.folderDomainAddress
          : ResultSortOrder.newestFirst;
    });
  }

  /// Item 6: the Folders chip (shared with Review, F283). Issue 3: the folder
  /// list is cached for performance.
  Widget _buildFolderFilterChip(List<EmailActionResult> allResults) =>
      FolderFilterChip(
        folders: _cachedFolders ?? [],
        selected: _selectedFolders,
        onChanged: (selected) => setState(() => _selectedFolders = selected),
      );

  /// IMP-1 (Sprint 46 retro): maps ListView indices to rows, inserting the
  /// provider-group heading before and the end indicator after the first
  /// [_providerGroupCount] tiles. When the group is empty the list renders
  /// exactly as before (no heading, no indicator).
  Widget _buildGroupedRow(List<EmailActionResult> results, int index) {
    final n = _providerGroupCount;
    if (n <= 0) return _buildResultTile(results[index]);
    if (index == 0) return ProviderGroupHeader(count: n);
    if (index <= n) return _buildResultTile(results[index - 1]);
    if (index == n + 1) return const ProviderGroupEnd();
    return _buildResultTile(results[index - 2]);
  }

  /// Issue #47: one row (shared with Review, F283). F21: the rule shown is
  /// the effective evaluation (includes inline assignment overrides).
  Widget _buildResultTile(EmailActionResult result) => EmailResultTile(
        result: result,
        ruleName: _getEffectiveEvaluation(result)?.matchedRule ?? '',
        onTap: (tileKey) => _showEmailDetailSheet(result, itemKey: tileKey),
      );

  /// Show positioned popup with email details and inline quick actions
  /// Issue 6: CSS-like positioning - show popup below/above email item
  ///
  /// [anchorPosition]/[anchorSize] (Sprint 46, Harold item 2): explicit
  /// anchor override used by the "No rule" auto-advance flow, where the next
  /// email's popup reuses the previous popup's anchor so it appears at the
  /// same screen position (list tiles get fresh GlobalKeys every rebuild, so
  /// the next item's own key is not addressable from here).
  void _showEmailDetailSheet(EmailActionResult result,
      {GlobalKey? itemKey, Offset? anchorPosition, Size? anchorSize}) {
    // F283 (Sprint 78): the pop-up itself is shared with Review No Rule Items
    // (`email_detail_popup.dart`). It only reports the choice; this screen's
    // pipeline -- add the rule, re-evaluate, re-process, auto-advance -- is
    // unchanged and runs through the same _quickActionThenAdvance as before.
    final email = result.email;
    showEmailDetailPopup(
      context,
      result: result,
      // F21: effective evaluation (re-evaluated after inline rule assignment)
      effectiveEval: _getEffectiveEvaluation(result),
      // F283 R-6 (MV-Q17): the date row names the account.
      accountEmail: widget.accountEmail,
      // F136/F230: Skip only under the "No rule" filter, where an unaddressed
      // sequence exists to advance through.
      showSkip: _filter == EmailActionType.none,
      itemKey: itemKey,
      anchorPosition: anchorPosition,
      anchorSize: anchorSize,
      onQuickAction: (request, position, size) => _quickActionThenAdvance(
        current: result,
        anchorPosition: position,
        anchorSize: size,
        action: () => request.kind == QuickActionKind.safeSender
            ? _addSafeSender(request.value, request.type, email: email)
            : _createBlockRule(request.type, request.value, email: email),
        coveredByAction: (other) => request.covers(other.email),
      ),
      onSkip: (position, size) => _skipToNext(
        result: result,
        anchorPosition: position,
        anchorSize: size,
      ),
    );
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

  /// Resolve the result list the screen is currently displaying -- the same
  /// live-vs-historical resolution used by build/_reEvaluateNoRuleEmails/
  /// _reProcessAffectedEmails (historical-scan views always use
  /// _historicalResults; otherwise live results when present or a scan is
  /// active, else the reloaded historical results).
  List<EmailActionResult> _currentResults() {
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final liveResults = scanProvider.results;
    final isLiveScanActive = scanProvider.status == ScanStatus.scanning ||
        scanProvider.status == ScanStatus.paused;
    return (widget.historicalScanId != null)
        ? _historicalResults
        : ((liveResults.isNotEmpty || isLiveScanActive)
            ? liveResults
            : _historicalResults);
  }

  /// Sprint 46 manual-testing feedback (Harold 2026-07-11, item 2 + speed
  /// follow-up): when the "No rule" filter is active, acting on an email from
  /// the detail popup auto-advances to the NEXT remaining item -- its popup
  /// opens IMMEDIATELY at the same screen position, so triage becomes
  /// click-action -> next email appears -> click-action -> ...
  ///
  /// Ordering, per Harold's follow-up ("the auto-advance ... was very slow"):
  /// 1. Pick the next item FIRST -- the first following item in the filtered
  ///    list NOT covered by the action just taken ([coveredByAction] predicts
  ///    which items the new rule/safe-sender also addresses, e.g. every email
  ///    from the same domain when a domain rule is created).
  /// 2. Fire the processing pipeline WITHOUT awaiting it -- the rule persist,
  ///    re-evaluation, IMAP re-processing, and snackbar all complete in the
  ///    background (they refresh the list via setState when done).
  /// 3. Open the next item's popup immediately.
  ///
  /// The prediction can rarely under-skip (a rule that also matches a later
  /// email by a signal the predicate does not model); the consequence is just
  /// that the popup shows an email that gets addressed moments later -- the
  /// user sees it resolve and clicks on. No-op advance when the "No rule"
  /// filter is not active or nothing remains.
  /// F136 (Sprint 52): the popup-header "Skip" control.
  ///
  /// Duplicated from the inline quick-action button styling (Harold's steering:
  /// *"you can re-use an existing button, just duplicate and change the name to
  /// Skip"*), sized to sit comfortably beside the safe-sender / rule buttons.
  ///
  /// CONTRACT -- Skip must leave the item COMPLETELY unaffected:
  ///   - no rule, no safe sender, no processed flag, no DB write
  ///   - the item stays in the list and can be returned to
  ///   - it is navigation, not a state change
  /// It therefore passes a no-op `action` and a `coveredByAction` that always
  /// returns false, so nothing is treated as resolved by skipping.
  /// Open the next unaddressed item's popup, changing nothing about the
  /// current one (F136). The shared pop-up has already closed itself.
  void _skipToNext({
    required EmailActionResult result,
    required Offset? anchorPosition,
    required Size? anchorSize,
  }) {
    _quickActionThenAdvance(
      current: result,
      anchorPosition: anchorPosition,
      anchorSize: anchorSize,
      // No-op: skipping must not touch the item in any way.
      action: () async {},
      // Skipping resolves NOTHING, so no other item may be treated as covered.
      coveredByAction: (_) => false,
    );
  }

  void _quickActionThenAdvance({
    required EmailActionResult current,
    required Offset? anchorPosition,
    required Size? anchorSize,
    required Future<void> Function() action,
    required bool Function(EmailActionResult other) coveredByAction,
  }) {
    final noRuleFilterActive = _filter == EmailActionType.none;

    // Step 1: choose the next popup target BEFORE the slow pipeline runs.
    EmailActionResult? next;
    if (noRuleFilterActive) {
      final visible = _getFilteredResults(_currentResults());
      final currentKey = _getEmailKey(current.email);
      final idx =
          visible.indexWhere((r) => _getEmailKey(r.email) == currentKey);
      if (idx >= 0) {
        for (final candidate in visible.skip(idx + 1)) {
          if (!coveredByAction(candidate)) {
            next = candidate;
            break;
          }
        }
      }
    }

    // Step 2: process the current email in the background (matches the
    // original fire-and-forget behavior of these buttons pre-auto-advance).
    // The action's own internals surface user-facing failures via SnackBar;
    // this guard catches anything thrown by the re-evaluate/re-process tail
    // so a background exception is logged instead of becoming an unhandled
    // async error (Copilot review, Sprint 46).
    unawaited(action().catchError((Object e, StackTrace s) {
      Logger().e('Background quick-action pipeline failed',
          error: e, stackTrace: s);
      // Sprint 74 MV: this failure was console-only, so a tapped action that
      // died here left no trace a tester could read. Error class only.
      unawaited(DiagnosticLogger.failure(
        context: 'quick-action',
        kind: DiagnosticLogger.kindException,
        reason: 'pipeline failed after the tap: ${e.runtimeType}',
      ));
    }));

    // Step 3: show the next item's popup right away.
    if (next != null && mounted) {
      _showEmailDetailSheet(next,
          anchorPosition: anchorPosition, anchorSize: anchorSize);
    }
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
    // Sprint 76 (Fold, 0.17.1): NOT while a live scan is still running. The
    // screen renders while results stream in, so the first capture took the
    // count at that moment -- "0 of 1 ... 148 remaining", then "22 of 1".
    // Until the scan completes, _computeNoRuleStats falls back to the live
    // count; the full total is captured on the first render after it ends.
    // (The Sprint 38 Round 8 re-entry semantic is unchanged.)
    if (widget.historicalScanId == null) {
      final status =
          Provider.of<EmailScanProvider>(context, listen: false).status;
      if (status == ScanStatus.scanning || status == ScanStatus.paused) {
        return;
      }
    }
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
  /// F120 (Sprint 49): when [deltaRule] or [deltaSafeSenderPattern] is given
  /// (the quick-action paths), the no-rule set is evaluated against ONLY that
  /// newly-ADDED delta. This is semantically exact for additions: a "No rule"
  /// email already failed every existing rule, so only the new one can change
  /// its outcome. The previous full-set re-evaluation ran all no-rule emails
  /// x the entire rule set per quick action (~197 x 12,539 = 1-2 MINUTES of
  /// main-isolate compute on the 0.5.6 Store prod DB) inside an await chain
  /// whose futures complete synchronously -- microtask continuations never
  /// yield to the Windows message pump, so the window went "(Not Responding)".
  /// The no-delta path (historical-screen load, where rules may have changed
  /// arbitrarily) keeps the full set but yields to the event loop every few
  /// emails so the UI thread keeps pumping.
  Future<void> _reEvaluateNoRuleEmails({
    Rule? deltaRule,
    String? deltaSafeSenderPattern,
  }) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final bool useDelta = deltaRule != null || deltaSafeSenderPattern != null;
    final evaluator = useDelta
        ? RuleEvaluator(
            ruleSet: RuleSet(
              version: ruleProvider.rules.version,
              settings: const {},
              rules: [if (deltaRule != null) deltaRule],
            ),
            safeSenderList: SafeSenderList(safeSenders: [
              if (deltaSafeSenderPattern != null) deltaSafeSenderPattern,
            ]),
            compiler: _sharedCompiler,
          )
        : RuleEvaluator(
            ruleSet: ruleProvider.rules,
            safeSenderList: ruleProvider.safeSenders,
            compiler: _sharedCompiler,
            // Copilot review (PR #278), sibling of the MT-2c sweep: the
            // FULL-SET path re-evaluates every no-rule email against every
            // rule, so per-item eval logging is pure noise at prod scale.
            // The delta path above stays verbose -- it is one rule over a
            // handful of emails and the log line is diagnostically useful.
            silent: true,
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
    // F120 + Copilot review (PR #276): on the full-set path, yield a REAL
    // event-loop turn (Future.delayed, not a microtask) TIME-BASED -- every
    // ~100ms of work -- so the platform message pump keeps running regardless
    // of per-email cost or rule-set size. A fixed every-N-emails cadence
    // could still block ~5s between yields at ~0.5s/email (the Windows
    // Not Responding threshold).
    final yieldClock = Stopwatch()..start();
    for (final result in allResults) {
      if (_getEffectiveAction(result) == EmailActionType.none) {
        if (!useDelta && yieldClock.elapsedMilliseconds >= 100) {
          await Future<void>.delayed(Duration.zero);
          yieldClock.reset();
        }
        final evalResult = await evaluator.evaluate(result.email);
        // Only store override if the new evaluation found a match
        if (evalResult.matchedRule.isNotEmpty || evalResult.isSafeSender) {
          final key = _getEmailKey(result.email);
          _evaluationOverrides[key] = evalResult;
        }
      }
    }
  }

  /// F212 R-4 (Sprint 70): mark the emails whose IMAP action did not succeed.
  ///
  /// [attempted] is everything sent in the batch; [failedIds] is the subset the
  /// adapter reported as failed. A key that fails is REMOVED from the
  /// re-processed set as well, so a later retry is not skipped as "already
  /// done" -- otherwise a failed email would be permanently unactionable
  /// without a restart, which is the same shape of trap F220 fixed.
  /// Sprint 76: one diagnostic line per distinct failure reason of a rule
  /// update's batch (see [summarizeBatchFailureReasons]). Nothing when all
  /// succeeded.
  void _logReProcessFailureReasons(
      String action, Map<String, String> failedIds) {
    if (failedIds.isEmpty) return;
    for (final line in summarizeBatchFailureReasons(failedIds)) {
      unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindInfo,
        context: 'F38/re-process',
        detail: '$action failed: $line',
      ));
    }
  }

  void _recordBatchFailures(
    List<EmailMessage> attempted,
    Set<String> failedIds,
  ) {
    // Copilot review (PR #418, HIGH): a key that LATER SUCCEEDS must be
    // CLEARED, not left in the cumulative set forever. The first version of
    // this method returned early when nothing failed, so a successful retry
    // never removed the key -- the footer then reported "could not be applied"
    // permanently, `isComplete` could never become true, and
    // `_reProcessAffectedEmails` re-attempted the same email on every future
    // rule add. This early return is exactly what made the H-2 fix incomplete:
    // I added the skip guard without ever clearing the set.
    //
    // So: do NOT return early. Succeeded keys are the ones attempted but not
    // in failedIds, and they are cleared below.
    final succeededKeys = <String>{};
    for (final email in attempted) {
      if (failedIds.contains(email.id)) continue;
      succeededKeys.add(_getEmailKey(email));
    }
    if (failedIds.isEmpty && succeededKeys.isEmpty) return;
    // H-3 (code review, Sprint 70): mutate inside setState. The footer reads
    // `_reProcessFailedKeys.length` to decide whether to show the green
    // "all addressed" banner, so without this the correction depended on an
    // unrelated rebuild happening to land afterwards. The delete/move blocks
    // have a nearby setState that covered it by accident; the OUTER CATCH path
    // -- the total-failure case F212 exists for -- had none.
    void apply() {
      // A key that succeeded this time is no longer failed, whatever happened
      // on a previous attempt.
      _reProcessFailedKeys.removeAll(succeededKeys);
      for (final email in attempted) {
        if (!failedIds.contains(email.id)) continue;
        final key = _getEmailKey(email);
        _reProcessFailedKeys.add(key);
        _reProcessedEmailKeys.remove(key);
        _hiddenEmailKeys.remove(key);
      }
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
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
    // F212 R-4 (Sprint 70): a failed IMAP action must never read as
    // "addressed". `stats.addressed` is computed from rule EVALUATION alone --
    // an email counts the moment a matching rule exists, regardless of whether
    // the server accepted the action. That is why a batch that failed 100%
    // still showed the green "All N addressed." banner.
    final failed = _reProcessFailedKeys.length;
    final isComplete = remaining == 0 && initial > 0 && failed == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isComplete ? Colors.green.shade50 : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isComplete ? Colors.green.shade300 : Colors.amber.shade300,
          ),
        ),
        // Sprint 60 MV (F166, Harold): flag icon and trailing progress bar
        // removed -- the text alone carries the information.
        child: Text(
          isComplete
              ? 'All $initial "No rule" emails addressed.'
              : failed > 0
                  ? '$addressed of $initial "No rule" emails addressed -- '
                      '$failed could not be applied to your mailbox. '
                      'Check your connection and try again.'
                  : '$addressed of $initial "No rule" emails addressed -- $remaining remaining.',
          style: TextStyle(
            fontSize: 13,
            color: isComplete ? Colors.green.shade900 : Colors.amber.shade900,
            fontWeight: FontWeight.w500,
          ),
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
  /// F228 (Sprint 72): show the result of a rule/safe-sender action HONESTLY.
  ///
  /// **The defect this replaces.** Both call sites hardcoded their colour
  /// (`Colors.green` for a safe sender, `Colors.blue` for a block rule) and ran
  /// AFTER `await _reProcessAffectedEmails()`, so the IMAP outcome was already
  /// known and simply not consulted. Harold reproduced it on demand with
  /// airplane mode on: a success-coloured toast per item while the batch
  /// summary for the same actions was orange, `Re-processed 0 of 6 (6 failed)`.
  ///
  /// **What stays true and must not be "fixed"**: the rule itself IS created
  /// offline, and that is correct -- rules are local state and the user's
  /// intent is worth recording without a connection. `stats.remaining`
  /// legitimately drops because the rule now matches. The bug was the CLAIM
  /// about the mailbox, so only the claim changes here.
  ///
  /// [successColor] preserves each site's existing success colour, so a
  /// working action looks exactly as it did before.
  ///
  /// The batch summary inside `_reProcessAffectedEmails` already did this
  /// correctly (`failCount == 0 ? green : orange`) and is deliberately left
  /// alone -- it is the model this follows, not something to unify away.
  void _showActionOutcome({
    required String baseMessage,
    required String progressSuffix,
    required ReProcessOutcome outcome,
    required Color successColor,
  }) {
    if (!mounted) return;

    final described = describeActionOutcome(
      baseMessage: baseMessage,
      progressSuffix: progressSuffix,
      outcome: outcome,
      successColor: successColor,
    );
    final message = described.message;
    final background = described.background;

    // F231: record BEFORE showing. The toast can be missed, replaced or
    // covered by the next item's dialog; this cannot.
    // Inside setState: the history button is rendered conditionally on this
    // list being non-empty, so without a rebuild the FIRST action records
    // silently and the control never appears -- the durable record would exist
    // and be unreachable, which is the same shape as the defect it fixes.
    setState(() {
      _sessionActivity.add(
        '${TimeOfDay.fromDateTime(DateTime.now()).format(context)}  $message',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        // F231 (Sprint 72): a failure needs longer than a success. Harold
        // measured ~1s of readable time on the old 3s value, because the
        // duration includes animation and each new action REPLACES the
        // current SnackBar rather than queueing.
        duration: Duration(seconds: outcome.anyFailed ? 8 : 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  /// F231 (Sprint 72): show every outcome from this session.
  ///
  /// This is the answer to *"it went past faster than I could see it"*. A
  /// toast is transient by nature and this screen actively works against
  /// reading them -- actions replace each other, and auto-advance opens the
  /// next item's dialog over the top. The list does not move.
  void _showSessionActivity() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('This session'),
        content: SizedBox(
          width: 420,
          child: _sessionActivity.isEmpty
              ? const Text('No actions yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sessionActivity.length,
                  itemBuilder: (context, i) {
                    // Newest first: the last thing that happened is what the
                    // user is usually here to check.
                    final entry =
                        _sessionActivity[_sessionActivity.length - 1 - i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        entry,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// F232 (Sprint 72): the scan mode that should govern a USER-INITIATED
  /// action from this screen.
  ///
  /// **Delegates to `SettingsStore.getEffectiveScanMode`, which is the
  /// canonical resolver.** Its order is:
  ///   1. the account's manual-mode override,
  ///   2. the account's GENERIC scan-mode override,
  ///   3. the app-wide manual default.
  ///
  /// **C-2/C-2b (Phase 5.1.1 review, Sprint 72) -- this method used to
  /// reimplement that resolution, and got it wrong twice.**
  ///
  /// First, it consulted `scanProvider.scanMode` before the settings, on the
  /// reasoning that "a live scan in this session means the user chose a mode
  /// explicitly". The premise is sound and the implementation was not:
  /// `EmailScanProvider` is a single app-wide singleton holding ONE
  /// `_scanMode` with no account identity. Scan account A as
  /// `safeSendersAndRules`, then open results for account B configured
  /// `readOnly`, and that step returned A's mode for B -- bypassing B's
  /// deliberate read-only configuration, which is the one thing this card
  /// promised not to do.
  ///
  /// Second, it implemented tiers 1 and 3 and SKIPPED tier 2. An account
  /// configured only through the generic `setAccountScanMode` path resolved to
  /// the app-wide default instead of its own override -- so a mailbox the user
  /// configured not to touch could be acted on. Same harm, different trigger.
  ///
  /// The lesson is the repo's own: do not design a new member of a shared
  /// abstraction without reading the existing one. `getEffectiveScanMode` was
  /// already there, already correct, and already documented.
  ///
  /// MANUAL rather than background mode (`isBackground: false`) is deliberate:
  /// this is a foreground action the user just took, and letting a background
  /// policy govern it would be a different setting answering a question it was
  /// not asked.
  ///
  /// Returns `ScanMode.readOnly` on any failure. That is the safe direction: a
  /// resolution error must never become an unintended deletion.
  Future<ScanMode> _resolveEffectiveScanMode(
    EmailScanProvider scanProvider,
  ) async {
    try {
      return await SettingsStore()
          .getEffectiveScanMode(widget.accountId, isBackground: false);
    } catch (e) {
      Logger().w('[F38] scan-mode resolution failed, defaulting to '
          'read-only: $e');
      return ScanMode.readOnly;
    }
  }


  /// [userInitiated] MUST be false on any path the user did not ask for.
  ///
  /// **C-1 (Phase 5.1.1 review, Sprint 72) -- this parameter exists because the
  /// F232 fix was applied one level too deep and switched on a path that has no
  /// user intent behind it.**
  ///
  /// `_loadLastCompletedScan` calls this during SCREEN LOAD when a saved scan is
  /// opened from Scan History. Before F232 that was harmless: the old
  /// `scanMode == readOnly` guard ALWAYS tripped there, because opening history
  /// sets no session mode and the provider field holds its read-only default.
  /// Resolving the mode from saved settings removed that accident -- so on an
  /// account configured `rulesOnly` or `safeSendersAndRules`, merely VIEWING a
  /// saved scan would have deleted mail. The user tapped a history row, not an
  /// action button, and the outcome is discarded on that path so it would have
  /// been the least visible thing on the screen.
  ///
  /// F232 is about a rule the user just CREATED being applied. It was never
  /// about acting on screen load, and this parameter keeps the two apart.
  /// F224 (Sprint 73): stop the scan started by "Scan Again" from this screen.
  ///
  /// Same contract as the scan screen's control, and deliberately the same
  /// shape: raise the coordinator's flag and return. The running scan observes
  /// it at its next batch boundary, throws, and its own `finally` releases the
  /// lease and closes the IMAP session. Nothing is torn down from here -- doing
  /// so would free the lease while the socket is still open, which is the
  /// session leak this design exists to avoid.
  void _cancelRunningScan(
      BuildContext context, EmailScanProvider scanProvider) {
    final requested =
        ScanCoordinator.instance.requestCancel(
            accountId: widget.accountId,
            reason: 'user tapped Stop (Results)');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(requested
            // PR #435 review I-3: the earlier wording promised the scan
            // would "finish the emails it already fetched", which it does not
            // -- throwIfCancelled unwinds past BOTH the evaluation phase and
            // the batch-execution phase, so no fetched email is ever acted on.
            // The counts already recorded are kept, which is what AC-4 asks
            // for, but nothing further is filed or moved.
            ? 'Stopping the scan. Emails already checked are kept; nothing '
                'further will be filed or moved.'
            : 'That scan has already finished.'),
      ),
    );
  }

  Future<ReProcessOutcome> _reProcessAffectedEmails({
    bool userInitiated = true,
  }) async {
    final scanProvider = Provider.of<EmailScanProvider>(context, listen: false);
    final logger = Logger();

    // F232 (Sprint 72): resolve the effective scan mode from SAVED SETTINGS,
    // not from session state. Harold decided this (option 2, 2026-09-21) after
    // reporting that blocking a domain from a saved scan deleted nothing --
    // and that the very next background scan then deleted exactly the count
    // that session should have.
    //
    // **What was wrong.** This used to read `scanProvider.scanMode`, which
    // DEFAULTS to `ScanMode.readOnly` (`email_scan_provider.dart:165`) and is
    // only ever set by `initializeScanMode()`, whose call sites are all
    // scan-STARTING paths: `background_scan_core.dart:125`,
    // `account_setup_screen.dart:318`/`:1090`, `scan_progress_screen.dart:722`.
    // **Nothing set it when a HISTORICAL scan was opened from Scan History**,
    // so in a session where the user had not started a scan the mode was still
    // the read-only default and every IMAP action here was skipped -- silently,
    // to a console log nobody could read. The Sprint 38 Round 9 comment below
    // states that premise outright and worked around the VISUAL symptom by
    // hiding rows, which made the skipped deletion invisible.
    //
    // **One account, one mode.** `ResultsDisplayScreen` takes a single required
    // `accountId`, loads one credential set and talks to one platform, so it is
    // structurally single-account and a single resolved mode is correct.
    // (An earlier version of this comment claimed the batch was PARTITIONED
    // per account for an All-Accounts view. Neither half was true -- I-1 of the
    // Phase 5.1.1 review -- and a comment asserting a safety property nothing
    // implements is worse than no comment, because the next reader inherits the
    // confidence and stops checking the deletion path.)
    //
    // **A configured read-only account is still honoured.** This replaces
    // "skip because no scan ran this session" with "act per the account's
    // configured intent" -- it does not override a deliberate read-only
    // choice. Windows DEV/Prod are configured read-only, so they still skip;
    // what changes is that they now SAY so.
    // C-1: a non-user-initiated call never touches the mailbox. Resolving to
    // read-only here (rather than returning early) keeps the single exit path
    // and the same reporting shape for every caller.
    final effectiveMode = userInitiated
        ? await _resolveEffectiveScanMode(scanProvider)
        : ScanMode.readOnly;
    // F234: set when the account may not act, so the collection loop still
    // runs and the preview can be built from what it finds.
    var isReadOnly = false;
    if (effectiveMode == ScanMode.readOnly) {
      logger.i('[F38] Skipping re-process: account is configured read-only');
      unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindSkipped,
        context: 'F38/re-process',
        detail: userInitiated
            ? 'account ${Redact.email(widget.accountEmail)} is configured '
                'read-only; no mailbox action attempted'
            : 'screen-load re-evaluation; mailbox actions are never taken '
                'without user intent (C-1)',
      ));
      // I-2 (Phase 5.1.1 review): NO SnackBar here. This method used to show
      // its own read-only message AND return the outcome, so the caller's
      // `_showActionOutcome` composed a second, differently-worded one -- and
      // because a new SnackBar REPLACES the current rather than queueing (the
      // same mechanism F231 documents), the user saw a flash then a different
      // sentence. The caller owns the message; this method reports the outcome.
      // It also means the load path stays silent, which C-1 requires.
      // F234 (Sprint 73): DO NOT return yet.
      //
      // The card's audit said the would-have data "already exists" because
      // `toDelete`/`toMoveSafe` are built before the mode check. That was half
      // right: they are built LATER IN THIS METHOD, but this early return fired
      // BEFORE the collection loop, so on the read-only path they were never
      // populated at all. Building the preview means letting the collection run
      // and returning after it.
      //
      // Nothing below this point touches the mailbox until the execution block,
      // which is guarded by `isReadOnly`. The collection loop only reads
      // evaluation overrides.
      isReadOnly = true;
    }
    // F234 (Sprint 73), Phase 5.1.1/5.1.2 review C-2: the collection loop must
    // run under the mode that WOULD have acted, not under `readOnly`.
    //
    // THE DEFECT THIS FIXES, and it made the whole feature inert: the first cut
    // forced `scanMode = ScanMode.readOnly` here, and the loop below gates every
    // append on `scanMode == rulesOnly || == safeSendersAndRules` (and the
    // safe-sender equivalent). `readOnly` matches NEITHER, so both lists stayed
    // empty on exactly the path the preview exists to serve, the
    // `toDelete.isEmpty && toMoveSafe.isEmpty` guard returned `nothingToDo()`
    // first, and the preview block below was unreachable. The user saw "nothing
    // needed doing" and never a preview.
    //
    // `effectiveMode` is itself `readOnly` for such an account, so the intended
    // mode cannot be recovered from it. A preview answers "what would this rule
    // have done", so it is computed against `safeSendersAndRules` -- the
    // broadest mode, which is the honest answer to that question and the only
    // one that previews BOTH kinds as Harold chose at approval.
    //
    // This is the design the comment above already described ("nothing below
    // this point touches the mailbox until the execution block, which is
    // guarded by `isReadOnly`"). The comment was right and the code did not
    // implement it -- CLAUDE.md IMP-2 in its own right.
    final scanMode =
        isReadOnly ? ScanMode.safeSendersAndRules : effectiveMode;

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

      // Determine which IMAP action to execute based on new evaluation and
      // scan mode. Extracted to a pure function (review C-2) so the decision
      // can be tested WITHOUT a platform, credentials or a database -- the
      // absence of exactly that test is why the broken version shipped with a
      // green suite.
      switch (classifyForReProcess(
          newAction: newAction, scanMode: scanMode)) {
        case ReProcessBucket.delete:
          toDelete.add(result.email);
        case ReProcessBucket.moveSafe:
          toMoveSafe.add(result.email);
        case ReProcessBucket.none:
          break;
      }
    }

    // F234 (Sprint 73): the read-only PREVIEW.
    //
    // The lists now hold exactly what WOULD have been actioned, so report the
    // counts and stop before touching the mailbox. The user sees a rule's blast
    // radius without anything being removed -- the whole point of the card, and
    // most valuable on Windows, configured read-only, where a rule's effect was
    // previously invisible.
    //
    // Rows are NOT hidden here, deliberately: hiding them would imply the mail
    // had been dealt with, which is the F228 defect in a different costume. A
    // preview must leave the screen looking untouched.
    //
    // Review C-2: this is returned BEFORE the isEmpty guard below.
    //
    // Order matters and it is the second half of the same defect: with the
    // guard first, a read-only run that genuinely had nothing to preview and
    // one that had plenty were indistinguishable, because the empty lists sent
    // both down the `nothingToDo()` path. The preview now decides first, and
    // `hasPreview` is false when both counts are zero -- so a read-only run
    // with nothing to show still reports "nothing to do" through the message,
    // without a misleading "0 would have been filed".
    if (isReadOnly) {
      logger.i('[F38] read-only preview: would delete ${toDelete.length}, '
          'would move ${toMoveSafe.length}');
      // F248 / Q4 (Sprint 76): successful and preview outcomes are logged
      // too, not only failures -- otherwise a rule's real reach is invisible.
      unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindInfo,
        context: 'F38/re-process',
        detail: 'read-only preview: would delete ${toDelete.length}, would '
            'move ${toMoveSafe.length} (no mailbox change)',
      ));
      return ReProcessOutcome.readOnly(
        wouldHaveDeleted: toDelete.length,
        wouldHaveMoved: toMoveSafe.length,
      );
    }

    if (toDelete.isEmpty && toMoveSafe.isEmpty) {
      logger.i('[F38] No emails need IMAP re-processing');
      unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindInfo,
        context: 'F38/re-process',
        detail: 'nothing to act on (mode ${effectiveMode.name})',
      ));
      return const ReProcessOutcome.nothingToDo();
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
    logger.i(
        '[F38] Re-processing ${toDelete.length} deletes, ${toMoveSafe.length} safe sender moves');

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

    // F212 R-3 (Sprint 70): acquire the scan lease BEFORE opening a session.
    //
    // This path used to bypass `ScanCoordinator` entirely -- `email_scanner
    // .dart:170` was the only acquisition site in the app. So a background
    // scan holding an IMAP session and a user tapping "add rule" opened TWO
    // sessions to the same account, which is exactly the per-account session
    // cap failure F175 was built to prevent (Sprint 61: four stacked AOL
    // scans).
    //
    // This was the card's leading hypothesis (R-2) for the 100% failure. It
    // was NOT the cause -- that was the adapter contract divergence fixed in
    // `generic_imap_adapter.dart` -- but the bypass is real and worth closing
    // on its own merits, so it is fixed here rather than left because the
    // hypothesis missed.
    //
    // The user now waits behind an active scan. R-3 calls for the same
    // "waiting" signal the scanner shows; the re-processing banner already
    // renders while this runs, so the wait is visible rather than silent.
    ScanLease? lease;
    InteractiveScanClaim? claim;
    ScanAccountBusyException? busy;

    try {
      lease = await ScanCoordinator.instance.acquire(
        scanType: 'reprocess',
        accountId: widget.accountId,
      );
      // Harold Q1 (Sprint 74): a live claim row BEFORE connecting, so a
      // background scan (another isolate or process) sees this account is
      // busy and yields instead of opening a second session.
      // Harold Q4 (Sprint 74 MV): taken through the per-account scan lock;
      // if another scan holds the account, this throws and NOTHING connects.
      claim = await ScanResultStore(DatabaseHelper())
          .claimInteractive(widget.accountId);

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
          throw Exception(
              'No credentials found for account ${widget.accountId}');
        }
        await platform.loadCredentials(credentials);
      }

      final settingsStore = SettingsStore();

      // Execute delete actions
      if (toDelete.isNotEmpty) {
        // F202 (Sprint 74): account -> provider default, same resolver as
        // the scanner. LIVE-DELETION PATH: this decides where real mail goes.
        final deletedRuleFolder =
            await settingsStore.getEffectiveDeletedRuleFolder(widget.accountId);
        if (deletedRuleFolder != null) {
          platform.setDeletedRuleFolder(deletedRuleFolder);
        }

        // Copilot review (PR #418): the marking loop below must test THIS
        // batch's failures, not the cumulative set. Hoisted so the loop can
        // see it after the try/catch.
        var deleteFailedIds = <String>{};
        try {
          final result =
              await platform.takeActionBatch(toDelete, FilterAction.delete);
          successCount += result.successCount;
          failCount += result.failureCount;
          deleteFailedIds = result.failedIds.keys.toSet();
          // F212 R-4: record WHICH emails failed, so the progress footer can
          // stop calling them "addressed". The batch result reports failures
          // per id; map them back to the keys the footer counts.
          _recordBatchFailures(toDelete, result.failedIds.keys.toSet());
          logger.i(
              '[F38] Delete batch: ${result.successCount} succeeded, ${result.failureCount} failed');
          _logReProcessFailureReasons('delete', result.failedIds);
        } catch (e) {
          logger.e('[F38] Delete batch failed: $e');
          // F233 (Sprint 72): this is the SERVER_REFUSED shape -- the batch ran
          // and threw -- as distinct from the adapter's NOT_CONNECTED guard.
          // Telling them apart is what F232 needed and could not get.
          unawaited(DiagnosticLogger.failure(
            context: 'F38/delete-batch',
            kind: DiagnosticLogger.kindServerRefused,
            reason: 'batch threw: $e',
            attempted: toDelete.length,
            failed: toDelete.length,
          ));
          failCount += toDelete.length;
          // A throw means the WHOLE batch failed -- none of it was addressed.
          deleteFailedIds = toDelete.map((m) => m.id).toSet();
          _recordBatchFailures(toDelete, deleteFailedIds);
        }

        // Mark as re-processed and update banner.
        // H-2 (code review, Sprint 70): SKIP the keys that failed. This loop
        // used to be unconditional, which immediately re-added every key
        // `_recordBatchFailures` had just removed -- defeating its whole
        // purpose and leaving a failed email permanently unretryable, because
        // `_reProcessAffectedEmails` skips anything in this set. The bug was
        // invisible on the total-failure path (the outer catch runs after this
        // loop) and only bit the COMMON partial-failure case.
        for (final email in toDelete) {
          if (deleteFailedIds.contains(email.id)) continue;
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
        // F202 (Sprint 74): account -> provider -> overall, as in the scanner.
        final targetFolder =
            await settingsStore.getEffectiveSafeSenderFolder(widget.accountId);

        // Sprint 76 (0.17.5 Fold, 12:02): an email ALREADY in the target is
        // addressed with no mailbox call -- the same rule the scan uses.
        // Before, AOL "moved" it Inbox -> Inbox, acknowledged without moving,
        // and the update reported "could not be applied".
        final alreadyThere = [
          for (final m in toMoveSafe)
            if (safeSenderAlreadyInTarget(
                platformId: widget.platformId,
                messageFolderName: m.folderName,
                safeSenderTarget: targetFolder))
              m,
        ];
        final toMove = [
          for (final m in toMoveSafe)
            if (!alreadyThere.contains(m)) m,
        ];
        if (alreadyThere.isNotEmpty) {
          successCount += alreadyThere.length;
          _recordBatchFailures(alreadyThere, const <String>{});
          logger.i('[F38] Safe sender move: ${alreadyThere.length} already in '
              '"$targetFolder", nothing to move');
        }

        var moveFailedIds = <String>{};
        if (toMove.isNotEmpty) {
        try {
          final result =
              await platform.moveToFolderBatch(toMove, targetFolder);
          successCount += result.successCount;
          failCount += result.failureCount;
          moveFailedIds = result.failedIds.keys.toSet();
          _recordBatchFailures(toMove, result.failedIds.keys.toSet());
          logger.i(
              '[F38] Safe sender move batch: ${result.successCount} succeeded, ${result.failureCount} failed');
          _logReProcessFailureReasons(
              'safe-sender move to "$targetFolder"', result.failedIds);
        } catch (e) {
          logger.e('[F38] Safe sender move batch failed: $e');
          // Sprint 76: the delete batch's sibling line -- this path wrote
          // nothing to the diagnostic log.
          unawaited(DiagnosticLogger.failure(
            context: 'F38/move-safe-batch',
            // Review LOW: a thrown batch is usually a connection error, not a
            // server refusal.
            kind: DiagnosticLogger.kindException,
            reason: 'batch threw: ${DiagnosticLogger.describeError(e)}',
            attempted: toMove.length,
            failed: toMove.length,
          ));
          failCount += toMove.length;
          moveFailedIds = toMove.map((m) => m.id).toSet();
          _recordBatchFailures(toMove, moveFailedIds);
        }
        }

        // Mark as re-processed and update banner.
        // H-2: skip failed keys -- see the delete block above.
        for (final email in toMoveSafe) {
          if (moveFailedIds.contains(email.id)) continue;
          _reProcessedEmailKeys.add(_getEmailKey(email));
        }
        if (mounted) {
          setState(() {
            _reProcessCompleted += toMoveSafe.length;
          });
        }
      }
    } on ScanAccountBusyException catch (e) {
      // Harold Q4 (Sprint 74 MV): refused before connecting. The rule or safe
      // sender is already saved; only the mailbox action waits for a scan.
      logger.i('[F38] Re-processing NOT started: $e');
      busy = e;
    } catch (e) {
      logger.e('[F38] Re-processing failed: $e');
      // F233: the line Sprint 71 needed and could not read. An exception HERE
      // fails the whole batch even though per-email work may already have
      // succeeded, which is the F228 contradiction.
      unawaited(DiagnosticLogger.failure(
        context: 'F38/re-process',
        kind: DiagnosticLogger.kindException,
        reason: 'whole-batch failure before or during execution: $e',
        attempted: toDelete.length + toMoveSafe.length,
        failed: toDelete.length + toMoveSafe.length,
      ));
      failCount = toDelete.length + toMoveSafe.length;
      // F212 R-4: this is the path that produced Harold's 6-of-6 / 8-of-8.
      // An exception here (e.g. AuthenticationException from loadCredentials)
      // fails the ENTIRE batch, so nothing in it was addressed.
      final allAttempted = [...toDelete, ...toMoveSafe];
      _recordBatchFailures(
        allAttempted,
        allAttempted.map((m) => m.id).toSet(),
      );
    } finally {
      // Close platform connection
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (e) {
          logger.w('[F38] Failed to disconnect platform: $e');
        }
      }
      // F212 R-3: release on EVERY path, including the throw. A lease leaked
      // here would wedge every later scan behind work that already finished --
      // the same process-global wedge F220 fixed for the scan screen.
      // The claim ends on every path, like the lease -- and BEFORE the lease
      // is released (PR #440 review): release() hands the lease straight to
      // a queued manual scan, which would otherwise reach the account lock
      // while this claim row still exists and be refused ("a rule update is
      // already running").
      await claim?.end();
      if (lease != null) {
        ScanCoordinator.instance.release(lease);
      }
    }

    if (busy != null) {
      if (mounted) setState(() => _isReProcessing = false);
      return ReProcessOutcome.busy(busy);
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

    // F248 / Q4 (Sprint 76): the outcome of every run, success included --
    // "acted on N of N" is the evidence a block rule from a saved scan really
    // moved the mail (Sprint 76 phone checklist item 2).
    unawaited(DiagnosticLogger.log(
      kind: DiagnosticLogger.kindInfo,
      context: 'F38/re-process',
      detail: 'acted on $successCount of $total (failed $failCount): '
          'delete=${toDelete.length} moveSafe=${toMoveSafe.length} '
          'mode=${effectiveMode.name}',
    ));

    // F228 (Sprint 72): hand the outcome back so the CALLER can tell the truth.
    // This method used to return void and report only through the snackbar
    // above, which is why the per-action toast could be hardcoded green while
    // this same run knew it had failed.
    return ReProcessOutcome(
      attempted: total,
      succeeded: successCount,
      failed: failCount,
    );
  }

  /// Add sender to safe senders list
  /// Types: 'exact' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com)
  Future<void> _addSafeSender(String value, String type,
      {EmailMessage? email}) async {
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
      final classification = AuthResultsParser.classificationFromName(
          email.authClassificationOverride);
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

    // R76-4 (ADR-0047, R-6): the user's decision on the stored email, when
    // the dev-only content history is on. Best effort, never throws.
    if (email != null) {
      unawaited(ContentHistory.recordDecision(
        settings: SettingsStore(),
        accountId: widget.accountId,
        email: email,
        decision: 'safe_sender:$type',
      ));
    }

    // F21: Re-evaluate email against updated rules and refresh list
    if (email != null) {
      await _reEvaluateEmail(email);
    }

    // Re-evaluate all remaining "No rule" emails against the new safe sender
    // ONLY (F120 delta -- full-set re-eval froze the UI 1-2 min per action).
    final preStats = _computeNoRuleStats();
    await _reEvaluateNoRuleEmails(
        deltaSafeSenderPattern: result.createdSafeSenderPattern);
    final postStats = _computeNoRuleStats();

    // Sprint 38 Round 4 (2026-05-17): advance the oldest-unaddressed-no-rule
    // UID cursor per folder so the next IMAP scan resumes from the
    // remaining backlog (or clears the cursor and falls back to daysBack
    // if all are addressed). Non-IMAP rows are skipped inside the helper.
    await _updateOldestNoRuleCursorsFromResults();

    // F38: Execute IMAP actions for affected emails
    final reProcessOutcome = await _reProcessAffectedEmails();

    if (mounted) {
      setState(() {}); // Refresh list to show updated rule assignment
      // Sprint 38 F82 (Issue #252): append "N removed, M remaining" so the
      // user sees concrete progress against the no-rules pool.
      final removedNow = preStats.remaining - postStats.remaining;
      final remaining = postStats.remaining;
      final progressSuffix = removedNow > 0
          ? ' -- $removedNow removed, $remaining "No rule" remaining'
          : (remaining > 0 ? ' -- $remaining "No rule" remaining' : '');
      _showActionOutcome(
        baseMessage: result.displayMessage,
        progressSuffix: progressSuffix,
        outcome: reProcessOutcome,
        successColor: Colors.green,
      );
    }
  }

  /// Create a block rule (persists to database and YAML)
  /// Types: 'from' (email), 'exactDomain' (@subdomain.domain.com), 'entireDomain' (@*.domain.com), 'subject'
  Future<void> _createBlockRule(String type, String value,
      {EmailMessage? email}) async {
    final ruleProvider = Provider.of<RuleSetProvider>(context, listen: false);
    final logger = Logger();

    // F39 (Sprint 46): rule-persistence core is shared with the
    // cross-account "No rule" review screen via RuleQuickActionService.
    final service = RuleQuickActionService(ruleProvider: ruleProvider);
    final senderEmailForConflictCheck = type != 'subject' && email != null
        ? EmailBodyParser().extractEmailAddress(email.from).toLowerCase().trim()
        : null;
    // Sprint 74 MV (Harold): a subject rule tapped from a saved scan never
    // reached the database, and nothing recorded whether the tap arrived.
    // These lines make the next occurrence settle it. Type and error CLASS
    // only -- the diagnostic log records no message content, and the value
    // is a subject, address or domain.
    unawaited(DiagnosticLogger.failure(
      context: 'rule-create',
      kind: DiagnosticLogger.kindInfo,
      reason: 'block rule requested (type: $type)',
    ));
    final result = await service.createBlockRule(
      type: type,
      value: value,
      senderEmailForConflictCheck: senderEmailForConflictCheck,
    );
    unawaited(DiagnosticLogger.failure(
      context: 'rule-create',
      kind: result.success
          ? DiagnosticLogger.kindInfo
          : DiagnosticLogger.kindException,
      reason: result.success
          ? 'block rule saved (type: $type'
              '${result.alreadyExisted ? ', already existed' : ''})'
          : 'block rule NOT saved (type: $type, '
              'error: ${result.error?.runtimeType ?? 'rejected'})',
    ));

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

    // R76-4 (ADR-0047, R-6): see _addSafeSender.
    if (email != null) {
      unawaited(ContentHistory.recordDecision(
        settings: SettingsStore(),
        accountId: widget.accountId,
        email: email,
        decision: 'block:$type',
      ));
    }

    // F21: Re-evaluate email against updated rules and refresh list
    if (email != null) {
      await _reEvaluateEmail(email);
    }

    // Re-evaluate all remaining "No rule" emails against the new rule ONLY
    // (F120 delta -- full-set re-eval froze the UI 1-2 min per action).
    final preStats = _computeNoRuleStats();
    await _reEvaluateNoRuleEmails(deltaRule: result.createdRule);
    final postStats = _computeNoRuleStats();

    // Sprint 38 Round 4 (2026-05-17): advance the oldest-unaddressed-no-rule
    // UID cursor per folder so the next IMAP scan resumes from the
    // remaining backlog. See companion call site in safe-sender-add
    // handler above.
    await _updateOldestNoRuleCursorsFromResults();

    // F38: Execute IMAP actions for affected emails
    final reProcessOutcome = await _reProcessAffectedEmails();

    if (mounted) {
      setState(() {}); // Refresh list to show updated rule assignment
      // Sprint 38 F82 (Issue #252): append "N removed, M remaining" so the
      // user sees concrete progress against the no-rules pool.
      final removedNow = preStats.remaining - postStats.remaining;
      final remaining = postStats.remaining;
      final progressSuffix = removedNow > 0
          ? ' -- $removedNow removed, $remaining "No rule" remaining'
          : (remaining > 0 ? ' -- $remaining "No rule" remaining' : '');
      _showActionOutcome(
        baseMessage: result.displayMessage,
        progressSuffix: progressSuffix,
        outcome: reProcessOutcome,
        successColor: Colors.blue,
      );
    }
  }

}
