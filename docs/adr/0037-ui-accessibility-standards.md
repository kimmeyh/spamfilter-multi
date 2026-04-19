# ADR-0037: UI/Accessibility Standards and Cross-Platform Compatibility

## Status

Proposed (pending user review)

## Date

2026-04-18

## Context

The app targets multiple platforms (Windows, Android, iOS, macOS, Linux) with different input paradigms (mouse, touch, keyboard, screen reader). As the UI grows more complex (manual rule creation in F56, scan history, settings screens), we need consistent standards for accessibility, text selection, and cross-platform testability.

### Current State

- `accessibility_helper.dart` exists with basic Semantics utilities and 48dp touch target minimum
- Some screens use SelectionArea/SelectableText, others do not
- WinWright E2E tests (Sprint 27+) depend on Windows UI Automation, which requires Semantics labels on interactive elements
- No formal accessibility target documented
- YAML round-trip invariant (export -> user edit -> re-import) is informally understood but not codified

### Problems

1. **Inconsistent text selectability**: Users cannot copy error messages, scan results, or rule patterns on some screens
2. **Missing Semantics labels**: WinWright tests fail to discover elements without labels, making E2E testing unreliable
3. **No accessibility target**: Cannot measure compliance without a stated goal
4. **YAML round-trip breakage risk**: Schema changes that drop classification fields break the export/import cycle

## Decision

### Accessibility Target

**WCAG 2.1 AA** is the target conformance level for all platforms. This covers:
- Color contrast ratios (4.5:1 for normal text, 3:1 for large text)
- Keyboard navigability for all interactive elements
- Screen reader compatibility via Semantics tree
- Touch target minimum of 48dp (already enforced via `AccessibilityHelper.minTouchTargetSize`)

### Semantics Labeling Strategy

All interactive elements must have Semantics labels. This serves two purposes:
1. **Screen reader support**: Users with visual impairments can navigate the app
2. **WinWright testability**: E2E tests discover elements via Windows UI Automation, which reads the Semantics tree

**Rules**:
- Every `IconButton`, `ElevatedButton`, `TextButton`, and `FloatingActionButton` must have a `tooltip` or be wrapped in `Semantics(label: ...)`
- Every `TextField` must have a `decoration.labelText` or be wrapped in `Semantics(label: ...)`
- List items that are tappable must have `Semantics(label: ...)` describing the action
- Use `AccessibilityHelper` constants for common labels (add account, delete, scan, etc.)
- Decorative elements (dividers, spacers, icons paired with text) should use `ExcludeSemantics`

**Adoption**:
- All new UI code must follow these rules (enforced in code review)
- Existing screens are updated opportunistically when touched for other reasons
- `accessibility_helper.dart` is the single source of truth for label constants and helper methods

### SelectionArea/SelectableText Standard

All user-visible text that a user might want to copy must be selectable:
- Error messages
- Scan results (email addresses, rule names, pattern text)
- Rule patterns in Manage Rules / Manage Safe Senders
- Log entries
- Settings values

**Implementation**: Wrap screen content in `SelectionArea` at the Scaffold body level. For screens with complex widget trees where `SelectionArea` causes layout issues, use `SelectableText` on individual text widgets.

**Exclusions**: Navigation labels, button text, and tab headers do not need to be selectable.

### YAML Round-Trip Invariant

All rule and safe-sender schema changes must preserve the export -> user edit -> re-import cycle:
- `Rule.toMap()` must include `patternCategory`, `patternSubType`, `sourceDomain` when present
- `Rule.fromMap()` must read these fields back
- `YamlService` export must write these fields; import must parse them
- Classification fields must survive: YAML export -> user edits YAML in text editor -> re-import via Settings > Data Management

This invariant is tested by the existing YAML round-trip tests and must not be broken by future schema changes.

### Cross-Platform UI Standards

- **Framework**: Flutter Material 3 with `useMaterial3: true`
- **Adaptive breakpoints**: Responsive layout per ADR-0001 (phone < 600dp, tablet 600-900dp, desktop > 900dp)
- **Touch target minimum**: 48dp per `AccessibilityHelper.minTouchTargetSize`
- **Typography**: Use Material 3 type scale (`Theme.of(context).textTheme`)
- **Colors**: Use theme colors, not hardcoded values, for automatic dark mode support

## Consequences

### Positive

- WinWright E2E tests become reliable (elements always discoverable)
- Screen reader users can navigate the app
- Users can copy text from any screen (error messages, patterns, results)
- YAML round-trip is formally protected against regressions
- Consistent look and feel across platforms

### Negative

- All new UI code requires Semantics labels (small overhead per widget)
- Existing screens need gradual updates (technical debt until complete)
- SelectionArea can cause subtle layout issues in complex widget trees (use SelectableText as fallback)

## References

- [WCAG 2.1 AA](https://www.w3.org/WAI/WCAG21/quickref/?currentsidebar=%23col_overview&levels=aaa)
- [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)
- `lib/ui/utils/accessibility_helper.dart` -- existing helper utilities
- ADR-0001: Flutter/Dart single codebase
- Sprint 27: WinWright E2E test infrastructure
