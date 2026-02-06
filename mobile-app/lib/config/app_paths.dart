import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static const String rulesFileName = 'rules.yaml';
  static const String safeSendersFileName = 'rules_safe_senders.yaml';
  static const String archiveDirectoryName = 'Archive';

  static Future<Directory> _supportDirectory() async {
    return getApplicationSupportDirectory();
  }

  static Future<String> rulesPath() async {
    return '${(await _supportDirectory()).path}/$rulesFileName';
  }

  static Future<String> safeSendersPath() async {
    return '${(await _supportDirectory()).path}/$safeSendersFileName';
  }

  static Future<String> archivePath() async {
    return '${(await _supportDirectory()).path}/$archiveDirectoryName';
  }

  static Future<File> rulesFile() async {
    return File(await rulesPath());
  }

  static Future<File> safeSendersFile() async {
    return File(await safeSendersPath());
  }
}
