/// Sprint 38 F85 (ADR-0038): content-asset loader for Markdown files
/// under `assets/content/`, resolved via `assets/content/manifest.yaml`.
///
/// Loads each `.md` body once per process (in-memory cache) so repeated
/// access (e.g., scrolling Help and re-entering) does not re-read the
/// asset bundle.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class ContentLoader {
  static const String _manifestAsset = 'assets/content/manifest.yaml';
  static const String _assetsPrefix = 'assets/content/';

  /// In-memory cache. Keyed by the manifest content key joined as
  /// `<namespace>.<key>` (e.g., `help.scanHistory`). Value is the
  /// fully-loaded Markdown body.
  final Map<String, String> _cache = {};

  /// In-memory copy of the parsed manifest. Lazily loaded on first call.
  Map<String, Map<String, String>>? _manifest;

  static final ContentLoader _instance = ContentLoader._internal();
  factory ContentLoader() => _instance;
  ContentLoader._internal();

  /// Loads the body for `<namespace>.<key>` (e.g., `'help', 'scanHistory'`).
  /// Returns the file contents from the asset bundle, with leading/trailing
  /// whitespace trimmed. Throws ArgumentError if the key is not present in
  /// the manifest; this surfaces drift between the calling enum and the
  /// manifest at runtime if the build-time validator missed it.
  Future<String> load(String namespace, String key) async {
    final cacheKey = '$namespace.$key';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final manifest = await _loadManifest();
    final namespaceMap = manifest[namespace];
    if (namespaceMap == null) {
      throw ArgumentError(
        'Content manifest has no namespace "$namespace". '
        'Available: ${manifest.keys.toList()}',
      );
    }
    final relativePath = namespaceMap[key];
    if (relativePath == null) {
      throw ArgumentError(
        'Content manifest namespace "$namespace" has no key "$key". '
        'Available: ${namespaceMap.keys.toList()}',
      );
    }

    final assetPath = '$_assetsPrefix$relativePath';
    final body = (await rootBundle.loadString(assetPath)).trim();
    _cache[cacheKey] = body;
    return body;
  }

  /// Clear the in-memory cache. Used by tests; production code should not
  /// need to call this -- the cache is process-lifetime correct because
  /// asset content does not change at runtime.
  void clearCacheForTesting() {
    _cache.clear();
    _manifest = null;
  }

  Future<Map<String, Map<String, String>>> _loadManifest() async {
    if (_manifest != null) return _manifest!;
    final raw = await rootBundle.loadString(_manifestAsset);
    final parsed = loadYaml(raw);
    if (parsed is! YamlMap) {
      throw StateError('content manifest must be a YAML map at the top level');
    }
    final result = <String, Map<String, String>>{};
    for (final entry in parsed.entries) {
      final namespace = entry.key.toString();
      final namespaceValue = entry.value;
      if (namespaceValue is! YamlMap) continue;
      final inner = <String, String>{};
      for (final sub in namespaceValue.entries) {
        inner[sub.key.toString()] = sub.value.toString();
      }
      result[namespace] = inner;
    }
    _manifest = result;
    return result;
  }
}
