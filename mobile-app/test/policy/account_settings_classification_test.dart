/// F324 (Sprint 83, Q3 = 3): every per-account setting key is classified.
///
/// Removing an account keeps `accountSettingKeysKept` and deletes the rest
/// (`DataDeletionService.deleteAccountData`). That is an ALLOWLIST, so a key
/// added to `SettingsStore` later would be silently deleted on removal (or, if
/// someone widened the list without thinking, silently kept). This gate fails
/// the build until a new key is placed in `accountSettingKeysKept` (a user
/// choice) or `accountSettingKeysRefreshed` (tied to the old sign-in, or an
/// internal allocation) on purpose.
///
/// What this does NOT catch: a key written through a path that does not use
/// the `_setAccountSetting(accountId, '<literal>', ...)` shape (for example a
/// key built at run time), and a key put in the wrong set. The behavior of
/// both sets is pinned by `test/unit/services/data_deletion_service_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/services/data_deletion_service.dart';

void main() {
  final source =
      File('lib/core/storage/settings_store.dart').readAsStringSync();

  Set<String> usedKeys() {
    final keys = <String>{};
    final call = RegExp(
        r"_(?:get|set|delete)AccountSetting\(\s*\w+,\s*'([a-z_]+)'");
    for (final m in call.allMatches(source)) {
      keys.add(m.group(1)!);
    }
    // The schedule slot is written through its own constant and transaction.
    final slot = RegExp(r"_scheduleSlotKey\s*=\s*'([a-z_]+)'")
        .firstMatch(source);
    if (slot != null) keys.add(slot.group(1)!);
    return keys;
  }

  test('the scan finds the account setting keys (guards the regex itself)', () {
    final keys = usedKeys();
    expect(keys.length, greaterThanOrEqualTo(16));
    expect(keys, containsAll(['background_enabled', 'schedule_slot']));
  });

  test('every key SettingsStore uses is classified kept or refreshed', () {
    final classified = {...accountSettingKeysKept, ...accountSettingKeysRefreshed};
    final unclassified = usedKeys().difference(classified);
    expect(unclassified, isEmpty,
        reason: 'add each key to accountSettingKeysKept (a user choice) or '
            'accountSettingKeysRefreshed (old sign-in state or an internal '
            'allocation) in data_deletion_service.dart');
  });

  test('no key is in both sets, and no entry is dead', () {
    expect(accountSettingKeysKept.intersection(accountSettingKeysRefreshed),
        isEmpty);
    final dead = {...accountSettingKeysKept, ...accountSettingKeysRefreshed}
        .difference(usedKeys());
    expect(dead, isEmpty, reason: 'a listed key SettingsStore no longer uses');
  });
}
