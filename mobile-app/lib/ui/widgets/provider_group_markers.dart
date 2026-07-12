import 'package:flutter/material.dart';

/// Sprint 46 retro IMP-1 (Harold): visual markers for the email-provider
/// sender group at the top of scan-result lists. Shown ONLY when the group
/// is non-empty; lists without provider senders render exactly as before.
/// Shared by `ResultsDisplayScreen` and `NoRuleReviewScreen` so the group
/// reads identically everywhere.

/// Heading rendered ABOVE the provider-sender group.
class ProviderGroupHeader extends StatelessWidget {
  final int count;

  const ProviderGroupHeader({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('provider_group_header'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.contact_mail_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Email provider senders ($count) -- process these together first',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled divider rendered AFTER the provider-sender group.
class ProviderGroupEnd extends StatelessWidget {
  const ProviderGroupEnd({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withOpacity(0.6);
    return Padding(
      key: const Key('provider_group_end'),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'End of email provider senders',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}
