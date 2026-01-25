/// Provider-based state management for rule sets
/// 
/// Exposes rules and safe senders to the UI layer via Provider pattern,
/// handling loading, caching, and mutations.
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/local_rule_store.dart';
import '../../core/models/rule_set.dart';
import '../../core/models/safe_sender_list.dart';
import '../../core/services/pattern_compiler.dart';
import '../../core/storage/database_helper.dart';
import '../../core/storage/rule_database_store.dart';
import '../../core/storage/safe_sender_database_store.dart';

/// Loading state for rule data
enum RuleLoadingState { idle, loading, success, error }

/// Provider for managing rule sets and safe senders
/// 
/// This provider handles:
/// - Loading rules from persistent storage
/// - Loading safe senders from persistent storage
/// - Caching compiled regex patterns
/// - Exposing state changes to UI widgets via notifyListeners()
/// - Error handling and logging
/// 
/// Example in main.dart:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => RuleSetProvider(),
///   child: MyApp(),
/// )
/// ```
/// 
/// Example in UI widget:
/// ```dart
/// class RuleListScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final ruleProvider = Provider.of<RuleSetProvider>(context);
///     
///     if (ruleProvider.isLoading) {
///       return CircularProgressIndicator();
///     }
///     
///     if (ruleProvider.error != null) {
///       return Text('Error: ${ruleProvider.error}');
///     }
///     
///     return ListView(
///       children: ruleProvider.rules.rules.map((rule) {
///         return ListTile(title: Text(rule.name));
///       }).toList(),
///     );
///   }
/// }
/// ```
class RuleSetProvider extends ChangeNotifier {
  late AppPaths _appPaths;
  late RuleDatabaseStore _databaseStore;
  late SafeSenderDatabaseStore _safeSenderStore;
  late LocalRuleStore _ruleStore; // Keep for YAML export (dual-write pattern)
  final PatternCompiler _patternCompiler = PatternCompiler();
  final Logger _logger = Logger();

  // State
  RuleSet? _rules;
  SafeSenderList? _safeSenders;
  RuleLoadingState _loadingState = RuleLoadingState.idle;
  String? _error;

  // Getters
  RuleSet get rules => _rules ?? RuleSet(version: '1.0', settings: {}, rules: []);
  SafeSenderList get safeSenders => _safeSenders ?? SafeSenderList(safeSenders: []);
  bool get isLoading => _loadingState == RuleLoadingState.loading;
  bool get isError => _loadingState == RuleLoadingState.error;
  String? get error => _error;
  RuleLoadingState get loadingState => _loadingState;

  /// Initialize the provider (must call before using)
  ///
  /// This initializes AppPaths and loads rules from database storage.
  /// Uses dual-write pattern: database is primary, YAML export for version control.
  Future<void> initialize() async {
    _setLoadingState(RuleLoadingState.loading);

    try {
      // Initialize app paths
      _appPaths = AppPaths();
      await _appPaths.initialize();

      // Create database stores (primary storage)
      final databaseHelper = DatabaseHelper();
      _databaseStore = RuleDatabaseStore(databaseHelper);
      _safeSenderStore = SafeSenderDatabaseStore(databaseHelper);

      // Create YAML store for export (secondary, for version control)
      _ruleStore = LocalRuleStore(_appPaths);

      // Load rules and safe senders from database
      await loadRules();
      await loadSafeSenders();

      _setLoadingState(RuleLoadingState.success);
      _logger.i('RuleSetProvider initialized successfully with database storage');
    } catch (e) {
      _setError('Failed to initialize rules: $e');
      _setLoadingState(RuleLoadingState.error);
      _logger.e('Failed to initialize RuleSetProvider', error: e);
    }
  }

  /// Load rules from database storage
  Future<void> loadRules() async {
    try {
      _setLoadingState(RuleLoadingState.loading);
      _rules = await _databaseStore.loadRules();
      _setLoadingState(RuleLoadingState.success);
      _logger.i('Loaded ${_rules!.rules.length} rules from database');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load rules: $e');
      _setLoadingState(RuleLoadingState.error);
      _logger.e('Failed to load rules', error: e);
      notifyListeners();
    }
  }

  /// Load safe senders from database storage
  Future<void> loadSafeSenders() async {
    try {
      // Load SafeSenderPattern objects from database
      final safeSenderPatterns = await _safeSenderStore.loadSafeSenders();

      // Convert to SafeSenderList (simple patterns for backward compatibility)
      final patterns = safeSenderPatterns.map((s) => s.pattern).toList();
      _safeSenders = SafeSenderList(safeSenders: patterns);

      _logger.i('Loaded ${_safeSenders!.safeSenders.length} safe sender patterns from database');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load safe senders: $e');
      _logger.e('Failed to load safe senders', error: e);
      notifyListeners();
    }
  }

