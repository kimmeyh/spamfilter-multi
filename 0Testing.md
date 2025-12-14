# Run flutter unit tests
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter test


#-------------------------------
# If need to do a full build:
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter clean; flutter pub get; flutter build windows

cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter clean;
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter pub get
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows

# If all tests passed, then before running re-build the app
cd d:\Data\Harold\github\spamfilter-multi\mobile-app; flutter build windows

**Run Phase 1 Regression Tests Only:**
cd d:\Data\Harold\github\spamfilter-multi\mobile-app

# Test pattern compilation
flutter test test/unit/pattern_compiler_test.dart

# Test safe sender lists
flutter test test/unit/safe_sender_list_test.dart

# Test YAML file loading
flutter test test/integration/yaml_loading_test.dart

# Test complete workflows
flutter test test/integration/end_to_end_workflow_test.dart
