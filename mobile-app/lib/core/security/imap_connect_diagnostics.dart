/// F347 (Sprint 86): name the step and the network when an IMAP connect fails.
///
/// A connect that ends in a `TimeoutException` or `SocketException` says only
/// that it did not finish. The F342 research of the Fold logs could not tell a
/// DNS stall from a TCP stall from a TLS stall, nor Wi-Fi from mobile data.
/// This helper writes ONE diagnostic line per such failure with:
/// - `phase`: the step that did not finish (`dns`, `tcp`, `tls`, `greeting`,
///   or `tcp+tls` where the library hides the split);
/// - the elapsed milliseconds of each step that DID finish;
/// - the network type at that moment (`connectivity_plus`).
///
/// It never changes the failure or its timing: the original exception object
/// is rethrown at once (the report runs in the background and is never
/// awaited), so the type, message and arrival time the adapter sees
/// (`generic_imap_adapter.dart`, the `Network connection failed: ...` branch)
/// are what they were (R-3). When the diagnostic log is off the report does
/// no lookup and no connectivity read. It writes no credential and no email address; the host name is
/// logged, the exception TYPE only (not its message).
///
/// Two connect paths use it:
/// - Custom IMAP (`ImapTlsConnector.connect`): the connector marks the steps
///   on an [ImapConnectTrace]. STARTTLS has tcp, starttls, tls and greeting
///   as separate steps. SSL/TLS keeps ONE `SecureSocket.connect` (a version
///   that split it into `Socket.connect` + `SecureSocket.secure` made the
///   Custom IMAP integration tests hang for 30 s each, measured 2026-11-24,
///   so the connect is NOT split) and reports `tcp+tls`, then `greeting`.
/// - AOL, Gmail (IMAP), Yahoo, iCloud: `ImapClient.connectToServer`
///   (enough_mail 2.1.7, `client_base.dart:99-122`) hides TCP and TLS inside
///   one `SecureSocket.connect(...).timeout(timeout)`. Same `tcp+tls`.
/// The line says `phase-inferred` whenever the phase is `tcp+tls`.
///
/// DNS: the connect resolves the name itself and the library hides when. So
/// the lookup is checked AFTER a failure, and only when the connect had not
/// got past TCP: one `InternetAddress.lookup(host)`, bounded by [dnsTimeout].
/// A lookup that FAILS makes the phase `dns`; one that TIMES OUT is "could not
/// check", so the phase stays the in-flight one and the line adds
/// `dns-recheck=timeout`. The line labels it `dns-recheck` because it ran
/// after the failure, not during the connect.
/// A connect that reached TLS or the greeting got past DNS (`dns=passed`).
/// No lookup runs on a successful connect (an earlier design ran one beside
/// every connect; the Custom IMAP integration tests then hung, and the
/// extra work on the success path bought nothing).
///
/// Platform parity (ADR-0042): shared Dart; `dart:io` lookup and
/// `connectivity_plus` exist on Windows, Android and iPhone. No exception.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

import '../services/diagnostic_logger.dart';

/// Outcome of the diagnostic DNS lookup.
class _DnsResult {
  const _DnsResult.ok(this.elapsedMs) : failure = null;
  const _DnsResult.failed(this.elapsedMs, this.failure);

  final int elapsedMs;

  /// `null` when the lookup finished; otherwise `timeout` or the error type.
  final String? failure;
}

/// Records which connect step is running and how long finished steps took.
class ImapConnectTrace {
  ImapConnectTrace._(this.host, this.port);

  final String host;
  final int port;
  final Stopwatch _total = Stopwatch()..start();
  final Stopwatch _step = Stopwatch();
  final List<MapEntry<String, int>> _finished = [];
  String? _current;

  /// The step that is running now, or `null` between steps.
  String? get currentPhase => _current;

  /// Start [phase]; the previous step, if any, is recorded as finished.
  void begin(String phase) {
    end();
    _current = phase;
    _step
      ..reset()
      ..start();
  }

  /// Record the running step as finished.
  void end() {
    final current = _current;
    if (current != null) {
      _finished.add(MapEntry(current, _step.elapsedMilliseconds));
    }
    _current = null;
    _step.stop();
  }
}

/// See the library comment.
class ImapConnectDiagnostics {
  ImapConnectDiagnostics._();

  /// How long the diagnostic DNS lookup may run.
  static Duration dnsTimeout = const Duration(seconds: 5);

