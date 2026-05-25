import 'package:flutter/material.dart';

import '../../core/services/auth_results_parser.dart';

/// F89 (Sprint 39): a small color-coded chip that summarizes an email's
/// SPF/DKIM/DMARC authentication state.
///
/// Color mapping:
///   - GREEN: "Authenticated" -- all present checks passed.
///   - YELLOW: "Partly authenticated" -- mixed results, non-blocking caution.
///   - RED: "Authentication failed" -- a confident spoof signal.
///   - GREY: "No authentication data" -- no headers to assess.
///
/// The badge is purely presentational; the caller computes the
/// [EmailAuthResult] (typically via [AuthResultsParser.parse]) so the same
/// result can drive both the badge and the warn-then-confirm dialog.
class EmailAuthBadge extends StatelessWidget {
  /// The parsed authentication result to display.
  final EmailAuthResult authResult;

  /// When true (default), the badge shows a text label beside the icon.
  /// When false, only the icon chip is shown (compact list contexts).
  final bool showLabel;

  const EmailAuthBadge({
    Key? key,
    required this.authResult,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final classification = AuthResultsParser.classify(authResult);
    final spec = _specFor(classification);

    return Tooltip(
      message: spec.tooltip,
      child: Container(
        key: ValueKey('email_auth_badge_${classification.name}'),
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10 : 6,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: spec.foreground.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 14, color: spec.foreground),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: TextStyle(
                  color: spec.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _BadgeSpec _specFor(AuthClassification c) {
    switch (c) {
      case AuthClassification.green:
        return const _BadgeSpec(
          label: 'Authenticated',
          tooltip: 'SPF, DKIM, and DMARC checks passed.',
          icon: Icons.verified_user,
          foreground: Color(0xFF1B5E20),
          background: Color(0xFFE8F5E9),
        );
      case AuthClassification.yellow:
        return const _BadgeSpec(
          label: 'Partly authenticated',
          tooltip: 'Some authentication checks did not pass. Verify the '
              'sender before trusting this email.',
          icon: Icons.gpp_maybe,
          foreground: Color(0xFF8D6E00),
          background: Color(0xFFFFF8E1),
        );
      case AuthClassification.red:
        return const _BadgeSpec(
          label: 'Authentication failed',
          tooltip: 'This email failed SPF/DKIM and DMARC. It may be spoofed. '
              'Do not whitelist the sender without verifying.',
          icon: Icons.gpp_bad,
          foreground: Color(0xFFB71C1C),
          background: Color(0xFFFFEBEE),
        );
      case AuthClassification.grey:
        return const _BadgeSpec(
          label: 'No authentication data',
          tooltip: 'This email carried no SPF/DKIM/DMARC headers, so its '
              'authenticity cannot be assessed.',
          icon: Icons.help_outline,
          foreground: Color(0xFF455A64),
          background: Color(0xFFECEFF1),
        );
    }
  }
}

/// Internal presentation spec for a single badge state.
class _BadgeSpec {
  final String label;
  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _BadgeSpec({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
  });
}
