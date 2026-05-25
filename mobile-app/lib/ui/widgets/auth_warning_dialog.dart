import 'package:flutter/material.dart';

import '../../core/services/auth_results_parser.dart';

/// F89 (Sprint 39): the warn-then-confirm dialog shown when a user tries to
/// whitelist (add as safe sender) an email whose authentication state is RED
/// (a confident spoof signal: SPF or DKIM failed AND DMARC failed).
///
/// The dialog explains, in plain English:
///   (a) WHAT failed, per protocol;
///   (b) WHY it matters -- whitelisting a spoofable sender lets future
///       spoofed mail bypass all rules;
///   (c) WHAT the safer alternatives are.
///
/// Default focus is Cancel; "Add Anyway" is the secondary, de-emphasized
/// action. The raw `Authentication-Results` text is available in a
/// collapsible "Show technical details" section.
class AuthWarningDialog {
  /// Show the RED-state safe-sender warning for [authResult] against
  /// [senderEmail].
  ///
  /// Returns true if the user chose "Add Anyway", false (or null coerced to
  /// false) if they cancelled or dismissed the dialog.
  static Future<bool> showSafeSenderWarning(
    BuildContext context, {
    required String senderEmail,
    required EmailAuthResult authResult,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _SafeSenderAuthWarningDialog(
        senderEmail: senderEmail,
        authResult: authResult,
      ),
    );
    return result ?? false;
  }
}

class _SafeSenderAuthWarningDialog extends StatefulWidget {
  final String senderEmail;
  final EmailAuthResult authResult;

  const _SafeSenderAuthWarningDialog({
    required this.senderEmail,
    required this.authResult,
  });

  @override
  State<_SafeSenderAuthWarningDialog> createState() =>
      _SafeSenderAuthWarningDialogState();
}

class _SafeSenderAuthWarningDialogState
    extends State<_SafeSenderAuthWarningDialog> {
  bool _showTechnicalDetails = false;

  @override
  Widget build(BuildContext context) {
    final auth = widget.authResult;

    return AlertDialog(
      key: const Key('safe_sender_auth_warning_dialog'),
      title: Row(
        children: [
          Icon(Icons.gpp_bad, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Expanded(child: Text('Sender failed authentication')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (a) WHAT failed, per protocol, in plain English.
              Text(
                'Email from ${widget.senderEmail} did not pass the checks that '
                'prove it really came from that domain:',
              ),
              const SizedBox(height: 12),
              _protocolLine('SPF', auth.spf, _spfExplanation(auth.spf)),
              _protocolLine('DKIM', auth.dkim, _dkimExplanation(auth.dkim)),
              _protocolLine('DMARC', auth.dmarc, _dmarcExplanation(auth.dmarc)),
              const SizedBox(height: 16),

              // (b) WHY it matters.
              _sectionTitle(context, 'Why this matters'),
              const SizedBox(height: 4),
              const Text(
                'Adding this sender to your safe list tells the app to skip all '
                'spam rules for it. If this email is spoofed, future spoofed '
                'mail pretending to be this sender would bypass your rules and '
                'land in your inbox.',
              ),
              const SizedBox(height: 16),

              // (c) WHAT the safer alternatives are.
              _sectionTitle(context, 'Safer alternatives'),
              const SizedBox(height: 4),
              const _BulletLine(
                'Whitelist this exact email address instead of the entire '
                'domain, so only this address is trusted.',
              ),
              const _BulletLine(
                'Verify the sender out of band (a phone call or a known-good '
                'website) before trusting the message.',
              ),
              const _BulletLine(
                'If you did not expect this message, delete it and report it '
                'as phishing rather than whitelisting it.',
              ),
              const SizedBox(height: 8),

              // Collapsible raw Authentication-Results.
              if (auth.raw.isNotEmpty) ...[
                const Divider(),
                InkWell(
                  key: const Key('toggle_technical_details'),
                  onTap: () => setState(
                      () => _showTechnicalDetails = !_showTechnicalDetails),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _showTechnicalDetails
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text('Show technical details'),
                      ],
                    ),
                  ),
                ),
                if (_showTechnicalDetails)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      auth.raw,
                      key: const Key('technical_details_text'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Default / focused action: Cancel.
        ElevatedButton(
          key: const Key('auth_warning_cancel'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        // Secondary, de-emphasized: Add Anyway.
        TextButton(
          key: const Key('auth_warning_add_anyway'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Add Anyway'),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _protocolLine(String name, AuthMethodResult result, String detail) {
    final failed = result == AuthMethodResult.fail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.cancel : Icons.info_outline,
            size: 16,
            color: failed ? Colors.red.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _spfExplanation(AuthMethodResult r) {
    switch (r) {
      case AuthMethodResult.fail:
        return 'failed. The sending server is not authorized to send mail for '
            'this domain.';
      case AuthMethodResult.softfail:
        return 'soft-failed. The domain discourages this sending server.';
      case AuthMethodResult.none:
        return 'no result. The domain published no SPF record.';
      default:
        return 'result: ${r.name}.';
    }
  }

  String _dkimExplanation(AuthMethodResult r) {
    switch (r) {
      case AuthMethodResult.fail:
        return 'failed. The cryptographic signature did not verify, so the '
            'message may have been altered or forged.';
      case AuthMethodResult.none:
        return 'no result. The message was not signed.';
      default:
        return 'result: ${r.name}.';
    }
  }

  String _dmarcExplanation(AuthMethodResult r) {
    switch (r) {
      case AuthMethodResult.fail:
        return 'failed. The domain owner\'s policy says mail like this should '
            'not be trusted.';
      case AuthMethodResult.none:
        return 'no result. The domain published no DMARC policy.';
      default:
        return 'result: ${r.name}.';
    }
  }
}

/// A single bullet line in the alternatives list.
class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('  -  '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
