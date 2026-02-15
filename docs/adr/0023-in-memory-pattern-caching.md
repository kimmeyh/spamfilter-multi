# ADR-0023: In-Memory Pattern Caching

## Status

Accepted

## Date

~2025-10 (project inception)

## Context

The spam filter evaluates regex patterns against email fields (from, subject, body, headers) for every email during a scan. Pattern evaluation involves two steps:

1. **Compilation**: Converting a regex string (e.g., `@spam\.com$`) into a compiled `RegExp` object
2. **Matching**: Running the compiled `RegExp` against email text

Compilation is expensive relative to matching. A scan of 500 emails against 50 rules with 3 patterns each means 75,000 pattern evaluations per scan. Without caching, each evaluation recompiles the regex from the string, wasting CPU on redundant work.

Performance benchmarks showed:
- **Without caching**: ~2.1ms per pattern compilation + match
- **With caching**: ~0.18ms per match (compilation amortized to zero after first use)
- **Speedup**: ~100x for cached patterns

## Decision

Implement an in-memory `HashMap<String, RegExp>` cache in `PatternCompiler` that stores compiled regex objects keyed by their source pattern string. A parallel `HashMap<String, String>` tracks compilation failures.

### Cache Behavior

- **First compilation**: Pattern string is compiled to `RegExp(pattern, caseSensitive: false)`, stored in cache, and returned
- **Subsequent lookups**: Cache hit returns the compiled `RegExp` directly, skipping compilation
- **Invalid patterns**: Compilation failures are caught, logged, and cached as a never-matching sentinel (`RegExp(r'(?!)')`) to avoid repeated compilation attempts. The error message is stored in the `_failures` map
- **Statistics**: Hit count, miss count, and failure count are tracked for performance monitoring

### Python Regex Compatibility

Patterns imported from the original Python desktop app may contain Python-specific inline flags (`(?i)`, `(?m)`, `(?s)`, `(?x)`) that Dart's `RegExp` does not support. The compiler strips these flags before compilation, since all patterns are compiled with `caseSensitive: false` (making `(?i)` redundant).

### Cache Lifecycle

- **No eviction**: The cache grows unbounded for the lifetime of the app process (known limitation, Issue #16)
- **Manual clear**: `clear()` method wipes both caches and resets statistics
- **Per-process**: Cache is not persisted; each app launch starts with an empty cache

## Alternatives Considered

### No Caching (Recompile Every Time)
- **Description**: Compile each regex pattern from string on every evaluation, with no caching
- **Pros**: Simplest implementation; no memory overhead; no stale cache concerns; no cache invalidation needed
- **Cons**: 100x slower for repeated patterns (2.1ms vs 0.18ms); a 500-email scan with 50 rules would take ~75 seconds of compilation alone vs. ~750ms with caching; unacceptable for production scans
- **Why Rejected**: The performance difference is order-of-magnitude. Without caching, email scanning would be impractically slow for users with moderate rule sets

### LRU (Least Recently Used) Cache
- **Description**: Cache compiled patterns with a maximum size limit, evicting the least recently used entries when the limit is reached
- **Pros**: Bounded memory usage; prevents unbounded growth (Issue #16); retains frequently used patterns; well-understood cache algorithm
- **Cons**: More complex implementation; eviction of patterns that are needed later in the scan causes recompilation; must choose a size limit (too small = frequent evictions, too large = same as unbounded)
- **Why Rejected**: Not rejected in principle - this is the recommended future improvement documented in Issue #16. The current unbounded cache was simpler to implement initially and is adequate for current data sizes (typical rule sets have fewer than 200 unique patterns, consuming negligible memory)

### Per-Scan Cache with Clear
- **Description**: Create a new cache for each scan, clearing it when the scan completes
- **Pros**: Bounded to scan lifetime; no leak between scans; fresh start for each scan
- **Cons**: Patterns must be recompiled at the start of every scan; loses the amortization benefit across scans; if a user runs multiple scans in a session, all benefit from a persistent cache
- **Why Rejected**: Users commonly run multiple scans in a session (different accounts, different modes). A persistent cache means the second and subsequent scans benefit from patterns compiled during the first scan

### Pre-Compiled Pattern Storage
- **Description**: Compile all patterns at rule load time and store the compiled `RegExp` objects alongside the rule data
- **Pros**: Zero compilation overhead during scanning; patterns compiled once when rules are loaded or modified
- **Cons**: `RegExp` objects cannot be serialized to the database; compilation must happen after database load (same as current approach); patterns in YAML cannot store compiled objects; essentially the same as the cache but tied to the rule data model
- **Why Rejected**: This approach is functionally equivalent to the cache but would couple compilation with the rule data model. The cache approach is cleaner because it is transparent - the PatternCompiler is a standalone service that any consumer can use

## Consequences

### Positive
- **100x speedup**: Cached patterns provide ~100x faster evaluation compared to recompilation (0.18ms vs 2.1ms per pattern)
- **Transparent caching**: Callers of `PatternCompiler.compile()` do not need to manage caching; the cache is internal and automatic
- **Failure resilience**: Invalid patterns are cached as never-matching sentinels, preventing repeated compilation attempts and providing clear error tracking for the UI
- **Cross-platform consistency**: All patterns are compiled with `caseSensitive: false`, ensuring consistent matching behavior across platforms

### Negative
- **Unbounded growth (Issue #16)**: The cache HashMap grows without limit. For typical rule sets (under 200 patterns), this is negligible (~50KB). For hypothetical extreme cases (thousands of unique patterns), memory usage could become significant
- **No invalidation**: If a pattern string is modified in the database, the old compiled version remains in the cache until the app is restarted. In practice, rule modifications trigger `PatternCompiler.clear()` via the RuleSetProvider, but this is not enforced at the cache level
- **Process-scoped only**: The cache does not persist across app restarts, meaning the first scan after launch always incurs compilation overhead

### Neutral
- **Python flag stripping**: The automatic stripping of `(?i)`, `(?m)`, `(?s)`, `(?x)` flags is a compatibility convenience that could mask issues if a user intentionally includes these flags expecting them to change behavior. Since all patterns are case-insensitive, the stripping is functionally correct

## References

- `mobile-app/lib/core/services/pattern_compiler.dart` - Cache implementation (lines 1-80): HashMap caches (7-8), compile with cache (13-47), failure tracking (38-45), statistics (65-72), Python flag stripping (21-32)
- `docs/PERFORMANCE_BENCHMARKS.md` - 100x speedup measurement (lines 37-38)
- GitHub Issue #16 - Unbounded cache growth (medium priority, future improvement)
- GitHub Issue #4 - Silent regex compilation failures (fixed: now tracked in _failures map)
- ADR-0003 (Regex-Only Pattern Matching) - PatternCompiler is the sole compilation path