  /// A network-type read slower than this is reported as `unknown`.
  static Duration networkReadTimeout = const Duration(seconds: 1);

  /// Test seam: the DNS lookup.
  static Future<List<InternetAddress>> Function(String host) dnsLookup =
      (host) => InternetAddress.lookup(host);

  /// Test seam: the network type. Default reads `connectivity_plus`.
  static Future<String> Function() networkTypeReader = _readNetworkType;

  /// Test seam: where the line goes. Default is the diagnostic log (a no-op
  /// while diagnostic logging is off).
  static Future<void> Function(String detail) sink = (detail) =>
      DiagnosticLogger.log(
        kind: DiagnosticLogger.kindNotConnected,
        context: 'IMAP/connect',
        detail: detail,
      );

  /// Restore every seam. For tests.
  static void resetForTest() {
    dnsTimeout = const Duration(seconds: 5);
    networkReadTimeout = const Duration(seconds: 1);
    dnsLookup = (host) => InternetAddress.lookup(host);
    networkTypeReader = _readNetworkType;
    logEnabled = DiagnosticLogger.isEnabled;
    sink = (detail) => DiagnosticLogger.log(
          kind: DiagnosticLogger.kindNotConnected,
          context: 'IMAP/connect',
          detail: detail,
        );
  }

  /// Run [body], which performs the connect and marks steps on its trace.
  ///
  /// Any failure is rethrown UNCHANGED (same object, same stack). A
  /// `TimeoutException` or `SocketException` also STARTS a background report
  /// of the diagnostic line; the rethrow does not wait for it (Sprint 86
  /// 7.7.1 M-2: this comment used to say the line is written "first"). A
  /// process that exits soon after calls [flush] so the line is not lost.
  /// When [providerPath] is true the body never marks a step, and a failure
  /// is reported as the inferred phase `tcp+tls`.
  static Future<T> traceConnect<T>({
    required String host,
    required int port,
    required Future<T> Function(ImapConnectTrace trace) body,
    bool providerPath = false,
  }) async {
    final trace = ImapConnectTrace._(host, port);
    if (providerPath) trace.begin('tcp+tls');
    try {
      return await body(trace);
    } on TimeoutException {
      await reportFailure(trace, 'TimeoutException');
      rethrow;
    } on SocketException catch (e) {
      await reportFailure(trace, 'SocketException',
          lookupFailed: isLookupFailure(e));
      rethrow;
    }
  }

  /// True when [e] is the connect's own name lookup failing. `dart:io`
  /// throws `SocketException("Failed host lookup: '<host>'")` for it
  /// (`sdk/lib/_internal/vm/bin/socket_patch.dart:620` and `:1205`, Flutter
  /// 3.47.4). Sprint 86 7.7.1 M4: without this, a lookup that failed DURING
  /// the connect and passed in the later recheck (Wi-Fi to mobile data) was
  /// labeled `tcp+tls`.
  static bool isLookupFailure(SocketException e) =>
      e.message.startsWith('Failed host lookup');

  static Future<_DnsResult> _recheckDns(String host) async {
    final sw = Stopwatch()..start();
    try {
      await dnsLookup(host).timeout(dnsTimeout);
      return _DnsResult.ok(sw.elapsedMilliseconds);
    } on TimeoutException {
      return _DnsResult.failed(sw.elapsedMilliseconds, 'timeout');
    } catch (e) {
      return _DnsResult.failed(sw.elapsedMilliseconds, e.runtimeType.toString());
    }
  }

  /// Report launched but not yet finished. A caller never waits on these.
  static final Set<Future<void>> _pending = {};

  /// Test seam: complete when every launched report has finished.
  static Future<void> settleForTest() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  /// Wait up to [max] for launched reports, then return. Never throws.
  ///
  /// Called by the paths that end the process or the isolate right after a
  /// scan (Windows Task Scheduler run before `exit()`, the Android
  /// WorkManager task before it returns), so a connect failure on the LAST
  /// account still reaches the log (Sprint 86 7.7.1 M-2). Returns at once
  /// when nothing is pending. A report still running after [max] is lost;
  /// the bound keeps a stalled DNS recheck from holding the exit.
  static Future<void> flush(
      {Duration max = const Duration(seconds: 3)}) async {
    if (_pending.isEmpty) return;
    try {
      await settleForTest().timeout(max);
    } catch (e) {
      _logger.w('IMAP connect diagnostic flush did not finish: '
          '${e.runtimeType}');
    }
  }

