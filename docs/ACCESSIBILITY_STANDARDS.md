# Accessibility Standards

**Status**: Active reference. Produced by **F133-S52** (Sprint 52), the first run of the F133
repeatable audit template.
**Relationship to ADR-0037**: this document **extends** `docs/adr/0037-ui-accessibility-standards.md`.
ADR-0037 is the *decision* -- it sets **WCAG 2.1 AA** as the target and states the labelling rules.
This document is the *practice*: the patterns that actually work in this codebase, the shapes that
silently fail, and how to prove a change is correct. Where the two disagree, ADR-0037 governs the
decision and this document governs the technique.

**Why this exists**: Sprint 51 fixed four surfaces -- No-Rule rows, account rows, the account-picker
dialog, and the MT-1 quick-action grid. **Every one was found reactively**, because an automation
script hit a wall, and two of the four shipped *broken* on the first attempt. A standard that lives
only in a test-harness README and in the memory of whoever last hit the problem is not a standard.

---

## 1. The one rule that matters most

> **A tree dump proves a name exists. Only an interaction proves the node still works.**

Sprint 51 shipped a fix that named the account-picker entries correctly *and made them unclickable*.
It looked right in every inspection. It was caught only when a script tried to press one.

**Therefore**: every accessibility change must be verified by something that **activates** the
control -- a widget test performing `SemanticsAction.tap`, or a WinWright script that drives it.
Never by a tree dump, a screenshot, or reading the code.

This is the "drive it, don't dump it" rule (Sprint 51 retro IMP-6).

---

## 2. The wrapper pattern (proven; do not re-derive)

To make a composite row (`Card` / `ListTile` / `Container` + `Text`) announce as ONE named, actionable
element:

```dart
Semantics(
  container: true,
  button: true,             // only if it is genuinely actionable
  excludeSemantics: true,   // merges children into one node
  label: '<what it IS>',    // e.g. 'kimmeyharold@aol.com - AOL Mail - App Password'
  hint: '<what it DOES>',   // e.g. 'Select account to scan'
  onTap: () => <the same handler the child uses>,   // MANDATORY -- see below
  child: Tooltip(                                    // Tooltip is what reaches Windows UIA
    message: '<label>',
    child: <the real control, innermost>,            // keeps its own onTap
  ),
)
```

### The three shapes that fail, each proven by a failing test

| Shape | Symptom | Why |
|---|---|---|
| `Tooltip` alone | Projects to UIA, but **no screen-reader label** | Tooltip is not a semantic label |
| `Semantics` alone | Labels the Flutter tree, **never reaches Windows UIA** | The UIA projection surfaces tooltip-bearing widgets |
| `Tooltip` **wrapping** `Semantics` | Two stacked nodes; **clicks hit the wrapper**, control never fires | Wrong nesting order |
| `Semantics(button:)` **without** `excludeSemantics` | **Two stacked Buttons with the same name**; a name-based selector matches the outer one, which has no handler | The child keeps its own node |
| `excludeSemantics: true` **without** `onTap` | **One correctly-named node that cannot be activated** | `excludeSemantics` drops the child's gesture node too |

**The last two are the dangerous ones**: both look correct in a tree dump, and both were shipped in
Sprint 51. The second was found by GitHub Copilot during PR review, still live in production after
the "fix".

`explicitChildNodes: true` on a parent **suppresses** a child checkbox's own node -- do not use it on
a row that contains its own interactive controls.

---

## 3. What must carry an accessible name

Per ADR-0037, plus what the Sprint 51/52 audit found in practice:

| Element | Requirement | Current state |
|---|---|---|
| `IconButton`, `ElevatedButton`, `TextButton`, FAB | `tooltip:` (which also reaches UIA) | **Good** -- 87 tooltips across 27 screens |
| `TextField` | `decoration.labelText` or a `Semantics` wrapper | Mostly good |
| **`InkWell` / `GestureDetector`** | `Semantics` wrapper per §2 | **WEAK** -- 16 tappable sites across 8 screens have NO `Semantics` |
| Composite list rows | `Semantics` wrapper per §2 | **WEAK** -- only 5 of 27 screens use `Semantics` at all |
| Decorative icons paired with text | `ExcludeSemantics` | Ad hoc |

**A bare `InkWell` or `GestureDetector` is the highest-risk pattern in this codebase.** Unlike an
`IconButton`, nothing prompts the author for a name, so it renders as an unnamed node that a screen
reader announces as nothing and automation cannot address. That is exactly what the MT-1 quick-action
grid was.

---

