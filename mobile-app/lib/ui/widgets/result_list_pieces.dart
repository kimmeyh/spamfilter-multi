/// F283 (Sprint 78): the pieces the Results screen and the Review No Rule
/// Items screen share, so the two screens look and work the same with ONE copy
/// of each piece (Sprint 52 IMP-5).
///
/// Moved here from `results_display_screen.dart`, unchanged in behavior:
/// the display order and date formats (F222), the action icon, color and
/// description, the "Showing X of Y" filter bar, the Sort and Folders chips
/// and the folder dialog, and the email row tile. The shared row model is
/// [EmailActionResult]; the Review screen converts its No Rule rows to it.
///
/// ADR-0042: shared widgets, identical on Windows and Android.
library;

import 'package:flutter/material.dart';

import '../../core/models/email_message.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/utils/pattern_normalization.dart';
import '../../core/utils/result_ordering.dart';

/// F222 (Sprint 74, reworked at Manual Validation): the display order,
/// extracted so the WIRING is testable (a test of the pure orders alone would
/// pass with the call site still sorting some other way -- the Sprint 73
/// "correct abstraction, wrong wiring" defect class).
///
/// [order] defaults to [ResultSortOrder.folderDomainAddress], the
/// pre-Sprint-74 order Harold asked to keep as the default. The folder,
/// domain and address keys are the ones the old in-place sort used
/// (`EmailBodyParser`), so the default is unchanged, not re-derived.
List<EmailActionResult> orderResultsForDisplay(
  List<EmailActionResult> results, {
  ResultSortOrder order = ResultSortOrder.folderDomainAddress,
}) {
  final parser = EmailBodyParser();
  String tieBreak(EmailActionResult r) =>
      '${r.email.from}\u0000${r.email.subject}';
  switch (order) {
    case ResultSortOrder.folderDomainAddress:
      return orderByFolderDomainAddress<EmailActionResult>(
        results,
        folderOf: (r) => r.email.folderName,
        domainOf: (r) => parser.extractDomainFromEmail(r.email.from) ?? '',
        addressOf: (r) => parser.extractEmailAddress(r.email.from),
        tieBreak: tieBreak,
      );
    case ResultSortOrder.newestFirst:
      return orderNewestFirst<EmailActionResult>(
        results,
        receivedAt: (r) => r.email.receivedDate,
        tieBreak: tieBreak,
      );
  }
}

/// F222 (Sprint 74 MV, Harold): the received date and time on the
/// assign-a-rule pop-up. Local time, to the minute ("2026-09-26 22:05").
String formatReceivedDateForDisplay(DateTime receivedDate) =>
    receivedDate.toLocal().toString().substring(0, 16);

/// F222 (Sprint 74 MV round 2, Harold): the Scan Results ROW shows the date
/// only -- *"do not need time displayed on the results screen, only date is
/// needed (Ok to keep time on the assign rule pop-up)"*. Derived from
/// [formatReceivedDateForDisplay], so the row's date is always the pop-up's
/// date ("2026-09-26").
String formatReceivedDayForRow(DateTime receivedDate) =>
    formatReceivedDateForDisplay(receivedDate).substring(0, 10);

/// Item 8 (Ctrl-F search): whether a row matches the search [query]. Matches
/// sender, subject, folder and the rule name ([ruleName]; empty on Review,
/// where every row is "No rule"). [query] must already be lower case.
bool resultMatchesSearch(
    EmailActionResult result, String ruleName, String query) {
  return result.email.from.toLowerCase().contains(query) ||
      result.email.subject.toLowerCase().contains(query) ||
      result.email.folderName.toLowerCase().contains(query) ||
      ruleName.toLowerCase().contains(query);
}

