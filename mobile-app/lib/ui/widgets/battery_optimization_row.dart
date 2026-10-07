import 'package:flutter/material.dart';

import '../../core/services/android_battery_status.dart';

/// F252 (Sprint 76): Settings > Background > "Keep background scans running".
///
/// Shows whether Android exempts the app from battery optimization and opens
/// the page where the user sets Battery > Unrestricted. Without the exemption
/// Android may hold background scans back while the phone is idle and, for an
/// app the user does not open, limit them to about once a day.
///
/// The state is re-read whenever the app returns to the foreground, because
/// the user changes it in Android's settings, outside the app.
///
/// ADR-0042: Android only (declared exception); the caller shows this row only
/// on Android.
class BatteryOptimizationRow extends StatefulWidget {
  const BatteryOptimizationRow({super.key});

  @override
  State<BatteryOptimizationRow> createState() => _BatteryOptimizationRowState();
}

class _BatteryOptimizationRowState extends State<BatteryOptimizationRow>
    with WidgetsBindingObserver {
  /// true = Unrestricted, false = Optimized, null = unknown / not read yet.
  bool? _unrestricted;
  bool _openFailed = false;

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
    final value = await AndroidBatteryStatus.isUnrestricted();
    if (!mounted) return;
    setState(() => _unrestricted = value);
  }

  Future<void> _open() async {
    final opened = await AndroidBatteryStatus.openAppSettings();
    if (!mounted) return;
    setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String status;
    switch (_unrestricted) {
      case true:
        status = 'Battery: Unrestricted. Android lets background scans run '
            'while the phone is idle.';
      case false:
        status = 'Battery: Optimized. Android may delay or skip background '
            'scans, and limits them to about once a day if the app is not '
            'opened for several days.';
      case null:
        status = 'Battery setting: not available.';
    }

    return Padding(
      key: const Key('battery_optimization_row'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Keep background scans running', style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(status,
              key: const Key('battery_optimization_status'),
              style: textTheme.bodySmall),
          if (_unrestricted != true) ...[
            const SizedBox(height: 4),
            Text(
              'To change it: tap the button, then Battery (or App battery '
              'usage), then Unrestricted. On Samsung phones, also add the app '
              'to "Never sleeping apps" in Settings > Battery > Background '
              'usage limits.',
              style: textTheme.bodySmall,
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('battery_optimization_open'),
              onPressed: _open,
              child: const Text('Open battery settings'),
            ),
          ),
          if (_openFailed)
            Text('Could not open Android settings. Open Settings > Apps > '
                'this app > Battery.',
                style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
