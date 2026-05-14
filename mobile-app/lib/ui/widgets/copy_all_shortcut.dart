/// Sprint 38 F84 Sub-task A (Issue #253): keyboard shortcut for "copy ALL
/// rows in a filtered list to clipboard".
///
/// Default Flutter behavior on a `ListView.builder` + `SelectionArea`:
/// Ctrl+A selects only items currently RENDERED in the viewport. Items
/// below the visible region are not built and are skipped from selection.
/// Users who want to copy the full filtered list out (e.g., to paste into
/// a support ticket, share rule lists, or audit safe-sender entries) have
/// to scroll through the entire list while holding the selection -- which
/// does not work either.
///
/// This widget wraps any list screen, intercepts Ctrl+A (Windows/Linux) or
/// Cmd+A (macOS), reads the caller-provided in-memory list of strings, and
/// writes the joined text directly to the clipboard. Bypasses Flutter's
/// selection model entirely. The caller passes a `rowTextBuilder` that
/// returns the user-visible text per row (typically title + subtitle).
///
/// Sub-tasks B (Shift+Click extend) and C (Ctrl+Click-drag disjoint) from
/// Issue #253 are deferred to a follow-up sprint -- they require
/// significantly more state tracking and a more invasive list-row
/// refactor. Sub-task A solves the most-common user pain (no way to get
/// the full list) without that complexity.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyAllShortcut extends StatelessWidget {
  /// Builds the per-row text that gets joined for the clipboard. Called
  /// when the user hits Ctrl+A / Cmd+A. Must return the visible row text
  /// (typically `"$title\t$subtitle"` or similar). Returning an empty
  /// string skips that row.
  final String Function() textBuilder;

  /// Optional label for the snackbar that confirms the copy. Example:
  /// "rules" -> "Copied 47 rules to clipboard". Defaults to "rows".
  final String itemLabel;

  /// The list screen to wrap.
  final Widget child;

  const CopyAllShortcut({
    super.key,
    required this.textBuilder,
    required this.child,
    this.itemLabel = 'rows',
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Single binding works for both Ctrl+A (Windows/Linux) and
        // Cmd+A (macOS) thanks to SingleActivator's control/meta semantics.
        // We register both modifiers; CallbackShortcuts dispatches on
        // either match.
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            () => _copyAllToClipboard(context),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            () => _copyAllToClipboard(context),
      },
      // Focus must be in the subtree for shortcuts to fire. Wrapping in
      // a Focus widget with autofocus=true ensures the screen has focus
      // on entry.
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  Future<void> _copyAllToClipboard(BuildContext context) async {
    final text = textBuilder();
    if (text.isEmpty) {
      // Nothing to copy; do nothing (silent no-op rather than confusing
      // "0 rows copied" snackbar).
      return;
    }

    final rowCount = '\n'.allMatches(text).length + 1;
    await Clipboard.setData(ClipboardData(text: text));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $rowCount $itemLabel to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
