import 'package:flutter/material.dart';

/// Empty state widget with helpful messaging
///
/// Displays when there is no content to show, with helpful messaging
/// and optional action buttons to guide the user.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              icon,
              size: 80,
              color: colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            // Action button (optional)
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined empty states for common scenarios

class NoAccountsEmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;

  const NoAccountsEmptyState({
    super.key,
    required this.onAddAccount,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.email_outlined,
      title: 'No Accounts Yet',
      message: 'Add your first email account to start scanning for spam.',
      actionLabel: 'Add Account',
      onActionPressed: onAddAccount,
    );
  }
}

class NoResultsEmptyState extends StatelessWidget {
  const NoResultsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.inbox_outlined,
      title: 'No Results Yet',
      message: 'Run a scan to see email processing results here.',
    );
  }
}

class NoMatchingEmailsEmptyState extends StatelessWidget {
  const NoMatchingEmailsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.filter_alt_outlined,
      title: 'No Matching Emails',
      message: 'No emails match the current filter. Try selecting a different filter or clearing filters.',
    );
  }
}

class NoRulesEmptyState extends StatelessWidget {
  final VoidCallback? onAddRule;

  const NoRulesEmptyState({
    super.key,
    this.onAddRule,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.rule_outlined,
      title: 'No Rules Configured',
      message: 'Add spam filtering rules to automatically process incoming emails.',
      actionLabel: onAddRule != null ? 'Add Rule' : null,
      onActionPressed: onAddRule,
    );
  }
}
