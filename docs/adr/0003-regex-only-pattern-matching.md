# ADR-0003: Regex-Only Pattern Matching

## Status

Accepted

## Date

2025-11-10 (legacy wildcard mode removed)

## Context

The spam filter rule engine evaluates patterns against email fields (from, subject, body, headers) to determine whether an email matches a rule. The system originally supported two pattern syntaxes:

1. **Wildcard patterns**: Simple glob-style matching (e.g., `*@spam.com`) inherited from the original Python desktop application
2. **Regex patterns**: Full regular expression matching (e.g., `@(?:[a-z0-9-]+\.)*spam\.com$`)

This dual-mode system caused several problems:

- **User confusion**: Users were unsure when to use `*` (wildcard) vs. `.*` (regex), leading to rules that did not match as expected
- **Maintenance burden**: Two pattern compilation paths had to be maintained and tested independently
- **Inconsistent behavior**: Wildcard and regex patterns behaved differently in edge cases (escaping, anchoring, case sensitivity)
- **Cross-platform portability**: Regex is a universal standard; wildcard globbing varies by implementation
- **Pattern validation**: Validating wildcards required separate logic from regex validation

## Decision

Remove wildcard pattern support entirely and use regex as the sole pattern matching syntax across all rules. The `PatternCompiler` service:

1. **Compiles all patterns as Dart `RegExp`** with `caseSensitive: false`
2. **Strips Python-style inline flags** (`(?i)`, `(?m)`, `(?s)`) that Dart does not support, since case-insensitive matching is always enabled
3. **Caches compiled patterns** in a HashMap to avoid recompilation during scans
4. **Fails gracefully**: Invalid regex patterns are logged and tracked in a `_failures` map; a never-matching fallback pattern (`(?!)`) is returned instead of throwing an exception
5. **Error visibility**: Compilation failures are tracked and surfaced to the UI so users can fix invalid patterns

The `pattern_type` field in legacy data is ignored; all patterns are treated as regex regardless of this field.

## Alternatives Considered

### Keep Both Wildcard and Regex Modes
- **Description**: Continue supporting both `*`-based wildcard patterns and full regex patterns, with a `pattern_type` field indicating which mode to use
- **Pros**: Backward compatible with existing rules; simpler syntax available for basic patterns
- **Cons**: Two code paths to maintain, test, and debug; user confusion about which to use persists; edge cases where wildcard and regex behave differently
- **Why Rejected**: The maintenance cost of dual modes outweighed the simplicity benefit of wildcards. Most effective spam patterns require regex features (anchoring, character classes, alternation) that wildcards cannot express

### Auto-Convert Wildcards to Regex at Parse Time
- **Description**: Accept wildcard syntax in YAML files but internally convert `*` to `.*`, `?` to `.`, and escape other special characters before compiling as regex
- **Pros**: Users can write simple patterns; no dual compilation paths; backward compatible
- **Cons**: Conversion is lossy (not all glob semantics map cleanly to regex); users see regex in error messages but wrote wildcards; creates a false impression that wildcards are supported
- **Why Rejected**: The translation layer adds complexity without clear benefit. Teaching users basic regex patterns is more valuable than maintaining a translation layer that may produce unexpected results

### Glob-Style Patterns (fnmatch)
- **Description**: Use Python-style fnmatch/glob pattern matching instead of regex
- **Pros**: Simpler syntax; familiar to users who work with file systems
- **Cons**: Cannot express many useful spam patterns (alternation, anchoring, character classes, lookahead); limited expressiveness compared to regex; no standard Dart glob library for string matching (only file paths)
- **Why Rejected**: Spam filtering requires pattern capabilities (domain+subdomain matching, header value extraction, alternation) that glob patterns cannot express efficiently

## Consequences

### Positive
- **Single pattern language**: One compilation path, one set of tests, one mental model for developers and users
- **Full expressiveness**: Regex supports domain+subdomain matching (`@(?:[a-z0-9-]+\.)*spam\.com$`), character classes, alternation, anchoring, and lookahead - all useful for spam filtering
- **Cross-platform portability**: Regex is a universal standard supported by Dart, Python, JavaScript, and every major language. Rules written on one platform work identically on others
- **Pattern validation**: A single validation path catches all invalid patterns and surfaces them to the UI (Issue #4)
- **Performance**: Compiled `RegExp` objects are cached by `PatternCompiler`, avoiding recompilation. Regex matching is optimized by the Dart VM

### Negative
- **Steeper learning curve**: Users creating custom rules must learn basic regex syntax. Patterns like `@(?:[a-z0-9-]+\.)*example\.com$` are not intuitive for non-technical users
- **Error-prone patterns**: Regex syntax errors (unescaped dots, missing anchors, unclosed groups) are common and can cause rules to match incorrectly or not at all
- **No backward compatibility**: Existing wildcard-style rules from the Python era required manual conversion to regex (though in practice the rule set was small enough for a one-time migration)

### Neutral
- **Case-insensitive by default**: All patterns are compiled with `caseSensitive: false`, which matches email conventions but means users cannot create case-sensitive patterns if needed (unlikely requirement for spam filtering)
- **Python flag stripping**: The PatternCompiler strips `(?i)`, `(?m)`, `(?s)` flags for Dart compatibility. This is transparent to users but means patterns imported from Python regex tools may need minor adjustment

## References

- `mobile-app/lib/core/services/pattern_compiler.dart` - Pattern compilation and caching (lines 1-79)
- `mobile-app/lib/core/services/rule_evaluator.dart` - Rule evaluation using compiled patterns
- `docs/RULE_FORMAT.md` - YAML rule format specification (documents regex-only requirement)
- `rules.yaml` - Active spam filtering rules (all regex patterns)
- `rules_safe_senders.yaml` - Safe sender whitelist (all regex patterns)
- GitHub Issue #4 - Silent regex compilation failures (fixed: patterns now tracked and surfaced)
- GitHub Issue #18 - Comprehensive RuleEvaluator test suite (32 tests, 97.96% coverage)
