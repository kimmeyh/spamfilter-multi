# ADR-0009: Provider Pattern for State Management

## Status

Accepted

## Date

~2025-10 (project inception)

## Context

The Flutter spam filter application needs state management for two primary concerns:

1. **Rule state** (`RuleSetProvider`): Loading, caching, and modifying spam filtering rules and safe sender lists. Changes must propagate to the UI and persist to both the database and YAML files (dual-write pattern, see ADR-0004).

2. **Scan state** (`EmailScanProvider`): Tracking real-time scan progress (processed count, deleted count, moved count, safe sender count, errors, current email, current folder) and scan configuration (mode, folder selections, email limits).

Both state types require:
- **Reactive UI updates**: The UI must rebuild when state changes (progress counters, loading indicators, error states)
- **Async initialization**: Rules load from the database at startup; scans perform async email operations
- **Throttled notifications**: Scan progress updates must be throttled to avoid excessive UI rebuilds (every 10 emails or 2 seconds)
- **Lifecycle management**: State must persist across widget rebuilds and navigation

Flutter offers several state management approaches, each with different trade-offs for complexity, boilerplate, testability, and learning curve.

## Decision

Use the `provider` package (v6.1.0) with `ChangeNotifier`-based providers, set up via `MultiProvider` in `main.dart`.

**Two providers**:

1. **`RuleSetProvider extends ChangeNotifier`**: Manages rule set and safe sender list. State includes: `RuleSet`, `SafeSenderList`, `RuleLoadingState` (idle/loading/success/error), and error messages. Calls `notifyListeners()` after rule loads, adds, updates, and deletes. Orchestrates the dual-write pattern (database write, then YAML export, then notify UI).

2. **`EmailScanProvider extends ChangeNotifier`**: Manages scan lifecycle and progress. State includes: `ScanStatus` (idle/scanning/paused/completed/error), `ScanMode`, processed/deleted/moved/safe/noRule/error counts, current email, current folder, and results list. Implements throttled notifications to avoid excessive UI rebuilds during rapid email processing.

**Setup in `main.dart`**:
```
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => RuleSetProvider()),
    ChangeNotifierProvider(create: (_) => EmailScanProvider()),
  ],
  child: MaterialApp(...)
)
```

**Initialization**: `RuleSetProvider.initialize()` is called in an `_AppInitializer` widget after providers are created, showing a loading spinner until rules are loaded from the database.

**UI consumption**: Widgets use `context.watch<T>()` for reactive rebuilds and `context.read<T>()` for one-time access or method calls.

## Alternatives Considered

### BLoC (Business Logic Component)
- **Description**: Use the `flutter_bloc` package with separate Event, State, and Bloc classes for each state domain
- **Pros**: Strong separation of concerns; event-driven architecture makes state transitions explicit; built-in support for async operations via `EventHandler`; excellent tooling (BlocObserver, DevTools); well-suited for complex state machines
- **Cons**: Significant boilerplate (Event class, State class, Bloc class per feature); steeper learning curve; more files per feature; event/state pattern adds indirection that can obscure simple operations like "add a rule to the list"
- **Why Rejected**: The state management needs of this application are relatively straightforward - loading data, tracking progress counters, and notifying the UI of changes. BLoC's event-driven architecture and boilerplate are better suited for applications with complex state transitions (e.g., multi-step forms, complex navigation flows). For this project, the additional indirection would add complexity without proportional benefit

### Riverpod
- **Description**: Use the `riverpod` package (v2.x) with `StateNotifier` or `AsyncNotifier` providers
- **Pros**: Compile-time safety (no runtime `ProviderNotFoundException`); no `BuildContext` dependency for reading state; better support for combining providers; more functional/declarative style; easier testing via `ProviderContainer`
- **Cons**: Different mental model from standard Flutter Provider (learning curve for team); less documentation and community examples at the time of project inception; `ref.watch`/`ref.read` pattern differs from standard Flutter patterns; migration from Provider to Riverpod is non-trivial
- **Why Rejected**: At the time of project inception, Provider was the more established and widely documented choice. The project's state management needs are simple enough that Provider's limitations (runtime exceptions, BuildContext dependency) are not significant pain points. Riverpod's advantages (compile-time safety, provider combination) would provide marginal benefit for this project's scope

