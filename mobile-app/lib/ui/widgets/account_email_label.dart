import 'package:flutter/material.dart';

/// F176 (Sprint 62, Harold): "add current email address to Manual scan
/// screen on mobile and the live scan screen (small in order to fit). If not
/// already on Windows screens, should probably be added there as well."
///
/// Both scan screens DO carry the email in their AppBar titles, but at phone
/// width the title truncates behind the action icons and the email is the
/// part that disappears -- during multi-account validation there was no way
/// to tell WHICH account a scan was running against. This small body label
/// is the fix: one shared widget (identical on Windows and Android, ADR-0042
/// -- no exception), small type, single line, ellipsized so a long address
/// can never break the layout at 411px (the F169 phone-width rule).
///
/// The Settings Background tab's Sprint 38 account header is the precedent:
/// same problem (which account does this apply to?), same answer.
class AccountEmailLabel extends StatelessWidget {
  const AccountEmailLabel({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    if (email.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_circle_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
