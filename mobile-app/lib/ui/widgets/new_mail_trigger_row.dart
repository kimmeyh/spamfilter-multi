import 'package:flutter/material.dart';

import '../../core/services/new_mail_trigger.dart';

/// F253 (Sprint 76): Settings > Background > "Scan when new mail arrives".
///
/// OFF by default. Turning it on also opens Android's Notification access
/// screen when access is not yet granted -- access is requested only here,
/// never at startup. The row shows whether access is granted and the last
/// trigger's outcome, and is re-read when the user returns from Android
/// settings.
///
/// Applies to ALL accounts: a new-mail notification starts one scan of every
/// account whose background scanning is on. So the row is shown on every
/// account's Background tab, not only when that account's background scanning
/// is on (review M-1).
///
/// Review (Sprint 76): an unreadable state shows as unknown, never as "off"
/// (MEDIUM-1); a change the phone did not confirm is reverted and reported
/// (HIGH-2); a refresh that started before the user's tap cannot overwrite it
/// (L-2).
///
/// ADR-0042: Android only (declared exception); the caller shows this row only
/// on Android. See ADR-0044.
class NewMailTriggerRow extends StatefulWidget {
  const NewMailTriggerRow({super.key});

  @override
  State<NewMailTriggerRow> createState() => _NewMailTriggerRowState();
}

class _NewMailTriggerRowState extends State<NewMailTriggerRow>
    with WidgetsBindingObserver {
  /// null = not read yet or unreadable.
  bool? _enabled;
  bool? _granted;
  String? _lastResult;
  String? _problem;

  /// Bumped by every user change; a refresh that started earlier is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
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
    final enabled = await NewMailTrigger.isEnabled();
    final granted = await NewMailTrigger.isAccessGranted();
    final last = await NewMailTrigger.lastResult();
    if (!mounted || generation != _generation) return;
    setState(() {
      _enabled = enabled;
      _granted = granted;
      _lastResult = last;
    });
  }

  Future<void> _onChanged(bool value) async {
    _generation++;
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _problem = null;
    });
    final saved = await NewMailTrigger.setEnabled(value);
    if (!mounted) return;
    if (!saved) {
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
        return 'On, for all accounts with background scanning on. When Gmail, '
            'AOL, Yahoo, Samsung Email or Outlook shows a new-mail '
            'notification, those accounts are scanned. The app reads only '
            'which app posted the notification, never its content.';
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
          title: const Text('Scan when new mail arrives (all accounts)'),
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
