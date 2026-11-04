/// F323 R-1 (Sprint 83): reads ONE message's full body for the Block Body
/// choice in the No Rule Item pop-up. It runs when the pop-up opens.
///
/// The body is never stored (SEC-14). The session follows the same rules as
/// re-processing mail from a saved scan (F212, Sprint 74): it takes the scan
/// lease and the per-account claim FIRST, so it never opens a second session
/// beside a running scan (the F175 per-account session cap). When a scan holds
/// the account, [fetch] throws and the pop-up shows "Could not read message";
/// it never blocks the pop-up and never shows an error dialog.
///
/// TEXT: read with `fetchContentText` (text/plain, else the HTML part as
/// text), not the rule-path `fetchFullBody`, which keeps text/plain only and so
/// read every HTML-only message as empty. `fetchFullBody` remains the fallback
/// for providers whose `fetchContentText` is the named no-op (demo, mock).
///
/// FAILURE: `fetchContentText` THROWS on a failed IMAP or Gmail fetch; the
/// throw reaches the caller. No text at all throws [PopupBodyUnavailable]. The
/// pop-up says "Could not read message" for both.
///
/// ADR-0042: shared Dart. Windows and Android both use it through the same
/// `SpamFilterPlatform` interface (Gmail API, IMAP).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

import '../../adapters/email_providers/email_provider.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';
import '../../adapters/storage/secure_credentials_store.dart';
import '../models/email_message.dart';
import '../storage/database_helper.dart';
import '../storage/scan_result_store.dart';
import 'scan_coordinator.dart';

/// The body could not be read, or the message has no text part.
class PopupBodyUnavailable implements Exception {
  PopupBodyUnavailable(this.why);
  final String why;
  @override
  String toString() => 'PopupBodyUnavailable($why)';
}

/// Fetches one message body. Seams are for tests; the defaults are the real
/// platform registry, credentials store, coordinator and claim.
class PopupBodyFetcher {
  PopupBodyFetcher({
    SpamFilterPlatform? Function(String platformId)? platformFactory,
    Future<Credentials?> Function(String accountId)? credentialsLoader,
    Future<ScanLease> Function(String accountId)? leaseAcquirer,
    Future<InteractiveScanClaim> Function(String accountId)? claimer,
  })  : _platformFactory = platformFactory ?? PlatformRegistry.getPlatform,
        _credentialsLoader = credentialsLoader ??
            ((id) => SecureCredentialsStore().getCredentials(id)),
        _leaseAcquirer = leaseAcquirer ??
            // The pop-up waits at most 15 seconds for a running scan, then
            // acquire() removes its queue entry and throws TimeoutException.
            ((id) => ScanCoordinator.instance.acquire(
                  scanType: 'reprocess',
                  accountId: id,
                  waitLimit: const Duration(seconds: 15),
                )),
        // 'reprocess' is deliberate: the history list never shows that scan
        // type (ScanResultStore.claimInteractive), so a body read leaves no
        // row in Scan History.
        _claimer = claimer ??
            ((id) => ScanResultStore(DatabaseHelper()).claimInteractive(id));

  final SpamFilterPlatform? Function(String platformId) _platformFactory;
  final Future<Credentials?> Function(String accountId) _credentialsLoader;
  final Future<ScanLease> Function(String accountId) _leaseAcquirer;
  final Future<InteractiveScanClaim> Function(String accountId) _claimer;

  static final Logger _logger = Logger();

  /// Test seam: when true, [fetch] throws at once, before any lease, claim or
  /// database work. `test/flutter_test_config.dart` sets it for every test file.
  /// Without it, any widget test that opens the pop-up from a screen would start
  /// a REAL scan claim (a database transaction) under FakeAsync, which never
  /// completes and hangs the test for its whole timeout (seen in Sprint 83:
  /// 10 minutes per test). The fetcher's own tests set it back to false.
  @visibleForTesting
  static bool debugDisabled = false;

  /// The full body text of [message], or throws. [message] needs the PROVIDER
  /// id and folder (IMAP: the UID and folder; Gmail: the message id).
  Future<String> fetch({
    required String platformId,
    required String accountId,
    required EmailMessage message,
  }) async {
    if (debugDisabled) throw PopupBodyUnavailable('disabled in tests');
    ScanLease? lease;
    InteractiveScanClaim? claim;
    SpamFilterPlatform? platform;
    try {
      // Throws TimeoutException when a scan in this process holds the lease.
      lease = await _leaseAcquirer(accountId);
      // Throws ScanAccountBusyException when another process (a background
      // scan) holds the account; nothing connects in that case.
      claim = await _claimer(accountId);

      platform = _platformFactory(platformId);
      if (platform == null) {
        throw PopupBodyUnavailable('platform $platformId not supported');
      }
      if (platformId != 'demo') {
        final credentials = await _credentialsLoader(accountId);
        if (credentials == null) {
          throw PopupBodyUnavailable('no credentials for the account');
        }
        await platform.loadCredentials(credentials);
      }
      // 5.1.9 rehearsal (Sprint 83): [SpamFilterPlatform.fetchContentText]
      // first. The rule-path body ([fetchFullBody]) is the text/plain part
      // ONLY, so an HTML-only message read as empty and showed "Could not read
      // message" on 3 of 3 live DEV AOL items. fetchContentText falls back to
      // the HTML part as text, and THROWS on a failed fetch (IMAP, Gmail).
      final text = await platform.fetchContentText(message);
      if (text != null && text.trim().isNotEmpty) return text;
      // Null: no text in the message, or a provider without a real
      // fetchContentText (demo, mock: the mixin's named no-op), whose
      // fetchFullBody returns the body it already has.
      final full = await platform.fetchFullBody(message);
      if (full.body.trim().isEmpty) {
        throw PopupBodyUnavailable('no text in the message');
      }
      return full.body;
    } finally {
      if (platform != null) {
        try {
          await platform.disconnect();
        } catch (e) {
          _logger.w('Block Body fetch: disconnect failed: ${e.runtimeType}');
        }
      }
      // Claim first, then lease: release() hands the lease to a queued scan,
      // which must not meet this claim row (F212, PR #440 review).
      await claim?.end();
      if (lease != null) ScanCoordinator.instance.release(lease);
    }
  }
}
