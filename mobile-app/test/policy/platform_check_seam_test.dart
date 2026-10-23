import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0049 (Sprint 80, F294): every Windows / Android difference is answered
/// by `PlatformCapabilities` or `PlatformPolicy`. No file under `lib/` outside
/// `lib/core/platform/` may read `Platform.isAndroid`, `Platform.isWindows`,
/// `Platform.isIOS`, `Platform.isMacOS`, `Platform.isLinux` or
/// `Platform.isFuchsia`, and inside `lib/core/platform/` only
/// `host_platform.dart` may.
///
/// **Why a gate.** Before ADR-0049 there were 62 scattered checks. Nothing
/// stopped the 63rd, and each new one decides a difference where it stands, out
/// of sight of the ADR-0042 exception list.
///
/// **How comments are handled.** Text after `//` (including `///` doc
/// comments) and text inside `/* ... */` is ignored, so a comment may name a
/// getter or even quote the old expression. A `//` inside a string literal is
/// NOT a comment (a URL, for example). The scanner is checked against crafted
/// input below, so it cannot pass by matching nothing.
///
/// **What this does NOT catch.** It reads text, not meaning: a check written
/// as `Platform.operatingSystem == 'android'`, `defaultTargetPlatform`,
/// `kIsWeb`, `Theme.of(context).platform` or `Platform.environment` is not
/// flagged, and neither is `Platform.is...` built by string concatenation. It
/// does not check that a getter is the RIGHT one for a site; the unit test
/// `test/unit/platform/platform_capabilities_test.dart` checks each getter's
/// answers and the behavior tests check each branch. It scans `lib/` only, so
/// `test/` and `tool/` may read `Platform.isX` freely. A multi-line raw string
/// that contains the text is read as code (none exists in `lib/`).
final RegExp _platformCheck =
    RegExp(r'\bPlatform\.is(Android|Windows|IOS|MacOS|Linux|Fuchsia)\b');

/// Returns [source] with comments blanked out, one output line per input line
/// so reported line numbers stay true.
String stripComments(String source) {
  final out = StringBuffer();
  var inBlock = false;
  for (final line in source.split('\n')) {
    final kept = StringBuffer();
    String? quote; // the open string delimiter, if any
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      final next = i + 1 < line.length ? line[i + 1] : '';
      if (inBlock) {
        if (c == '*' && next == '/') {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (quote != null) {
        kept.write(c);
        if (c == r'\' && next.isNotEmpty) {
          kept.write(next);
          i += 2;
          continue;
        }
        if (c == quote) quote = null;
        i++;
        continue;
      }
      if (c == '/' && next == '/') break; // line comment: drop the rest
      if (c == '/' && next == '*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') quote = c;
      kept.write(c);
      i++;
    }
    out.writeln(kept);
  }
  return out.toString();
}

/// `file:line: text` for each platform check in [source], comments ignored.
List<String> findPlatformChecks(String source, String label) {
  final hits = <String>[];
  final lines = stripComments(source).split('\n');
  final original = source.split('\n');
  for (var n = 0; n < lines.length; n++) {
    if (_platformCheck.hasMatch(lines[n])) {
      hits.add('$label:${n + 1}: ${original[n].trim()}');
    }
  }
  return hits;
}

String _norm(String path) => path.replaceAll('\\', '/');

List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('ADR-0049: no scattered platform checks in lib/', () {
    test('no Platform.isX outside lib/core/platform/', () {
      final hits = <String>[];
      for (final file in _libDartFiles()) {
        final path = _norm(file.path);
        if (path.startsWith('lib/core/platform/')) continue;
        hits.addAll(findPlatformChecks(file.readAsStringSync(), path));
      }
      expect(hits, isEmpty,
          reason: 'Use PlatformCapabilities.current (what the code CAN do) or '
              'PlatformPolicy.current (what the app SHOULD do) instead of a '
              'bare Platform.isX. Add a getter named for what you branch on, '
              'with its Windows, Android and iOS answers in the doc comment, '
              'and add it to the ADR-0049 site table. Offending lines:\n'
              '${hits.join('\n')}');
    });

    test('inside lib/core/platform/ only host_platform.dart reads Platform.isX',
        () {
      final readers = <String>[];
      for (final file in _libDartFiles()) {
        final path = _norm(file.path);
        if (!path.startsWith('lib/core/platform/')) continue;
        if (findPlatformChecks(file.readAsStringSync(), path).isNotEmpty) {
          readers.add(path);
        }
      }
      expect(readers, ['lib/core/platform/host_platform.dart'],
          reason: 'host_platform.dart is the ONE detection point; the two '
              'seam classes are built from the HostPlatform it returns.');
    });
  });

  group('the scanner itself (so the gate cannot pass by matching nothing)', () {
    test('flags a bare check and reports its line', () {
      const src = 'void f() {\n  if (Platform.isWindows) {}\n}\n';
      expect(findPlatformChecks(src, 'x.dart'),
          ['x.dart:2: if (Platform.isWindows) {}']);
    });

    test('flags every platform name, including an aliased import', () {
      for (final name in [
        'isAndroid',
        'isWindows',
        'isIOS',
        'isMacOS',
        'isLinux',
        'isFuchsia'
      ]) {
        expect(findPlatformChecks('final a = io.Platform.$name;', 'x'),
            hasLength(1),
            reason: name);
      }
    });

    test('ignores line, doc and block comments', () {
      const src = '// Platform.isAndroid in a comment\n'
          '/// Platform.isWindows in a doc comment\n'
          'final a = 1; // trailing Platform.isIOS\n'
          '/* Platform.isLinux\n'
          '   Platform.isMacOS */ final b = 2;\n';
      expect(findPlatformChecks(src, 'x'), isEmpty);
    });

    test('a // inside a string is not a comment', () {
      const src = "final u = 'https://x.test'; final a = Platform.isAndroid;";
      expect(findPlatformChecks(src, 'x'), hasLength(1));
    });

    test('allows Platform members that are not platform decisions', () {
      const src = 'final a = Platform.operatingSystem;\n'
          'final b = Platform.pathSeparator;\n'
          'final c = Platform.resolvedExecutable;\n';
      expect(findPlatformChecks(src, 'x'), isEmpty);
    });
  });
}
