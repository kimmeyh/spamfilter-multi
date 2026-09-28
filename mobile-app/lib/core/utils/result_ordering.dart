/// F222 (Sprint 74, reworked at Manual Validation 2026-09-27): the two
/// orders the Scan Results list can be shown in.
///
/// Harold, after seeing the first version (newest-first clustered by base
/// domain): *"default should stay sorted by folder, then sender domain A to
/// Z, then sender address A to Z. ... Need a UI mechanism to switch between
/// the 2 sorts (default and date (descending))"*. So:
///
/// - [ResultSortOrder.folderDomainAddress] -- the DEFAULT, and exactly the
///   pre-Sprint-74 comparator (folder, then sender domain, then sender
///   address, all A to Z).
/// - [ResultSortOrder.newestFirst] -- received date, newest first.
///
/// Both then get the Sprint 46 "from email providers / not from email
/// providers" partition, which the screen applies AFTER sorting (a stable
/// partition), so neither order here knows about it.
///
/// Pure and generic so each order is testable without a widget; the call
/// site is tested separately (Sprint 73 "correct abstraction, wrong wiring").
library;

/// The two Scan Results orders (F222).
enum ResultSortOrder {
  /// Default: folder, then sender domain, then sender address (A to Z).
  folderDomainAddress,

  /// Received date, newest first.
  newestFirst,
}

/// Folder, then sender domain, then sender address -- all A to Z. The exact
/// pre-Sprint-74 order. [tieBreak], when given, makes equal keys
/// deterministic (Dart's `List.sort` is not stable).
///
/// Returns a NEW list; [items] is never reordered in place (the caller's list
/// may be the provider's own).
List<T> orderByFolderDomainAddress<T>(
  List<T> items, {
  required String Function(T) folderOf,
  required String Function(T) domainOf,
  required String Function(T) addressOf,
  String Function(T)? tieBreak,
}) {
  return List<T>.of(items)
    ..sort((a, b) {
      final byFolder = folderOf(a).compareTo(folderOf(b));
      if (byFolder != 0) return byFolder;
      final byDomain = domainOf(a).compareTo(domainOf(b));
      if (byDomain != 0) return byDomain;
      final byAddress = addressOf(a).compareTo(addressOf(b));
      if (byAddress != 0 || tieBreak == null) return byAddress;
      return tieBreak(a).compareTo(tieBreak(b));
    });
}

/// Received date, newest first. Ties broken by [tieBreak] when given.
///
/// Returns a NEW list; [items] is never reordered in place.
List<T> orderNewestFirst<T>(
  List<T> items, {
  required DateTime Function(T) receivedAt,
  String Function(T)? tieBreak,
}) {
  return List<T>.of(items)
    ..sort((a, b) {
      final byDate = receivedAt(b).compareTo(receivedAt(a));
      if (byDate != 0 || tieBreak == null) return byDate;
      return tieBreak(a).compareTo(tieBreak(b));
    });
}
