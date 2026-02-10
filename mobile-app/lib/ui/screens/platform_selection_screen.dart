import 'package:flutter/material.dart';
import '../../adapters/email_providers/platform_registry.dart';
import '../../adapters/email_providers/spam_filter_platform.dart';
import 'account_setup_screen.dart';

/// Platform selection screen - first step in account setup
/// 
/// Displays available email providers (AOL, Gmail, Outlook, Yahoo)
/// and guides user to appropriate setup form
class PlatformSelectionScreen extends StatefulWidget {
  const PlatformSelectionScreen({super.key});

  @override
  State<PlatformSelectionScreen> createState() =>
      _PlatformSelectionScreenState();
}

class _PlatformSelectionScreenState extends State<PlatformSelectionScreen> {
  // [NEW] ISSUE #125: Demo mode toggle state
  bool _showDemoMode = false;

  /// Get all supported platforms for display
  List<PlatformInfo> _getSupportedPlatforms() {
    final allPlatforms = PlatformRegistry.getSupportedPlatforms();
    
    // [UPDATED] ISSUE #125: Include demo mode (phase 0) if toggle enabled
    // Otherwise, filter to Phase 1 + Phase 2 platforms only (exclude Phase 3+ for now)
    if (_showDemoMode) {
      return allPlatforms.where((p) => p.phase <= 2 || p.phase == 0).toList();
    } else {
      return allPlatforms.where((p) => p.phase <= 2 && p.phase != 0).toList();
    }
  }

