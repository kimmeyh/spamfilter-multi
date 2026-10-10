/// F283 (Sprint 78): the email detail pop-up -- the email's summary plus the
/// Safe Sender and Block Rule quick actions -- shared by the Results screen
/// and the Review No Rule Items screen, so both open the SAME pop-up (Sprint 52
/// IMP-5: one copy).
///
/// Moved here from `results_display_screen.dart` (`_showEmailDetailSheet`),
/// with its layout history comments kept. What the pop-up does NOT do is run
/// an action: it reports the user's choice through [onQuickAction] (a
/// [QuickActionRequest]) or [onSkip], and each screen runs its own pipeline.
/// Results keeps its re-evaluate / re-process / auto-advance pipeline
/// unchanged; Review creates the rule and marks the No Rule row handled.
///
/// F283 R-6 (MV-Q17, Harold): the date row names the ACCOUNT email where it
/// used to show the sender's domain, on both screens. The domain is still on
/// the domain action buttons below it.
///
/// ADR-0042: shared widget, identical on Windows and Android. The compact
/// (phone-width) placement below is a WIDTH rule, not a platform branch.
library;

import 'package:flutter/material.dart';

import '../../core/data/common_email_providers.dart';
import '../../core/models/email_message.dart';
import '../../core/models/evaluation_result.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/services/email_body_parser.dart';
import '../../core/utils/pattern_normalization.dart';
import 'result_list_pieces.dart';

/// Which quick action the user chose.
enum QuickActionKind { safeSender, blockRule }

/// The quick action the user chose in the pop-up.
class QuickActionRequest {
  const QuickActionRequest({
    required this.kind,
    required this.type,
    required this.value,
    required this.covers,
  });

  final QuickActionKind kind;

  /// Safe sender: 'exact', 'exactDomain' or 'entireDomain'. Block rule:
  /// 'from', 'exactDomain', 'entireDomain' or 'subject'.
  final String type;

  /// The value the rule or safe sender is created from.
  final String value;

  /// Sprint 46 (Harold speed follow-up): predicts which OTHER emails this
  /// action will ALSO address, so auto-advance skips them up front instead of
  /// opening an email that is about to be resolved by the same rule.
  final bool Function(EmailMessage other) covers;
}

/// F47: warns before a domain-level rule for a known email provider.
///
/// Returns true if the user confirms they want to proceed, false to cancel.
/// Returns true at once (no warning) if the domain is not a known provider.
Future<bool> checkProviderDomainWarning(
  BuildContext context, {
  required String domain,
  required bool isBlockRule,
}) async {
  // Extract bare domain (remove leading @ and subdomain wildcard patterns)
  final bareDomain =
      domain.replaceAll('@', '').replaceAll('*.', '').toLowerCase().trim();

  final providerName = CommonEmailProviders.getProviderName(bareDomain);
  if (providerName == null) return true; // Not a provider domain, proceed

  final ruleType = isBlockRule ? 'Block Rule' : 'Safe Sender';

  final content = isBlockRule
      ? 'The domain "$bareDomain" belongs to $providerName, a major email '
          'provider used by millions of individual and business accounts.\n\n'
          'Blocking this entire domain would prevent all emails from '
          '$providerName users from reaching your inbox.\n\n'
          'Recommendation: Use "Exact Email" to block a specific sender '
          'instead. If you do block the domain, you can add individual Safe '
          'Sender exceptions, but those emails would need to be rescued after '
          'being deleted.'
      : 'The domain "$bareDomain" belongs to $providerName, a major email '
          'provider used by millions of individual and business accounts.\n\n'
          'Adding this domain as a Safe Sender means all emails from any '
          '$providerName user will bypass your spam rules. Since Safe Sender '
          'rules override Block Rules, you would not be able to block specific '
          'senders from this domain.\n\n'
          'Recommendation: Use "Exact Email" to add specific trusted senders '
          'instead.';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Flexible(child: Text('$ruleType for Email Provider')),
        ],
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: isBlockRule ? Colors.red : Colors.green,
          ),
          child: const Text('Proceed Anyway'),
        ),
      ],
    ),
  );

  return confirmed == true;
}

