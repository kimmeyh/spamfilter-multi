import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/scan_interval.dart';

/// F281 (Sprint 78, Harold picked Alternative D from
/// `docs/research/F281_SCAN_INTERVAL_CONTROL.md`): Settings > Background >
/// "Scan every" is a drop-down of preset intervals ([kIntervalPresets]) plus
/// "Custom...", which opens a small dialog with a number box and a unit
/// (Minutes | Hours). The interval runs from 5 minutes to 24 hours, the same
/// on Windows and Android (ADR-0042: shared code, identical UI). It replaced
/// the F264 (Sprint 77) unit drop-down and 2-digit number box in the row.
///
/// **When a value is saved.** Picking a preset saves at once (MV-Q3: no Save
/// button in the row). The Custom dialog saves on its Save button, which stays
/// disabled until the entry is in range -- so the row can never hold an
/// invalid value. A saved custom value shows in the row as
/// "45 minutes (custom)".
///
/// **An entry outside 5 minutes to 24 hours is NOT saved**: the dialog shows
/// "Minimum is 5 minutes, to limit battery use" or "Maximum is 24 hours" and
/// Save stays disabled.
///
/// Accessibility (ADR-0037): the drop-down carries the label "Scan every"; the
/// dialog's number box carries "Interval number"; the inline message is a
/// keyed `Text` in the theme's error color.
class ScanIntervalControl extends StatefulWidget {
  const ScanIntervalControl({
    super.key,
    required this.initialMinutes,
    required this.onCommit,
  });

  /// The stored interval, in minutes. Shown as the nearest value the control
  /// can express (a value such as 125 minutes shows as 2 hours).
  final int initialMinutes;

  /// Called with the new interval in minutes when a VALID value is chosen and
  /// differs from the last committed value.
  final Future<void> Function(int minutes) onCommit;

  @override
  State<ScanIntervalControl> createState() => _ScanIntervalControlState();
}

/// The drop-down value that opens the Custom dialog (never a real interval).
const int _kCustomChoice = -1;

class _ScanIntervalControlState extends State<ScanIntervalControl> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = ScanInterval.nearestValid(widget.initialMinutes);
  }

  @override
  void didUpdateWidget(ScanIntervalControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value changed from outside (the settings screen finished
    // loading, or another account was selected): show it. A change this
    // control itself just committed equals [_minutes] and is ignored.
    final incoming = ScanInterval.nearestValid(widget.initialMinutes);
    if (widget.initialMinutes != oldWidget.initialMinutes &&
        incoming != _minutes) {
      setState(() => _minutes = incoming);
    }
  }

  Future<void> _commit(int minutes) async {
    if (minutes == _minutes || ScanInterval.validate(minutes) != null) return;
    setState(() => _minutes = minutes);
    await widget.onCommit(minutes);
  }

  Future<void> _openCustom() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _CustomIntervalDialog(initialMinutes: _minutes),
    );
    if (chosen != null) await _commit(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !kIntervalPresets.contains(_minutes);
    return Column(
      key: const Key('scan_interval_control'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Scan every',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const Key('scan_interval_dropdown'),
              value: _minutes,
              isExpanded: true,
              items: [
                // A saved value that is not a preset is listed first, marked.
                if (isCustom)
                  DropdownMenuItem(
                    value: _minutes,
                    child: Text('${ScanInterval.label(_minutes)} (custom)'),
                  ),
                for (final m in kIntervalPresets)
                  DropdownMenuItem(value: m, child: Text(ScanInterval.label(m))),
                const DropdownMenuItem(
                  value: _kCustomChoice,
                  child: Text('Custom...'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                if (v == _kCustomChoice) {
                  _openCustom();
                } else {
                  _commit(v);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// "Custom...": a number box and a unit, 5 minutes to 24 hours. Save stays
/// disabled until the entry is valid; Cancel changes nothing.
class _CustomIntervalDialog extends StatefulWidget {
  const _CustomIntervalDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomIntervalDialog> createState() => _CustomIntervalDialogState();
}

class _CustomIntervalDialogState extends State<_CustomIntervalDialog> {
  late ScanIntervalUnit _unit;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    final split = ScanInterval.split(widget.initialMinutes);
    _unit = split.unit;
    _number = TextEditingController(text: split.number.toString());
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  /// The entry as minutes, or null when the box is empty.
  int? get _enteredMinutes {
    final n = int.tryParse(_number.text.trim());
    return n == null ? null : ScanInterval.toMinutes(_unit, n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _enteredMinutes;
    final problem = minutes == null ? null : ScanInterval.validate(minutes);
    final canSave = minutes != null && problem == null;
    void save() {
      if (canSave) Navigator.pop(context, minutes);
    }

    return AlertDialog(
      key: const Key('scan_interval_custom_dialog'),
      title: const Text('Scan every'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Semantics(
                  label: 'Interval number',
                  child: TextField(
                    key: const Key('scan_interval_number'),
                    controller: _number,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Number',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => save(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Unit',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ScanIntervalUnit>(
                      key: const Key('scan_interval_unit'),
                      value: _unit,
                      isExpanded: true,
                      items: [
                        for (final u in ScanIntervalUnit.values)
                          DropdownMenuItem(value: u, child: Text(u.label)),
                      ],
                      onChanged: (u) {
                        if (u != null) setState(() => _unit = u);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (problem != null)
            Text(
              problem,
              key: const Key('scan_interval_message'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            )
          else
            Text('5 minutes to 24 hours', style: theme.textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('scan_interval_custom_save'),
          onPressed: canSave ? save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
