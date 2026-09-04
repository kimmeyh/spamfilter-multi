import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GP-5 publication gate (Sprint 64, Issue #368).
///
/// The legal documents under docs/legal/ are PUBLISHED LIVE at
/// https://myemailspamfilter.com/legal/ directly from main:/docs via GitHub
/// Pages. After the 2026-08-28 publication (effective date + contact email
/// set, Harold-approved), no editorial placeholder may ever reappear -- a
/// placeholder that reaches main is immediately visible to the public.
void main() {
  test('published legal documents contain no editorial placeholders', () {
    final legalDir = Directory('../docs/legal');
    expect(legalDir.existsSync(), isTrue,
        reason: 'docs/legal must exist (published site content)');

    final offenders = <String>[];
    for (final entity in legalDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final content = entity.readAsStringSync();
      for (final marker in ['[SET AT PUBLICATION', '[CONTACT EMAIL']) {
        if (content.contains(marker)) {
          offenders.add('${entity.path}: $marker');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'placeholders in published legal docs: ${offenders.join('; ')}');
  });

  test('legal documents carry an effective date and canonical URL', () {
    for (final name in ['PRIVACY_POLICY.md', 'TERMS.md']) {
      final content = File('../docs/legal/$name').readAsStringSync();
      expect(content, contains('**Effective date**:'),
          reason: '$name must state its effective date');
      expect(content, contains('https://myemailspamfilter.com/legal/'),
          reason: '$name must state its canonical published URL');
    }
  });
}
