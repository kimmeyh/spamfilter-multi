import 'package:flutter/material.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/services/new_mail_trigger.dart';
import '../../core/services/notification_account_filter.dart';
import '../../core/storage/settings_store.dart';

/// F253 (Sprint 76), made per ACCOUNT by F264 (Sprint 77): Settings >
/// Background > "Scan when new mail arrives".
///
/// OFF by default. Each account has its own switch, stored in the app database
/// with its other background settings ([SettingsStore.getAccountNewMailTrigger]).
/// The native listener cannot read that database, so every change also syncs
/// ONE native "any account has it on" flag ([NewMailTrigger.syncAnyAccountOn]).
/// A new-mail notification then scans only the accounts the posting app can be
/// about (Gmail app -> Gmail accounts, AOL -> AOL, Yahoo Mail -> Yahoo; Samsung
/// Email and Outlook -> every account with its switch on) AND whose own
/// background scanning is on -- see `notification_account_filter.dart`.
///
/// Turning it on also opens Android's Notification access screen when access
/// is not yet granted -- access is requested only here, never at startup. The
/// row shows whether access is granted and the last trigger's outcome, and is
/// re-read when the user returns from Android settings.
///
/// Shown on every account's Background tab, not only when that account's
/// background scanning is on (review M-1, Sprint 76): the switch is its own
/// setting, and hiding it behind another switch hid the only control.
///
/// Review (Sprint 76): an unreadable state shows as unknown, never as "off"
/// (MEDIUM-1); a change the phone did not confirm is reverted and reported
/// (HIGH-2); a refresh that started before the user's tap cannot overwrite it
/// (L-2).
///
/// ADR-0042: Android only (declared exception); the caller shows this row only
/// on Android and it is HIDDEN on Windows (Sprint 77 Q10 = 1). See ADR-0044.
class NewMailTriggerRow extends StatefulWidget {
  const NewMailTriggerRow({
    super.key,
    required this.accountId,
    this.platformId,
    this.settingsStore,
    this.getSavedAccountIds,
  });

  /// The account this switch belongs to.
  final String accountId;

  /// The account's platform id (`gmail`, `aol`, `yahoo`, ...), used only to
  /// name the mail apps in the status line. Null when unknown.
  final String? platformId;

  /// Test seam; defaults to the app's [SettingsStore].
  final SettingsStore? settingsStore;

  /// Test seam; defaults to the saved accounts in the credentials store.
  final Future<List<String>> Function()? getSavedAccountIds;

  /// The mail apps whose notifications scan an account on [platformId], for
  /// the status line. Samsung Email and Outlook can show any account, so they
  /// are always named. Display text only: the authority is the table in
  /// `MailNotificationPolicy.kt`, and a test pins that the two agree.
  static String appsFor(String? platformId) {
    final family = platformId == null ? null : providerFamilyOf(platformId);
    final own = switch (family) {
      'gmail' => 'Gmail, ',
      'aol' => 'AOL, ',
      'yahoo' => 'Yahoo Mail, ',
      _ => '',
    };
    return '${own}Samsung Email or Outlook';
  }

  @override
  State<NewMailTriggerRow> createState() => _NewMailTriggerRowState();
}

class _NewMailTriggerRowState extends State<NewMailTriggerRow>
    with WidgetsBindingObserver {
  late final SettingsStore _settings =
      widget.settingsStore ?? SettingsStore();

  /// This account's switch. null = not read yet or unreadable.
  bool? _enabled;
  bool? _granted;
  String? _lastResult;
  String? _problem;

  /// Bumped by every user change; a refresh that started earlier is dropped.
  int _generation = 0;

  Future<List<String>> _savedAccountIds() =>
      (widget.getSavedAccountIds ?? SecureCredentialsStore().getSavedAccounts)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didUpdateWidget(NewMailTriggerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _generation++;
      _enabled = null;
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final generation = _generation;
    bool? enabled;
    try {
      enabled = await _settings.getAccountNewMailTrigger(widget.accountId) ??
          false;
    } catch (_) {
      enabled = null; // unreadable is UNKNOWN, never "off"
    }
    final granted = await NewMailTrigger.isAccessGranted();
    final last = await NewMailTrigger.lastResult();
    if (!mounted || generation != _generation) return;
    setState(() {
      _enabled = enabled;
      _granted = granted;
      _lastResult = last;
    });
  }

  /// Writes the account's switch and syncs the native flag. True only when
  /// both happened.
  Future<bool> _save(bool value) async {
    try {
      await _settings.setAccountNewMailTrigger(widget.accountId, value);
      return await NewMailTrigger.syncAnyAccountOn(
          _settings, await _savedAccountIds());
    } catch (_) {
      return false;
    }
  }

  Future<void> _onChanged(bool value) async {
    _generation++;
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _problem = null;
    });
    final saved = await _save(value);
    if (!mounted) return;
    if (!saved) {
      // Put the stored value and the native flag back, best effort, so the
      // two stores do not disagree with what the switch now shows.
      await _save(previous ?? false);
      if (!mounted) return;
      setState(() {
        _enabled = previous;
        _problem = 'Could not change the setting. Try again.';
      });
      return;
    }
    if (value && _granted != true) {
      final opened = await NewMailTrigger.openAccessSettings();
      if (!mounted) return;
      if (!opened) {
        setState(() => _problem = 'Could not open Android settings. Open '
            'Settings > Notifications > Notification access (or Device & app '
            'notifications) and allow this app.');
      }
    }
  }

  String _status() {
    final enabled = _enabled;
    if (enabled == null) return 'Status unavailable.';
    if (!enabled) return 'Off. Scans run on the background schedule only.';
    switch (_granted) {
      case true:
        return 'On for this account. When ${NewMailTriggerRow.appsFor(widget.platformId)} '
            'shows a new-mail notification, this account is scanned (if its '
            'background scanning is on). The app reads only which app posted '
            'the notification, never its content.';
      case false:
        return 'Needs Notification access: allow this app in Android '
            'settings, then come back.';
      case null:
        return 'On. Notification access could not be checked.';
    }
  }

  String? _lastResultLine() {
    final parsed = NewMailTrigger.parseLastResult(_lastResult);
    if (parsed == null) return null;
    final t = parsed.at;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Last new-mail trigger: ${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)} -- ${parsed.outcome}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final last = _lastResultLine();
    return Column(
      key: const Key('new_mail_trigger_row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('new_mail_trigger_switch'),
          title: const Text('Scan when new mail arrives'),
          subtitle: Text(_status(), key: const Key('new_mail_trigger_status')),
          value: _enabled ?? false,
          // Disabled while the state is unknown: a switch drawn OFF when the
          // feature may be ON would be a confident wrong answer.
          onChanged: _enabled == null ? null : _onChanged,
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_problem!,
                key: const Key('new_mail_trigger_problem'),
                style: textTheme.bodySmall),
          ),
        if (_enabled == true && last != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(last,
                key: const Key('new_mail_trigger_last'),
                style: textTheme.bodySmall),
          ),
        if (_enabled == true && _granted != true)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextButton(
              key: const Key('new_mail_trigger_open_access'),
              onPressed: () async {
                final opened = await NewMailTrigger.openAccessSettings();
                if (!opened && mounted) {
                  setState(() => _problem = 'Could not open Android settings. '
                      'Open Settings > Notifications > Notification access and '
                      'allow this app.');
                }
              },
              child: const Text('Open Notification access'),
            ),
          ),
      ],
    );
  }
}