### GetX
- **Description**: Use the `get` package for state management with reactive observables (`.obs` and `Obx()`)
- **Pros**: Minimal boilerplate; includes routing, dependency injection, and state management in one package; reactive variables are very concise
- **Cons**: "Magic" behavior that is hard to debug; encourages patterns that bypass Flutter's widget lifecycle; less predictable than explicit `notifyListeners()` calls; controversial in the Flutter community for encouraging anti-patterns; monolithic package scope (state + routing + DI + HTTP + storage)
- **Why Rejected**: GetX's implicit reactivity and monolithic scope make it harder to reason about when and why UI updates occur. For a safety-critical application where scan mode enforcement and progress tracking must be predictable, explicit `notifyListeners()` calls provide better visibility and debuggability

### setState Only (No State Management Library)
- **Description**: Use Flutter's built-in `setState()` for all state management, passing data through constructor parameters
- **Pros**: No dependencies; uses only Flutter primitives; easiest to understand; no learning curve
- **Cons**: State must be lifted to common ancestor widgets and passed down through constructors ("prop drilling"); deeply nested widget trees become unwieldy; no easy way to access state from distant widgets; difficult to share state between unrelated screens; rebuilds propagate through entire subtrees
- **Why Rejected**: The scan progress state needs to be accessed from multiple screens (ScanProgressScreen, ResultsDisplayScreen, notification handlers). Passing this state through constructor parameters across the widget tree would create tight coupling and prop drilling. Provider's `context.watch()`/`context.read()` pattern solves this cleanly

## Consequences

### Positive
- **Simple mental model**: `ChangeNotifier` with `notifyListeners()` is easy to understand - mutate state, then notify. No events, reducers, or streams to manage
- **Low boilerplate**: Each provider is a single class extending `ChangeNotifier`. No separate event, state, or action files
- **Flutter-native**: Provider is recommended in Flutter's official documentation and uses standard Flutter concepts (InheritedWidget, BuildContext)
- **Throttled notifications**: `EmailScanProvider` implements custom throttling (10 emails or 2 seconds) within the standard `notifyListeners()` pattern, which would be equally possible but more complex with event-driven approaches
- **Dual-write integration**: `RuleSetProvider` naturally orchestrates the database-write-then-YAML-export sequence within its mutation methods, keeping the dual-write pattern encapsulated

### Negative
- **Runtime exceptions**: Accessing a provider that is not in the widget tree throws a runtime `ProviderNotFoundException` (Riverpod catches this at compile time)
- **BuildContext dependency**: State can only be accessed from widgets with a `BuildContext`, not from services or background tasks. This is a limitation for background scanning where no UI context is available
- **No built-in async support**: Async operations (database loads, YAML exports) must be managed manually with try/catch and state flags (`isLoading`, `isError`). BLoC and Riverpod have built-in async state handling
- **Scaling concern**: If the application grows significantly in complexity (more state domains, more cross-cutting state), Provider's flat `MultiProvider` structure may become harder to manage than Riverpod's provider graph or BLoC's organized event streams

### Neutral
- **Provider v6.1.0 stability**: The Provider package is mature and stable with infrequent breaking changes. This stability reduces maintenance burden but also means the package evolves slowly compared to Riverpod

## References

- `mobile-app/lib/core/providers/rule_set_provider.dart` - Rule state management (lines 63-354)
- `mobile-app/lib/core/providers/email_scan_provider.dart` - Scan state management (lines 93-748), ScanMode enum (lines 22-28), throttling (lines 140-145, 297-306)
- `mobile-app/lib/main.dart` - MultiProvider setup (lines 83-93), initialization (lines 135-154)
- `mobile-app/pubspec.yaml` - `provider: ^6.1.0` dependency
- ADR-0004 (Dual-Write Storage) - RuleSetProvider orchestrates the dual-write pattern
- ADR-0006 (Four Progressive Scan Modes) - EmailScanProvider manages scan mode state
