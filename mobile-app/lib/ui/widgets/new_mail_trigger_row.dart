import 'package:flutter/material.dart';

import '../../core/services/new_mail_trigger.dart';

/// F253 (Sprint 76): Settings > Background > "Scan when new mail arrives".
///
/// OFF by default. Turning it on also opens Android's Notification access
/// screen when access is not yet granted -- access is requested only here,
/// never at startup. The row shows whether access is granted and is re-read
/// when the user returns from Android settings.
///
/// Applies to ALL accounts: a new-mail notification starts one scan of every
/// account whose background scanning is on.
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
  bool _enabled = false;
  bool? _granted;

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
    final enabled = await NewMailTrigger.isEnabled();
    final granted = await NewMailTrigger.isAccessGranted();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _granted = granted;
    });
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    await NewMailTrigger.setEnabled(value);
    if (value && _granted != true) {
      await NewMailTrigger.openAccessSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status;
    if (!_enabled) {
      status = 'Off. Scans run on the background schedule only.';
    } else if (_granted == true) {
      status = 'On. When Gmail, AOL, Yahoo, Samsung Email or Outlook shows a '
          'new-mail notification, every account with background scanning on '
          'is scanned. The app reads only which app posted the notification, '
          'never its content.';
    } else {
      status = 'Needs Notification access: allow this app in the Android '
          'screen that opened, then come back.';
    }

    return Column(
      key: const Key('new_mail_trigger_row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('new_mail_trigger_switch'),
          title: const Text('Scan when new mail arrives'),
          subtitle: Text(status, key: const Key('new_mail_trigger_status')),
          value: _enabled,
          onChanged: _onChanged,
        ),
        if (_enabled && _granted != true)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextButton(
              key: const Key('new_mail_trigger_open_access'),
              onPressed: NewMailTrigger.openAccessSettings,
              child: const Text('Open Notification access'),
            ),
          ),
      ],
    );
  }
}
