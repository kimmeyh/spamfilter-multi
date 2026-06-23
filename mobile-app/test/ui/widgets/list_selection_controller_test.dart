/// Sprint 39 S38-CI-3 (= F84 Sub-tasks B + C, Issue #253): widget tests for
/// the multi-region row-selection model shared by the Manage Rules and
/// Manage Safe Senders screens (`list_selection_controller.dart`).
///
/// WHY this tests the mixin via a minimal harness instead of pumping the
/// real screens: `RulesManagementScreen` / `SafeSendersManagementScreen`
/// call `_loadRules` / `_loadSafeSenders` from `initState`, which opens a
/// sqflite database. In `flutter test` that path deadlocks against the
/// FakeAsync clock (Sprint 37 round 1 dropped screen-level widget tests
/// for exactly this reason). The selection BEHAVIOR under test lives
/// entirely in the mixin and has no database dependency, so we mount the
/// mixin on a tiny harness with injected in-memory rows. This exercises
/// the identical Shift+Click / Ctrl+Click(+drag) code path both screens
/// use, with zero database I/O and no hang.
///
/// Covered:
///   1. Plain click selects exactly one row (and resets the anchor).
///   2. Shift+Click extends the selection from the anchor (Sub-task B),
///      forward and backward, preserving the anchor.
///   3. Ctrl+Click adds a disjoint row without clearing the prior
///      selection, and toggles a selected row off (Sub-task C, click form).
///   4. Ctrl+Click-and-drag adds a swept range without clearing prior
///      selection (Sub-task C, drag form).
///   5. Cmd (Meta) is the macOS equivalent of Ctrl (cross-platform map).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/widgets/list_selection_controller.dart';

/// Minimal host widget that mixes in [ListSelectionController] and renders
/// [itemCount] tappable rows, mirroring how the real screens wire the
/// gesture handlers (GestureDetector.onTap -> handleRowTap; onPanStart ->
/// handleRowDragStart; MouseRegion.onEnter -> handleRowDragTo).
class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness({required this.itemCount});
  final int itemCount;

  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness>
    with ListSelectionController<_SelectionHarness> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              MouseRegion(
                key: ValueKey('region-$i'),
                onEnter: (_) => handleRowDragTo(i, widget.itemCount),
                child: GestureDetector(
                  key: ValueKey('row-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => handleRowTap(i, widget.itemCount),
                  onPanStart: (_) => handleRowDragStart(i, widget.itemCount),
                  onPanEnd: (_) => handleRowDragEnd(),
                  onPanCancel: handleRowDragEnd,
                  child: Container(
                    height: 40,
                    color: isRowSelected(i) ? Colors.blue : Colors.grey,
                    child: Text('row $i'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension _HarnessFinder on WidgetTester {
  _SelectionHarnessState get controller =>
      state<_SelectionHarnessState>(find.byType(_SelectionHarness));
}

Future<void> _tapRow(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('row-$index')));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S38-CI-3 -- ListSelectionController (F84 Sub-tasks B + C)', () {
    testWidgets('plain click selects exactly one row', (tester) async {
      await tester.pumpWidget(const _SelectionHarness(itemCount: 5));

      await _tapRow(tester, 2);

      expect(tester.controller.selectedRowIndices, [2],
          reason: 'A plain click must select only the clicked row.');
      expect(tester.controller.hasRowSelection, isTrue);

      // A second plain click on a different row replaces the selection.
      await _tapRow(tester, 4);
      expect(tester.controller.selectedRowIndices, [4],
          reason:
              'A second plain click must reset the selection to the new row, '
              'not accumulate.');
    });

    testWidgets('Shift+Click extends selection from the anchor (Sub-task B)',
        (tester) async {
      await tester.pumpWidget(const _SelectionHarness(itemCount: 6));

      // Plain click sets the anchor at row 1.
      await _tapRow(tester, 1);

      // Shift+Click row 4 -> range 1..4 selected, anchor preserved at 1.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _tapRow(tester, 4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(tester.controller.selectedRowIndices, [1, 2, 3, 4],
          reason:
              'Shift+Click must extend the contiguous range from the anchor '
              '(row 1) to the clicked row (row 4).');

      // Shift+Click row 0 (BACKWARD from the same anchor) -> range 0..1.
      // The anchor must have been preserved at row 1, so the new range is
      // 0..1 and it REPLACES the prior range (plain Shift = replace).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _tapRow(tester, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(tester.controller.selectedRowIndices, [0, 1],
          reason:
              'A backward Shift+Click must re-extend from the SAME preserved '
              'anchor (row 1), proving the anchor was not moved by the prior '
              'Shift+Click.');
    });

    testWidgets(
        'Ctrl+Click adds disjoint row without clearing, and toggles off '
        '(Sub-task C)', (tester) async {
      await tester.pumpWidget(const _SelectionHarness(itemCount: 6));

      await _tapRow(tester, 1);

      // Ctrl+Click row 4 -> {1, 4} (disjoint, prior selection preserved).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _tapRow(tester, 4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(tester.controller.selectedRowIndices, [1, 4],
          reason:
              'Ctrl+Click must ADD a disjoint row without clearing the prior '
              'selection (non-contiguous select).');

      // Ctrl+Click row 1 again -> toggles it OFF, leaving {4}.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _tapRow(tester, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(tester.controller.selectedRowIndices, [4],
          reason:
              'Ctrl+Click on an already-selected row must toggle it OFF, '
              'leaving the rest of the disjoint selection intact.');
    });

    testWidgets('Ctrl+Click-and-drag adds a swept range (Sub-task C, drag)',
        (tester) async {
      await tester.pumpWidget(const _SelectionHarness(itemCount: 8));

      // Establish a prior selection at row 0 with a plain click.
      await _tapRow(tester, 0);
      expect(tester.controller.selectedRowIndices, [0]);

      // Hold Ctrl and drag from row 3 across rows 4 and 5. We simulate the
      // drag by starting the gesture on row 3 (handleRowDragStart) then
      // driving MouseRegion.onEnter for rows 4 and 5 (handleRowDragTo), the
      // exact wiring the screens use.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final state = tester.controller;
      state.handleRowDragStart(3, 8);
      state.handleRowDragTo(4, 8);
      state.handleRowDragTo(5, 8);
      state.handleRowDragEnd();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(tester.controller.selectedRowIndices, [0, 3, 4, 5],
          reason:
              'A Ctrl-drag from row 3 through row 5 must ADD the swept range '
              '{3,4,5} to the existing disjoint selection {0} without '
              'clearing it.');
    });

    testWidgets('Cmd (Meta) behaves like Ctrl on macOS (cross-platform map)',
        (tester) async {
      await tester.pumpWidget(const _SelectionHarness(itemCount: 6));

      await _tapRow(tester, 0);

      // Cmd+Click row 3 -> disjoint add {0, 3}, same as Ctrl on Win/Linux.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await _tapRow(tester, 3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(tester.controller.selectedRowIndices, [0, 3],
          reason:
              'Meta (Cmd) is the macOS equivalent of Ctrl -- it must produce '
              'the same disjoint-add behavior so the gesture works '
              'cross-platform without per-OS branching.');
    });
  });
}
