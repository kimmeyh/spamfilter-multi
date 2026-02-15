# ADR-0022: Throttled UI Progress Updates

## Status

Accepted

## Date

~2025-10 (project inception; tuned in Sprint 14, Issue #128)

## Context

During an email scan, the `EmailScanProvider` processes emails sequentially, updating counters (processed, deleted, moved, safe, no-rule, error) for each email. The UI displays these counters in real time on the Scan Progress screen.

Without throttling, `notifyListeners()` would be called for every email processed. In a scan of 1000 emails, this means 1000 UI rebuilds in rapid succession. This causes:

- **UI thrashing**: Widget tree rebuilds faster than the screen can render, causing visual stuttering
- **Battery drain**: Continuous UI updates on mobile devices waste CPU and battery
- **Performance degradation**: The Provider notification mechanism triggers all listening widgets to rebuild, even if the visual change is imperceptible (counter going from 501 to 502)

The challenge is finding the right balance: updates should be frequent enough to feel responsive but infrequent enough to avoid waste.

## Decision

Implement dual-threshold throttling: notify listeners every **10 emails processed** OR every **2 seconds**, whichever comes first.

### Implementation

```
_progressEmailInterval = 10      // emails between notifications
_progressTimeInterval = 2 seconds // time between notifications (was 3s, Issue #128)
_emailsSinceLastNotification = 0  // counter, reset on each notification
_lastProgressNotification = null  // timestamp, reset on scan start
```

### Throttling Logic (in `updateProgress()`)

```
For each email processed:
  increment _emailsSinceLastNotification

  shouldNotify =
    _emailsSinceLastNotification >= 10
    OR _lastProgressNotification == null (first update)
    OR now - _lastProgressNotification >= 2 seconds

  if shouldNotify:
    reset _emailsSinceLastNotification to 0
    set _lastProgressNotification to now
    notifyListeners()
```

### Result Recording Throttle

A separate 2-second throttle applies to `recordResult()` to prevent excessive rebuilds of the results list during rapid evaluation.

### History

- **Original (Sprint 1-13)**: 3-second interval
- **Sprint 14 (Issue #128)**: Reduced to 2 seconds based on user feedback that 3-second gaps between folder updates felt unresponsive

### Reset on Scan Start

Both `_lastProgressNotification` and `_emailsSinceLastNotification` are reset in `startScan()` to ensure the first email in a new scan triggers an immediate UI update.

## Alternatives Considered

### Update Per Email (No Throttling)
- **Description**: Call `notifyListeners()` after every single email is processed
- **Pros**: Maximally responsive; users see real-time progress for every email; counters always current
- **Cons**: 1000+ UI rebuilds per scan; visible stuttering; wasted CPU/battery; Provider notification overhead accumulates; mobile devices may drop frames
- **Why Rejected**: The performance cost is unacceptable for large scans. Users cannot perceive the difference between updating every email vs. every 10 emails at scan speeds of 20-50 emails/second

### Fixed Timer Only (No Email Count Threshold)
- **Description**: Notify listeners every N seconds, regardless of how many emails have been processed
- **Pros**: Predictable notification frequency; simple implementation; consistent battery usage
- **Cons**: During slow scans (network latency), the timer fires even if no new emails have been processed (wasted rebuild); during fast scans, the timer may miss bursts of activity (10 emails processed in 500ms but no update for 2 more seconds)
- **Why Rejected**: A timer-only approach does not adapt to scan speed. The email-count threshold catches fast bursts, while the timer ensures updates during slow periods. The dual-threshold approach handles both extremes

### Debounce (Delay Until Quiet)
- **Description**: Delay notifications until no new emails arrive for N milliseconds (debounce pattern)
- **Pros**: Minimizes notifications during rapid processing; coalesces multiple updates into one
- **Cons**: During continuous scanning, the debounce timer keeps resetting and the UI never updates until the scan pauses or completes; users see no progress during the scan itself
- **Why Rejected**: Debouncing works well for user input (search-as-you-type) but poorly for continuous processing. Users need to see progress during the scan, not just at the end

### Percentage-Based Updates (Every 5% or 10%)
- **Description**: Notify when the processed count crosses percentage thresholds (e.g., 10%, 20%, ..., 100%)
- **Pros**: Fixed number of updates (10-20 per scan); consistent regardless of scan size
- **Cons**: For small scans (20 emails), updates are too infrequent at 10% intervals (every 2 emails is fine); requires knowing total count upfront (not always available with dynamic folder discovery); late-scan updates are sparse when users are most eager to see results
- **Why Rejected**: The total email count is not always known at scan start (dynamic folder discovery). Percentage-based updates cannot adapt to unknown totals and provide poor granularity for small scans

## Consequences

### Positive
- **Responsive feel**: 2-second maximum gap between updates feels responsive without being wasteful
- **Burst handling**: The 10-email threshold catches fast processing bursts, ensuring the UI reflects rapid progress
- **Battery friendly**: On mobile, limiting rebuilds to ~30 per minute (vs. 1000+) significantly reduces CPU and battery usage
- **Adaptive**: Works well for both slow scans (network-bound, timer kicks in) and fast scans (email count kicks in)

### Negative
- **Not real-time**: Counters may lag behind actual progress by up to 2 seconds or 9 emails, which could confuse users expecting instant updates
- **Hardcoded thresholds**: The 10-email and 2-second values are constants, not user-configurable. Different devices or use cases might benefit from different thresholds

### Neutral
- **Tuning history**: The time interval was tuned from 3 seconds to 2 seconds based on user feedback (Issue #128). Further tuning may occur as scan speeds change with batch operations or different email providers

## References

- `mobile-app/lib/core/providers/email_scan_provider.dart` - Throttling constants (lines 144-145), throttling logic (lines 294-306), result throttling (lines 593-603), scan start reset (lines 239-241)
- GitHub Issue #128 - Reduced throttle interval from 3s to 2s (Sprint 14)
- ADR-0009 (Provider Pattern) - EmailScanProvider uses notifyListeners() for reactive UI updates
