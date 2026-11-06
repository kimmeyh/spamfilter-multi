// Sprint 83 7.7.1 (code-reviewer L-2, silent-failure-hunter L-6): the IMAP
// platform ids are ONE list, owned by PlatformRegistry, and it matches the
// factories. A provider added to the factories but not to the list would lose
// the background sign-in skip and the lockout clear on removal.
//
// What this does NOT catch: an IMAP provider whose factory returns a type
// other than GenericIMAPAdapter (none today).
import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/email_providers/generic_imap_adapter.dart';
import 'package:my_email_spam_filter/adapters/email_providers/platform_registry.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imapPlatformIds equals the ids whose factory builds a GenericIMAPAdapter',
      () {
    final fromFactories = <String>{
      for (final id in PlatformRegistry.getSupportedPlatformIds())
        if (PlatformRegistry.getPlatform(id) is GenericIMAPAdapter) id,
    };
    expect(fromFactories, isNotEmpty);
    expect(PlatformRegistry.imapPlatformIds, fromFactories);
  });

  test('the background skip reads the registry list, not a copy', () {
    expect(identical(BackgroundScanCore.imapPlatformIds,
        PlatformRegistry.imapPlatformIds), isTrue);
  });
}
