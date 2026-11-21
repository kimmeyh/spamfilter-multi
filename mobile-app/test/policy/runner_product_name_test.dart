// F354 (Sprint 85): the Windows executable's ProductName decides the
// app-support folder (path_provider_windows 2.3.0 builds it from
// CompanyName\ProductName), and with it where flutter_secure_storage keeps the
// credential file. A production build (including the Store MSIX) MUST keep
// "MyEmailSpamFilter", or every existing user loses their saved accounts and
// data on update. A DEV build MUST use "MyEmailSpamFilter_Dev", or DEV writes
// production credentials again.
//
// What this does NOT catch: whether the resource compiler really receives
// SPAMFILTER_IS_DEV from CMake (proven by reading the built exe's
// VersionInfo.ProductName after a DEV build and after the release self-test
// build); a CompanyName change made together with a matching edit here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/dev_credential_separation.dart';

void main() {
  final rc = File('windows/runner/Runner.rc').readAsStringSync();
  final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();

  test('ProductName comes from SPAMFILTER_PRODUCT_NAME', () {
    expect(rc, contains('VALUE "ProductName", SPAMFILTER_PRODUCT_NAME "\\0"'));
  });

  test('production keeps "MyEmailSpamFilter"; DEV gets the _Dev name', () {
    final m = RegExp(
      r'#if defined\(SPAMFILTER_IS_DEV\)\s*'
      r'#define SPAMFILTER_PRODUCT_NAME "MyEmailSpamFilter_Dev"\s*'
      r'#else\s*'
      r'#define SPAMFILTER_PRODUCT_NAME "MyEmailSpamFilter"\s*'
      r'#endif',
    ).hasMatch(rc);
    expect(m, isTrue);
  });

  test('CompanyName is unchanged (the DEV folder is a sibling of the '
      'production folder, which DevCredentialSeparation relies on)', () {
    expect(rc, contains('VALUE "CompanyName", "MyEmailSpamFilter" "\\0"'));
    expect(DevCredentialSeparation.productionFolderName, 'MyEmailSpamFilter');
  });

  test('CMake sets SPAMFILTER_IS_DEV only when SPAMFILTER_APP_ENV is not prod',
      () {
    final m = RegExp(
      r'if\(NOT SPAMFILTER_APP_ENV STREQUAL "prod"\)\s*'
      r'target_compile_definitions\(\$\{BINARY_NAME\} PRIVATE '
      r'"SPAMFILTER_IS_DEV=1"\)\s*endif\(\)',
    ).hasMatch(cmake);
    expect(m, isTrue);
  });
}
