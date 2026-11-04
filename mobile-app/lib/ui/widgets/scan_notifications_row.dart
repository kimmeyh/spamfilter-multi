import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/services/android_notification_settings.dart';
import '../../core/services/scan_complete_notifier.dart';
import '../../core/storage/settings_store.dart';

/// F322 (Sprint 83): Settings > Background > "Scan notifications".
///
/// Which completed background scans tell the user. The text is the same on
/// every platform:
/// - "Every completed scan"
/// - "Only when one or more No Rule items" (the default, Q2 = 1)
///
/// Where the user sets it differs, by the Sprint 83 Q1 = 1 decision
/// (ADR-0042 / ADR-0049 declared exception, `ScanCompleteNotifier`):
/// - Windows, iPhone and Android 7.x (no channels): this in-app choice.
/// - Android 8.0+: Android owns the choice. The row opens Android's
///   notification settings for the app, where "Scans with No Rule items" and
///   "Scans with nothing to review" are listed; the user turns the second one
///   off. The in-app choice is not shown (it would disagree with the channel
///   settings).
class ScanNotificationsRow extends StatefulWidget {
  const ScanNotificationsRow({
    super.key,
    this.settingsStore,
    this.channelsProbe,
    this.openAndroidSettings,
  });

  /// Test seam: defaults to the app's [SettingsStore].
  final SettingsStore? settingsStore;

  /// Test seam: defaults to [ScanCompleteNotifier.ensureAndroidChannels].
  final Future<bool> Function()? channelsProbe;

  /// Test seam: defaults to [AndroidNotificationSettings.open].
  final Future<bool> Function()? openAndroidSettings;

  static const String title = 'Scan notifications';
  static const String everyLabel = 'Every completed scan';
  static const String noRuleOnlyLabel = 'Only when one or more No Rule items';
  static const String androidHelp =
      'Android decides which scans notify you. Open Android notification '
      'settings and turn off "Scans with nothing to review" to be told only '
      'when there are No Rule items.';
  static const String openButtonLabel = 'Open notification settings';

  @override
  State<ScanNotificationsRow> createState() => _ScanNotificationsRowState();
}

class _ScanNotificationsRowState extends State<ScanNotificationsRow> {
  static final Logger _logger = Logger();

  late final SettingsStore _store = widget.settingsStore ?? SettingsStore();
  ScanNotifyChoice _choice = SettingsStore.defaultScanNotifyChoice;

  /// null = still deciding; true = Android 8.0+ (channels); false = in-app.
  bool? _useAndroidChannels;
  bool _openFailed = false;
  bool _saveFailed = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var channels = false;
    if (PlatformCapabilities.current.notificationDelivery ==
        NotificationDelivery.androidChannel) {
      channels = await (widget.channelsProbe ??
          ScanCompleteNotifier.ensureAndroidChannels)();
    }
    var choice = SettingsStore.defaultScanNotifyChoice;
    var loadFailed = false;
    if (!channels) {
      try {
        choice = await _store.getScanNotifyChoice();
      } catch (e) {
        // 5.1.2 F4: the dropdown then shows the default, which may not be the
        // saved choice, so the row says so.
        loadFailed = true;
        _logger.w('Could not read the scan notification choice: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _useAndroidChannels = channels;
      _choice = choice;
      _loadFailed = loadFailed;
    });
  }

  Future<void> _select(ScanNotifyChoice choice) async {
    final previous = _choice;
    setState(() {
      _choice = choice;
      _saveFailed = false;
    });
    try {
      await _store.setScanNotifyChoice(choice);
      if (mounted) setState(() => _loadFailed = false);
    } catch (e) {
      _logger.e('Could not save the scan notification choice: $e');
      if (!mounted) return;
      // Show the value that is really saved, and say so.
      setState(() {
        _choice = previous;
        _saveFailed = true;
      });
    }
  }

  Future<void> _openAndroid() async {
    final opened =
        await (widget.openAndroidSettings ?? AndroidNotificationSettings.open)();
    if (!mounted) return;
    setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final useChannels = _useAndroidChannels;
    if (useChannels == null) {
      return const SizedBox.shrink(key: Key('scan_notifications_row'));
    }
    return Padding(
      key: const Key('scan_notifications_row'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ScanNotificationsRow.title, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          if (useChannels) ...[
            Text(ScanNotificationsRow.androidHelp,
                key: const Key('scan_notifications_android_help'),
                style: textTheme.bodySmall),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('scan_notifications_open'),
                onPressed: _openAndroid,
                child: const Text(ScanNotificationsRow.openButtonLabel),
              ),
            ),
            if (_openFailed)
              Text(
                  'Could not open Android settings. Open Settings > Apps > '
                  'this app > Notifications.',
                  key: const Key('scan_notifications_open_failed'),
                  style: textTheme.bodySmall),
          ] else ...[
            DropdownButton<ScanNotifyChoice>(
              key: const Key('scan_notifications_choice'),
              isExpanded: true,
              value: _choice,
              items: const [
                DropdownMenuItem(
                  value: ScanNotifyChoice.every,
                  child: Text(ScanNotificationsRow.everyLabel),
                ),
                DropdownMenuItem(
                  value: ScanNotifyChoice.noRuleOnly,
                  child: Text(ScanNotificationsRow.noRuleOnlyLabel),
                ),
              ],
              onChanged: (value) {
                if (value != null) _select(value);
              },
            ),
            if (_loadFailed)
              Text(
                  'Could not read the saved choice. The choice shown may not '
                  'be the one saved; pick one to save it.',
                  key: const Key('scan_notifications_load_failed'),
                  style: textTheme.bodySmall),
            if (_saveFailed)
              Text('Could not save this choice. The previous choice is kept.',
                  key: const Key('scan_notifications_save_failed'),
                  style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
