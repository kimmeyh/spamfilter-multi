import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/rule_set_provider.dart';

/// Shows the app ([child]) once the rules have loaded, with a loading screen
/// and an error screen before that.
///
/// Sprint 78 MV-3 (Harold: "the screen behind goes blank for about 5
/// seconds" after picking a rule): the loading and error screens are for the
/// FIRST load only. Before this gate, the app root showed them whenever
/// [RuleSetProvider] was loading -- and every quick action reloads the rules
/// (`RuleQuickActionService`), so creating one rule swapped the whole home
/// screen out and back in. Review No Rule Items is the home screen, so it was
/// disposed and rebuilt from scratch: a blank list while it re-read every row.
/// Once the rules have loaded successfully, [child] stays mounted. A later
/// reload ERROR shows a non-blocking banner with Retry over [child]: the
/// provider swallows the error, so no caller can report it (7.7.1 H-1).
///
/// Until that first success the behavior is unchanged, including the brief
/// [child] shown while the provider is still idle.
class RulesReadyGate extends StatefulWidget {
  final Widget child;

  const RulesReadyGate({super.key, required this.child});

  @override
  State<RulesReadyGate> createState() => _RulesReadyGateState();
}

class _RulesReadyGateState extends State<RulesReadyGate> {
  /// Latched true at the first successful load, and never reset.
  bool _loadedOnce = false;

  @override
  Widget build(BuildContext context) {
    final ruleProvider = context.watch<RuleSetProvider>();
    final state = ruleProvider.loadingState;
    if (state == RuleLoadingState.success) _loadedOnce = true;
    if (_loadedOnce) {
      return _withReloadBanner(
          context,
          state == RuleLoadingState.error
              ? (ruleProvider.error ?? 'unknown error')
              : null);
    }

    if (state == RuleLoadingState.loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading spam filter rules...'),
            ],
          ),
        ),
      );
    }

    if (state == RuleLoadingState.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${ruleProvider.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<RuleSetProvider>().initialize(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return _withReloadBanner(context, null);
  }

  /// [child] always sits at index 0 of the SAME Stack, whether or not the
  /// banner shows, so a reload error never disposes and rebuilds the home
  /// screen (the MV-3 defect). Every return of [child] goes through here --
  /// including the idle one before the first load -- so the tree shape never
  /// changes between them.
  ///
  /// [reloadError] non-null: a reload AFTER the first success failed.
  /// `loadRules()` catches its own error, so the caller (for example a quick
  /// action) cannot report it; without this banner the app would keep the old
  /// rules with no sign anywhere (Sprint 78 7.7.1 silent-failure H-1).
  Widget _withReloadBanner(BuildContext context, String? reloadError) {
    return Stack(
      children: [
        widget.child,
        if (reloadError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Material(
                key: const Key('rules_reload_error_banner'),
                elevation: 6,
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Spam filter rules could not be reloaded. The rules '
                          'loaded earlier are still in use. ($reloadError)',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.read<RuleSetProvider>().initialize(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
