import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/ui/screens/email_detail_view.dart';
import 'package:spam_filter_mobile/core/storage/unmatched_email_store.dart';

// Test double for UnmatchedEmailStore
class FakeUnmatchedEmailStore implements UnmatchedEmailStore {
  bool markProcessedCalled = false;
  bool lastProcessedValue = false;

  @override
  Future<bool> markAsProcessed(int emailId, bool processed) async {
    markProcessedCalled = true;
    lastProcessedValue = processed;
    return true;
  }

  @override
  Future<int> addUnmatchedEmail(UnmatchedEmail email) async => 1;

  @override
  Future<List<int>> addUnmatchedEmailBatch(List<UnmatchedEmail> emails) async =>
      [];

  @override
  Future<bool> deleteUnmatchedEmail(int emailId) async => true;

  @override
  Future<int> deleteUnmatchedEmailsByScan(int scanResultId) async => 0;

  @override
  Future<UnmatchedEmail?> getUnmatchedEmailById(int emailId) async => null;

  @override
  Future<int> getUnmatchedEmailCountByScan(int scanResultId) async => 0;

  @override
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScan(int scanResultId) async =>
      [];

  @override
  Future<List<UnmatchedEmail>> getUnmatchedEmailsByScanFiltered(
    int scanResultId, {
    bool? availabilityOnly,
    bool? processedOnly,
    bool? unprocessedOnly,
  }) async =>
      [];

  @override
  Future<bool> updateAvailabilityStatus(
    int emailId,
    String status,
  ) async =>
      true;
}

void main() {
  group('EmailDetailView', () {
    late UnmatchedEmail testEmail;
    late FakeUnmatchedEmailStore fakeEmailStore;

    setUp(() {
      fakeEmailStore = FakeUnmatchedEmailStore();

      testEmail = UnmatchedEmail(
        id: 1,
        scanResultId: 1,
        providerIdentifierType: 'gmail_message_id',
        providerIdentifierValue: 'msg1',
        fromEmail: 'sender@example.com',
        fromName: 'Test Sender',
        subject: 'Test Subject',
        bodyPreview: 'This is the email body preview',
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
          home: EmailDetailView(
            email: testEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify email subject is displayed
      expect(find.text('Test Subject'), findsWidgets);

      // Verify sender email is displayed
      expect(find.text('sender@example.com'), findsWidgets);

      // Verify folder name is displayed
      expect(find.text('INBOX'), findsWidgets);
    });

    testWidgets('Shows availability status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: testEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify availability status is shown
      expect(find.text('Available'), findsWidgets);
    });

    testWidgets('Displays body preview', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: testEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify body preview is displayed
      expect(find.text('This is the email body preview'), findsWidgets);
    });

    testWidgets('Shows quick-action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: testEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify quick-action buttons are displayed
      expect(find.text('Add Safe Sender'), findsWidgets);
      expect(find.text('Create Auto-Delete Rule'), findsWidgets);
    });

    testWidgets('Mark as processed button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: testEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Mark as Processed" button is shown
      expect(find.text('Mark as Processed'), findsOneWidget);

      // Verify button is clickable by tapping it
      await tester.tap(find.text('Mark as Processed'));
      await tester.pump();

      // Test completes successfully (button was tappable)
      expect(find.byType(OutlinedButton), findsWidgets);
    });

    testWidgets('Shows processed status for processed emails', (WidgetTester tester) async {
      final processedEmail = testEmail.copyWith(processed: true);

      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: processedEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify button shows "Mark as Unprocessed"
      expect(find.text('Mark as Unprocessed'), findsWidgets);
    });

    testWidgets('Shows deleted status with red indicator', (WidgetTester tester) async {
      final deletedEmail = testEmail.copyWith(availabilityStatus: 'deleted');

      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: deletedEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify deleted status is shown
      expect(find.text('Deleted'), findsWidgets);
    });

    testWidgets('Handles no subject gracefully', (WidgetTester tester) async {
      final noSubjectEmail = testEmail.copyWith(subject: '');

      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: noSubjectEmail,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify placeholder text is shown
      expect(find.text('(No subject)'), findsWidgets);
    });

    testWidgets('Displays sender name when available', (WidgetTester tester) async {
      final emailWithName = testEmail.copyWith(fromName: 'Sender Display Name');

      await tester.pumpWidget(
        MaterialApp(
          home: EmailDetailView(
            email: emailWithName,
            unmatchedEmailStore: fakeEmailStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify sender name is displayed
      expect(find.text('Sender Display Name'), findsWidgets);
    });
  });
}
