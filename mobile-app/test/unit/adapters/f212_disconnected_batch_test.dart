/// F212 (Sprint 70): re-processing after adding rules fails 100%.
///
/// **AC-1 required the actual exception before any fix. This is it, and the
/// card's leading hypothesis (R-2) was NOT the cause.**
///
/// R-2 proposed that the re-process path bypasses `ScanCoordinator` and so
/// opens a second IMAP session against an account that already has one. That
/// bypass is REAL -- `results_display_screen.dart` never acquires a lease,
/// while `email_scanner.dart:170` is the only acquisition site -- and it is
/// worth fixing. But it is not what produces the 100% failure.
///
/// **The actual root cause: the two adapters DISAGREE about what a missing
/// connection means, and both answers are wrong in different ways.**
///
/// Given the same condition (the batch methods called before a connection
/// exists):
///
///   - `GmailApiAdapter` returns `BatchActionResult.allFailed(...)` with
///     "Not connected. Call signIn() first."
///   - `GenericIMAPAdapter` returns `BatchActionResult.allSuccess(...)`
///
/// That single divergence explains BOTH reported symptoms from one cause:
///
///   - **Gmail/Android: 100% failure.** The whole-batch shape Harold saw
///     (6 of 6, 8 of 8) is the signature of ONE decision applied to the batch,
///     not N independent failures -- exactly what R-1 predicted the logs would
///     show.
///   - **AOL/IMAP: silent fake success.** Worse than the reported bug. The user
///     is told "Re-processed 9 emails" in a GREEN snackbar while no mail was
///     touched. Nobody filed this because it looks like success.
///
/// **Why `allSuccess` for an unconnected client is indefensible.** It claims
/// work was done that provably was not. Every caller that trusts
/// `successCount` -- the snackbar, `_reProcessedEmailKeys`, the counter in
/// AC-2 -- is then working from a fabricated number. `moveToFolderBatch` even
/// logs `client=false` as it does this, so the information was present and
/// discarded.
///
/// These tests pin the CONTRACT both adapters must share. They are written
/// against the shared `BatchActionResult` semantics rather than a live socket,
/// so they run everywhere and cannot rot into an integration test.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/models/batch_action_result.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/adapters/email_providers/spam_filter_platform.dart';

EmailMessage _msg(String id) => EmailMessage(
      id: id,
      from: 'sender@example.com',
      subject: 'subject $id',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 9, 17),
      folderName: 'INBOX',
    );

void main() {
  final messages = [_msg('1'), _msg('2'), _msg('3')];

  group('F212 AC-2: a disconnected adapter never reports fake success', () {
    test('IMAP moveToFolderBatch does NOT claim success when unconnected',
        () async {
      // THE DEFECT. Before the fix this returned allSuccess for every message
      // while _imapClient was null -- the app told the user their mail had
      // been filed and touched nothing.
      final adapter = GenericIMAPAdapter.aol();

      final result = await adapter.moveToFolderBatch(messages, 'Trash');

      expect(result.successCount, 0,
          reason: 'no connection means no work was done -- reporting success '
              'here fabricates the number the snackbar and the AC-2 counter '
              'both read');
      expect(result.failureCount, messages.length);
      expect(result.failedIds.values.first, contains('onnect'),
          reason: 'the failure must SAY it was a connection problem, or the '
              'user is told their mail failed for no stated reason');
    });

    test('IMAP takeActionBatch does NOT claim success when unconnected',
        () async {
      final adapter = GenericIMAPAdapter.aol();

      final result =
          await adapter.takeActionBatch(messages, FilterAction.delete);

      expect(result.successCount, 0);
      expect(result.failureCount, messages.length);
    });

    test('Gmail already reports failure -- this is the CORRECT behaviour',
        () async {
      // Pinned so the fix brings IMAP UP to Gmail's contract rather than
      // dragging Gmail down to IMAP's. Gmail was never the broken one; it was
      // the one telling the truth, which is why Gmail is where the bug got
      // NOTICED.
      final adapter = GmailApiAdapter();

      final result =
          await adapter.takeActionBatch(messages, FilterAction.delete);

      expect(result.successCount, 0);
      expect(result.failureCount, messages.length);
      expect(result.failedIds.values.first, contains('Not connected'));
    });

    test('BOTH adapters agree on the unconnected contract', () async {
      // The real invariant. A shared abstraction whose implementations return
      // OPPOSITE answers to the same question is the defect; the specific
      // wording is not.
      final imap = GenericIMAPAdapter.aol();
      final gmail = GmailApiAdapter();

      final imapResult =
          await imap.takeActionBatch(messages, FilterAction.delete);
      final gmailResult =
          await gmail.takeActionBatch(messages, FilterAction.delete);

      expect(imapResult.successCount, gmailResult.successCount,
          reason: 'ADR-0042: one behaviour across platforms unless a platform '
              'exception is declared. There is no exception here -- an '
              'unconnected adapter did no work on either platform.');
      expect(imapResult.failureCount, gmailResult.failureCount);
    });
  });

  group('F212: an EMPTY batch is still success, not failure', () {
    test('empty input returns an empty result on both adapters', () async {
      // The unhappy-input case that must NOT regress while fixing the above.
      // Nothing asked for means nothing failed -- if this flipped to failure,
      // the snackbar would report a spurious error whenever a re-process
      // matched no mail.
      final imap = GenericIMAPAdapter.aol();
      final gmail = GmailApiAdapter();

      final imapResult =
          await imap.moveToFolderBatch(const <EmailMessage>[], 'Trash');
      final gmailResult =
          await gmail.moveToFolderBatch(const <EmailMessage>[], 'Trash');

      for (final r in <BatchActionResult>[imapResult, gmailResult]) {
        expect(r.successCount, 0);
        expect(r.failureCount, 0);
      }
    });
  });
}
