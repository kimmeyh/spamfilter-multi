import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../core/services/content_history.dart';
import '../../core/storage/content_history_store.dart';
import '../../core/storage/settings_store.dart';

/// R76-4 (Sprint 78, ADR-0047 R-9): Settings > General > "Content history" --
/// the on/off switch, how many emails are stored, and "Delete content
/// history". DEV BUILDS ONLY: in a prod build this widget builds nothing
/// ([ContentHistory.isAvailable] is false), so no customer ever sees it.
class ContentHistoryRow extends StatefulWidget {
  const ContentHistoryRow({super.key, this.settingsStore, this.store});

  /// Test seams.
  final SettingsStore? settingsStore;
  final ContentHistoryStore? store;

  @override
  State<ContentHistoryRow> createState() => _ContentHistoryRowState();
}

class _ContentHistoryRowState extends State<ContentHistoryRow> {
  late final SettingsStore _settings = widget.settingsStore ?? SettingsStore();
  late final ContentHistoryStore _store =
      widget.store ?? ContentHistoryStore.instance;
  final Logger _logger = Logger();

  bool _enabled = false;
  int? _count;

  @override
  void initState() {
    super.initState();
    if (ContentHistory.isAvailable) _refresh();
  }

  Future<void> _refresh() async {
    bool enabled = false;
    int? count;
    try {
      enabled = await _settings.getContentHistoryEnabled();
      count = _store.fileExists() ? await _store.count() : 0;
    } catch (e) {
      _logger.w('Content history state could not be read: $e');
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _count = count;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await _settings.setContentHistoryEnabled(value);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete content history?'),
        content: Text('This deletes the ${_count ?? 0} stored emails. It '
            'cannot be undone. Your rules, accounts and scan history are not '
            'changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.deleteAll();
    } catch (e) {
      _logger.w('Content history delete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete the content history. Close other '
              'windows of this app and try again.'),
        ));
      }
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!ContentHistory.isAvailable) return const SizedBox.shrink();
    final count = _count;
    return Column(
      key: const Key('content_history_row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('content_history_switch'),
          title: const Text('Content history (development build only)'),
          subtitle: Text(
            'Keeps one copy of each scanned email -- sender, subject, '
            'outcome and plain text -- in a file on this computer, for '
            'building better spam detection. '
            '${count == null ? '' : '$count stored.'}',
          ),
          value: _enabled,
          onChanged: _setEnabled,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: OutlinedButton.icon(
            key: const Key('content_history_delete'),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete content history'),
            onPressed: (count ?? 0) > 0 ? _delete : null,
          ),
        ),
      ],
    );
  }
}