/// MT-1 (Sprint 50): one quick-action cell. [onTap] is nullable -- a null
/// handler renders the button as a DISABLED placeholder (grey, non-tappable)
/// so the fixed action grid keeps every cell in place even when an action
/// does not apply to the current item.
Widget buildInlineActionButton({
  required IconData icon,
  required String label,
  required String subtitle,
  required Color color,
  required VoidCallback? onTap,
  bool isMatched = false, // Item 2: Visual indicator for current rule match
}) {
  final bool enabled = onTap != null;
  final Color effectiveColor = enabled ? color : Colors.grey.shade400;
  // F129 (Sprint 51): these quick-action cells were built from a bare InkWell
  // wrapping loose Text, so each one surfaced as an UNNAMED node with its
  // label floating alongside as separate Text -- a screen reader announced
  // nothing actionable, and name-based automation could not address the grid
  // at all (the MT-1 blocker). The wrapper order below is the one proven on
  // the No-Rule checkbox and the account picker: Semantics OUTSIDE (supplies
  // the assistive-technology label), Tooltip INSIDE (what actually reaches
  // the Windows UIA projection), real control innermost. `excludeSemantics`
  // merges the label/subtitle Text into ONE named node instead of leaving
  // them as loose siblings, and `onTap` is carried on the Semantics node
  // itself so the merged node stays actionable -- omitting it names the cell
  // but makes it unclickable (the account-picker regression, same sprint).
  // `enabled: false` cells deliberately keep the label but take no onTap, so
  // a disabled placeholder announces as present-but-inactive.
  return Semantics(
    container: true,
    button: true,
    enabled: enabled,
    excludeSemantics: true,
    label: label,
    hint: subtitle,
    onTap: onTap,
    child: Tooltip(
      message: enabled ? '$label. $subtitle' : '$label (unavailable)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isMatched
                  ? effectiveColor
                  : effectiveColor.withValues(alpha: 0.3),
              width: isMatched ? 2 : 1, // Thicker border for matched rule
            ),
            borderRadius: BorderRadius.circular(8),
            color: isMatched
                ? effectiveColor.withValues(
                    alpha: 0.15) // Darker shade for matched
                : effectiveColor.withValues(alpha: 0.05),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: effectiveColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: effectiveColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Item 2: Green checkmark in top-right corner for matched rule
              if (isMatched)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// F136 (Sprint 52): Skip -- leaves this email unchanged and moves to the next
/// unaddressed one. Harold: about the same size as the safe sender and rule
/// buttons.
Widget _buildSkipButton(VoidCallback onSkip) {
  return Semantics(
    container: true,
    button: true,
    excludeSemantics: true,
    label: 'Skip',
    hint: 'Leave this email unchanged and go to the next unaddressed item',
    onTap: onSkip,
    child: Tooltip(
      message: 'Skip -- leave unchanged, go to the next unaddressed item',
      child: InkWell(
        onTap: onSkip,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blueGrey.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blueGrey.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, size: 16, color: Colors.blueGrey.shade700),
              const SizedBox(width: 6),
              Text(
                'Skip',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows the pop-up for [result], placed next to the row it came from.
///
/// [itemKey] is the row's key (the pop-up measures the row). [anchorPosition]
/// / [anchorSize] (Sprint 46, Harold item 2) are an explicit anchor used by
/// the auto-advance flow, where the next email's pop-up reuses the previous
/// pop-up's anchor so it appears at the same screen position (list rows get
/// fresh keys on every rebuild, so the next row's key is not addressable).
///
/// [onQuickAction] and [onSkip] receive the anchor the pop-up used, so the
/// screen can open the NEXT pop-up in the same place. The pop-up closes itself
/// before calling either; for a domain action it shows the F47 email-provider
/// warning first and calls nothing when the user cancels.
void showEmailDetailPopup(
  BuildContext context, {
  required EmailActionResult result,
  required EvaluationResult? effectiveEval,
  required String accountEmail,
  required bool showSkip,
  required void Function(
          QuickActionRequest request, Offset? anchorPosition, Size? anchorSize)
      onQuickAction,
  required void Function(Offset? anchorPosition, Size? anchorSize) onSkip,
  GlobalKey? itemKey,
  Offset? anchorPosition,
  Size? anchorSize,
}) {
  final email = result.email;
  final bodyParser = EmailBodyParser();
  // Extract raw email and domain (Punycode format) - used for block rule creation
  final rawSenderEmail = bodyParser.extractEmailAddress(email.from);
  final rawSenderDomain = bodyParser.extractDomainFromEmail(email.from);
  // Normalized email (plus-sign stripped) - used for safe sender pattern creation
  // This matches how SafeSenderList.findMatch() normalizes emails during evaluation
  final normalizedSenderEmail =
      PatternNormalization.normalizeFromHeader(email.from);
  // Decode for display only
  final displaySenderEmail =
      PatternNormalization.normalizeAndDecodeEmail(rawSenderEmail);
  final displaySenderDomain = rawSenderDomain != null
      ? PatternNormalization.decodePunycodeDomain(rawSenderDomain)
      : null;
  // Extract root domain from RAW domain (for rule creation)
  final rawRootDomain = PatternNormalization.extractRootDomain(rawSenderDomain);
  // Decode root domain for display
  final displayRootDomain = rawRootDomain != null
      ? PatternNormalization.decodePunycodeDomain(rawRootDomain)
      : null;
  // F21: the effective evaluation (re-evaluated after inline rule assignment)
  final matchedRule = effectiveEval?.matchedRule ?? '';
  final isDeleted = effectiveEval?.shouldDelete == true;
  final isSafeSender = effectiveEval?.isSafeSender == true;

  // Clean subject for display
  final cleanedSubject =
      PatternNormalization.cleanSubjectForDisplay(email.subject);
  final displaySubject =
      cleanedSubject.isNotEmpty ? cleanedSubject : '(No subject)';

  // Format date/time
  final dateStr = formatReceivedDateForDisplay(email.receivedDate);

  // Sprint 46 (Harold speed follow-up): predicates predicting which OTHER
  // emails the quick action about to be taken will ALSO address.
  bool coversSameEmail(EmailMessage o) =>
      bodyParser.extractEmailAddress(o.from).toLowerCase().trim() ==
      rawSenderEmail.toLowerCase().trim();
  bool coversExactDomain(EmailMessage o) =>
      rawSenderDomain != null &&
      bodyParser.extractDomainFromEmail(o.from) == rawSenderDomain;
  bool coversEntireDomain(EmailMessage o) {
    final target = rawRootDomain ?? rawSenderDomain;
    if (target == null) return false;
    final otherDomain = bodyParser.extractDomainFromEmail(o.from);
    return PatternNormalization.extractRootDomain(otherDomain) == target;
  }

  bool coversSubject(EmailMessage o) =>
      PatternNormalization.cleanSubjectForDisplay(o.subject)
          .toLowerCase()
          .contains(cleanedSubject.toLowerCase());

  // Issue 6: Calculate position for CSS-like popup positioning
  Offset? itemPosition = anchorPosition;
  Size? itemSize = anchorSize;
  if (itemKey != null) {
    final RenderBox? renderBox =
        itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      itemPosition = renderBox.localToGlobal(Offset.zero);
      itemSize = renderBox.size;
    }
  }

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    // F178 round 2: control the safe area OURSELVES. showDialog's default
    // useSafeArea:true wraps the Stack in a SafeArea whose size and
    // clipping do not match the GLOBAL anchor coordinates the position
    // math uses -- the popup overflowed the SafeArea'd Stack and was
    // flush-CLIPPED at its bottom edge (Harold's first-row screenshot:
    // "Block Subject" simply cut off). With useSafeArea:false the Stack
    // spans the full screen (matching the anchors), and the inset math
    // below keeps the popup inside the safe area explicitly.
    useSafeArea: false,
    builder: (dialogContext) {
      // Closes the pop-up, then reports the choice with the anchor used.
      void choose(QuickActionRequest request) {
        Navigator.pop(dialogContext);
        onQuickAction(request, itemPosition, itemSize);
      }

      // F47: a DOMAIN action warns first for an email-provider domain.
      Future<void> chooseDomain(
          QuickActionRequest request, String domain, bool isBlockRule) async {
        Navigator.pop(dialogContext);
        if (!await checkProviderDomainWarning(context,
            domain: domain, isBlockRule: isBlockRule)) {
          return;
        }
        onQuickAction(request, itemPosition, itemSize);
      }

      // Get screen dimensions.
      // F178 round 2 (Sprint 62 MV, Harold's first-row screenshot): read
      // the insets from the ROOT VIEW, not an inherited MediaQuery. Both
      // the screen's context (Scaffold body) and the dialog's context
      // (inside showDialog's SafeArea, when enabled) see CONSUMED padding
      // -- zeros -- which silently degenerated round 1's safe-area math to
      // the old full-screen math on a real phone, while the flat
      // widget-test harness kept the padding and stayed green.
      // MediaQueryData.fromView cannot be consumed by anything.
      final mediaQuery = MediaQueryData.fromView(View.of(context));
      final screenSize = mediaQuery.size;
      final screenHeight = screenSize.height;
      // F178 (Sprint 62, found by Harold with screenshots): on a phone,
      // `size.height` includes the system status/navigation bar areas, so
      // the Sprint 60 clamp below let the popup's BOTTOM sit under the
      // Android navigation bar -- "Block Subject" and the rows below it
      // were unreachable even at full scroll. All height/position math now
      // works within the SAFE area. On desktop the insets are zero, so
      // this is a no-op there (ADR-0042: parity by construction).
      final safeTop = mediaQuery.padding.top;
      final safeBottom = mediaQuery.padding.bottom;
      final safeScreenBottom = screenHeight - safeBottom;
      final safeHeight = screenHeight - safeTop - safeBottom;
      // F178 round 2 (Harold, Sprint 62 MV): on COMPACT widths the popup
      // is TIED TO THE BOTTOM of the safe area and grows upward as large
      // as its content needs -- the same pattern the Windows app uses at
      // very small window sizes. Anchor-relative placement is a desktop
      // affordance (it keeps the source row and the NEXT row visible
      // beside the popup); on a phone the popup covers the list anyway,
      // and bottom-anchoring guarantees the bottom actions ("Block
      // Subject") are always at a fixed, reachable place.
      final isCompactWidth = screenSize.width < 600;
      final popupHeight = isCompactWidth
          ? safeHeight - 24 // grow toward the top, small breathing gap
          : safeHeight * 0.6; // desktop: within safe area (Sprint 60 cap)

      // Calculate position
      double? top;
      double? bottom;

      // Sprint 60 MV (Harold): the popup must FIT fully inside the window
      // for EVERY visible row. `popupHeight` is an estimate the real
      // content can exceed, and the branches below never clamped `top` --
      // so for rows near the TOP of the list the popup started low enough
      // that its bottom rows ("Block Subject") were clipped off-window.
      // Two-part fix: (1) every `top` is clamped so top + popupHeight stays
      // on-screen; (2) the popup itself is hard-capped at `popupHeight`
      // (see the ConstrainedBox below), so the clamp is against the REAL
      // maximum height, with the existing inner SingleChildScrollView as
      // the graceful fallback if content ever exceeds the cap.
      // F178: clamp against the SAFE bottom, and never above the safe top.
      final maxTop = (safeScreenBottom - popupHeight - 8)
          .clamp(safeTop + 8.0, screenHeight);

      if (isCompactWidth) {
        // Bottom-anchored: Positioned(bottom:) measures from the STACK's
        // bottom (the full screen with useSafeArea: false), so the system
        // inset is added explicitly. The ConstrainedBox cap lets content
        // grow upward to popupHeight; shorter content hugs the bottom.
        bottom = safeBottom;
      } else if (itemPosition != null && itemSize != null) {
        final itemBottom = itemPosition.dy + itemSize.height;
        final spaceBelow = safeScreenBottom - itemBottom;
        final spaceAbove = itemPosition.dy;
        // Sprint 46 manual-testing feedback (Harold 2026-07-11): when the
        // screen has room, drop the popup one additional email-height lower
        // (the clicked tile's own height is the best available estimate of
        // one list item) so the NEXT item in the list stays visible above
        // the popup -- after acting on this email the user can immediately
        // click the next one instead of it being covered.
        final oneItemGap = itemSize.height;

        if (spaceBelow >= popupHeight + oneItemGap) {
          // Show one email lower, keeping the next list item clickable
          top = (itemBottom + oneItemGap + 8).clamp(0.0, maxTop);
        } else if (spaceBelow >= popupHeight) {
          // Show directly below email (no room to also expose the next item)
          top = (itemBottom + 8).clamp(0.0, maxTop);
        } else if (spaceAbove - safeTop >= popupHeight + 8) {
          // Show above email. PR #335 cowork review: the +8 belongs in the
          // guard too -- with spaceAbove in [popupHeight, popupHeight+8)
          // the 8px gap pushed the popup's top edge up to 8px off-window.
          // Sprint 62 code review (M-1): spaceAbove measures from y=0, but
          // only the space below safeTop is usable -- without subtracting
          // it, a top inset (large-screen Android/foldable; zero on
          // desktop) let the popup's top edge extend into the status bar.
          bottom = screenHeight - itemPosition.dy + 8; // 8px gap
        } else {
          // Not enough room above or below -- as high as needed to fit.
          top = itemPosition.dy.clamp(0.0, maxTop);
        }
      }

      return Stack(
        children: [
          Positioned(
            top: top,
            bottom: bottom,
            left: 16,
            right: 16,
            // F151e (Sprint 58) / Sprint 60 MV round 3 (Harold): on desktop the
            // popup's LEFT edge sits around 35% of the width and it extends to
            // the right edge, so the rows' sender and subject stay visible on
            // the left; on compact widths it takes the FULL width (it covers
            // the list anyway). FractionallySizedBox scales with the window.
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              // Sprint 62 code review (M-2): reuse the fromView-based
              // isCompactWidth so position math and width factor cannot
              // disagree when the inherited MediaQuery diverges from the
              // raw view size.
              widthFactor: isCompactWidth ? 1.0 : 0.65,
              child: ConstrainedBox(
                // maxHeight (Sprint 60 MV): the hard cap that makes the
                // clamped `top` a real fit guarantee -- content beyond the
                // cap scrolls inside the popup instead of clipping off the
                // window's bottom edge. Width is governed by widthFactor
                // alone (PR #335 cowork review).
                constraints: BoxConstraints(maxHeight: popupHeight),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Handle bar
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // One-line summary matching the row format.
                            // F230 (Sprint 72): Skip is NOT in this row. The
                            // sender is Expanded with ellipsis, so every pixel
                            // Skip took came out of the address (at 411px it
                            // rendered "kimmeyharold@help.ramirezo...").
                            Row(
                              children: [
                                resultActionIcon(result.action),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displaySenderEmail,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                result.success
                                    ? const Icon(Icons.check,
                                        color: Colors.green, size: 18)
                                    : const Icon(Icons.error,
                                        color: Colors.red, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Subtitle line: folder • subject • rule
                            Text(
                              '${email.folderName} • $displaySubject • ${matchedRule.isNotEmpty ? matchedRule : "No rule"}',
                              // F230 (Sprint 72): a theme style, not a literal
                              // size -- theme styles honour the OS font-size
                              // accessibility setting (ADR-0037). One shared
                              // change, no platform exception (Harold).
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey[700]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Date/time and the account (F283 R-6).
                            Row(
                              children: [
                                Icon(Icons.schedule,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  // F216 (Sprint 75, Harold "2. a"): matches
                                  // the folder/subject/rule line above.
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                                if (accountEmail.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.account_circle_outlined,
                                      size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  // F230: BOUNDED. Flexible + ellipsis makes a
                                  // long account email yield instead of the row
                                  // breaking when Skip shares the row.
                                  Flexible(
                                    child: Text(
                                      accountEmail,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                                // F230 (Sprint 72): Skip lives at the bottom
                                // right of this section, where there is room.
                                // Shown only where an unaddressed sequence
                                // exists to advance through ([showSkip]).
                                if (showSkip) ...[
                                  const Spacer(),
                                  _buildSkipButton(() {
                                    Navigator.pop(dialogContext);
                                    onSkip(itemPosition, itemSize);
                                  }),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Action result badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: resultActionColor(result.action)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                resultActionDescription(result),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: resultActionColor(result.action),
                                ),
                              ),
                            ),
                            const Divider(height: 20),

                            // === SHARED PROVIDER HINT ===
                            if (rawSenderDomain != null &&
                                CommonEmailProviders.isCommonProvider(
                                    rawSenderDomain)) ...[
                              Builder(builder: (_) {
                                final providerName =
                                    CommonEmailProviders.getProviderName(
                                            rawSenderDomain) ??
                                        'Unknown';
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.amber
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16, color: Colors.amber[800]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$providerName is a shared email provider. '
                                          'Use "Exact Email" when adding rules for this sender.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.amber[900]),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                            ],

                            // === SAFE SENDER SECTION ===
                            // Issue 5: Always show Safe Sender options for all emails
                            Text(
                              isSafeSender
                                  ? 'Update Safe Sender'
                                  : 'Add to Safe Senders',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            // MT-1 (Sprint 50, Harold): FIXED 3-column grid -- the
                            // Email | Exact Domain | Entire Domain actions keep the
                            // SAME position for every item (equal-width cells,
                            // ellipsized subtitles, disabled placeholder when a
                            // domain action is unavailable) so muscle memory works
                            // across items.
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: buildInlineActionButton(
                                      icon: Icons.person,
                                      label: 'Exact Email',
                                      subtitle: displaySenderEmail,
                                      color: Colors.green,
                                      isMatched: isSafeSender &&
                                          effectiveEval?.matchedPatternType ==
                                              'exact_email',
                                      // Normalized email (plus-signs stripped)
                                      // to match SafeSenderList evaluation.
                                      onTap: () => choose(QuickActionRequest(
                                        kind: QuickActionKind.safeSender,
                                        type: 'exact',
                                        value: normalizedSenderEmail,
                                        covers: coversSameEmail,
                                      )),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: rawSenderDomain == null
                                        ? buildInlineActionButton(
                                            icon: Icons.domain,
                                            label: 'Exact Domain',
                                            subtitle: 'Not available',
                                            color: Colors.green,
                                            onTap: null,
                                          )
                                        : buildInlineActionButton(
                                            icon: Icons.domain,
                                            label: 'Exact Domain',
                                            subtitle: '@$displaySenderDomain',
                                            color: Colors.green,
                                            isMatched: isSafeSender &&
                                                effectiveEval
                                                        ?.matchedPatternType ==
                                                    'exact_domain',
                                            onTap: () => chooseDomain(
                                                QuickActionRequest(
                                                  kind:
                                                      QuickActionKind.safeSender,
                                                  type: 'exactDomain',
                                                  value: '@$rawSenderDomain',
                                                  covers: coversExactDomain,
                                                ),
                                                rawSenderDomain,
                                                false),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: rawSenderDomain == null
                                        ? buildInlineActionButton(
                                            icon: Icons.public,
                                            label: 'Entire Domain',
                                            subtitle: 'Not available',
                                            color: Colors.green,
                                            onTap: null,
                                          )
                                        : buildInlineActionButton(
                                            icon: Icons.public,
                                            label: 'Entire Domain',
                                            subtitle:
                                                '@*.${displayRootDomain ?? displaySenderDomain}',
                                            color: Colors.green,
                                            isMatched: isSafeSender &&
                                                effectiveEval
                                                        ?.matchedPatternType ==
                                                    'entire_domain',
                                            onTap: () => chooseDomain(
                                                QuickActionRequest(
                                                  kind:
                                                      QuickActionKind.safeSender,
                                                  type: 'entireDomain',
                                                  value: rawRootDomain ??
                                                      rawSenderDomain,
                                                  covers: coversEntireDomain,
                                                ),
                                                rawRootDomain ?? rawSenderDomain,
                                                false),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // === BLOCK RULE SECTION ===
                            // Issue 5: Always show Block Rule options for all emails
                            const Text(
                              'Create Block Rule',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            // MT-1 (Sprint 50, Harold): same fixed 3-column grid
                            // as the Safe row -- Block Entire Domain is ALWAYS
                            // the right-most cell. Block Subject gets its own
                            // full-width row below so its presence/absence never
                            // shifts the grid.
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: buildInlineActionButton(
                                      icon: Icons.person_off,
                                      label: 'Block Email',
                                      subtitle: displaySenderEmail,
                                      color: Colors.red,
                                      isMatched: isDeleted &&
                                          effectiveEval?.matchedPatternType ==
                                              'exact_email',
                                      onTap: () => choose(QuickActionRequest(
                                        kind: QuickActionKind.blockRule,
                                        type: 'from',
                                        value: rawSenderEmail,
                                        covers: coversSameEmail,
                                      )),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: rawSenderDomain == null
                                        ? buildInlineActionButton(
                                            icon: Icons.domain_disabled,
                                            label: 'Block Exact Domain',
                                            subtitle: 'Not available',
                                            color: Colors.red,
                                            onTap: null,
                                          )
                                        : buildInlineActionButton(
                                            icon: Icons.domain_disabled,
                                            label: 'Block Exact Domain',
                                            subtitle: '@$displaySenderDomain',
                                            color: Colors.red,
                                            isMatched: isDeleted &&
                                                effectiveEval
                                                        ?.matchedPatternType ==
                                                    'exact_domain',
                                            onTap: () => chooseDomain(
                                                QuickActionRequest(
                                                  kind:
                                                      QuickActionKind.blockRule,
                                                  type: 'exactDomain',
                                                  value: '@$rawSenderDomain',
                                                  covers: coversExactDomain,
                                                ),
                                                rawSenderDomain,
                                                true),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: rawSenderDomain == null
                                        ? buildInlineActionButton(
                                            icon: Icons.public_off,
                                            label: 'Block Entire Domain',
                                            subtitle: 'Not available',
                                            color: Colors.red,
                                            onTap: null,
                                          )
                                        : buildInlineActionButton(
                                            icon: Icons.public_off,
                                            label: 'Block Entire Domain',
                                            subtitle:
                                                '@*.${displayRootDomain ?? displaySenderDomain}',
                                            color: Colors.red,
                                            isMatched: isDeleted &&
                                                effectiveEval
                                                        ?.matchedPatternType ==
                                                    'entire_domain',
                                            onTap: () => chooseDomain(
                                                QuickActionRequest(
                                                  kind:
                                                      QuickActionKind.blockRule,
                                                  type: 'entireDomain',
                                                  value: rawRootDomain ??
                                                      rawSenderDomain,
                                                  covers: coversEntireDomain,
                                                ),
                                                rawRootDomain ?? rawSenderDomain,
                                                true),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            if (cleanedSubject.isNotEmpty &&
                                cleanedSubject != '(No subject)') ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: buildInlineActionButton(
                                  icon: Icons.subject,
                                  label: 'Block Subject',
                                  subtitle: cleanedSubject.length > 20
                                      ? '${cleanedSubject.substring(0, 20)}...'
                                      : cleanedSubject,
                                  color: Colors.orange,
                                  isMatched: isDeleted &&
                                      effectiveEval?.matchedPatternType ==
                                          'subject',
                                  onTap: () => choose(QuickActionRequest(
                                    kind: QuickActionKind.blockRule,
                                    type: 'subject',
                                    value: cleanedSubject,
                                    covers: coversSubject,
                                  )),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ), // Close SelectionArea
                ), // Close Material
              ), // Close ConstrainedBox
            ), // Close FractionallySizedBox
          ), // Close Positioned
        ],
      );
    },
  );
}
