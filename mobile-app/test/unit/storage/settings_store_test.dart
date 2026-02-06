import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/storage/settings_store.dart';
import 'package:spam_filter_mobile/core/providers/email_scan_provider.dart';
import '../../helpers/database_test_helper.dart';

/// Unit tests for SettingsStore
///
/// Tests cover:
/// - App-wide setting getters and setters
/// - Per-account setting overrides
/// - Default value handling
/// - Effective setting resolution
void main() {
  late DatabaseTestHelper testHelper;
  late SettingsStore settingsStore;

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    settingsStore = SettingsStore(testHelper.dbHelper);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('App-Wide Settings - Manual Scan', () {
    test('getManualScanMode returns default when not set', () async {
      final mode = await settingsStore.getManualScanMode();
      expect(mode, SettingsStore.defaultManualScanMode);
    });

    test('setManualScanMode persists and retrieves correctly', () async {
      await settingsStore.setManualScanMode(ScanMode.fullScan);
      final mode = await settingsStore.getManualScanMode();
      expect(mode, ScanMode.fullScan);
    });

    test('getManualScanFolders returns default when not set', () async {
      final folders = await settingsStore.getManualScanFolders();
      expect(folders, SettingsStore.defaultManualScanFolders);
    });

    test('setManualScanFolders persists and retrieves correctly', () async {
      final folders = ['INBOX', 'Spam', 'Junk'];
      await settingsStore.setManualScanFolders(folders);
      final retrieved = await settingsStore.getManualScanFolders();
      expect(retrieved, folders);
    });

    test('getConfirmDialogsEnabled returns default when not set', () async {
      final enabled = await settingsStore.getConfirmDialogsEnabled();
      expect(enabled, SettingsStore.defaultConfirmDialogsEnabled);
    });

    test('setConfirmDialogsEnabled persists and retrieves correctly', () async {
      await settingsStore.setConfirmDialogsEnabled(false);
      final enabled = await settingsStore.getConfirmDialogsEnabled();
      expect(enabled, false);
    });
  });

  group('App-Wide Settings - Background Scan', () {
    test('getBackgroundScanEnabled returns default when not set', () async {
      final enabled = await settingsStore.getBackgroundScanEnabled();
      expect(enabled, SettingsStore.defaultBackgroundScanEnabled);
    });

    test('setBackgroundScanEnabled persists and retrieves correctly', () async {
      await settingsStore.setBackgroundScanEnabled(true);
      final enabled = await settingsStore.getBackgroundScanEnabled();
      expect(enabled, true);
    });

    test('getBackgroundScanFrequency returns default when not set', () async {
      final freq = await settingsStore.getBackgroundScanFrequency();
      expect(freq, SettingsStore.defaultBackgroundScanFrequency);
    });

    test('setBackgroundScanFrequency persists and retrieves correctly', () async {
      await settingsStore.setBackgroundScanFrequency(30);
      final freq = await settingsStore.getBackgroundScanFrequency();
      expect(freq, 30);
    });

    test('getBackgroundScanMode returns default when not set', () async {
      final mode = await settingsStore.getBackgroundScanMode();
      expect(mode, SettingsStore.defaultBackgroundScanMode);
    });

    test('setBackgroundScanMode persists and retrieves correctly', () async {
      await settingsStore.setBackgroundScanMode(ScanMode.testAll);
      final mode = await settingsStore.getBackgroundScanMode();
      expect(mode, ScanMode.testAll);
    });
  });

  group('Per-Account Settings', () {
    const accountId = 'test-account-123';

    test('getAccountFolders returns null when not set', () async {
      final folders = await settingsStore.getAccountFolders(accountId);
      expect(folders, isNull);
    });

    test('setAccountFolders persists and retrieves correctly', () async {
      final folders = ['Custom1', 'Custom2'];
      await settingsStore.setAccountFolders(accountId, folders);
      final retrieved = await settingsStore.getAccountFolders(accountId);
      expect(retrieved, folders);
    });

    test('setAccountFolders with null clears the override', () async {
      await settingsStore.setAccountFolders(accountId, ['Custom1']);
      await settingsStore.setAccountFolders(accountId, null);
      final retrieved = await settingsStore.getAccountFolders(accountId);
      expect(retrieved, isNull);
    });

    test('getAccountScanMode returns null when not set', () async {
      final mode = await settingsStore.getAccountScanMode(accountId);
      expect(mode, isNull);
    });

    test('setAccountScanMode persists and retrieves correctly', () async {
      await settingsStore.setAccountScanMode(accountId, ScanMode.fullScan);
      final mode = await settingsStore.getAccountScanMode(accountId);
      expect(mode, ScanMode.fullScan);
    });

    test('hasAccountOverrides returns false when no overrides', () async {
      final hasOverrides = await settingsStore.hasAccountOverrides(accountId);
      expect(hasOverrides, false);
    });

    test('hasAccountOverrides returns true when overrides exist', () async {
      await settingsStore.setAccountScanMode(accountId, ScanMode.fullScan);
      final hasOverrides = await settingsStore.hasAccountOverrides(accountId);
      expect(hasOverrides, true);
    });

    test('clearAccountOverrides removes all account settings', () async {
      await settingsStore.setAccountScanMode(accountId, ScanMode.fullScan);
      await settingsStore.setAccountFolders(accountId, ['Custom']);
      await settingsStore.clearAccountOverrides(accountId);

      final mode = await settingsStore.getAccountScanMode(accountId);
      final folders = await settingsStore.getAccountFolders(accountId);
      final hasOverrides = await settingsStore.hasAccountOverrides(accountId);

      expect(mode, isNull);
      expect(folders, isNull);
      expect(hasOverrides, false);
    });
  });

  group('Effective Settings Resolution', () {
    const accountId = 'test-account-123';

    test('getEffectiveScanMode uses global when no account override', () async {
      await settingsStore.setManualScanMode(ScanMode.fullScan);
      final effective = await settingsStore.getEffectiveScanMode(accountId);
      expect(effective, ScanMode.fullScan);
    });

    test('getEffectiveScanMode uses account override when set', () async {
      await settingsStore.setManualScanMode(ScanMode.readonly);
      await settingsStore.setAccountScanMode(accountId, ScanMode.fullScan);
      final effective = await settingsStore.getEffectiveScanMode(accountId);
      expect(effective, ScanMode.fullScan);
    });

    test('getEffectiveScanMode uses background mode when isBackground true', () async {
      await settingsStore.setManualScanMode(ScanMode.readonly);
      await settingsStore.setBackgroundScanMode(ScanMode.fullScan);
      final effective = await settingsStore.getEffectiveScanMode(null, isBackground: true);
      expect(effective, ScanMode.fullScan);
    });

    test('getEffectiveFolders uses global when no account override', () async {
      await settingsStore.setManualScanFolders(['Global1', 'Global2']);
      final effective = await settingsStore.getEffectiveFolders(accountId);
      expect(effective, ['Global1', 'Global2']);
    });

    test('getEffectiveFolders uses account override when set', () async {
      await settingsStore.setManualScanFolders(['Global1']);
      await settingsStore.setAccountFolders(accountId, ['Account1', 'Account2']);
      final effective = await settingsStore.getEffectiveFolders(accountId);
      expect(effective, ['Account1', 'Account2']);
    });

    test('getEffectiveFolders handles null accountId', () async {
      await settingsStore.setManualScanFolders(['Global1']);
      final effective = await settingsStore.getEffectiveFolders(null);
      expect(effective, ['Global1']);
    });
  });

  group('ScanMode Parsing', () {
    test('All scan modes can be stored and retrieved', () async {
      for (final mode in ScanMode.values) {
        await settingsStore.setManualScanMode(mode);
        final retrieved = await settingsStore.getManualScanMode();
        expect(retrieved, mode, reason: 'Failed for mode: ${mode.name}');
      }
    });
  });

  group('Export Settings', () {
    test('getCsvExportDirectory returns null when not set', () async {
      final directory = await settingsStore.getCsvExportDirectory();
      expect(directory, isNull);
    });

    test('setCsvExportDirectory persists and retrieves correctly', () async {
      const testPath = 'C:\\Users\\Test\\Documents\\SpamFilter';
      await settingsStore.setCsvExportDirectory(testPath);
      final retrieved = await settingsStore.getCsvExportDirectory();
      expect(retrieved, testPath);
    });

    test('setCsvExportDirectory with null clears the setting', () async {
      await settingsStore.setCsvExportDirectory('C:\\Test');
      await settingsStore.setCsvExportDirectory(null);
      final retrieved = await settingsStore.getCsvExportDirectory();
      expect(retrieved, isNull);
    });
  });
}
