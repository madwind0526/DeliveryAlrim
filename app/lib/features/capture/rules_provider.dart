import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parser/parse_rule.dart';
import 'parser/rule_engine.dart';

/// Loads the bundled rule set. Wave 4 replaces this with OTA sync
/// (Supabase parse_rules → local cache → bundled fallback).
final ruleSetProvider = FutureProvider<RuleSet>((ref) async {
  final jsonString =
      await rootBundle.loadString('assets/parse_rules_fallback.json');
  return RuleSet.fromJsonString(jsonString);
});

final ruleEngineProvider = FutureProvider<RuleEngine>((ref) async {
  final ruleSet = await ref.watch(ruleSetProvider.future);
  return RuleEngine(ruleSet);
});
