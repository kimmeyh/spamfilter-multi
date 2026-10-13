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
/// Once the rules have loaded successfully, [child] stays mounted; a later
/// reload or reload error is reported by the code that asked for it.
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
    if (_loadedOnce) return widget.child;

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

    return widget.child;
  }
}
