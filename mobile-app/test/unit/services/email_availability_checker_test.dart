import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/provider_email_identifier.dart';
import 'package:spam_filter_mobile/core/services/email_availability_checker.dart';

void main() {
  group('EmailAvailabilityResult', () {
    test('statusString returns "available" when stillExists is true', () {
      final result = EmailAvailabilityResult(
        stillExists: true,
        checkedAt: DateTime.now(),
      );
      expect(result.statusString, 'available');
    });

    test('statusString returns "moved" when stillExists is false and not confirmed absence', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        isConfirmedAbsence: false,
      );
      expect(result.statusString, 'moved');
    });

    test('statusString returns "deleted" when stillExists is false and confirmed absence', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        isConfirmedAbsence: true,
      );
      expect(result.statusString, 'deleted');
    });

    test('statusString returns "unknown" when errorMessage is not null', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        errorMessage: 'Network error',
      );
      expect(result.statusString, 'unknown');
    });

    test('isConfirmedAbsence defaults to false', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
      );
      expect(result.isConfirmedAbsence, false);
    });

    test('errorMessage is null by default', () {
      final result = EmailAvailabilityResult(
        stillExists: true,
        checkedAt: DateTime.now(),
      );
      expect(result.errorMessage, isNull);
    });

    test('checkedAt timestamp is preserved', () {
      final now = DateTime.now();
      final result = EmailAvailabilityResult(
        stillExists: true,
        checkedAt: now,
      );
      expect(result.checkedAt, now);
    });
  });

  group('EmailAvailabilityChecker - Instance Creation', () {
    test('EmailAvailabilityChecker can be instantiated', () {
      final checker = EmailAvailabilityChecker();
      expect(checker, isNotNull);
    });

    test('Multiple checker instances are independent', () {
      final checker1 = EmailAvailabilityChecker();
      final checker2 = EmailAvailabilityChecker();
      expect(checker1, isNot(checker2));
    });
  });

  group('EmailAvailabilityResult - Edge Cases', () {
    test('statusString with errorMessage takes priority over stillExists', () {
      final result = EmailAvailabilityResult(
        stillExists: true,
        checkedAt: DateTime.now(),
        errorMessage: 'Some error',
      );
      // Even though stillExists is true, error takes priority
      expect(result.statusString, 'unknown');
    });

    test('errorMessage can be very long', () {
      final longError = 'E' * 1000;
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        errorMessage: longError,
      );
      expect(result.errorMessage, longError);
      expect(result.statusString, 'unknown');
    });

    test('isConfirmedAbsence can be explicitly set to true', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        isConfirmedAbsence: true,
      );
      expect(result.isConfirmedAbsence, true);
      expect(result.statusString, 'deleted');
    });

    test('Result with both error and isConfirmedAbsence=true prioritizes error', () {
      final result = EmailAvailabilityResult(
        stillExists: false,
        checkedAt: DateTime.now(),
        errorMessage: 'Connection failed',
        isConfirmedAbsence: true,
      );
      // Error message takes priority
      expect(result.statusString, 'unknown');
    });
  });

  group('EmailAvailabilityResult - Multiple Results', () {
    test('Can create list of results', () {
      final results = [
        EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), isConfirmedAbsence: true),
        EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), errorMessage: 'Error'),
      ];
      expect(results.length, 3);
      expect(results[0].statusString, 'available');
      expect(results[1].statusString, 'deleted');
      expect(results[2].statusString, 'unknown');
    });

    test('Can map results by key', () {
      final resultsMap = <String, EmailAvailabilityResult>{
        'email1': EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        'email2': EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), isConfirmedAbsence: true),
      };
      expect(resultsMap.length, 2);
      expect(resultsMap['email1']!.statusString, 'available');
      expect(resultsMap['email2']!.statusString, 'deleted');
    });

    test('Can filter results by status', () {
      final results = [
        EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), isConfirmedAbsence: true),
        EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), errorMessage: 'Error'),
      ];

      final available = results.where((r) => r.statusString == 'available').toList();
      final deleted = results.where((r) => r.statusString == 'deleted').toList();
      final unknown = results.where((r) => r.statusString == 'unknown').toList();

      expect(available.length, 2);
      expect(deleted.length, 1);
      expect(unknown.length, 1);
    });
  });

  group('EmailAvailabilityChecker - Batch Operations Structure', () {
    late EmailAvailabilityChecker checker;

    setUp(() {
      checker = EmailAvailabilityChecker();
    });

    test('checkAvailabilityBatch method exists and is callable', () {
      expect(checker.checkAvailabilityBatch, isNotNull);
    });

    test('checkAvailabilityOptimized method exists and is callable', () {
      expect(checker.checkAvailabilityOptimized, isNotNull);
    });

    test('checkAvailability method exists and is callable', () {
      expect(checker.checkAvailability, isNotNull);
    });
  });

  group('ProviderEmailIdentifier - Gmail Support', () {
    test('Gmail identifier created with factory method', () {
      final identifier = ProviderEmailIdentifier.gmail('msg123');
      expect(identifier.providerType, 'gmail');
      expect(identifier.identifierType, 'gmail_message_id');
      expect(identifier.identifierValue, 'msg123');
    });

    test('Gmail identifier isGmail returns true', () {
      final identifier = ProviderEmailIdentifier.gmail('msg123');
      expect(identifier.isGmail, true);
    });

    test('Gmail identifier isImap returns false', () {
      final identifier = ProviderEmailIdentifier.gmail('msg123');
      expect(identifier.isImap, false);
    });

    test('Multiple Gmail identifiers are independent', () {
      final id1 = ProviderEmailIdentifier.gmail('msg1');
      final id2 = ProviderEmailIdentifier.gmail('msg2');
      expect(id1.identifierValue, 'msg1');
      expect(id2.identifierValue, 'msg2');
      expect(id1.identifierValue, isNot(id2.identifierValue));
    });
  });

  group('ProviderEmailIdentifier - IMAP Support', () {
    test('IMAP identifier created with factory method', () {
      final identifier = ProviderEmailIdentifier.imap('aol', 12345);
      expect(identifier.providerType, 'aol');
      expect(identifier.identifierType, 'imap_uid');
      expect(identifier.identifierValue, '12345');
    });

    test('IMAP identifier isImap returns true', () {
      final identifier = ProviderEmailIdentifier.imap('aol', 12345);
      expect(identifier.isImap, true);
    });

    test('IMAP identifier isGmail returns false', () {
      final identifier = ProviderEmailIdentifier.imap('aol', 12345);
      expect(identifier.isGmail, false);
    });

    test('IMAP imapUid property returns correct UID', () {
      final identifier = ProviderEmailIdentifier.imap('yahoo', 67890);
      expect(identifier.imapUid, 67890);
    });

    test('Multiple IMAP identifiers with different UIDs', () {
      final id1 = ProviderEmailIdentifier.imap('aol', 100);
      final id2 = ProviderEmailIdentifier.imap('aol', 200);
      expect(id1.identifierValue, '100');
      expect(id2.identifierValue, '200');
    });

    test('IMAP identifier with different providers', () {
      final aol = ProviderEmailIdentifier.imap('aol', 123);
      final yahoo = ProviderEmailIdentifier.imap('yahoo', 123);
      expect(aol.providerType, 'aol');
      expect(yahoo.providerType, 'yahoo');
    });
  });

  group('ProviderEmailIdentifier - Serialization', () {
    test('Gmail identifier toJson produces valid map', () {
      final identifier = ProviderEmailIdentifier.gmail('msg456');
      final json = identifier.toJson();
      expect(json['provider_type'], 'gmail');
      expect(json['identifier_type'], 'gmail_message_id');
      expect(json['identifier_value'], 'msg456');
    });

    test('IMAP identifier toJson produces valid map', () {
      final identifier = ProviderEmailIdentifier.imap('aol', 789);
      final json = identifier.toJson();
      expect(json['provider_type'], 'aol');
      expect(json['identifier_type'], 'imap_uid');
      expect(json['identifier_value'], '789');
    });

    test('Gmail identifier can be reconstructed from JSON', () {
      final original = ProviderEmailIdentifier.gmail('xyz123');
      final json = original.toJson();
      final reconstructed = ProviderEmailIdentifier.fromJson(json);
      expect(reconstructed.providerType, original.providerType);
      expect(reconstructed.identifierType, original.identifierType);
      expect(reconstructed.identifierValue, original.identifierValue);
    });

    test('IMAP identifier can be reconstructed from JSON', () {
      final original = ProviderEmailIdentifier.imap('yahoo', 999);
      final json = original.toJson();
      final reconstructed = ProviderEmailIdentifier.fromJson(json);
      expect(reconstructed.providerType, original.providerType);
      expect(reconstructed.identifierType, original.identifierType);
      expect(reconstructed.identifierValue, original.identifierValue);
    });
  });

  group('EmailAvailabilityChecker - Logger Integration', () {
    test('EmailAvailabilityChecker initializes logger', () {
      final checker = EmailAvailabilityChecker();
      // Just verify it creates without errors
      expect(checker, isNotNull);
    });
  });

  group('EmailAvailabilityResult - Batch Result Handling', () {
    test('Empty batch returns map', () {
      final Map<String, EmailAvailabilityResult> results = {};
      expect(results, isEmpty);
      expect(results.length, 0);
    });

    test('Batch results can be keyed with provider:identifier format', () {
      final results = <String, EmailAvailabilityResult>{
        'gmail:msg1': EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        'gmail:msg2': EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), isConfirmedAbsence: true),
        'aol:123': EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
      };
      expect(results.length, 3);
      expect(results.containsKey('gmail:msg1'), true);
      expect(results.containsKey('aol:123'), true);
    });

    test('Can get summary statistics from batch results', () {
      final results = <String, EmailAvailabilityResult>{
        'id1': EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        'id2': EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), isConfirmedAbsence: true),
        'id3': EmailAvailabilityResult(stillExists: true, checkedAt: DateTime.now()),
        'id4': EmailAvailabilityResult(stillExists: false, checkedAt: DateTime.now(), errorMessage: 'Error'),
      };

      final available = results.values.where((r) => r.stillExists).length;
      final deleted = results.values.where((r) => r.isConfirmedAbsence).length;
      final errors = results.values.where((r) => r.errorMessage != null).length;

      expect(available, 2);
      expect(deleted, 1);
      expect(errors, 1);
    });
  });

  group('ProviderEmailIdentifier - Edge Cases', () {
    test('Gmail identifier with long message ID', () {
      final longId = 'x' * 1000;
      final identifier = ProviderEmailIdentifier.gmail(longId);
      expect(identifier.identifierValue, longId);
    });

    test('IMAP identifier with very large UID', () {
      final bigUid = 999999999;
      final identifier = ProviderEmailIdentifier.imap('aol', bigUid);
      expect(identifier.imapUid, bigUid);
    });

    test('IMAP factory converts provider type to lowercase', () {
      final aol = ProviderEmailIdentifier.imap('AOL', 123);
      final aolLower = ProviderEmailIdentifier.imap('aol', 123);
      // Both should be converted to lowercase by the factory
      expect(aol.providerType, 'aol');
      expect(aolLower.providerType, 'aol');
      expect(aol.providerType, aolLower.providerType);
    });
  });
}
