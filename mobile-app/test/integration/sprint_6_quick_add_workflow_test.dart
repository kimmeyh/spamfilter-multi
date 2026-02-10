/// Sprint 6 End-to-End Tests: Quick-Add Workflow Integration
/// Tests complete user workflows from unmatched email review through rule/safe sender creation

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/email_message.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
library;


import 'package:spam_filter_mobile/core/storage/rule_database_store.dart';
import 'package:spam_filter_mobile/core/storage/safe_sender_database_store.dart'
    show SafeSenderDatabaseStore, SafeSenderPattern;
import 'package:spam_filter_mobile/core/storage/database_helper.dart';
import 'package:spam_filter_mobile/core/utils/pattern_generation.dart';
import 'package:spam_filter_mobile/core/utils/pattern_normalization.dart';

import '../helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  group('Sprint 6 - Quick-Add Workflow Integration Tests', () {
    late DatabaseTestHelper testHelper;
    late DatabaseHelper databaseHelper;
    late SafeSenderDatabaseStore safeSenderStore;
    late RuleDatabaseStore ruleStore;

    setUp(() async {
      // Initialize test helper with isolated database
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      databaseHelper = testHelper.dbHelper;

      safeSenderStore = SafeSenderDatabaseStore(databaseHelper);
      ruleStore = RuleDatabaseStore(databaseHelper);

      print('\n[CHECKLIST] Sprint 6 Integration Tests - Quick-Add Workflow');
      print('━' * 70);
    });

    tearDown(() async {
      await testHelper.tearDown();
      print('\n[OK] Sprint 6 Integration Tests - Cleanup complete');
    });

    // ============================================================================
    // WORKFLOW 1: Add Safe Sender from Unmatched Email
    // ============================================================================

    test('Workflow 1: Add safe sender (Type 1 - Exact Email)', () async {
      // Clean up database before test
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('\n[PENDING] Workflow 1: Add Safe Sender - Exact Email Match');
      print('   Step 1: Review unmatched email');

      // Simulate unmatched email received
      final email = EmailMessage(
        id: 'email-001',
        from: 'trusted.sender@company.com',
        subject: 'Important Report',
        body: 'Please review the attached report.',
        headers: {'from': 'trusted.sender@company.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      print('      From: ${email.from}');
      print('      Subject: ${email.subject}');

      print('   Step 2: Generate Type 1 (Exact Email) pattern');

      // Pattern generation (same as SafeSenderQuickAddScreen)
      final pattern = PatternGeneration.generateExactEmailPattern(email.from);
      print('      Generated Pattern: $pattern');

      expect(pattern, contains('^'));
      expect(pattern, contains('\$'));

      print('   Step 3: Create SafeSenderPattern with metadata');

      // Create pattern with auto-detected type
      final typeInt = PatternGeneration.detectPatternType(pattern);
      final safeSenderPattern = SafeSenderPattern(
        pattern: pattern,
        patternType: typeInt.toString(),
        exceptionPatterns: [],
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'quick_add',
      );

      print('      Pattern Type: ${safeSenderPattern.patternType}');

      print('   Step 4: Persist to database');

      // Save to database
      await safeSenderStore.addSafeSender(safeSenderPattern);

      // Verify persistence
      final savedPattern = await safeSenderStore.getSafeSender(pattern);
      expect(savedPattern, isNotNull);
      expect(savedPattern!.pattern, equals(pattern));

      print('      ✓ Pattern persisted to database');
      print('\n   [OK] Workflow 1 Complete: Safe sender added successfully');
    });

    test('Workflow 2: Add safe sender (Type 3 - Domain + Subdomains)', () async {
      // Clean up database before test
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('\n[PENDING] Workflow 2: Add Safe Sender - Domain + Subdomains');
      print('   Step 1: Review unmatched email');

      final email = EmailMessage(
        id: 'email-002',
        from: 'contact@mail.trusted.com',
        subject: 'Newsletter',
        body: 'Monthly newsletter',
        headers: {'from': 'contact@mail.trusted.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      print('      From: ${email.from}');
      print('      Subdomain: mail.trusted.com');

      print('   Step 2: Generate Type 3 (Subdomain) pattern');

      final pattern = PatternGeneration.generateSubdomainPattern(email.from);
      print('      Generated Pattern: $pattern');

      expect(pattern, contains('@(?:[a-z0-9-]+\\.)*'));

      print('   Step 3: Add exception patterns (optional)');

      final typeInt = PatternGeneration.detectPatternType(pattern);
      final safeSenderPattern = SafeSenderPattern(
        pattern: pattern,
        patternType: typeInt.toString(),
        exceptionPatterns: ['noreply@.*trusted\\.com'],
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'quick_add',
      );

      print('      Exceptions: ${safeSenderPattern.exceptionPatterns}');

      print('   Step 4: Persist and verify');

      await safeSenderStore.addSafeSender(safeSenderPattern);
      final saved = await safeSenderStore.getSafeSender(pattern);

      expect(saved, isNotNull);
      expect(saved!.exceptionPatterns, isNotEmpty);

      print('      ✓ Pattern with exceptions persisted');
      print('\n   [OK] Workflow 2 Complete: Subdomain pattern with exceptions added');
    });

    // ============================================================================
    // WORKFLOW 3: Create Auto-Delete Rule from Unmatched Email
    // ============================================================================

    test('Workflow 3: Create auto-delete rule (From Header)', () async {
      // Clean up database before test
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('\n[PENDING] Workflow 3: Create Auto-Delete Rule - From Header');
      print('   Step 1: Review unmatched email');

      final email = EmailMessage(
        id: 'email-003',
        from: 'spammer@spam-domain.com',
        subject: 'Buy cheap drugs now!!!',
        body: 'Click here: http://spam.com',
        headers: {'from': 'spammer@spam-domain.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      print('      From: ${email.from}');
      print('      Subject: ${email.subject}');

      print('   Step 2: Normalize email data');

      final normalizedEmail = PatternNormalization.normalizeFromHeader(email.from);
      print('      Normalized From: $normalizedEmail');

      print('   Step 3: Generate rule pattern');

      final pattern = PatternGeneration.generateDomainPattern(normalizedEmail);
      print('      Rule Pattern: $pattern');

      print('   Step 4: Auto-generate rule name from domain');

      final domainParts = normalizedEmail.substring(normalizedEmail.lastIndexOf('@') + 1).split('.');
      final ruleName = 'AutoDelete' + domainParts.map((p) =>
        p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : ''
      ).join('');

      print('      Generated Rule Name: $ruleName');

      print('   Step 5: Get next execution order from database');

      final ruleSet = await ruleStore.loadRules();
      final nextOrder = ruleSet.rules.isEmpty ? 10 :
        (ruleSet.rules.map((r) => r.executionOrder).reduce((a, b) => a > b ? a : b) + 10);

      print('      Execution Order: $nextOrder');

      print('   Step 6: Create rule with conditions and actions');

      final rule = Rule(
        name: ruleName,
        enabled: true,
        isLocal: true,
        executionOrder: nextOrder,
        conditions: RuleConditions(
          type: 'OR',
          from: [pattern],
          subject: [],
          body: [],
        ),
        actions: RuleActions(
          delete: true,
          moveToFolder: null,
        ),
        metadata: {
          'created_by': 'quick_add',
          'source_email_id': email.id,
          'source_from': email.from,
        },
      );

      print('      Rule: $ruleName');
      print('      Conditions: FROM matching $pattern (OR logic)');
      print('      Action: Delete permanently');

      print('   Step 7: Persist rule to database');

      await ruleStore.addRule(rule);

      // Verify persistence
      final saved = await ruleStore.getRule(ruleName);
      expect(saved, isNotNull);
      expect(saved!.actions.delete, true);

      print('      ✓ Rule persisted to database');
      print('\n   [OK] Workflow 3 Complete: Auto-delete rule created successfully');
    });

    // ============================================================================
    // WORKFLOW 4: Create Multi-Condition Rule
    // ============================================================================

    test('Workflow 4: Create rule with multiple conditions (Subject + URL)', () async {
      // Clean up database before test
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('\n[PENDING] Workflow 4: Create Rule - Multiple Conditions');
      print('   Step 1: Review unmatched email');

      final email = EmailMessage(
        id: 'email-004',
        from: 'phisher@evil.com',
        subject: 'Verify your account urgently',
        body: 'Click here to verify: http://phishing-site.com',
        headers: {'from': 'phisher@evil.com'},
        receivedDate: DateTime.now(),
        folderName: 'INBOX',
      );

      print('      From: ${email.from}');
      print('      Subject: ${email.subject}');
      print('      Body: ${email.body}');

      print('   Step 2: Extract and normalize patterns from multiple sources');

      final normalizedSubject = PatternNormalization.normalizeSubject(email.subject);
      final extractedUrls = PatternNormalization.extractUrls(email.body);

      print('      Normalized Subject: $normalizedSubject');
      print('      Extracted URLs: $extractedUrls');

      print('   Step 3: Generate patterns');

      final fromPattern = PatternGeneration.generateDomainPattern(email.from);
      final subjectPattern = normalizedSubject.isNotEmpty ?
        normalizedSubject.substring(0, normalizedSubject.length > 30 ? 30 : normalizedSubject.length) :
        '';

      print('      From Pattern: $fromPattern');
      print('      Subject Pattern: $subjectPattern');

      print('   Step 4: Create rule with AND logic (all conditions must match)');

      final ruleSet = await ruleStore.loadRules();
      final nextOrder = ruleSet.rules.isEmpty ? 10 :
        (ruleSet.rules.map((r) => r.executionOrder).reduce((a, b) => a > b ? a : b) + 10);

      final rule = Rule(
        name: 'PhishingDetection_Evil',
        enabled: true,
        isLocal: true,
        executionOrder: nextOrder,
        conditions: RuleConditions(
          type: 'AND',  // All conditions must match
          from: [fromPattern],
          subject: [subjectPattern],
          body: [],
        ),
        actions: RuleActions(
          delete: true,
          moveToFolder: null,
        ),
        metadata: {
          'created_by': 'quick_add',
          'threat_level': 'high',
        },
      );

      print('      Rule: ${rule.name}');
      print('      Logic: AND (requires all conditions to match)');
      print('      Conditions: 2');
      print('        - FROM: $fromPattern');
      print('        - SUBJECT: $subjectPattern');

      print('   Step 5: Persist multi-condition rule');

      await ruleStore.addRule(rule);
      final saved = await ruleStore.getRule('PhishingDetection_Evil');

      expect(saved, isNotNull);
      expect(saved!.conditions.type, equals('AND'));
      expect(saved.conditions.from, isNotEmpty);
      expect(saved.conditions.subject, isNotEmpty);

      print('      ✓ Multi-condition rule persisted');
      print('\n   [OK] Workflow 4 Complete: Complex rule with AND logic created');
    });

    // ============================================================================
    // WORKFLOW 5: Verify Pattern Detection
    // ============================================================================

    test('Workflow 5: Pattern type auto-detection', () async {
      // Clean up database before test (not needed for this test, but consistent)
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('\n[PENDING] Workflow 5: Pattern Type Auto-Detection');
      print('   Step 1: Test Type 1 (exact email) detection');

      final pattern1 = '^user@example\\.com\$';
      final type1 = PatternGeneration.detectPatternType(pattern1);
      print('      Pattern: $pattern1');
      print('      Detected Type: $type1');
      expect(type1, equals(1));

      print('   Step 2: Test Type 2 (domain) detection');

      final pattern2 = '@example\\.com\$';
      final type2 = PatternGeneration.detectPatternType(pattern2);
      print('      Pattern: $pattern2');
      print('      Detected Type: $type2');
      expect(type2, equals(2));

      print('   Step 3: Test Type 3 (subdomain) detection');

      final pattern3 = '@(?:[a-z0-9-]+\\.)*example\\.com\$';
      final type3 = PatternGeneration.detectPatternType(pattern3);
      print('      Pattern: $pattern3');
      print('      Detected Type: $type3');
      expect(type3, equals(3));

      print('   Step 4: Test Type 0 (custom) detection');

      final pattern0 = '^custom.*pattern\$';
      final type0 = PatternGeneration.detectPatternType(pattern0);
      print('      Pattern: $pattern0');
      print('      Detected Type: $type0 (custom)');
      expect(type0, equals(0));

      print('\n   [OK] Workflow 5 Complete: All pattern types detected correctly');
    });

    // ============================================================================
    // WORKFLOW 6: Complete Database Verification
    // ============================================================================

    test('Workflow 6: Verify database persistence across operations', () async {
      // Add a test safe sender and rule, then verify they can be retrieved
      print('\n[PENDING] Workflow 6: Database Persistence Verification');

      // Clean database and add fresh data for verification
      final db = await databaseHelper.database;
      await db.delete('safe_senders');
      await db.delete('rules');

      print('   Step 1: Add test safe sender and verify retrieval');

      final testPattern = '^persistence\.test@example\\.com\$';
      final testSafeSender = SafeSenderPattern(
        pattern: testPattern,
        patternType: '1',
        exceptionPatterns: [],
        dateAdded: DateTime.now().millisecondsSinceEpoch,
        createdBy: 'test',
      );

      await safeSenderStore.addSafeSender(testSafeSender);
      final retrieved = await safeSenderStore.getSafeSender(testPattern);

      expect(retrieved, isNotNull);
      expect(retrieved!.pattern, equals(testPattern));
      print('      ✓ Safe sender persisted and retrieved');

      print('   Step 2: Add test rule and verify retrieval');

      final testRule = Rule(
        name: 'TestPersistenceRule',
        enabled: true,
        isLocal: true,
        executionOrder: 999,
        conditions: RuleConditions(
          type: 'OR',
          from: ['@test\\.com\$'],
          subject: [],
          body: [],
        ),
        actions: RuleActions(
          delete: true,
          moveToFolder: null,
        ),
        metadata: {'test': 'persistence'},
      );

      await ruleStore.addRule(testRule);
      final retrievedRule = await ruleStore.getRule('TestPersistenceRule');

      expect(retrievedRule, isNotNull);
      expect(retrievedRule!.name, equals('TestPersistenceRule'));
      expect(retrievedRule.actions.delete, true);
      print('      ✓ Rule persisted and retrieved');

      print('   Step 3: Verify data loads from database');

      final allSafeSenders = await safeSenderStore.loadSafeSenders();
      final allRules = await ruleStore.loadRules();

      expect(allSafeSenders, isNotEmpty);
      expect(allRules.rules, isNotEmpty);
      print('      ✓ All data loads from database correctly');

      print('\n   [OK] Workflow 6 Complete: Database persistence verified');
    });

  });
}

