# ADR-0001: Flutter/Dart Single Codebase for All Platforms

## Status

Accepted

## Date

~2025-10 (project inception)

## Context

The spam filter project originated as a Python desktop application (`archive/desktop-python/`) targeting only Microsoft Outlook on Windows. The vision expanded to support multiple email providers (Gmail, AOL, Yahoo, iCloud, ProtonMail, Outlook.com) across all major platforms (Windows, macOS, Linux, Android, iOS).

Key forces driving this decision:

- **Multi-platform requirement**: Users need spam filtering on desktop and mobile devices
- **Single rule engine**: The same YAML-based spam filtering rules must work identically across all platforms
- **Small team**: A solo/small developer team cannot maintain 2-5 separate native codebases
- **Business logic portability**: The rule evaluator, pattern compiler, and email scanner should not be reimplemented per platform
- **Time to market**: Building once and deploying everywhere is faster than building per platform

## Decision

Use 100% Flutter/Dart for all platforms with a single codebase. The original Python desktop application is archived (retained as reference in `archive/desktop-python/`) and all new development uses Flutter.

The application targets all five platforms from a single `mobile-app/` directory:
- Android and iOS (mobile)
- Windows, macOS, and Linux (desktop)

All business logic (rule evaluation, pattern compilation, email scanning) lives in `lib/core/` and is completely platform-agnostic. Platform-specific code is isolated in `lib/adapters/` behind abstract interfaces.

## Alternatives Considered

### Keep Python Desktop + Build Separate Mobile Apps
- **Description**: Maintain the existing Python/Outlook app for Windows and build separate native apps (Kotlin for Android, Swift for iOS) for mobile
- **Pros**: Each platform gets a fully native experience; Python app already working for Outlook
- **Cons**: Business logic (rule evaluation, pattern matching) must be reimplemented in 3 languages; YAML rule format must be parsed identically in Python, Kotlin, and Swift; bug fixes must be applied in multiple places; testing effort multiplied per platform
- **Why Rejected**: Duplicating the rule engine across languages creates divergence risk and multiplies maintenance effort beyond what a small team can sustain

### React Native
- **Description**: Use React Native with JavaScript/TypeScript for a cross-platform mobile and desktop app
- **Pros**: Large ecosystem, strong community, web developers can contribute
- **Cons**: Desktop support (via Electron or react-native-windows/macos) was less mature at decision time; JavaScript runtime overhead; bridging to native IMAP libraries more complex; no strong typing without TypeScript setup
- **Why Rejected**: Desktop support maturity was a concern, and the Flutter desktop story was more cohesive for targeting Windows/macOS/Linux from the same framework

### Kotlin Multiplatform (KMP)
- **Description**: Share business logic in Kotlin across Android, iOS, and desktop, with platform-specific UI layers
- **Pros**: Native UI per platform; Kotlin is expressive and type-safe; strong Android support
- **Cons**: Desktop (Compose Multiplatform) support was nascent at decision time; still requires platform-specific UI code; iOS integration via Kotlin/Native adds complexity
- **Why Rejected**: Would still require maintaining separate UI codebases per platform, increasing total effort. Flutter provides a single UI framework across all platforms

### .NET MAUI
- **Description**: Use Microsoft .NET MAUI for cross-platform development with C#
- **Pros**: Strong Windows support; good integration with Outlook/Microsoft ecosystem; C# is well-suited for business logic
- **Cons**: Linux support was limited/absent; heavier runtime; smaller community for mobile compared to Flutter/React Native; tighter coupling to Microsoft ecosystem
- **Why Rejected**: Lack of Linux support and the desire to remain vendor-neutral (not tied to Microsoft ecosystem) made this less suitable

## Consequences

### Positive
- **Single rule engine**: RuleEvaluator, PatternCompiler, and EmailScanner are written once and work identically on all platforms
- **Shared YAML rules**: The same `rules.yaml` and `rules_safe_senders.yaml` files are portable across all devices
- **One test suite**: 122+ tests cover the entire business logic without per-platform duplication
- **Consistent UX**: Material Design UI is consistent across platforms (with platform-adaptive elements)
- **Single dependency tree**: One `pubspec.yaml` manages all dependencies
- **Faster iteration**: Bug fixes and features ship to all platforms simultaneously

### Negative
- **Flutter desktop maturity**: Desktop support (especially Windows) is less mature than mobile, requiring workarounds for features like system tray, native notifications, and Task Scheduler integration
- **Platform-specific workarounds**: Windows notifications use PowerShell-generated Toast scripts because `flutter_local_notifications` Windows support was pending; background scanning uses native Task Scheduler rather than a Flutter abstraction
- **OAuth complexity**: Each platform requires a different OAuth flow (Android native Google Sign-In, Windows browser-based loopback redirect, iOS native browser), adding platform-specific adapter code
- **Dart ecosystem**: Dart has a smaller ecosystem than JavaScript/Python/Kotlin, meaning fewer third-party packages for niche requirements

### Neutral
- **Dart as required language**: Developers must know Dart (less common than JS/Python/Kotlin), but Dart is relatively easy to learn for developers familiar with Java/C#/TypeScript
- **Flutter framework coupling**: The project is coupled to Flutter's release cycle and roadmap, but Flutter has strong backing from Google and an active community

## References

- `archive/desktop-python/` - Original Python desktop application (archived)
- `mobile-app/pubspec.yaml` - Flutter project configuration and dependencies
- `mobile-app/lib/core/` - Platform-agnostic business logic
- `mobile-app/lib/adapters/` - Platform-specific implementations behind interfaces
- `docs/ARCHITECTURE.md` - Full architecture documentation
