/// Represents a collection of spam filtering rules
class RuleSet {
  final String version;
  final Map<String, dynamic> settings;
  final List<Rule> rules;

  RuleSet({
    required this.version,
    required this.settings,
    required this.rules,
  });

  /// Load from YAML-compatible map
  factory RuleSet.fromMap(Map<String, dynamic> map) {
    final rulesData = map['rules'] as List? ?? [];
    return RuleSet(
      version: map['version'] as String? ?? '1.0',
      settings: map['settings'] as Map<String, dynamic>? ?? {},
      rules: rulesData.map((r) => Rule.fromMap(r as Map<String, dynamic>)).toList(),
    );
  }

  /// Convert to YAML-compatible map
  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'settings': settings,
      'rules': rules.map((r) => r.toMap()).toList(),
    };
  }
}

/// Individual spam filtering rule
class Rule {
  final String name;
  final bool enabled;
  final bool isLocal;
  final int executionOrder;
  final RuleConditions conditions;
  final RuleActions actions;
  final RuleExceptions? exceptions;
  final Map<String, dynamic>? metadata;

  Rule({
    required this.name,
    required this.enabled,
    required this.isLocal,
    required this.executionOrder,
    required this.conditions,
    required this.actions,
    this.exceptions,
    this.metadata,
  });

  factory Rule.fromMap(Map<String, dynamic> map) {
    return Rule(
      name: map['name'] as String,
      enabled: _parseBool(map['enabled']),
      isLocal: _parseBool(map['isLocal']),
      executionOrder: _parseInt(map['executionOrder']),
      conditions: RuleConditions.fromMap(map['conditions'] as Map<String, dynamic>),
      actions: RuleActions.fromMap(map['actions'] as Map<String, dynamic>),
      exceptions: map['exceptions'] != null
          ? RuleExceptions.fromMap(map['exceptions'] as Map<String, dynamic>)
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'enabled': enabled.toString(),
      'isLocal': isLocal.toString(),
      'executionOrder': executionOrder,
      'conditions': conditions.toMap(),
      'actions': actions.toMap(),
      if (exceptions != null) 'exceptions': exceptions!.toMap(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class RuleConditions {
  final String type; // 'OR' or 'AND'
  final List<String> from;
  final List<String> header;
  final List<String> subject;
  final List<String> body;

  RuleConditions({
    required this.type,
    this.from = const [],
    this.header = const [],
    this.subject = const [],
    this.body = const [],
  });

  factory RuleConditions.fromMap(Map<String, dynamic> map) {
    return RuleConditions(
      type: map['type'] as String? ?? 'OR',
      from: _toStringList(map['from']),
      header: _toStringList(map['header']),
      subject: _toStringList(map['subject']),
      body: _toStringList(map['body']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (from.isNotEmpty) 'from': from,
      if (header.isNotEmpty) 'header': header,
      if (subject.isNotEmpty) 'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

class RuleActions {
  final String? assignToCategory;
  final bool delete;
  final String? moveToFolder;

  RuleActions({
    this.assignToCategory,
    required this.delete,
    this.moveToFolder,
  });

  factory RuleActions.fromMap(Map<String, dynamic> map) {
    // Handle assign_to_category which can be a string or a map with category_name
    String? category;
    final categoryValue = map['assign_to_category'];
    if (categoryValue is String) {
      category = categoryValue;
    } else if (categoryValue is Map) {
      category = categoryValue['category_name'] as String?;
    }
    
    // Handle move_to_folder which can be a string or a map with folder_name
    String? folder;
    final folderValue = map['move_to_folder'] ?? map['copy_to_folder'];
    if (folderValue is String) {
      folder = folderValue;
    } else if (folderValue is Map) {
      folder = folderValue['folder_name'] as String?;
    }
    
    // Handle delete which can be bool or string 'True'/'False'
    bool shouldDelete = false;
    final deleteValue = map['delete'];
    if (deleteValue is bool) {
      shouldDelete = deleteValue;
    } else if (deleteValue is String) {
      shouldDelete = deleteValue.toLowerCase() == 'true';
    }
    
    return RuleActions(
      assignToCategory: category,
      delete: shouldDelete,
      moveToFolder: folder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (assignToCategory != null) 'assign_to_category': assignToCategory,
      'delete': delete,
      if (moveToFolder != null) 'move_to_folder': moveToFolder,
    };
  }
}

class RuleExceptions {
  final List<String> from;
  final List<String> header;
  final List<String> subject;
  final List<String> body;

  RuleExceptions({
    this.from = const [],
    this.header = const [],
    this.subject = const [],
    this.body = const [],
  });

  factory RuleExceptions.fromMap(Map<String, dynamic> map) {
    return RuleExceptions(
      from: RuleConditions._toStringList(map['from']),
      header: RuleConditions._toStringList(map['header']),
      subject: RuleConditions._toStringList(map['subject']),
      body: RuleConditions._toStringList(map['body']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (from.isNotEmpty) 'from': from,
      if (header.isNotEmpty) 'header': header,
      if (subject.isNotEmpty) 'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };
  }
}
