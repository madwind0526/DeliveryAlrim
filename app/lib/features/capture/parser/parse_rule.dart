import 'dart:convert';

/// One extraction rule. The app starts from bundled JSON, then can load local
/// rule rows with the same shape.
class ParseRule {
  final String id;
  final Set<String> sourceTypes;
  final String? packageName;
  final RegExp? senderMatch;
  final RegExp? titleMatch;
  final RegExp bodyRegex;

  /// Optional extra regex for product name; `(?<product>...)` group.
  final RegExp? productRegex;

  /// Force a courier instead of keyword detection (used by coupang rules).
  final String? courierCode;

  /// Force a status instead of keyword detection.
  final String? statusHint;

  /// Lower value = tried first.
  final int priority;

  ParseRule({
    required this.id,
    required this.sourceTypes,
    this.packageName,
    this.senderMatch,
    this.titleMatch,
    required this.bodyRegex,
    this.productRegex,
    this.courierCode,
    this.statusHint,
    required this.priority,
  });

  factory ParseRule.fromJson(Map<String, dynamic> json) {
    RegExp? re(String? pattern, {bool multiLine = false}) =>
        pattern == null ? null : RegExp(pattern, multiLine: multiLine);
    return ParseRule(
      id: json['id'] as String,
      sourceTypes: (json['sourceTypes'] as List).cast<String>().toSet(),
      packageName: json['packageName'] as String?,
      senderMatch: re(json['senderMatch'] as String?),
      titleMatch: re(json['titleMatch'] as String?),
      bodyRegex: RegExp(json['bodyRegex'] as String, multiLine: true),
      productRegex: re(json['productRegex'] as String?, multiLine: true),
      courierCode: json['courierCode'] as String?,
      statusHint: json['statusHint'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 100,
    );
  }
}

class RuleSet {
  final int rulesVersion;
  final List<ParseRule> rules;

  RuleSet({required this.rulesVersion, required List<ParseRule> rules})
    : rules = [...rules]..sort((a, b) => a.priority.compareTo(b.priority));

  factory RuleSet.fromJsonString(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return RuleSet(
      rulesVersion: (map['rulesVersion'] as num).toInt(),
      rules: (map['rules'] as List)
          .map((r) => ParseRule.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
