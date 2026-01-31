import 'package:flutter/material.dart';

/// Accessibility helper utilities
///
/// Provides constants and helper methods for improving app accessibility.
class AccessibilityHelper {
  /// Semantic labels for common actions
  static const String addAccountLabel = 'Add new email account';
  static const String deleteAccountLabel = 'Delete account';
  static const String selectAccountLabel = 'Select account to scan';
  static const String startScanLabel = 'Start scanning for spam';
  static const String viewResultsLabel = 'View scan results';
  static const String refreshLabel = 'Refresh content';
  static const String backLabel = 'Go back to previous screen';

  /// Minimum touch target size per accessibility guidelines
  static const double minTouchTargetSize = 48.0;

  /// Wrap widget with minimum touch target size
  static Widget withMinTouchTarget({
    required Widget child,
    double? width,
    double? height,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? minTouchTargetSize,
        minHeight: height ?? minTouchTargetSize,
      ),
      child: child,
    );
  }

  /// Create accessible button
  static Widget accessibleButton({
    required Widget child,
    required VoidCallback onPressed,
    required String semanticLabel,
    String? tooltip,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Tooltip(
        message: tooltip ?? semanticLabel,
        child: TextButton(
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }

  /// Announce message to screen readers
  static void announceMessage(BuildContext context, String message) {
    // This will be announced by screen readers
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Check if high contrast mode is enabled
  static bool isHighContrast(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }

  /// Get contrast-aware color
  static Color getContrastAwareColor({
    required BuildContext context,
    required Color normalColor,
    required Color highContrastColor,
  }) {
    return isHighContrast(context) ? highContrastColor : normalColor;
  }
}

/// Extension for adding semantic labels to common widgets
extension AccessibleWidget on Widget {
  /// Add semantic label to this widget
  Widget withSemanticLabel(String label) {
    return Semantics(
      label: label,
      child: this,
    );
  }

  /// Mark this widget as a button for screen readers
  Widget asButton(String label) {
    return Semantics(
      label: label,
      button: true,
      child: this,
    );
  }

  /// Mark this widget as a header
  Widget asHeader() {
    return Semantics(
      header: true,
      child: this,
    );
  }

  /// Exclude this widget from semantic tree (decorative elements)
  Widget excludeSemantics() {
    return ExcludeSemantics(child: this);
  }
}
