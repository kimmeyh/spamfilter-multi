/// Sprint 39 S38-CI-3 (= F84 Sub-tasks B + C, Issue #253): desktop
/// multi-region row-selection model shared by the Manage Rules and Manage
/// Safe Senders list screens.
///
/// Sub-task A (Sprint 38, `copy_all_shortcut.dart`) added Ctrl+A / Cmd+A
/// "copy the entire filtered list to clipboard". It deliberately bypassed
/// Flutter's selection model -- it never introduced a per-row selection
/// concept. Sub-tasks B and C DO require a per-row selection concept, so
/// this controller adds one:
///
///   - Sub-task B -- Shift+LeftClick "extend selection to here":
///     preserve the existing selection's start anchor and update its end
///     to the clicked row (Windows Explorer / macOS Finder standard). A
///     plain click resets the anchor to the clicked row.
///   - Sub-task C -- Ctrl+LeftClick (and Ctrl+LeftClick-and-drag) "add a
///     disjoint selection range": toggle / add rows to the selection set
///     without clearing the prior selection (Windows-standard
///     non-contiguous select).
///
/// Cross-platform key mapping mirrors `copy_all_shortcut.dart`:
///   - Windows / Linux: Control is the "command" modifier.
///   - macOS: Meta (Cmd) is the "command" modifier.
/// Shift is the "range" modifier on every platform.
///
/// The controller is a mixin on a [State] so each screen owns its own
/// selection state but shares the exact same gesture semantics. Indices
/// are positions into the screen's *filtered* list -- the same list the
/// screen renders and that Ctrl+A copies. Any filter / search / reload
/// that rebuilds the filtered list must call [clearRowSelection] so the
/// indices do not point at stale rows.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Mixin providing Windows-standard multi-region row selection to a list
/// screen's [State]. The host screen is responsible for:
///   1. Calling [handleRowTap] / [handleRowDragStart] / [handleRowDragTo]
///      from the row gesture handlers.
///   2. Reading [isRowSelected] to paint the selected highlight.
///   3. Calling [clearRowSelection] whenever the filtered list changes
///      (search, filter chip toggle, reload, delete).
mixin ListSelectionController<T extends StatefulWidget> on State<T> {
  /// Indices (into the filtered list) that are currently selected.
  final Set<int> _selectedIndices = <int>{};

  /// The anchor row for Shift+Click range extension. Null when there is no
  /// selection. A plain click and a Ctrl+Click both move the anchor; a
  /// Shift+Click preserves it.
  int? _anchorIndex;

  /// Drag bookkeeping for Sub-task C (Ctrl+Click-and-drag). When a
  /// Ctrl-drag starts we remember the row it started on; each row the
  /// pointer enters during the drag is unioned into the selection.
  int? _dragStartIndex;
  bool _dragIsAdditive = false;

  /// True when at least one row is selected. Screens use this to decide
  /// whether Ctrl+A should copy the SELECTION or the whole filtered list.
  bool get hasRowSelection => _selectedIndices.isNotEmpty;

  /// Unmodifiable view of the selected indices (sorted ascending). Useful
  /// for building the clipboard payload from a selection.
  List<int> get selectedRowIndices {
    final sorted = _selectedIndices.toList()..sort();
    return List.unmodifiable(sorted);
  }

  /// Whether [index] is currently part of the selection.
  bool isRowSelected(int index) => _selectedIndices.contains(index);

  /// Clears all selection state. Call this whenever the filtered list is
  /// rebuilt (search/filter/reload/delete) so indices cannot go stale.
  /// Does NOT call [setState]; callers that need a repaint should wrap or
  /// follow with their own setState (most call sites already setState for
  /// the filter change itself).
  void clearRowSelection() {
    _selectedIndices.clear();
    _anchorIndex = null;
    _dragStartIndex = null;
    _dragIsAdditive = false;
  }

  // ---- Modifier detection (cross-platform) --------------------------------

  /// True when the platform "command" modifier (Ctrl on Windows/Linux,
  /// Cmd/Meta on macOS) is held. We accept EITHER physical modifier on
  /// EITHER platform so a Linux keyboard on a Mac (or vice versa) still
  /// works -- this matches the both-modifiers-registered approach in
  /// `copy_all_shortcut.dart`.
  bool _isCommandModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  // ---- Tap handling (Sub-tasks B + C) -------------------------------------

  /// Handle a left-click on row [index]. Reads the live keyboard modifier
  /// state to decide between plain / Shift / Ctrl(Cmd) behavior. Calls
  /// [setState] so the host repaints the new highlight.
  ///
  /// [itemCount] is the length of the filtered list; range extension is
  /// clamped to `[0, itemCount)` so a stale index never selects past the
  /// end.
  void handleRowTap(int index, int itemCount) {
    if (index < 0 || index >= itemCount) return;
    final command = _isCommandModifierPressed();
    final shift = _isShiftModifierPressed();

    setState(() {
      if (shift && _anchorIndex != null) {
        // Sub-task B: extend the selection from the preserved anchor to
        // the clicked row. Shift+Ctrl UNIONS the new range onto the
        // existing disjoint selection (Windows-standard); plain Shift
        // replaces the selection with just the anchor..index range.
        if (!command) {
          _selectedIndices.clear();
        }
        final start = _anchorIndex! < index ? _anchorIndex! : index;
        final end = _anchorIndex! < index ? index : _anchorIndex!;
        for (var i = start; i <= end; i++) {
          if (i >= 0 && i < itemCount) _selectedIndices.add(i);
        }
        // Anchor is intentionally NOT moved on a Shift+Click so the user
        // can re-extend from the same origin (Windows behavior).
      } else if (command) {
        // Sub-task C (click form): toggle this row in/out of the
        // selection WITHOUT clearing the prior selection -- non-contiguous
        // select. Moves the anchor to the clicked row so a subsequent
        // Shift+Click extends from here.
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
        _anchorIndex = index;
      } else {
        // Plain click: reset to a single-row selection and move the anchor.
        _selectedIndices
          ..clear()
          ..add(index);
        _anchorIndex = index;
      }
    });
  }

  // ---- Drag handling (Sub-task C: Ctrl+Click-and-drag) --------------------

  /// Begin a potential Ctrl-drag on row [index]. Only Ctrl/Cmd-drags add a
  /// disjoint range; a plain drag is left to the underlying SelectionArea
  /// (text selection). Returns true when this drag is an additive
  /// row-selection drag (so the host can decide whether to claim the
  /// gesture).
  bool handleRowDragStart(int index, int itemCount) {
    if (index < 0 || index >= itemCount) return false;
    if (!_isCommandModifierPressed()) {
      _dragStartIndex = null;
      _dragIsAdditive = false;
      return false;
    }
    _dragStartIndex = index;
    _dragIsAdditive = true;
    // Seed the selection with the start row immediately so a Ctrl-press-
    // and-release-without-move still adds it (matches handleRowTap toggle
    // semantics for the simple case, but a drag is always additive -- it
    // never removes).
    setState(() {
      _selectedIndices.add(index);
      _anchorIndex = index;
    });
    return true;
  }

  /// Continue an additive Ctrl-drag, extending the swept range to row
  /// [index]. No-op when the current drag is not additive (plain drag).
  void handleRowDragTo(int index, int itemCount) {
    if (!_dragIsAdditive || _dragStartIndex == null) return;
    if (index < 0 || index >= itemCount) return;
    final start = _dragStartIndex! < index ? _dragStartIndex! : index;
    final end = _dragStartIndex! < index ? index : _dragStartIndex!;
    setState(() {
      for (var i = start; i <= end; i++) {
        if (i >= 0 && i < itemCount) _selectedIndices.add(i);
      }
      _anchorIndex = index;
    });
  }

  /// End the current drag (additive or not).
  void handleRowDragEnd() {
    _dragStartIndex = null;
    _dragIsAdditive = false;
  }
}
