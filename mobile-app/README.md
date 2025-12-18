# Spam Filter Mobile App

Cross-platform email spam filter application built with Flutter.

## Project Status

**Phase**: Phase 2.1 Verification ✅ COMPLETE (December 18, 2025)  
**Current Status**: All automated tests passing (79/79), manual Windows testing successful, ready for production testing and external user validation

### Pre-External Testing Blockers ✅ RESOLVED
- ✅ AccountSelectionScreen lists all saved Gmail/AOL accounts formatted as "email • Platform • Auth Method" (verified)
- ✅ ScanProgressScreen shows in-progress message immediately after scan starts (verified)
- ✅ ScanProgressScreen auto-resets on load/return (verified)
- ✅ Both Gmail OAuth and AOL App Password auth methods working on Windows (verified)
- ✅ Scan workflow validated end-to-end: account selection → scan progress → results display (verified)

## Architecture

- **Core Models**: EmailMessage, RuleSet, SafeSenderList, EvaluationResult
- **Services**: PatternCompiler, RuleEvaluator, YamlService
- **Adapters**: Email provider interfaces (IMAP, REST API)
- **Storage**: YAML files for rules, secure storage for credentials

## Development Setup

New to the project? See the Windows 11 setup guide: [NEW_DEVELOPER_SETUP.md](NEW_DEVELOPER_SETUP.md)

### Prerequisites

1. **Install Flutter SDK**
   ```powershell
   # Download from https://flutter.dev/docs/get-started/install/windows
   # Or use chocolatey (Admin PowerShell):
   choco install flutter -y
   ```

2. **Configure Android SDK & JDK (Windows)**
   See [NEW_DEVELOPER_SETUP.md](NEW_DEVELOPER_SETUP.md) for validated steps (SDK location, packages, licenses, and JDK 17 config).

3. **Verify Installation**
   ```powershell
   flutter doctor -v
   ```

4. **Get Dependencies**
   ```powershell
   cd mobile-app
   flutter pub get
   ```

### Running the App

```powershell
# Navigate to mobile app directory
cd mobile-app

# Run on connected device
flutter run

# Run tests
flutter test
```

### Quick scripts
- Build release APK:
   - [scripts/build-apk.ps1](scripts/build-apk.ps1)
   - Usage:
      ```powershell
      cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts
      .\build-apk.ps1
      ```
- Launch emulator and run:
   - [scripts/run-emulator.ps1](scripts/run-emulator.ps1)
   - Usage:
      ```powershell
      cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts
      .\run-emulator.ps1               # default emulator id: pixel34
      .\run-emulator.ps1 -EmulatorId pixel34
      .\run-emulator.ps1 -InstallReleaseApk
      ```

## Directory Structure

```
mobile-app/
├── lib/
│   ├── core/          # Business logic (provider-agnostic)
│   │   ├── models/    # EmailMessage, RuleSet, SafeSenderList, EvaluationResult
│   │   └── services/  # PatternCompiler, RuleEvaluator, YamlService
│   ├── adapters/      # Provider implementations
│   │   └── email_providers/  # EmailProvider interface
│   ├── ui/            # Flutter screens and widgets
│   │   └── screens/   # AccountSetupScreen
│   └── config/        # Configuration constants
├── test/              # Unit and integration tests
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── docs/              # Architecture and setup guides
├── android/           # Android-specific files
├── ios/               # iOS-specific files
└── pubspec.yaml       # Dependencies
```

## Migration from Desktop

This mobile app maintains compatibility with the desktop Python application's YAML rule format:
- `rules.yaml` - Spam filtering rules (regex patterns)
- `rules_safe_senders.yaml` - Safe sender whitelist (regex patterns)

See [`../memory-bank/mobile-app-plan.md`](../memory-bank/mobile-app-plan.md) for full development plan.

## Phase 1 MVP - Implementation Status

✅ **Completed**:
- Core models created (EmailMessage, RuleSet, SafeSenderList, EvaluationResult)
- Core services created (PatternCompiler, RuleEvaluator, YamlService)
- Email provider interface defined
- Basic UI scaffold (AccountSetupScreen)
- pubspec.yaml configured

🔄 **In Progress**:
- Flutter SDK installation required
- IMAP adapter implementation (AOL MVP)
- Platform storage integration

📋 **Next Steps**:
1. Install Flutter SDK: https://flutter.dev/docs/get-started/install/windows
2. Run `flutter pub get` to install dependencies
3. Implement GenericIMAPAdapter using `enough_mail` package
4. Add platform-specific storage paths (`path_provider`)
5. Build scan UI and progress tracking
6. Create unit tests for core business logic
7. Performance profiling with sample rule sets

## Testing

```powershell
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/rule_evaluator_test.dart
```

## Building

```powershell
# Build APK for Android
flutter build apk

# Build iOS (requires macOS)
flutter build ios

# Build for web
flutter build web
```

## Contributing

See [`../memory-bank/development-standards.md`](../memory-bank/development-standards.md) for coding standards and best practices.

## License

See [LICENSE](../LICENSE) for details.

## Related Documentation

- [Mobile App Plan](../memory-bank/mobile-app-plan.md) - Complete development roadmap
- [Processing Flow](../memory-bank/processing-flow.md) - Current processing logic
- [YAML Schemas](../memory-bank/yaml-schemas.md) - Rule format specifications
- [Desktop Archive](../Archive/desktop-python/README.md) - Original Python application
