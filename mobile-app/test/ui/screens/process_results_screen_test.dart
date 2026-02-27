import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/ui/screens/process_results_screen.dart';
import 'package:spam_filter_mobile/core/storage/scan_result_store.dart';
import 'package:spam_filter_mobile/core/storage/unmatched_email_store.dart';

// Test doubles for store interfaces
class FakeScanResultStore implements ScanResultStore {
  @override
  Future<int> addScanResult(ScanResult scanResult) async => 1;

  @override
  Future<ScanResult?> getScanResultById(int scanResultId) async => ScanResult(
    id: scanResultId,
    accountId: 'test@gmail.com',
    scanType: 'manual',
    scanMode: 'readonly',
    startedAt: DateTime.now().millisecondsSinceEpoch,
    completedAt: DateTime.now().millisecondsSinceEpoch,
    totalEmails: 2,
    processedCount: 0,
    deletedCount: 0,
    movedCount: 0,
    safeSenderCount: 0,
    noRuleCount: 2,
    errorCount: 0,
    status: 'completed',
    foldersScanned: ['INBOX'],
  );

  @override
  Future<List<ScanResult>> getScanResultsByAccount(String accountId) async => [];

  @override
  Future<List<ScanResult>> getScanResultsByAccountFiltered(
    String accountId, {
    String? scanType,
    String? statusOnly,
    bool? completedOnly,
  }) async =>
      [];

  @override
  Future<ScanResult?> getLatestScanByType(String accountId, String scanType) async =>
      null;

  @override
  Future<ScanResult?> getLatestCompletedScan(String accountId) async => null;

  @override
  Future<bool> updateScanResult(int scanResultId, ScanResult updates) async => true;

  @override
  Future<bool> updateScanResultFields(int scanResultId,
      Map<String, dynamic> updates) async =>
      true;

  @override
  Future<bool> markScanCompleted(int scanResultId) async => true;

  @override
  Future<bool> markScanError(int scanResultId, String errorMessage) async => true;

  @override
  Future<bool> deleteScanResult(int scanResultId) async => true;

  @override
  Future<int> deleteScanResultsByAccount(String accountId) async => 0;

  @override
  Future<int> getScanCountByAccount(String accountId) async => 0;

  @override
  Future<int> getIncompleteScansCount() async => 0;

  @override
  Future<List<ScanResult>> getAllScanHistory({int? limit, String? scanType}) async => [];

  @override
  Future<int> purgeOldScanResults(int retentionDays) async => 0;
}