## 4. Colors and contrast

**Target**: WCAG 2.1 AA -- **4.5:1** for normal text, **3:1** for large text (18pt+, or 14pt+ bold)
and for UI component boundaries.

**Current risk**: **113 hardcoded `Colors.grey.shadeNNN` / `Colors.grey[NNN]`** uses across the
screens. Grey-on-white is the classic AA failure:

| Shade | Contrast on white | AA normal text | AA large text |
|---|---|---|---|
| `grey.shade400` (#BDBDBD) | ~1.9:1 | **FAIL** | **FAIL** |
| `grey.shade500` (#9E9E9E, = bare `Colors.grey`) | ~2.7:1 | **FAIL** | **FAIL** |
| `grey.shade600` (#757575) | ~4.6:1 | PASS | PASS |
| `grey.shade700` (#616161) | ~6.2:1 | PASS | PASS |

*(Ratios corrected in the PR #292 re-review via the WCAG relative-luminance
formula -- the original table overstated every ratio and wrongly gave
`shade500` an AA-large PASS. The real situation was worse than documented:
`shade500`, including the bare `Colors.grey` alias, fails BOTH tiers. The
`shade600` floor conclusion is unchanged.)*

**Rules**:
1. Body and label text must use **`grey.shade600` or darker** on a light background.
2. `grey.shade400` and lighter are for **decoration only** -- dividers, disabled fills, borders that
   carry no information. Never for text a user must read.
3. Prefer `Theme.of(context).colorScheme.*` over hardcoded colors, so dark mode inherits correctly
   (ADR-0037 cross-platform standard).
4. **Never encode meaning in color alone** -- pair it with an icon, a label, or text. The scan-result
   action colors (red delete / orange junk / green safe) must remain distinguishable without color.

---

## 5. Testing approach

Two harnesses, two jobs (`ADR-0040`, `TESTING_STRATEGY.md`):

### Flutter widget tests -- the authoritative check
The Flutter semantics tree is the **source of truth** for whether a label exists. The Windows UIA
projection proved unreliable as a verification instrument (Sprint 51: the MCP snapshot path and the
CLI `inspect` path disagreed about the same process at the same moment).

```dart
final handle = tester.ensureSemantics();
// name exists?
expect(find.bySemanticsLabel('...'), findsOneWidget);
// and is it ACTUALLY ACTIVATABLE?  <-- the part that catches the real defect
final node = tester.getSemantics(find.bySemanticsLabel('...'));
expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
tester.binding.pipelineOwner.semanticsOwner!
    .performAction(node.id, SemanticsAction.tap);
handle.dispose();
```

Asserting `SemanticsFlag.isButton` is **not sufficient** -- the broken shapes set that flag too.

### WinWright -- proves it reaches the OS
Confirms the label survives the Windows UIA projection, which widget tests cannot see. Per-control
tool rules (see `mobile-app/test/winwright/README.md` for the full list):

- `ww_invoke` for Buttons
- `ww_click` + `useInvokePattern: false` for TabBar tabs, static `Text`, and `CheckBox` (these do not
  support InvokePattern)
- The semantics tree builds **lazily on query**, not on a timer -- prime it with a leading
  `ww_window_state`
- `ww_invoke` reports success on **off-screen** elements without pressing them; maximize first
- `{"success": true}` means *dispatched*, not *effective* -- follow every state change with a step
  that can only resolve if the app actually advanced

---

## 6. Checklist for any new or changed interactive UI

1. Does every interactive element have an accessible **name**?
2. Is every named element still **activatable**? (§1 -- prove it, do not assume)
3. Is any `InkWell` / `GestureDetector` wrapped per §2?
4. Is informational text `grey.shade600` or darker?
5. Is meaning ever carried by color alone?
6. Is there a widget test asserting the **tap action**, not just the label?
7. Touch targets ≥ 48dp (`AccessibilityHelper.minTouchTargetSize`).

---

## References

- `docs/adr/0037-ui-accessibility-standards.md` -- the governing decision (WCAG 2.1 AA)
- `docs/adr/0040-two-e2e-test-harnesses.md` -- why both harnesses exist
- `mobile-app/test/winwright/README.md` -- full harness constraint list
- `mobile-app/test/ui/screens/account_selection_semantics_test.dart` -- reference test, including the
  activation assertion added after the Copilot finding
- `docs/sprints/SPRINT_52_F133_FINDINGS.md` -- the per-screen gap analysis
- [WCAG 2.1 AA quick reference](https://www.w3.org/WAI/WCAG21/quickref/)