  /// Navigate to account setup screen for selected platform
  void _selectPlatform(PlatformInfo platformInfo) {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (context) => AccountSetupScreen(
          platformId: platformInfo.id,
          platformDisplayName: platformInfo.displayName,
        ),
      ),
    )
        .then((added) {
      if (added == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  /// Show setup instructions for selected platform
  void _showSetupInstructions(PlatformInfo platformInfo) {
    showDialog(
      context: context,
      builder: (context) => _SetupInstructionsDialog(
        platformInfo: platformInfo,
        onProceed: () {
          Navigator.of(context).pop();
          _selectPlatform(platformInfo);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platforms = _getSupportedPlatforms();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Email Provider'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section with introduction
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Email Provider',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your email provider to get started with spam filtering',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  // [NEW] ISSUE #125: Demo Mode toggle
                  Card(
                    color: _showDemoMode 
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: SwitchListTile(
                      title: const Text('Show Demo Mode'),
                      subtitle: const Text('Test with 50+ sample emails (no email account needed)'),
                      value: _showDemoMode,
                      onChanged: (enabled) {
                        setState(() => _showDemoMode = enabled);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Platform cards section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Phase 1 - MVP platforms
                  _buildPhaseHeader('Available Now', 1),
                  const SizedBox(height: 12),
                  ...platforms
                      .where((p) => p.phase == 1)
                      .map((p) => _buildPlatformCard(p))
                      .toList(),

                  // Phase 2 platforms
                  const SizedBox(height: 24),
                  _buildPhaseHeader('Coming Soon', 2),
                  const SizedBox(height: 12),
                  ...platforms
                      .where((p) => p.phase == 2)
                      .map((p) => _buildPlatformCard(p))
                      .toList(),

                  // Info section
                  const SizedBox(height: 32),
                  _buildInfoCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build section header for platform phases
  Widget _buildPhaseHeader(String label, int phase) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[300],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  /// Build individual platform card
  Widget _buildPlatformCard(PlatformInfo platformInfo) {
    final isPhase2 = platformInfo.phase == 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: isPhase2
                  ? Colors.grey[200]
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: _getPlatformIcon(platformInfo.id, isPhase2),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(platformInfo.displayName),
            if (isPhase2)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Phase 2',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              platformInfo.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              _getAuthMethodLabel(platformInfo.authMethod),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: isPhase2
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
        enabled: !isPhase2,
        onTap: isPhase2
            ? () => _showComingSoonDialog(platformInfo)
            : () => _showSetupInstructions(platformInfo),
        selected: false,
      ),
    );
  }

  /// Build information card with helpful tips
  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 12),
                Text(
                  'App Passwords',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'For security, we never ask for your main account password.\n\n- Gmail uses Google Sign-In (OAuth 2.0).\n- AOL/Yahoo/iCloud use app-specific passwords.\n\nTap on your provider to see setup steps.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog for Phase 2 platforms (coming soon)
  void _showComingSoonDialog(PlatformInfo platformInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text(
          '${platformInfo.displayName} support is planned for Phase 2.\n\n'
          'For now, you can use ${platformInfo.displayName} via our generic IMAP support if you have an app password available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  /// Get auth method display label
  String _getAuthMethodLabel(AuthMethod authMethod) {
    return switch (authMethod) {
      AuthMethod.none => 'No Authentication (Demo)',
      AuthMethod.appPassword => 'App Password Authentication',
      AuthMethod.oauth2 => 'OAuth 2.0 Sign-In',
      AuthMethod.basicAuth => 'Email & Password',
      AuthMethod.apiKey => 'API Key Authentication',
    };
  }

  /// Get platform-specific icon
  Widget _getPlatformIcon(String platformId, bool isDisabled) {
    final color = isDisabled ? Colors.grey[400] : null;
    switch (platformId) {
      case 'aol':
        return Icon(
          Icons.mail,
          color: color,
        );
      case 'gmail':
        return Icon(
          Icons.mail,
          color: color,
        );
      case 'outlook':
        return Icon(
          Icons.mail,
          color: color,
        );
      case 'yahoo':
        return Icon(
          Icons.mail,
          color: color,
        );
      case 'icloud':
        return Icon(
          Icons.mail,
          color: color,
        );
      default:
        return Icon(
          Icons.mail,
          color: color,
        );
    }
  }
}

/// Dialog displaying platform-specific setup instructions
class _SetupInstructionsDialog extends StatefulWidget {
  final PlatformInfo platformInfo;
  final VoidCallback onProceed;

  const _SetupInstructionsDialog({
    required this.platformInfo,
    required this.onProceed,
  });

  @override
  State<_SetupInstructionsDialog> createState() =>
      _SetupInstructionsDialogState();
}

class _SetupInstructionsDialogState extends State<_SetupInstructionsDialog> {
  late bool _understood;

  @override
  void initState() {
    super.initState();
    // Gmail uses OAuth, so no app password checkbox needed
    _understood = widget.platformInfo.id == 'gmail';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.platformInfo.displayName} Setup'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Before connecting, you\'ll need to generate an app password:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildSetupSteps(),
            const SizedBox(height: 16),
            if (widget.platformInfo.id != 'gmail')
              CheckboxListTile(
                value: _understood,
                onChanged: (value) =>
                    setState(() => _understood = value ?? false),
                title: const Text('I have my app password ready'),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.platformInfo.id == 'gmail')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_open, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Sign-In opens when you continue. No app password needed.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _understood ? widget.onProceed : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  /// Build platform-specific setup steps
  Widget _buildSetupSteps() {
    return switch (widget.platformInfo.id) {
      'aol' => _buildAolSteps(),
      'yahoo' => _buildYahooSteps(),
      'icloud' => _buildICloudSteps(),
      'gmail' => _buildGmailSteps(),
      _ => _buildGenericSteps(),
    };
  }

  Widget _buildGmailSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(1, 'Click Continue to open Google sign-in'),
        _buildStep(2, 'Choose the Google account you want to connect'),
        _buildStep(3, 'Approve Gmail access so spam filtering can read messages'),
        _buildStep(4, 'Return to the app to finish setup'),
      ],
    );
  }

  Widget _buildAolSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(1, 'Go to AOL Account Settings'),
        _buildStep(2, 'Select "Account Security" from the left menu'),
        _buildStep(3, 'Click "Generate app password"'),
        _buildStep(4, 'Choose "Other App" from the dropdown'),
        _buildStep(5, 'Enter "Spam Filter" as the app name'),
        _buildStep(6, 'Copy the generated 16-character password'),
      ],
    );
  }

  Widget _buildYahooSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(1, 'Go to Yahoo Account Security'),
        _buildStep(2, 'Click "Generate app password"'),
        _buildStep(3, 'Select "Other App" from the dropdown'),
        _buildStep(4, 'Enter "Spam Filter" as the app name'),
        _buildStep(5, 'Copy the generated 16-character password'),
      ],
    );
  }

  Widget _buildICloudSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(1, 'Go to appleid.apple.com'),
        _buildStep(2, 'Sign in with your Apple ID'),
        _buildStep(3, 'Go to "Account Security" section'),
        _buildStep(4, 'Under "App Passwords", click "Generate password"'),
        _buildStep(5, 'Select "Other (specify)" and enter "Spam Filter"'),
        _buildStep(6, 'Copy the generated password'),
      ],
    );
  }

  Widget _buildGenericSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(1, 'Visit your email provider\'s account settings'),
        _buildStep(2, 'Look for "Security" or "App Passwords" section'),
        _buildStep(3, 'Generate a new app password'),
        _buildStep(4, 'Copy the generated password'),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
