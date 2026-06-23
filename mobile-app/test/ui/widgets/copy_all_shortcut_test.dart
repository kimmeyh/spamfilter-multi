/// Sprint 38 F84 Sub-task A (Issue #253): widget tests for the
/// CopyAllShortcut wrapper.
///
/// Verifies:
///   1. Ctrl+A invokes the textBuilder and writes the result to clipboard
///   2. Cmd+A (macOS modifier) does the same
///   3. Empty textBuilder result is a silent no-op (no clipboard write,
///      no snackbar)
///   4. Snackbar reports the row count (split on \n + 1)
///
/// Clipboard access in `flutter test` is mocked via the test bindings.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/ui/widgets/copy_all_shortcut.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 38 F84 -- CopyAllShortcut', () {
    String? lastClipboardWrite;

    setUp(() {
      lastClipboardWrite = null;
      // Capture Clipboard.setData calls so we can assert on them.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            lastClipboardWrite = args['text'] as String?;
          }
          return null;
        },
      );
    });

    testWidgets('Ctrl+A copies textBuilder result to clipboard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyAllShortcut(
              itemLabel: 'rules',
              textBuilder: () => 'rule-1\trule-2\nrule-3\trule-4',
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      // Focus the subtree so the shortcut handler fires.
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(lastClipboardWrite, 'rule-1\trule-2\nrule-3\trule-4',
          reason:
              'Ctrl+A must invoke textBuilder and write its result verbatim to '
              'the clipboard.');
    });

    testWidgets('Cmd+A also triggers the copy (macOS-style modifier)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyAllShortcut(
              itemLabel: 'safe senders',
              textBuilder: () => 'sender-a\nsender-b',
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(lastClipboardWrite, 'sender-a\nsender-b',
          reason:
              'Cmd+A (the macOS modifier) must trigger the same handler as Ctrl+A '
              'so the shortcut works cross-platform without per-OS branching.');
    });

    testWidgets('empty textBuilder result is a silent no-op',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyAllShortcut(
              textBuilder: () => '',
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(lastClipboardWrite, isNull,
          reason:
              'When the textBuilder returns empty (filtered list has zero items), '
              'we must NOT write to clipboard and must NOT show "0 rows copied" -- '
              'silent no-op is the user-friendly behavior.');
    });

    testWidgets('snackbar shows the row count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopyAllShortcut(
              itemLabel: 'rules',
              // 3 newlines => 4 rows
              textBuilder: () => 'a\nb\nc\nd',
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(); // Pump so SnackBar shows.

      expect(find.text('Copied 4 rules to clipboard'), findsOneWidget,
          reason:
              'The snackbar count is computed from the joined text by counting '
              'newlines + 1 -- this verifies that formula stays correct.');
    });
  });
}
