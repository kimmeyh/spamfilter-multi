/// Frequency options for background scanning.
///
/// F144 (Sprint 60): extracted from the removed `background_scan_manager.dart`.
/// That file's classes (`BackgroundScanManager`/`BackgroundScanService`, a
/// workmanager-based Android scheduler predating the current architecture)
/// had ZERO call sites and were deleted per the F141/F144 direction -- the
/// Windows Task Scheduler architecture (ADR-0039/0040) takes precedence, and
/// the future Android implementation mirrors IT rather than the old code.
/// This enum, however, is the LIVE frequency vocabulary shared by the Windows
/// scheduler path (`windows_task_scheduler_service.dart`,
/// `powershell_script_generator.dart`), settings, and main.dart -- so it
/// moved here rather than dying with its old host file.
enum ScanFrequency {
  disabled(0, 'Disabled'),
  every15min(15, '15 minutes'),
  every30min(30, '30 minutes'),
  every1hour(60, '1 hour'),
  daily(1440, 'Daily');

  final int minutes;
  final String label;

  const ScanFrequency(this.minutes, this.label);

  static ScanFrequency fromMinutes(int minutes) {
    return values.firstWhere(
      (f) => f.minutes == minutes,
      orElse: () => ScanFrequency.disabled,
    );
  }
}
