import 'dart:io';
import '../../config/app_paths.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import '../services/yaml_service.dart';

class LocalRuleStore {
  final YamlService yamlService;

  LocalRuleStore({required this.yamlService});

  Future<void> ensureInitialized() async {
    await _ensureFileExists(
      await AppPaths.rulesPath(),
      defaultContent: 'version: "1.0"\nsettings: {}\nrules: []\n',
    );
    await _ensureFileExists(
      await AppPaths.safeSendersPath(),
      defaultContent: 'safe_senders: []\n',
    );
  }

  Future<RuleSet> loadRules() async {
    final path = await AppPaths.rulesPath();
    return yamlService.loadRules(path);
  }

  Future<SafeSenderList> loadSafeSenders() async {
    final path = await AppPaths.safeSendersPath();
    return yamlService.loadSafeSenders(path);
  }

  Future<void> saveRules(RuleSet rules) async {
    final path = await AppPaths.rulesPath();
    await yamlService.exportRules(rules, path);
  }

  Future<void> saveSafeSenders(SafeSenderList safeSenders) async {
    final path = await AppPaths.safeSendersPath();
    await yamlService.exportSafeSenders(safeSenders, path);
  }

  Future<void> _ensureFileExists(String path, {required String defaultContent}) async {
    final file = File(path);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    if (!await file.exists()) {
      await file.writeAsString(defaultContent);
      return;
    }

    if (await file.length() == 0) {
      await file.writeAsString(defaultContent);
    }
  }
}
