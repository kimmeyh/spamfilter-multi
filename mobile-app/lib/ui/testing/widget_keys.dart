// Sprint 42, F99 -- centralized ValueKey catalog for E2E-targetable widgets.
//
// These keys give the Flutter integration_test harness stable, unambiguous
// finders (find.byKey) for the widgets its lifecycle / picker / visual tests
// drive -- independent of user-facing label text (which can change and is
// sometimes duplicated, e.g. multiple "Save" / "Delete" buttons on a screen).
//
// CONVENTION: keys are added ONLY where a test needs disambiguation that a
// stable `find.text(...)` cannot provide (duplicate labels, icon-only buttons,
// animating dialog actions). Plain unique text is still matched by text finder.
// Keep this catalog small and intentional; do not key every widget.
//
// Not test-only in the sense of being stripped: ValueKeys are harmless in
// production (they only affect the element tree identity / finders).

import 'package:flutter/widgets.dart';

class WidgetKeys {
  WidgetKeys._();

  // --- Add Block Rule / create flow (F99-c lifecycle) ---
  /// The "Save Rule" button on the manual-rule-create screen.
  static const saveRuleButton = ValueKey('e2e_save_rule_button');

  /// The "Save" action in the "Confirm Block Rule" / "Confirm Safe Sender"
  /// dialog. Distinct from saveRuleButton (which opens the dialog) and from any
  /// other "Save" on screen.
  static const confirmDialogSaveButton = ValueKey('e2e_confirm_dialog_save');
}
