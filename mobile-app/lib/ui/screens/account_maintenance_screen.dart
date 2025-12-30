/// Account Maintenance Screen for managing email accounts
/// 
/// Allows users to:
/// - View saved email accounts
/// - Configure per-account folder scanning preferences
/// - Remove accounts
/// - Trigger one-time scans
/// 
/// ✨ PHASE 2 SPRINT 3: Account management and maintenance options
library;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../../adapters/storage/secure_credentials_store.dart';
import '../../core/providers/email_scan_provider.dart';
import '../../core/providers/rule_set_provider.dart';
import 'folder_selection_screen.dart';

/// Account maintenance screen
class AccountMaintenanceScreen extends StatefulWidget {
  const AccountMaintenanceScreen({super.key});

  @override
  State<AccountMaintenanceScreen> createState() =>
      _AccountMaintenanceScreenState();
}

class _AccountMaintenanceScreenState extends State<AccountMaintenanceScreen> {
  final Logger _logger = Logger();
  final SecureCredentialsStore _credStore = SecureCredentialsStore();
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  /// Load saved accounts
  Future<void> _loadAccounts() async {
    try {
      final accounts = await _credStore.getSavedAccounts();
      setState(() {
        _accounts = accounts
            .map((accountId) {
              // Parse accountId format: "platform-email"
              final parts = accountId.split('-');
              final platform = parts.isNotEmpty ? parts[0] : 'unknown';
              final email = parts.length > 1 ? parts.sublist(1).join('-') : accountId;

              return SavedAccount(
                accountId: accountId,
                platform: platform,
                email: email,
                addedDate: DateTime.now(), // In real implementation, would retrieve from storage
              );
            })
            .toList();

        _isLoading = false;
      });

      _logger.i('📋 Loaded ${_accounts.length} saved account(s)');
    } catch (e) {
      _logger.e('Failed to load accounts: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load accounts: $e')),
        );
      }
    }
  }

  /// Show folder selection for account (one-time scan)
  Future<void> _showFolderSelectionForAccount(SavedAccount account) async {
    final folders = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FolderSelectionScreen(
        platformId: account.platform,
        accountId: account.accountId,
        accountEmail: account.email,
        onFoldersSelected: (_) {
          // Callback handled by FolderSelectionScreen
        },
      ),
    );

    if (folders != null && mounted) {
      _logger.i('✅ Selected folders for ${account.email}: $folders');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: ${folders.join(", ")}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Remove account with confirmation
  Future<void> _removeAccount(SavedAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove ${account.email} (${account.platform.toUpperCase()})?'),
            const SizedBox(height: 12),
            const Text(
              'The stored credentials will be deleted. You can add the account again later.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _credStore.deleteCredentials(account.accountId);
        _logger.i('✅ Removed account: ${account.email}');

        setState(() {
          _accounts.removeWhere((a) => a.accountId == account.accountId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Account removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _logger.e('Failed to remove account: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove account: $e')),
          );
        }
      }
    }
  }

  /// Trigger one-time scan for account
  Future<void> _triggerOneTimeScan(SavedAccount account) async {
    final scanProvider = context.read<EmailScanProvider>();

    // Initialize scan mode
    scanProvider.initializeScanMode(mode: ScanMode.readonly);

    _logger.i('🔍 Initiating one-time scan for ${account.email}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Starting scan for ${account.email}...'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    // In real implementation, would navigate to ScanProgressScreen
    // For now, just show a message
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scan Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account: ${account.email}'),
              Text('Platform: ${account.platform.toUpperCase()}'),
              const SizedBox(height: 12),
              const Text(
                'Scan will run in read-only mode by default. Navigate to the main screen to monitor progress.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Maintenance'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No accounts configured',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first email account to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _accounts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) => _buildAccountTile(_accounts[index]),
                ),
    );
  }

  /// Build account tile with actions
  Widget _buildAccountTile(SavedAccount account) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.email,
          color: _getAccountColor(account.platform),
        ),
        title: Text(account.email),
        subtitle: Text(
          account.platform.toUpperCase(),
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Account info
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Credentials stored securely',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Added: ${_formatDate(account.addedDate)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select Folders'),
                        onPressed: () =>
                            _showFolderSelectionForAccount(account),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Scan'),
                        onPressed: () => _triggerOneTimeScan(account),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Remove button
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Remove Account',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () => _removeAccount(account),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get color for platform icon
  Color _getAccountColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'aol':
        return Colors.red.shade600;
      case 'gmail':
        return Colors.blue.shade600;
      case 'outlook':
        return Colors.blue.shade400;
      case 'yahoo':
        return Colors.purple.shade600;
      case 'icloud':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// Saved account model
class SavedAccount {
  final String accountId; // "{platform}-{email}"
  final String platform; // "aol", "gmail", etc.
  final String email;
  final DateTime addedDate;

  SavedAccount({
    required this.accountId,
    required this.platform,
    required this.email,
    required this.addedDate,
  });
}