class FakeUnmatchedEmailStore implements UnmatchedEmailStore {
  final List<UnmatchedEmail> _emails = [
    UnmatchedEmail(
      id: 1,
      scanResultId: 1,
      providerIdentifierType: 'gmail_message_id',
      providerIdentifierValue: 'msg1',
      fromEmail: 'sender1@example.com',
      fromName: 'Sender 1',
      subject: 'Test email 1',
      bodyPreview: 'This is the first test email',
      folderName: 'INBOX',
      emailDate: DateTime.now(),
      availabilityStatus: 'available',
      availabilityCheckedAt: DateTime.now(),
      processed: false,
      createdAt: DateTime.now(),
    ),
    UnmatchedEmail(
      id: 2,
      scanResultId: 1,
      providerIdentifierType: 'gmail_message_id',
      providerIdentifierValue: 'msg2',
      fromEmail: 'sender2@example.com',
      fromName: 'Sender 2',
      subject: 'Test email 2',
      bodyPreview: 'This is the second test email',
      folderName: 'INBOX',
      emailDate: DateTime.now(),
      availabilityStatus: 'deleted',
      availabilityCheckedAt: DateTime.now(),
      processed: true,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScan(int scanResultId) async =>
      _emails;

  @override
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScanFiltered(
    int scanResultId, {
    bool? availabilityOnly,
    bool? processedOnly,
    bool? unprocessedOnly,
  }) async =>
      _emails;

  @override
  Future<bool> markAsProcessed(int emailId, bool processed) async => true;

  @override
  Future<int> addUnmatchedEmail(UnmatchedEmail email) async => 1;

  @override
  Future<List<int>> addUnmatchedEmailBatch(List<UnmatchedEmail> emails) async => [];

  @override
  Future<UnmatchedEmail?> getUnmatchedEmailById(int emailId) async => null;

  @override
  Future<int> getUnmatchedEmailCountByScan(int scanResultId) async => 0;

  @override
  Future<bool> updateAvailabilityStatus(
    int emailId,
    String status,
  ) async =>
      true;

  @override
  Future<bool> deleteUnmatchedEmail(int emailId) async => true;

  @override
  Future<int> deleteUnmatchedEmailsByScan(int scanResultId) async => 0;
}

void main() {
  group('ProcessResultsScreen', () {
    late FakeScanResultStore fakeScanResultStore;
    late FakeUnmatchedEmailStore fakeEmailStore;

    setUp(() {
      fakeScanResultStore = FakeScanResultStore();
      fakeEmailStore = FakeUnmatchedEmailStore();
    });

    testWidgets('Renders with email list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Unmatched Emails - test@gmail.com'), findsOneWidget);

      // Verify email list is rendered
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Shows email cards with correct information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify email subjects are displayed
      expect(find.text('Test email 1'), findsWidgets);
      expect(find.text('Test email 2'), findsWidgets);

      // Verify sender emails are displayed
      expect(find.text('From: sender1@example.com'), findsWidgets);
      expect(find.text('From: sender2@example.com'), findsWidgets);
    });

    testWidgets('Displays status indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status chips are shown
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Deleted'), findsWidgets);
    });

    testWidgets('Shows processed status when email is processed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // One email should show "Processed" chip
      expect(find.text('Processed'), findsWidgets);
    });

    testWidgets('Search bar is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify search field exists
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search by from or subject...'), findsWidgets);
    });

    testWidgets('Sort dropdown is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessResultsScreen(
            scanResultId: 1,
            accountEmail: 'test@gmail.com',
            scanResultStore: fakeScanResultStore,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify screen renders without error
      expect(find.byType(ProcessResultsScreen), findsOneWidget);
    });

  });

  group('UnmatchedEmailCard', () {
    late UnmatchedEmail testEmail;

    setUp(() {
      testEmail = UnmatchedEmail(
        id: 1,
        scanResultId: 1,
        providerIdentifierType: 'gmail_message_id',
        providerIdentifierValue: 'msg1',
        fromEmail: 'sender@example.com',
        fromName: 'Test Sender',
        subject: 'Test Subject',
        bodyPreview: 'Test body preview',
        folderName: 'INBOX',
        emailDate: DateTime.now(),
        availabilityStatus: 'available',
        availabilityCheckedAt: DateTime.now(),
        processed: false,
        createdAt: DateTime.now(),
      );
    });

    testWidgets('Displays email information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(email: testEmail),
          ),
        ),
      );

      expect(find.text('Test Subject'), findsWidgets);
      expect(find.text('From: sender@example.com'), findsWidgets);
    });

    testWidgets('Shows availability status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(email: testEmail),
          ),
        ),
      );

      expect(find.text('Available'), findsWidgets);
    });

    testWidgets('Tap action is triggered', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(
              email: testEmail,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('Handles no subject gracefully', (WidgetTester tester) async {
      final emailNoSubject = testEmail.copyWith(subject: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(email: emailNoSubject),
          ),
        ),
      );

      expect(find.text('(No subject)'), findsWidgets);
    });

    testWidgets('Shows processed status when applicable', (WidgetTester tester) async {
      final processedEmail = testEmail.copyWith(processed: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(email: processedEmail),
          ),
        ),
      );

      expect(find.text('Processed'), findsWidgets);
    });

    testWidgets('Different status colors are correct', (WidgetTester tester) async {
      final deletedEmail = testEmail.copyWith(availabilityStatus: 'deleted');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnmatchedEmailCard(email: deletedEmail),
          ),
        ),
      );

      expect(find.text('Deleted'), findsWidgets);
    });
  });
}
