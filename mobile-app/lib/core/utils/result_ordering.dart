/// F222 (Sprint 74): newest-first ordering, clustered by base domain.
///
/// Harold's specification (2026-09-17), for a tester who found the scan
/// results list "quite confusing" because it did not read like an inbox:
///
///   1. take the NEWEST remaining email;
///   2. emit it, then every other remaining email sharing its BASE domain,
///      newest-first within that cluster;
///   3. repeat until nothing remains.
///
/// Implemented in O(n log n) rather than by repeated scanning: sort
/// newest-first once, then emit each domain's cluster in the order its
/// FIRST appearance occurs. Because the list is newest-first, a domain's
/// first appearance is its newest email, and the newest email not yet
/// emitted always belongs to the next cluster by first appearance -- which is
/// exactly steps 1-3.
///
/// Pure and generic so it is testable without a widget, and so the call site
/// cannot silently sort something else (Sprint 73 "correct abstraction, wrong
/// wiring": the call site is tested separately).
library;

/// Returns a NEW list; [items] is never reordered in place (the caller's list
/// may be the provider's own).
///
/// [receivedAt] supplies each item's date. [baseDomainOf] supplies its base
/// (registrable) domain -- an empty string is its own cluster. Ties on date
/// are broken by [tieBreak] when given, so the order is deterministic
/// (Dart's `List.sort` is not stable).
List<T> orderNewestFirstClusteredByDomain<T>(
  List<T> items, {
  required DateTime Function(T) receivedAt,
  required String Function(T) baseDomainOf,
  String Function(T)? tieBreak,
}) {
  final sorted = List<T>.of(items)
    ..sort((a, b) {
      final byDate = receivedAt(b).compareTo(receivedAt(a));
      if (byDate != 0 || tieBreak == null) return byDate;
      return tieBreak(a).compareTo(tieBreak(b));
    });

  // LinkedHashMap (the Dart default) preserves insertion order, so clusters
  // come out in order of each domain's newest email.
  final clusters = <String, List<T>>{};
  for (final item in sorted) {
    clusters.putIfAbsent(baseDomainOf(item).toLowerCase(), () => <T>[]).add(item);
  }
  return [for (final cluster in clusters.values) ...cluster];
}
