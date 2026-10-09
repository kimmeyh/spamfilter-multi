import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/scan_interval.dart';

/// F264 (Sprint 77): Settings > Background > "Scan every" -- a unit dropdown
/// FIRST (Minutes | Hours), then a 2-digit number box (1-99). The interval is
/// number x unit, from 5 minutes to 99 hours, the same on Windows and Android
/// (ADR-0042: shared code, identical UI).
///
/// **When a value is saved.** An entry is saved on the keyboard's Done key, when
/// the number box loses focus, or when the unit changes -- not on every
/// keystroke, so typing "12" does not first schedule "1". The inline message
/// updates live, so the user sees the floor as soon as they type under it.
///
/// **An entry under the floor is NOT saved**: the stored value stays what it
/// was and the message "Minimum is 5 minutes, to limit battery use" stays on
/// screen. The floor itself is `kMinIntervalMinutes` (one named constant).
///
/// Accessibility (ADR-0037): the number box carries the semantic label
/// "Interval number"; the inline message is a keyed `Text` in the theme's error
/// color.
class ScanIntervalControl extends StatefulWidget {
  const ScanIntervalControl({
    super.key,
    required this.initialMinutes,
    required this.onCommit,
  });

  /// The stored interval, in minutes. Shown as the nearest value the control
  /// can express (a value such as 125 minutes shows as 2 hours).
  final int initialMinutes;

  /// Called with the new interval in minutes when a VALID entry is committed
  /// and differs from the last committed value.
  final Future<void> Function(int minutes) onCommit;

  @override
  State<ScanIntervalControl> createState() => _ScanIntervalControlState();
}

class _ScanIntervalControlState extends State<ScanIntervalControl> {
  late ScanIntervalUnit _unit;
  late final TextEditingController _number;
  late final FocusNode _focus;
  late int _lastCommitted;
  String? _message;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChanged);
    _number = TextEditingController();
    _resetTo(widget.initialMinutes);
  }

  void _resetTo(int minutes) {
    final split = ScanInterval.split(minutes);
    _unit = split.unit;
    _number.text = split.number.toString();
    _lastCommitted = ScanInterval.nearestValid(minutes);
    _message = null;
  }

  @override
  void didUpdateWidget(ScanIntervalControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value changed from outside (the settings screen finished
    // loading, or another account was selected): show it. A change this
    // control itself just committed equals [_lastCommitted] and is ignored.
    if (widget.initialMinutes != oldWidget.initialMinutes &&
        ScanInterval.nearestValid(widget.initialMinutes) != _lastCommitted) {
      setState(() => _resetTo(widget.initialMinutes));
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _number.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  /// The entry as minutes, or null when the box is empty.
  int? get _enteredMinutes {
    final n = int.tryParse(_number.text.trim());
    return n == null ? null : ScanInterval.toMinutes(_unit, n);
  }

  void _validateLive() {
    final minutes = _enteredMinutes;
    setState(() => _message = minutes == null ? null : ScanInterval.validate(minutes));
  }

  Future<void> _commit() async {
    final minutes = _enteredMinutes;
    if (minutes == null) {
      // An empty box saves nothing and shows no message; restore the field to
      // the last saved value when the user leaves it.
      if (!_focus.hasFocus && mounted) {
        setState(() => _resetTo(_lastCommitted));
      }
      return;
    }
    final problem = ScanInterval.validate(minutes);
    if (!mounted) return;
    setState(() => _message = problem);
    if (problem != null || minutes == _lastCommitted) return;
    _lastCommitted = minutes;
    await widget.onCommit(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('scan_interval_control'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Scan every',
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
                      if (u == null) return;
                      setState(() => _unit = u);
                      _validateLive();
                      _commit();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Semantics(
                label: 'Interval number',
                child: TextField(
                  key: const Key('scan_interval_number'),
                  controller: _number,
                  focusNode: _focus,
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
                  onChanged: (_) => _validateLive(),
                  onSubmitted: (_) => _commit(),
                ),
              ),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              _message!,
              key: const Key('scan_interval_message'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
