import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Minimal UI screen for background scan execution
///
/// Displays only a simple status indicator while the background scan runs.
/// No navigation controls, settings buttons, or user interaction - designed
/// to be non-intrusive and exit automatically after scan completes.
class BackgroundScanProgressScreen extends StatelessWidget {
  static final Logger _logger = Logger();

  const BackgroundScanProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    _logger.d('Displaying background scan progress screen');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon or Logo
            Icon(
              Icons.email_outlined,
              size: 80,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 32),

            // Progress Indicator
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 24),

            // Status Text
            Text(
              'Scanning emails in background...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),

            // Secondary Text
            Text(
              'This will complete automatically',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
