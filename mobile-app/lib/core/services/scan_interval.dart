/// F264 (Sprint 77): the background-scan interval, as ONE shared model.
///
/// Replaces the fixed `ScanFrequency` list. An interval is an integer number of
/// minutes carried end to end -- UI, storage, startup reconciliation, the
/// Windows trigger and the Android alarm all speak minutes, and this file is
/// the only place that knows how minutes relate to what the user types
/// (a unit and a 1-99 number) and which values are allowed.
///
/// **Prevention (Harold's prevention-first rule).** The old design had FIVE
/// copies of the vocabulary (the enum, the Settings list `[15, 30, 60, 120,
/// 240]`, the startup `firstWhere`, the Windows trigger `switch`, and the
/// repair-path substring match). Two of the copies disagreed with the enum,
/// which produced three silent defects: saving 120 or 240 minutes scheduled
/// nothing, the startup path rescheduled the same account every 15 minutes, and
/// the repair path guessed an interval from a trigger string. A single model
/// with one validator, one normalizer and one conversion removes the class.
///
/// ADR-0042: shared code, identical on Windows and Android. The OS limits that
/// differ are declared where they apply (`background_scan_scheduler.dart`).
library;

/// The smallest interval a user may choose, in minutes.
///
/// Product Owner decision (Sprint 77 Q14): 5 minutes, held as ONE named
/// constant because the R76-1 battery measurements may move it later.
///
/// Tied to [BackgroundScanCore.kMinScanSpacing] by
/// `scan_interval_test.dart`: a background scan waits until that long after
/// the account's last completed scan, so an interval below it would make every
/// scan wait. The floor is the smallest value that never does.
const int kMinIntervalMinutes = 5;

/// The largest interval a user may choose: 99 hours (a 2-digit number of hours).
const int kMaxIntervalMinutes = 99 * 60;

/// The largest NUMBER the 2-digit box accepts, in either unit.
const int kMaxIntervalNumber = 99;

/// Android's WorkManager cannot run periodic work more often than this
/// (developer.android.com, "define work": "The minimum repeat interval that can
/// be defined is 15 minutes"). Only the WorkManager safety net is clamped to
/// it; the Doze alarm carries the user's own minutes.
const int kWorkManagerMinimumMinutes = 15;

/// Start-time jitter (Sprint 77 Q13, Harold: "if > 15 min then random +/- 5
/// minutes"): applies ONLY to intervals LONGER than this many minutes.
const int kJitterThresholdMinutes = 15;

/// The jitter is up to this many minutes either way.
const int kJitterMinutes = 5;

/// The unit a user picks in front of the number box.
enum ScanIntervalUnit {
  minutes('Minutes', 1),
  hours('Hours', 60);

  const ScanIntervalUnit(this.label, this.minutesPerUnit);

  /// Dropdown label.
  final String label;

  /// How many minutes one of this unit is.
  final int minutesPerUnit;
}

/// The message shown inline for an entry below the floor, verbatim from the
/// Product Owner (Sprint 77 Q11).
const String kIntervalTooShortMessage =
    'Minimum is 5 minutes, to limit battery use';

/// The message for an entry above the ceiling.
const String kIntervalTooLongMessage = 'Maximum is 99 hours';

/// Pure helpers for the interval model. No I/O, no platform branch.
class ScanInterval {
  ScanInterval._();

  /// `number x unit`, in minutes.
  static int toMinutes(ScanIntervalUnit unit, int number) =>
      number * unit.minutesPerUnit;

  /// Why [minutes] is not an allowed interval, or null when it is.
  ///
  /// Range only. A value such as 125 minutes is in range but not typable (the
  /// number box holds 1-99 of one unit); use [isRepresentable] for that and
  /// [nearestValid] to convert it.
  static String? validate(int minutes) {
    if (minutes < kMinIntervalMinutes) return kIntervalTooShortMessage;
    if (minutes > kMaxIntervalMinutes) return kIntervalTooLongMessage;
    return null;
  }

  /// Whether the unit + number control can express [minutes] exactly:
  /// 5-99 minutes, or a whole number of hours from 1 to 99.
  static bool isRepresentable(int minutes) {
    if (validate(minutes) != null) return false;
    if (minutes <= kMaxIntervalNumber) return true;
    return minutes % 60 == 0;
  }

  /// The nearest interval the control can express ([isRepresentable]).
  ///
  /// THE conversion for existing users (Sprint 77 Q11: "existing users take a
  /// conversion from current, Windows and Android"): a stored value that the
  /// control cannot show becomes the closest one it can. A tie goes to the
  /// LONGER interval, which costs less battery. Written once, used by the
  /// upgrade migration and by startup reconciliation.
  static int nearestValid(int minutes) {
    if (minutes <= kMinIntervalMinutes) return kMinIntervalMinutes;
    if (minutes >= kMaxIntervalMinutes) return kMaxIntervalMinutes;
    if (isRepresentable(minutes)) return minutes;

    // Between 100 and 5939 minutes and not a whole number of hours: the
    // candidates are 99 minutes and the whole hours on either side.
    final lowerHours = minutes ~/ 60;
    final candidates = <int>{
      if (minutes > kMaxIntervalNumber && lowerHours >= 2) lowerHours * 60,
      (lowerHours + 1) * 60,
      if (minutes < 2 * 60) kMaxIntervalNumber,
    }.where((c) => c <= kMaxIntervalMinutes).toList();
    var best = candidates.first;
    for (final c in candidates.skip(1)) {
      final dBest = (best - minutes).abs();
      final dC = (c - minutes).abs();
      if (dC < dBest || (dC == dBest && c > best)) best = c;
    }
    return best;
  }

  /// Splits [minutes] for display: a whole number of hours (60 or more) shows
  /// as hours, everything else as minutes. [minutes] should already satisfy
  /// [isRepresentable]; others are converted with [nearestValid] first.
  static ({ScanIntervalUnit unit, int number}) split(int minutes) {
    final m = nearestValid(minutes);
    if (m >= 60 && m % 60 == 0) {
      return (unit: ScanIntervalUnit.hours, number: m ~/ 60);
    }
    return (unit: ScanIntervalUnit.minutes, number: m);
  }

  /// User-facing text, for example "5 minutes", "1 hour", "2 hours".
  static String label(int minutes) {
    final s = split(minutes);
    final noun = s.unit == ScanIntervalUnit.hours ? 'hour' : 'minute';
    return '${s.number} $noun${s.number == 1 ? '' : 's'}';
  }

  /// Whether a run at [minutes] gets start-time jitter (Q13).
  static bool hasJitter(int minutes) => minutes > kJitterThresholdMinutes;

  /// The interval the Android WorkManager safety net is registered with: the
  /// user's minutes, but never below WorkManager's own documented minimum.
  static int workManagerMinutes(int minutes) =>
      minutes < kWorkManagerMinimumMinutes
          ? kWorkManagerMinimumMinutes
          : minutes;

  /// What startup reconciliation does with a stored interval: an out-of-range
  /// or untypable value is converted with [nearestValid] and the caller logs
  /// it. Never replaced by a hard-coded default (the old `orElse: every15min`).
  static ({int minutes, bool converted}) reconcileStored(int stored) {
    final fixed = nearestValid(stored);
    return (minutes: fixed, converted: fixed != stored);
  }
}
