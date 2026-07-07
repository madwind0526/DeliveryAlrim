import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/courier_registry.dart';
import 'parser/parse_rule.dart';
import 'parser/rule_engine.dart';

/// Loads the bundled rule set. Later this can read local rule rows before
/// falling back to bundled assets.
final ruleSetProvider = FutureProvider<RuleSet>((ref) async {
  final jsonString = await rootBundle.loadString(
    'assets/parse_rules_fallback.json',
  );
  return RuleSet.fromJsonString(jsonString);
});

final ruleEngineProvider = FutureProvider<RuleEngine>((ref) async {
  final ruleSet = await ref.watch(ruleSetProvider.future);
  final couriers = await ref.watch(courierListProvider.future);
  return RuleEngine(ruleSet, couriers: couriers);
});
