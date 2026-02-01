import 'package:flutter/material.dart';

/// Error display widget with recovery actions
///
/// Displays error messages with helpful recovery suggestions and action buttons.
class ErrorDisplay extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData icon;

  const ErrorDisplay({
    super.key,
    this.title = 'Something Went Wrong',
    required this.message,
    this.actionLabel,
    this.onActionPressed,
    this.icon = Icons.error_outline,
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
            // Error icon
            Icon(
              icon,
              size: 80,
              color: colorScheme.error,
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

            // Error message
            Text(
              message,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            // Action button
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
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

/// Predefined error displays for common scenarios

class NetworkErrorDisplay extends StatelessWidget {
  final VoidCallback onRetry;

  const NetworkErrorDisplay({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'Connection Error',
      message: 'Unable to connect to the email server. Please check your internet connection and try again.',
      icon: Icons.wifi_off_outlined,
      actionLabel: 'Retry',
      onActionPressed: onRetry,
    );
  }
}

class AuthenticationErrorDisplay extends StatelessWidget {
  final VoidCallback onReauthenticate;

  const AuthenticationErrorDisplay({
    super.key,
    required this.onReauthenticate,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      title: 'Authentication Failed',
      message: 'Your login credentials have expired or are invalid. Please sign in again to continue.',
      icon: Icons.lock_outline,
      actionLabel: 'Sign In Again',
      onActionPressed: onReauthenticate,
    );
  }
}

class GenericErrorDisplay extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const GenericErrorDisplay({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      message: errorMessage,
      actionLabel: onRetry != null ? 'Try Again' : null,
      onActionPressed: onRetry,
    );
  }
}

/// Error dialog helper
class ErrorDialog {
  /// Show error dialog with recovery action
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (actionLabel != null && onActionPressed != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onActionPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  /// Show network error dialog
  static Future<void> showNetworkError({
    required BuildContext context,
    required VoidCallback onRetry,
  }) async {
    return show(
      context: context,
      title: 'Connection Error',
      message: 'Unable to connect to the email server. Please check your internet connection and try again.',
      actionLabel: 'Retry',
      onActionPressed: onRetry,
    );
  }

  /// Show authentication error dialog
  static Future<void> showAuthenticationError({
    required BuildContext context,
    required VoidCallback onReauthenticate,
  }) async {
    return show(
      context: context,
      title: 'Authentication Failed',
      message: 'Your login credentials have expired or are invalid. Please sign in again to continue.',
      actionLabel: 'Sign In Again',
      onActionPressed: onReauthenticate,
    );
  }
}
