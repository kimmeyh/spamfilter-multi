/// Represents the safe senders whitelist
class SafeSenderList {
  final List<String> safeSenders;

  SafeSenderList({required this.safeSenders});

  /// Load from YAML-compatible map
  factory SafeSenderList.fromMap(Map<String, dynamic> map) {
    final senders = map['safe_senders'] as List? ?? [];
    return SafeSenderList(
      safeSenders: senders.map((s) => s.toString().toLowerCase().trim()).toList(),
    );
  }

  /// Convert to YAML-compatible map
  Map<String, dynamic> toMap() {
    return {
      'safe_senders': safeSenders,
    };
  }

  /// Check if email matches any safe sender pattern
  bool isSafe(String email) {
    final normalized = email.toLowerCase().trim();
    return safeSenders.any((pattern) => _matchesPattern(normalized, pattern));
  }

  /// Add a new safe sender pattern
  void add(String pattern) {
    final normalized = pattern.toLowerCase().trim();
    if (!safeSenders.contains(normalized)) {
      safeSenders.add(normalized);
      safeSenders.sort();
    }
  }

  /// Remove a safe sender pattern
  void remove(String pattern) {
    safeSenders.remove(pattern.toLowerCase().trim());
  }

  bool _matchesPattern(String email, String pattern) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      return regex.hasMatch(email);
    } catch (e) {
      // If pattern is not valid regex, treat as literal match
      return email == pattern;
    }
  }
}
