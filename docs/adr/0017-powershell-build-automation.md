# ADR-0017: PowerShell as Primary Build and Automation Shell

## Status

Accepted

## Date

~2025-10 (project inception on Windows 11)

## Context

The spam filter project is primarily developed on a Windows 11 machine (HP Omen). Build automation includes:

- **Windows desktop builds**: Clean build, secrets injection, code analysis, app launch
- **Android builds**: APK generation, emulator management, debug/release signing, installation
- **Secrets management**: Injecting OAuth credentials via `--dart-define-from-file`
- **Test automation**: Running Flutter tests with coverage
- **Background task setup**: Registering Windows Task Scheduler tasks

Windows offers several shell environments: PowerShell (native), Bash (via Git Bash or WSL), Command Prompt (legacy), and cross-platform tools like Make or Dart build_runner.

A critical constraint was discovered during development: **wrapping PowerShell in Bash loses VSCode terminal environment variables and Flutter toolchain context**, causing build failures. This makes PowerShell-native execution essential, not just a preference.

## Decision

Use PowerShell as the sole build and automation shell. All build scripts are `.ps1` files executed natively in PowerShell context.

### Script Inventory (15+ scripts in `mobile-app/scripts/`)

| Script | Purpose |
|--------|---------|
| `build-windows.ps1` | 5-step Windows build (clean, pub get, analyze, build, run) |
| `build-with-secrets.ps1` | Android build with secrets injection, emulator management |
| `build-apk.ps1` | Release APK generation |
| `run-tests.ps1` | Flutter test execution with coverage |
| `analyze.ps1` | Code quality analysis |

### Key Design Patterns

**Parameterized scripts** with switch flags:
```
.\build-windows.ps1 -RunAfterBuild:$false -Release -SkipClean
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator -EmulatorName "Pixel_7"
```

**Secrets injection**: Scripts detect `secrets.dev.json` and append `--dart-define-from-file=secrets.dev.json` to Flutter build commands.

**Emulator management**: `build-with-secrets.ps1` can auto-launch Android emulators, detect AVD names, wait for boot, and install APKs.

### Execution Constraint

From CLAUDE.md: "When running PowerShell commands programmatically, execute them directly in PowerShell context, NOT wrapped in Bash. Wrapping PowerShell in Bash (`bash -c "powershell ..."`) loses VSCode terminal environment variables and Flutter toolchain context, causing failures."

## Alternatives Considered

### Bash/Shell Scripts (via Git Bash or WSL)
- **Description**: Write `.sh` scripts using Bash syntax, executed via Git Bash or Windows Subsystem for Linux
- **Pros**: Cross-platform (same scripts work on macOS/Linux); familiar to most developers; better support in CI/CD pipelines
- **Cons**: Git Bash has limited Windows API access; WSL adds a virtualization layer; Flutter toolchain context lost when crossing Bash/PowerShell boundary; cannot natively access Windows Task Scheduler, Credential Manager, or Toast APIs; path translation issues between Unix and Windows paths
- **Why Rejected**: The project heavily uses Windows-native APIs (Task Scheduler, Toast notifications, Credential Manager). Bash cannot access these without calling PowerShell anyway, creating a two-layer shell problem

### Makefile
- **Description**: Use GNU Make with a `Makefile` defining build targets
- **Pros**: Declarative; dependency-aware (only rebuilds what changed); language-agnostic; widely used in open source
- **Cons**: Requires GNU Make installation on Windows (not native); Makefile syntax is tab-sensitive and error-prone; limited Windows API access; poor support for parameterized builds (flags, switches); not native to Flutter ecosystem
- **Why Rejected**: Make adds a non-native dependency to Windows and does not naturally support the parameterized, interactive build workflows needed (emulator selection, build type switching, secrets detection)

### Dart build_runner / Custom Dart Scripts
- **Description**: Write build automation in Dart using `build_runner` or custom CLI scripts in `bin/`
- **Pros**: Same language as the project; cross-platform; type-safe; can import project libraries
- **Cons**: Cannot access Windows-specific APIs (Task Scheduler, Toast, tray) without FFI; `build_runner` is designed for code generation, not build orchestration; slower startup than shell scripts; requires `dart run` context
- **Why Rejected**: Build orchestration (clean, analyze, build, deploy, launch emulator) is shell-level work, not application-level. Dart scripts cannot natively manage emulators, install APKs, or register Windows scheduled tasks

### GitHub Actions (CI-Only)
- **Description**: Move all build automation to GitHub Actions workflows, executing builds in cloud runners
- **Pros**: Reproducible; version-controlled; automatic on push/PR; platform matrix support
- **Cons**: Slow feedback loop (minutes vs. seconds); requires internet; cannot test on local devices/emulators; secrets must be configured in GitHub; cannot interact with local Windows APIs; development builds still need local scripts
- **Why Rejected**: Local development requires immediate build feedback and device/emulator interaction. CI/CD is complementary but cannot replace local build scripts. GitHub Actions may be added in the future for PR validation

## Consequences

### Positive
- **Native Windows API access**: Scripts can directly invoke Task Scheduler, Toast notifications, Credential Manager, and other Windows APIs without bridging layers
- **Flutter toolchain preservation**: Running scripts natively in PowerShell preserves VSCode environment variables, Flutter SDK paths, and Android SDK context
- **Parameterized flexibility**: PowerShell's `param()` blocks with typed switches provide a clean, discoverable interface for build configuration
- **No additional dependencies**: PowerShell is pre-installed on all Windows versions; no setup required

### Negative
- **Windows-only**: `.ps1` scripts do not run on macOS or Linux. If the project gains contributors on other platforms, equivalent shell scripts will be needed
- **Execution policy concerns**: Some Windows environments restrict PowerShell script execution. Scripts use `-ExecutionPolicy Bypass` flag, which may not be allowed in enterprise environments
- **Learning curve**: Developers more familiar with Bash must learn PowerShell syntax (different operators, cmdlet naming, pipeline behavior)

### Neutral
- **No CI/CD yet**: The project does not currently have GitHub Actions workflows. All build verification is local via PowerShell scripts. This works for the current solo/small team but would need CI/CD automation as the team grows

## References

- `mobile-app/scripts/build-windows.ps1` - Windows desktop build (5-step process)
- `mobile-app/scripts/build-with-secrets.ps1` - Android build with secrets and emulator management
- `mobile-app/scripts/build-apk.ps1` - Release APK generation
- `CLAUDE.md` - Windows Tool Restrictions section, PowerShell execution constraint
- ADR-0014 (Windows Background Scanning) - PowerShell scripts for Task Scheduler
- ADR-0018 (Windows Toast Notifications) - PowerShell scripts for WinRT Toast API