  /// Add a new rule
  ///
  /// Saves to database first, then exports to YAML for version control.
  Future<void> addRule(Rule rule) async {
    if (_rules == null) return;

    try {
      // Add to database
      await _databaseStore.addRule(rule);

      // Update local cache
      final updatedRules = [..._rules!.rules, rule];
      _rules = RuleSet(
        version: _rules!.version,
        settings: _rules!.settings,
        rules: updatedRules,
      );

      // Export to YAML for version control
      await _ruleStore.saveRules(_rules!);

      _logger.i('Added rule: ${rule.name}');
      notifyListeners();
    } catch (e) {
      _setError('Failed to add rule: $e');
      _logger.e('Failed to add rule', error: e);
      notifyListeners();
    }
  }

  /// Remove a rule by name
  ///
  /// Removes from database first, then exports to YAML for version control.
  Future<void> removeRule(String ruleName) async {
    if (_rules == null) return;

    try {
      // Remove from database
      await _databaseStore.deleteRule(ruleName);

      // Update local cache
      final updatedRules = _rules!.rules.where((r) => r.name != ruleName).toList();
      _rules = RuleSet(
        version: _rules!.version,
        settings: _rules!.settings,
        rules: updatedRules,
      );

      // Export to YAML for version control
      await _ruleStore.saveRules(_rules!);
      _logger.i('Removed rule: $ruleName');
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove rule: $e');
      _logger.e('Failed to remove rule', error: e);
      notifyListeners();
    }
  }

  /// Update a rule
  ///
  /// Updates database first, then exports to YAML for version control.
  Future<void> updateRule(String ruleName, Rule updatedRule) async {
    if (_rules == null) return;

    try {
      final ruleIndex = _rules!.rules.indexWhere((r) => r.name == ruleName);
      if (ruleIndex == -1) {
        throw Exception('Rule not found: $ruleName');
      }

      // Update in database
      await _databaseStore.updateRule(updatedRule);

      // Update local cache
      final updatedRules = [..._rules!.rules];
      updatedRules[ruleIndex] = updatedRule;

      _rules = RuleSet(
        version: _rules!.version,
        settings: _rules!.settings,
        rules: updatedRules,
      );

      // Export to YAML for version control
      await _ruleStore.saveRules(_rules!);
      _logger.i('Updated rule: $ruleName');
      notifyListeners();
    } catch (e) {
      _setError('Failed to update rule: $e');
      _logger.e('Failed to update rule', error: e);
      notifyListeners();
    }
  }

  /// Add a safe sender
  ///
  /// Saves to database first, then exports to YAML for version control.
  Future<void> addSafeSender(String pattern) async {
    if (_safeSenders == null) return;

    try {
      // Create SafeSenderPattern with auto-detected type
      final patternType = SafeSenderDatabaseStore.determinePatternType(pattern);
      final safeSenderPattern = SafeSenderPattern(
        pattern: pattern,
        patternType: patternType,
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      );

      // Add to database
      await _safeSenderStore.addSafeSender(safeSenderPattern);

      // Update local cache
      _safeSenders!.add(pattern);

      // Export to YAML for version control
      await _ruleStore.saveSafeSenders(_safeSenders!);
      _logger.i('Added safe sender: $pattern (type: $patternType)');
      notifyListeners();
    } catch (e) {
      _setError('Failed to add safe sender: $e');
      _logger.e('Failed to add safe sender', error: e);
      notifyListeners();
    }
  }

  /// Remove a safe sender
  ///
  /// Removes from database first, then exports to YAML for version control.
  Future<void> removeSafeSender(String pattern) async {
    if (_safeSenders == null) return;

    try {
      // Remove from database
      await _databaseStore.removeSafeSender(pattern);

      // Update local cache
      _safeSenders!.remove(pattern);

      // Export to YAML for version control
      await _ruleStore.saveSafeSenders(_safeSenders!);
      _logger.i('Removed safe sender: $pattern');
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove safe sender: $e');
      _logger.e('Failed to remove safe sender', error: e);
      notifyListeners();
    }
  }

  /// Get compilation stats (for debugging/profiling)
  Map<String, dynamic> getCompilerStats() {
    return _patternCompiler.getStats();
  }

  /// Internal: set loading state and clear error
  void _setLoadingState(RuleLoadingState state) {
    _loadingState = state;
    if (state != RuleLoadingState.error) {
      _error = null;
    }
  }

  /// Internal: set error message
  void _setError(String message) {
    _error = message;
  }
}