/// The icon for an action type, on the row and in the pop-up.
Widget resultActionIcon(EmailActionType action) {
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

/// The color for an action type (the pop-up's action badge).
Color resultActionColor(EmailActionType action) {
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

/// The pop-up's action badge text.
String resultActionDescription(EmailActionResult result) {
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

/// "Showing X of Y emails" with a clear (X) button, shown while a filter is
/// active.
class ResultFilterStatusBar extends StatelessWidget {
  const ResultFilterStatusBar({
    super.key,
    required this.filteredCount,
    required this.totalCount,
    required this.onClear,
  });

  final int filteredCount;
  final int totalCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
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
              // PR #335 cowork review: the old "Tap chip again" instruction
              // described the removed stat chips; the dropdown has no
              // toggle-off, so the X is the clear affordance.
              'Showing $filteredCount of $totalCount emails • Tap X to clear filters',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: onClear,
            tooltip: 'Clear filter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// The indigo chip style the Folders, Sort and (on Review) account chips
/// share. [active] marks a non-default choice with a darker face and a border.
Chip _indigoChip({
  Key? key,
  required String label,
  required IconData icon,
  required bool active,
}) {
  return Chip(
    key: key,
    label: Text(label),
    avatar: Icon(icon, size: 18),
    backgroundColor: active ? Colors.indigo.withValues(alpha: 0.7) : Colors.indigo,
    labelStyle: TextStyle(
      color: Colors.white,
      fontWeight: active ? FontWeight.w900 : FontWeight.bold,
    ),
    side: active
        ? const BorderSide(color: Colors.black, width: 2)
        : BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );
}

/// F222 (Sprint 74 MV, Harold): switches the list between the default
/// order (folder, domain, address) and newest first. One tap toggles. The
/// "from email providers" group stays at the top in both orders.
class ResultSortChip extends StatelessWidget {
  const ResultSortChip({
    super.key,
    required this.order,
    required this.onToggle,
  });

  final ResultSortOrder order;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isNewest = order == ResultSortOrder.newestFirst;
    final label = isNewest ? 'Sort: Newest first' : 'Sort: Folder';
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: label,
      hint: isNewest
          ? 'Switch to folder, domain and address order'
          : 'Switch to newest first',
      onTap: onToggle,
      child: Tooltip(
        message: isNewest
            ? 'Newest first. Tap for folder, domain, address.'
            : 'Folder, then domain, then address. Tap for newest first.',
        child: GestureDetector(
          onTap: onToggle,
          child: _indigoChip(
            key: const Key('results_sort_chip'),
            label: label,
            icon: Icons.sort,
            active: isNewest,
          ),
        ),
      ),
    );
  }
}

/// Item 6: the Folders chip and its multi-select dialog. An empty
/// [selected] set means all folders.
///
/// F283 / F284 R-1 (Sprint 78): carries button semantics like the Sort chip,
/// so a screen reader announces a button and UI automation can invoke it
/// without the mouse. No visual change.
class FolderFilterChip extends StatelessWidget {
  const FolderFilterChip({
    super.key,
    required this.folders,
    required this.selected,
    required this.onChanged,
  });

  final List<String> folders;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _FolderSelectionDialog(
        folders: folders,
        initial: selected,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        selected.isEmpty ? 'Folders: All' : 'Folders: ${selected.length}';
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: label,
      hint: 'Choose which folders to show',
      onTap: () => _open(context),
      child: GestureDetector(
        onTap: () => _open(context),
        child: _indigoChip(
          label: label,
          icon: Icons.folder,
          active: selected.isNotEmpty,
        ),
      ),
    );
  }
}

class _FolderSelectionDialog extends StatefulWidget {
  const _FolderSelectionDialog({required this.folders, required this.initial});

  final List<String> folders;
  final Set<String> initial;

  @override
  State<_FolderSelectionDialog> createState() => _FolderSelectionDialogState();
}

class _FolderSelectionDialogState extends State<_FolderSelectionDialog> {
  late final Set<String> _temp = Set<String>.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Folders'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            CheckboxListTile(
              title: const Text('All Folders',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              value: _temp.isEmpty,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) _temp.clear();
                });
              },
            ),
            const Divider(),
            ...widget.folders.map((folder) {
              return CheckboxListTile(
                title: Text(folder),
                value: _temp.contains(folder),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _temp.add(folder);
                    } else {
                      _temp.remove(folder);
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
          onPressed: () => Navigator.pop(context, _temp),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Issue #47 / F222: one email row -- sender as the title, then
/// "folder • date • subject • rule". [onTap] receives the row's key, which
/// the pop-up uses to place itself next to the row.
///
/// [accountLabel] (F283): the Review screen lists several accounts, so it
/// names the row's account above the sender. Results (one account) passes
/// null.
class EmailResultTile extends StatelessWidget {
  const EmailResultTile({
    super.key,
    required this.result,
    required this.ruleName,
    required this.onTap,
    this.accountLabel,
  });

  final EmailActionResult result;

  /// The matched rule, or empty for "No rule".
  final String ruleName;
  final void Function(GlobalKey tileKey) onTap;
  final String? accountLabel;

  @override
  Widget build(BuildContext context) {
    // Decode Punycode domains for display.
    final decodedFrom =
        PatternNormalization.normalizeAndDecodeEmail(result.email.from);
    final title = decodedFrom.isNotEmpty ? decodedFrom : 'Unknown sender';
    final folder = result.email.folderName;
    // Clean subject for display (remove tabs, extra spaces, repeated
    // punctuation).
    final cleanedSubject =
        PatternNormalization.cleanSubjectForDisplay(result.email.subject);
    final subject = cleanedSubject.isNotEmpty ? cleanedSubject : 'No subject';
    final rule = ruleName.isNotEmpty ? ruleName : 'No rule';
    // F222 (Sprint 74 MV, Harold): the received date, before the subject so a
    // long subject cannot push it off the line.
    final date = formatReceivedDayForRow(result.email.receivedDate);
    final subtitle = '$folder • $date • $subject • $rule';
    final trailing = result.success
        ? const Icon(Icons.check, color: Colors.green)
        : const Icon(Icons.error, color: Colors.red);

    // Issue 6: a key on the row so the pop-up can be placed beside it.
    final tileKey = GlobalKey();
    final label = accountLabel;

    return Container(
      key: tileKey,
      child: ListTile(
        leading: resultActionIcon(result.action),
        title: label == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(title),
                ],
              ),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: () => onTap(tileKey),
      ),
    );
  }
}

/// The key used to look up an email's session overrides and identity on a
/// results list.
String resultEmailKey(EmailMessage email) =>
    '${email.from}|${email.subject}|${email.receivedDate.toIso8601String()}';
