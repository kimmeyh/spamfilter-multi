/// Bounded markdown-section extraction for policy gates.
///
/// **Why this exists as shared code rather than a line in each gate.** Four
/// separate policy gates independently wrote `content.substring(start)` to
/// grab "the section starting here", and every one of them was wrong in the
/// same way: with no end boundary the range runs to END OF FILE, so the
/// assertion silently covers every section ever appended below it.
///
/// The failure mode is not theoretical and not uniform:
///
/// - A POSITIVE assertion (`contains(x)`) becomes vacuous -- it passes when
///   the section itself no longer contains `x`, because some later section
///   happens to mention it. `tester_instructions_test.dart` scanned 18,750
///   characters for a 3,214-character section; gutting the instructions
///   entirely still passed, because a plausible later FAQ used the same three
///   phrases in passing. Those instructions are what tell every tester to pick
///   App Password over Google Sign-In, during the one 14-day window Google
///   reviews.
/// - A NEGATIVE assertion (`isEmpty`, "this must not appear") becomes a false
///   positive -- it fires on innocent prose added later.
///   `closed_test_roster_test.dart` did exactly that, rejecting the app's own
///   public contact address in an appended section.
///
/// Both were found in Sprint 66, days apart, and the second fix was applied
/// without noticing the first gate had the same bug. Hence one helper.
library;

/// Returns the text from [header] up to the next top-level `## ` heading,
/// or to end-of-file when [header] introduces the last section.
///
/// Returns null when [header] is absent, so a caller can fail with its own
/// message rather than silently scanning nothing.
String? sectionFrom(String content, String header) {
  final start = content.indexOf(header);
  if (start < 0) return null;
  final next = content.indexOf('\n## ', start);
  return next > start ? content.substring(start, next) : content.substring(start);
}