  /// Test seam: whether the diagnostic log is on. Default asks
  /// [DiagnosticLogger.isEnabled] (the check [DiagnosticLogger.log] uses).
  static Future<bool> Function() logEnabled = DiagnosticLogger.isEnabled;

  /// Launch the diagnostic line for a failed connect and return AT ONCE.
  /// Never throws. Public so a connector that converts the failure itself
  /// (the STARTTLS exchange) can log before it converts.
  ///
  /// What holds: the returned future is already complete, so the caller's
  /// rethrow is not delayed by the DNS recheck (up to [dnsTimeout]) or the
  /// network read (up to [networkReadTimeout]). The report runs in the
  /// background; when the diagnostic log is off it does nothing at all (no
  /// lookup, no connectivity read). The trace is read when the report starts,
  /// which is before the caller's next await.
  ///
  /// [lookupFailed]: the failure itself says the name lookup failed (see
  /// [isLookupFailure]); the phase is then `dns` whatever the recheck finds.
  static Future<void> reportFailure(
      ImapConnectTrace trace, String exceptionType,
      {bool lookupFailed = false}) {
    final inFlight = trace._current; // did not finish
    final finishedSnapshot = List<MapEntry<String, int>>.of(trace._finished);
    final totalMs = trace._total.elapsedMilliseconds;
    final report = _report(trace, inFlight, finishedSnapshot, totalMs,
        exceptionType, lookupFailed);
    _pending.add(report);
    report.whenComplete(() => _pending.remove(report));
    return Future<void>.value();
  }

  static final Logger _logger = Logger();

  static Future<void> _report(
    ImapConnectTrace trace,
    String? inFlight,
    List<MapEntry<String, int>> finishedSteps,
    int totalMs,
    String exceptionType,
    bool lookupFailed,
  ) async {
    try {
      if (!await logEnabled()) return;
      // Only a connect that had not got past TCP can have failed in DNS.
      final mayBeDns =
          inFlight == null || inFlight == 'tcp' || inFlight == 'tcp+tls';
      final dns = mayBeDns ? await _recheckDns(trace.host) : null;
      final dnsFailed = dns != null && dns.failure != null;
      // A recheck that timed out is "could not check", not a cause: the
      // phase stays the in-flight one. Only a lookup that FAILED is `dns`.
      // The connect's own lookup failure outranks the recheck (M4).
      final dnsTimedOut = dnsFailed && dns.failure == 'timeout';
      final dnsBlamed = lookupFailed || (dnsFailed && !dnsTimedOut);

      final String phase;
      if (dnsBlamed) {
        phase = 'dns';
      } else if (inFlight != null) {
        phase = inFlight;
      } else {
        phase = 'unknown';
      }

      final finished = <String>[];
      for (final step in finishedSteps) {
        finished.add('${step.key}=${step.value}ms');
      }

      final dnsNote = dns == null
          ? (lookupFailed ? 'dns=failed-in-connect' : 'dns=passed')
          : lookupFailed
              ? 'dns=failed-in-connect dns-recheck='
                  '${dns.failure ?? 'ok'}(${dns.elapsedMs}ms)'
          : !dnsFailed
              ? 'dns-recheck=ok(${dns.elapsedMs}ms)'
              : dnsTimedOut
                  ? 'dns-recheck=timeout(${dns.elapsedMs}ms)'
                  : 'dns-recheck=${dns.failure}(${dns.elapsedMs}ms)';
      final inferred = phase == 'tcp+tls'
          ? ' phase-inferred (one call covers the TCP connect and the TLS '
              'handshake)'
          : '';
      final network = await _networkType();
      await sink(
        'connect did not finish: host=${trace.host}:${trace.port} '
        'phase=$phase$inferred finished=[${finished.join(', ')}] $dnsNote '
        'network=$network error=$exceptionType '
        'elapsed=${totalMs}ms',
      );
    } catch (e) {
      // Diagnostics must never replace the connect failure the caller maps.
      // Log the error TYPE only (no message, host or account).
      _logger.w('IMAP connect diagnostic line was not written: '
          '${e.runtimeType}');
    }
  }

  static Future<String> _networkType() async {
    try {
      return await networkTypeReader().timeout(networkReadTimeout);
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<String> _readNetworkType() async {
    final result = await Connectivity().checkConnectivity();
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.vpn:
        return 'vpn';
      case ConnectivityResult.none:
        return 'none';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.other:
        return 'other';
    }
  }
}
