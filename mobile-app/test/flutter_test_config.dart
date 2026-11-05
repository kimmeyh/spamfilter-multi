/// Runs once per test file, before its main().
///
/// F323 (Sprint 83): the No Rule Item pop-up reads the message body when it
/// opens (`PopupBodyFetcher`). In a widget test that would start a real scan
/// claim, a database transaction that never completes under FakeAsync, and the
/// test would hang for its full timeout. So every test file starts with the
/// fetch switched off; `f323_popup_body_fetcher_test.dart` turns it back on.
///
/// Sprint 83 7.7.1 (code-reviewer M-2): the pop-up waits
/// `emailPopupBodyReadDelay` before it reads the body. Tests run with no wait;
/// `f323_email_detail_popup_test.dart` sets it back to test the wait.
library;

import 'dart:async';

import 'package:my_email_spam_filter/core/services/popup_body_fetcher.dart';
import 'package:my_email_spam_filter/ui/widgets/email_detail_popup.dart'
    show emailPopupBodyReadDelay;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PopupBodyFetcher.debugDisabled = true;
  emailPopupBodyReadDelay = Duration.zero;
  await testMain();
}
