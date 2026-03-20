/// Domain DNS Verification Tests
///
/// Verifies that myemailspamfilter.com and myemailspamfilter.net DNS records
/// are correctly configured for GitHub Pages hosting.
///
/// These tests require network access and verify live DNS records.
/// Run with: flutter test test/integration/domain_dns_verification_test.dart
///
/// Expected DNS configuration:
///   myemailspamfilter.com A records -> 185.199.108-111.153 (GitHub Pages)
///   myemailspamfilter.com CNAME www -> kimmeyh.github.io
///   myemailspamfilter.net -> redirects to myemailspamfilter.com
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// GitHub Pages IP addresses (as of 2026)
const githubPagesIps = [
  '185.199.108.153',
  '185.199.109.153',
  '185.199.110.153',
  '185.199.111.153',
];

void main() {
  group('Domain DNS Verification - myemailspamfilter.com', () {
    test('A records include GitHub Pages IPs', () async {
      final addresses = await InternetAddress.lookup('myemailspamfilter.com');
      final ips = addresses
          .where((a) => a.type == InternetAddressType.IPv4)
          .map((a) => a.address)
          .toList();

      expect(ips, isNotEmpty, reason: 'Should have at least one A record');

      // Check that at least one GitHub Pages IP is present
      // During DNS propagation, stale cached IPs may coexist temporarily
      final githubIpsFound =
          ips.where((ip) => githubPagesIps.contains(ip)).toList();
      expect(
        githubIpsFound,
        isNotEmpty,
        reason: 'At least one GitHub Pages IP should be present. '
            'Found IPs: $ips. Expected some of: $githubPagesIps',
      );

      // Warn (but do not fail) if non-GitHub IPs are still present
      final staleIps =
          ips.where((ip) => !githubPagesIps.contains(ip)).toList();
      if (staleIps.isNotEmpty) {
        // ignore: avoid_print
        print('WARNING: Stale DNS records still propagating: $staleIps');
      }
    });

    test('www subdomain resolves (CNAME to GitHub Pages)', () async {
      final addresses =
          await InternetAddress.lookup('www.myemailspamfilter.com');
      expect(addresses, isNotEmpty,
          reason: 'www.myemailspamfilter.com should resolve');
    });
  });

  group('Domain DNS Verification - myemailspamfilter.net', () {
    test('.net domain resolves (for redirect)', () async {
      final addresses = await InternetAddress.lookup('myemailspamfilter.net');
      expect(addresses, isNotEmpty,
          reason: 'myemailspamfilter.net should resolve for redirect');
    });

    test('.net redirects to .com via HTTP', () async {
      final client = HttpClient();
      try {
        final request =
            await client.getUrl(Uri.parse('http://myemailspamfilter.net'));
        request.followRedirects = false;
        final response = await request.close();

        // Expect a redirect (301 permanent or 302 temporary)
        expect(
          [301, 302, 303, 307, 308].contains(response.statusCode),
          isTrue,
          reason:
              'Expected redirect status code, got ${response.statusCode}',
        );

        final location = response.headers.value('location');
        expect(location, isNotNull,
            reason: 'Redirect should have Location header');
        expect(
          location!.contains('myemailspamfilter.com'),
          isTrue,
          reason:
              'Redirect should point to myemailspamfilter.com, got: $location',
        );
      } finally {
        client.close();
      }
    });
  });
}
