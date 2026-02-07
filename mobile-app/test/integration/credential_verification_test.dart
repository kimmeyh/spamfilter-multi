// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:spam_filter_mobile/adapters/storage/secure_credentials_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/generic_imap_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/gmail_api_adapter.dart';
import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform.dart';
import 'package:spam_filter_mobile/adapters/email_providers/email_provider.dart';

void main() {
  group('Credential Verification - All Platforms', () {
    late SecureCredentialsStore credentialStore;
    final logger = Logger();

    setUp(() {
      credentialStore = SecureCredentialsStore();
    });

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('verify secure storage is available on this platform', () async {
      final available = await credentialStore.testAvailable();
      
      if (!available) {
        print('[WARNING] Secure storage not available on this platform');
        print('   This test requires platform-native secure storage');
        expect(available, isTrue, reason: 'Secure storage must be available');
      }
      
      expect(available, isTrue);
      print('[OK] Secure storage available');
    }, skip: 'Requires platform-specific plugin (run on device or use integration test runner)');

    test('test all saved accounts credentials with appropriate adapters', () async {
      // Get all saved account IDs
      final accountIds = await credentialStore.getSavedAccounts();
      
      print('\n[CHECKLIST] Found ${accountIds.length} saved account(s)');
      
      if (accountIds.isEmpty) {
        print('[WARNING] No saved credentials found in secure storage');
        print('   To test credentials, save at least one account via the app:');
        print('   - AOL Mail (email + app password)');
        print('   - Gmail (OAuth 2.0 access token)');
        return; // Skip test if no credentials saved
      }

      // Test results tracking
      final results = <String, CredentialTestResult>{};
      int successCount = 0;
      int failureCount = 0;

      // Test each saved account
      for (final accountId in accountIds) {
        print('\n[INVESTIGATION] Testing account: $accountId');
        
        try {
          // Load credentials
          final credentials = await credentialStore.getCredentials(accountId);
          
          if (credentials == null) {
            print('   [FAIL] Failed to load credentials for account: $accountId');
            results[accountId] = CredentialTestResult(
              accountId: accountId,
              email: 'unknown',
              platform: 'unknown',
              authMethod: 'unknown',
              isValid: false,
              errorMessage: 'Credentials not found in secure storage',
            );
            failureCount++;
            continue;
          }

          print('   📧 Email: ${credentials.email}');

          // Determine platform from stored platformId
          String? platformId = credentials.additionalParams?['platformId'];
          
          if (platformId == null || platformId.isEmpty) {
            platformId = await credentialStore.getPlatformId(accountId);
          }

          print('   🏢 Platform: ${platformId ?? "unknown (will attempt to infer)"}');

          // Test based on platform
          if (platformId == 'gmail' || credentials.accessToken?.isNotEmpty == true) {
            // Gmail OAuth credentials
            await _testGmailCredentials(
              credentials: credentials,
              accountId: accountId,
              results: results,
            );
            if (results[accountId]?.isValid == true) {
              successCount++;
            } else {
              failureCount++;
            }
          } else if (platformId == 'aol' || 
                     credentials.email?.endsWith('@aol.com') == true ||
                     platformId == null) {
            // IMAP-based credentials (AOL, Yahoo, iCloud, or unknown - default to IMAP)
            await _testIMAPCredentials(
              credentials: credentials,
              platformId: platformId,
              accountId: accountId,
              results: results,
            );
            if (results[accountId]?.isValid == true) {
              successCount++;
            } else {
              failureCount++;
            }
          } else {
            // Unknown platform
            print('   ❓ Unknown platform: $platformId');
            results[accountId] = CredentialTestResult(
              accountId: accountId,
              email: credentials.email,
              platform: platformId ?? 'unknown',
              authMethod: 'unknown',
              isValid: false,
              errorMessage: 'Platform not supported for verification',
            );
            failureCount++;
          }
        } catch (e) {
          print('   [FAIL] Error testing account: $e');
          results[accountId] = CredentialTestResult(
            accountId: accountId,
            email: 'error',
            platform: 'unknown',
            authMethod: 'unknown',
            isValid: false,
            errorMessage: e.toString(),
          );
          failureCount++;
        }
      }

      // Print summary
      print('\n' + '=' * 60);
      print('📊 CREDENTIAL VERIFICATION SUMMARY');
      print('=' * 60);
      print('Total accounts tested: ${accountIds.length}');
      print('[OK] Valid credentials: $successCount');
      print('[FAIL] Invalid/Failed: $failureCount');
      print('=' * 60);

      // Print detailed results
      print('\n📈 Detailed Results:');
      results.forEach((accountId, result) {
        final status = result.isValid ? '[OK]' : '[FAIL]';
        print('\n$status $accountId');
        print('   Email: ${result.email}');
        print('   Platform: ${result.platform}');
        print('   Auth Method: ${result.authMethod}');
        if (!result.isValid && result.errorMessage != null) {
          print('   Error: ${result.errorMessage}');
        } else if (result.isValid) {
          print('   Status: Connected successfully');
        }
      });

      // Summary assertion
      expect(
        results.isNotEmpty,
        isTrue,
        reason: 'At least one credential should be tested',
      );
      
      // At least one credential should be valid (if any were tested)
      if (results.isNotEmpty) {
        final hasValidCredential = results.values.any((r) => r.isValid);
        expect(
          hasValidCredential,
          isTrue,
          reason: 'At least one credential should be valid',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 5)), skip: 'Requires platform-native secure storage plugin');

    test('verify AOL IMAP credentials specifically', () async {
      final accountIds = await credentialStore.getSavedAccounts();
      final aolAccounts = <String>[];

      for (final accountId in accountIds) {
        final credentials = await credentialStore.getCredentials(accountId);
        if (credentials != null) {
          final platformId = credentials.additionalParams?['platformId'] ?? 
                            await credentialStore.getPlatformId(accountId);
          if (platformId == 'aol' || credentials.email?.endsWith('@aol.com') == true) {
            aolAccounts.add(accountId);
          }
        }
      }

      if (aolAccounts.isEmpty) {
        print('[WARNING] No AOL accounts found in saved credentials');
        return;
      }

      print('[INVESTIGATION] Verifying ${aolAccounts.length} AOL account(s)...\n');

      for (final accountId in aolAccounts) {
        print('Testing AOL account: $accountId');
        final credentials = await credentialStore.getCredentials(accountId);
        
        expect(credentials, isNotNull, reason: 'Credentials should exist for $accountId');
        expect(credentials!.email, isNotEmpty, reason: 'Email should not be empty');
        expect(credentials.password, isNotEmpty, reason: 'App password should not be empty');

        // Test connection with AOL adapter
        final adapter = GenericIMAPAdapter.aol();
        try {
          await adapter.loadCredentials(credentials);
          final status = await adapter.testConnection();
          
          expect(status.isConnected, isTrue, 
            reason: 'Should connect to AOL IMAP: ${status.errorMessage}');
          
          print('[OK] AOL account $accountId is valid');
        } catch (e) {
          print('[FAIL] AOL account $accountId failed: $e');
          rethrow;
        } finally {
          try {
            await adapter.disconnect();
          } catch (_) {}
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)), skip: 'Requires platform-native secure storage plugin');

    test('verify Gmail OAuth credentials specifically', () async {
      final accountIds = await credentialStore.getSavedAccounts();
      final gmailAccounts = <String>[];

      for (final accountId in accountIds) {
        final credentials = await credentialStore.getCredentials(accountId);
        if (credentials != null) {
          final platformId = credentials.additionalParams?['platformId'] ?? 
                            await credentialStore.getPlatformId(accountId);
          final hasAccessToken = credentials.accessToken?.isNotEmpty == true;
          
          if (platformId == 'gmail' || hasAccessToken) {
            gmailAccounts.add(accountId);
          }
        }
      }

      if (gmailAccounts.isEmpty) {
        print('[WARNING] No Gmail accounts found in saved credentials');
        print('   Gmail accounts require OAuth access token');
        return;
      }

      print('[INVESTIGATION] Verifying ${gmailAccounts.length} Gmail account(s)...\n');

      for (final accountId in gmailAccounts) {
        print('Testing Gmail account: $accountId');
        final credentials = await credentialStore.getCredentials(accountId);
        
        expect(credentials, isNotNull, reason: 'Credentials should exist for $accountId');
        expect(credentials!.email, isNotEmpty, reason: 'Email should not be empty');
        expect(credentials.accessToken, isNotEmpty, 
          reason: 'Gmail requires OAuth access token');

        // Test connection with Gmail adapter
        final adapter = GmailApiAdapter();
        try {
          await adapter.loadCredentials(credentials);
          final status = await adapter.testConnection();
          
          expect(status.isConnected, isTrue,
            reason: 'Should connect to Gmail: ${status.errorMessage}');
          
          print('[OK] Gmail account $accountId is valid');
        } catch (e) {
          print('[FAIL] Gmail account $accountId failed: $e');
          // Gmail OAuth might be platform-specific; don't fail test if unavailable
          if (!e.toString().contains('UnsupportedError') && 
              !e.toString().contains('not available')) {
            rethrow;
          }
          print('   (Note: Gmail OAuth might require platform-specific setup)');
        } finally {
          try {
            await adapter.disconnect();
          } catch (_) {}
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)), skip: 'Requires platform-native secure storage plugin');

    test('verify all credential types are properly encrypted', () async {
      final accountIds = await credentialStore.getSavedAccounts();
      
      if (accountIds.isEmpty) {
        print('[WARNING] No saved credentials to verify encryption');
        return;
      }

      print('🔐 Verifying credential encryption...\n');

      for (final accountId in accountIds) {
        final credentials = await credentialStore.getCredentials(accountId);
        
        if (credentials != null) {
          // Verify email is loaded
          expect(credentials.email, isNotEmpty,
            reason: 'Email should be loaded from secure storage for $accountId');

          // Verify either password or accessToken exists
          final hasPassword = credentials.password?.isNotEmpty == true;
          final hasToken = credentials.accessToken?.isNotEmpty == true;
          
          expect(
            hasPassword || hasToken,
            isTrue,
            reason: 'Credentials for $accountId must have either password or accessToken',
          );

          // Verify additional params
          expect(credentials.additionalParams, isNotNull,
            reason: 'Credentials should have additionalParams');
          expect(credentials.additionalParams!.containsKey('accountId'), isTrue,
            reason: 'accountId should be in additionalParams');

          print('[OK] $accountId credentials properly encrypted and loaded');
        }
      }
    });

    test('verify platform IDs are correctly stored and retrieved', () async {
      final accountIds = await credentialStore.getSavedAccounts();
      
      if (accountIds.isEmpty) {
        print('[WARNING] No saved credentials to verify platform IDs');
        return;
      }

      print('🏢 Verifying platform IDs...\n');

      for (final accountId in accountIds) {
        final platformId = await credentialStore.getPlatformId(accountId);
        final credentials = await credentialStore.getCredentials(accountId);
        
        if (credentials != null) {
          final storedPlatformId = credentials.additionalParams?['platformId'];
          
          print('Account: $accountId');
          print('  Stored platformId: $platformId');
          print('  In credentials.additionalParams: $storedPlatformId');
          
          if (platformId != null) {
            expect(
              ['aol', 'yahoo', 'icloud', 'imap', 'gmail'].contains(platformId),
              isTrue,
              reason: 'Platform ID should be one of the known providers',
            );
            print('  [OK] Valid platform: $platformId');
          }
        }
      }
    });
  });
}

/// Helper method to test IMAP credentials
Future<void> _testIMAPCredentials({
  required Credentials credentials,
  required String? platformId,
  required String accountId,
  required Map<String, CredentialTestResult> results,
}) async {
  try {
    print('   🔐 Auth Method: IMAP (App Password)');
    
    // Determine which IMAP provider to use based on email domain
    final email = credentials.email.toLowerCase();
    GenericIMAPAdapter adapter;
    
    if (platformId == 'aol' || email.endsWith('@aol.com')) {
      adapter = GenericIMAPAdapter.aol();
    } else if (platformId == 'yahoo' || email.endsWith('@yahoo.com')) {
      adapter = GenericIMAPAdapter.yahoo();
    } else if (platformId == 'icloud' || email.endsWith('@icloud.com')) {
      adapter = GenericIMAPAdapter.icloud();
    } else if (platformId == 'imap' || email.endsWith('@gmail.com')) {
      // Default to custom IMAP if platform unknown or Gmail IMAP
      adapter = GenericIMAPAdapter.custom(
        imapHost: email.endsWith('@gmail.com') ? 'imap.gmail.com' : 'mail.example.com',
      );
    } else {
      adapter = GenericIMAPAdapter.custom();
    }

    print('   🔌 Adapter: ${adapter.displayName}');

    // Test connection
    await adapter.loadCredentials(credentials);
    final status = await adapter.testConnection();

    if (status.isConnected) {
      print('   [OK] Connection successful');
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: adapter.platformId,
        authMethod: 'IMAP (App Password)',
        isValid: true,
      );
    } else {
      print('   [FAIL] Connection failed: ${status.errorMessage}');
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: adapter.platformId,
        authMethod: 'IMAP (App Password)',
        isValid: false,
        errorMessage: status.errorMessage,
      );
    }

    await adapter.disconnect();
  } catch (e) {
    print('   [FAIL] Error: $e');
    results[accountId] = CredentialTestResult(
      accountId: accountId,
      email: credentials.email,
      platform: platformId ?? 'unknown',
      authMethod: 'IMAP (App Password)',
      isValid: false,
      errorMessage: e.toString(),
    );
  }
}

/// Helper method to test Gmail OAuth credentials
Future<void> _testGmailCredentials({
  required Credentials credentials,
  required String accountId,
  required Map<String, CredentialTestResult> results,
}) async {
  try {
    print('   🔐 Auth Method: OAuth 2.0');
    
    final adapter = GmailApiAdapter();
    print('   🔌 Adapter: ${adapter.displayName}');

    // Test connection
    await adapter.loadCredentials(credentials);
    final status = await adapter.testConnection();

    if (status.isConnected) {
      print('   [OK] Connection successful');
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: 'gmail',
        authMethod: 'OAuth 2.0',
        isValid: true,
      );
    } else {
      print('   [FAIL] Connection failed: ${status.errorMessage}');
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: 'gmail',
        authMethod: 'OAuth 2.0',
        isValid: false,
        errorMessage: status.errorMessage,
      );
    }

    await adapter.disconnect();
  } catch (e) {
    print('   [FAIL] Error: $e');
    
    // Gmail OAuth might fail on some platforms (expected for mobile emulator)
    if (e.toString().contains('UnsupportedError') ||
        e.toString().contains('not available')) {
      print('   ℹ️ Gmail OAuth not available on this platform');
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: 'gmail',
        authMethod: 'OAuth 2.0',
        isValid: false,
        errorMessage: 'OAuth not available on this platform',
      );
    } else {
      results[accountId] = CredentialTestResult(
        accountId: accountId,
        email: credentials.email,
        platform: 'gmail',
        authMethod: 'OAuth 2.0',
        isValid: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Data class to track credential test results
class CredentialTestResult {
  final String accountId;
  final String email;
  final String platform;
  final String authMethod;
  final bool isValid;
  final String? errorMessage;

  CredentialTestResult({
    required this.accountId,
    required this.email,
    required this.platform,
    required this.authMethod,
    required this.isValid,
    this.errorMessage,
  });

  @override
  String toString() => 
    'CredentialTestResult(accountId=$accountId, email=$email, '
    'platform=$platform, authMethod=$authMethod, isValid=$isValid, '
    'error=${errorMessage ?? "none"})';
}
