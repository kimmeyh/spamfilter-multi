/// Host policy for Custom IMAP servers (SEC-15, merged into F192 in Sprint 77).
///
/// This file is the ONE place the policy lives. The setup form calls
/// [ImapHostPolicy.classify] from both Test Connection and Save; nothing else
/// implements a second copy.
///
/// Policy (Harold, Sprint 77 Q2):
/// - An address on the user's own computer or network (10/8, 172.16/12,
///   192.168/16, 127/8, 169.254/16, ::1, fc00::/7, fe80::/10, "localhost") is
///   allowed after ONE warning ([localNetworkWarning]).
/// - Everything else well formed is allowed without a warning.
/// - An empty or malformed value is rejected by the form with a field message.
///
/// The function is pure: it performs NO DNS lookup. A name that resolves to a
/// private address only on some network is classified as public here by
/// design; resolving would block legitimate names that resolve privately only
/// on a VPN, and would put a network call in a validator.
///
/// Why this is not an SSRF control: the host is typed by the person who owns
/// the device and reaches only that device's own network, so this is a
/// plain-language heads-up, not a security boundary.
library;

import 'dart:io';

/// What kind of server address the user typed.
enum ImapHostClass {
  /// Blank after trimming.
  empty,

  /// Not a usable host name or address (spaces, a port, a path, an invalid
  /// literal, or an all-numeric form such as `127.1` that some resolvers
  /// expand to a loopback address).
  malformed,

  /// A well formed name or address that is not local or private.
  publicHost,

  /// Loopback, private-range, link-local or unspecified address, or
  /// `localhost`. Allowed after one warning.
  localOrPrivate,
}

/// Single home of the Custom IMAP host policy.
class ImapHostPolicy {
  ImapHostPolicy._();

  /// Shown once when [classify] returns [ImapHostClass.localOrPrivate].
  /// Personal-email app: the text must not mention or suggest business use.
  static const String localNetworkWarning =
      'This server is on your own computer or local network. '
      'Continue only if you run this mail server yourself.';

  /// Field message for [ImapHostClass.empty].
  static const String emptyMessage = 'Enter the server name.';

  /// Field message for [ImapHostClass.malformed].
  static const String malformedMessage =
      'Enter only the server name, for example imap.example.com. '
      'Do not include spaces, a port or a path.';

  static final RegExp _hostnameLabel = RegExp(r'^[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?$');

  /// Classify [host] without any network access.
  static ImapHostClass classify(String host) {
    var value = host.trim().toLowerCase();
    if (value.isEmpty) return ImapHostClass.empty;

    // Bracketed IPv6 literal, as people copy it from a URL: [::1]
    final bracketed = value.startsWith('[') && value.endsWith(']');
    if (bracketed) {
      value = value.substring(1, value.length - 1);
    }

    final literal = InternetAddress.tryParse(value);
    // Brackets are only meaningful around an IPv6 literal.
    if (bracketed && (literal == null || literal.type != InternetAddressType.IPv6)) {
      return ImapHostClass.malformed;
    }
    if (literal != null) {
      return _classifyBytes(literal.rawAddress)
          ? ImapHostClass.localOrPrivate
          : ImapHostClass.publicHost;
    }

    // A colon that is not part of a valid IPv6 literal is a port or garbage.
    if (value.contains(':')) return ImapHostClass.malformed;

    // A trailing dot is a fully qualified name: "localhost." is localhost.
    if (value.endsWith('.')) value = value.substring(0, value.length - 1);
    if (value.isEmpty || value.length > 253) return ImapHostClass.malformed;

    final labels = value.split('.');
    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return ImapHostClass.malformed;
      if (!_hostnameLabel.hasMatch(label)) return ImapHostClass.malformed;
    }

    // No real top-level domain is all digits. A name whose last label is
    // numeric is an IPv4 shorthand ("127.1", "2130706433", "0x7f.1") that the
    // OS resolver may expand to an address; the classifier cannot tell which,
    // so it refuses the form rather than guessing.
    if (RegExp(r'^[0-9]+$').hasMatch(labels.last)) return ImapHostClass.malformed;

    if (value == 'localhost' || value.endsWith('.localhost')) {
      return ImapHostClass.localOrPrivate;
    }
    return ImapHostClass.publicHost;
  }

  /// True when the raw address bytes are loopback, private, link-local or
  /// unspecified.
  static bool _classifyBytes(List<int> b) {
    if (b.length == 4) return _isLocalV4(b);
    if (b.length != 16) return false;

    // ::  (unspecified) and ::1 (loopback)
    final leadingZero = b.sublist(0, 15).every((x) => x == 0);
    if (leadingZero && (b[15] == 0 || b[15] == 1)) return true;

    // IPv4-mapped (::ffff:a.b.c.d): judge the embedded IPv4 address.
    final mapped = b.sublist(0, 10).every((x) => x == 0) &&
        b[10] == 0xff &&
        b[11] == 0xff;
    if (mapped) return _isLocalV4(b.sublist(12, 16));

    // fc00::/7 unique local
    if ((b[0] & 0xFE) == 0xFC) return true;
    // fe80::/10 link local
    if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) return true;
    return false;
  }

  static bool _isLocalV4(List<int> b) {
    if (b[0] == 0) return true; // 0.0.0.0/8, "this host"
    if (b[0] == 10) return true; // 10/8
    if (b[0] == 127) return true; // 127/8
    if (b[0] == 169 && b[1] == 254) return true; // 169.254/16
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16/12
    if (b[0] == 192 && b[1] == 168) return true; // 192.168/16
    return false;
  }
}
