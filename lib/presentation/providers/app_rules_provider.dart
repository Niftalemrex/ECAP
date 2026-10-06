// lib/presentation/providers/app_rules_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasource/local_database.dart';
import 'package:ecap/presentation/providers/database_provider.dart';   // <-- your import path

// ─────────────────────────────────────────────────────────────
// AppRule model
// ─────────────────────────────────────────────────────────────
class AppRule {
  final int id;
  final int childId;
  final int appId;
  final String mode;        // 'allowed', 'blocked', 'limited'
  final int dailyLimitMinutes;
  final int? startTime;     // minutes from midnight, null = no restriction
  final int? endTime;
  final int version;

  const AppRule({
    required this.id,
    required this.childId,
    required this.appId,
    required this.mode,
    required this.dailyLimitMinutes,
    this.startTime,
    this.endTime,
    required this.version,
  });

  factory AppRule.fromMap(Map<String, dynamic> map) {
    return AppRule(
      id: map['id'] as int,
      childId: map['child_id'] as int,
      appId: map['app_id'] as int,
      mode: map['mode'] as String,
      dailyLimitMinutes: map['daily_limit_minutes'] as int,
      startTime: map['start_time'] as int?,
      endTime: map['end_time'] as int?,
      version: map['version'] as int,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Provider: all rules
// ─────────────────────────────────────────────────────────────
final allAppRulesProvider = FutureProvider<List<AppRule>>((ref) async {
  final db = await ref.watch(databaseFutureProvider.future);   // ✅ fixed name
  final List<Map<String, dynamic>> maps = await db.query('app_rules');
  return maps.map((map) => AppRule.fromMap(map)).toList();
});

// ─────────────────────────────────────────────────────────────
// Provider: rules for a specific child
// ─────────────────────────────────────────────────────────────
final childAppRulesProvider = FutureProvider.family<List<AppRule>, int>(
      (ref, childId) async {
    final db = await ref.watch(databaseFutureProvider.future);   // ✅ fixed name
    final List<Map<String, dynamic>> maps = await db.query(
      'app_rules',
      where: 'child_id = ?',
      whereArgs: [childId],
    );
    return maps.map((map) => AppRule.fromMap(map)).toList();
  },
);

// ─────────────────────────────────────────────────────────────
// Mutation: add or update a rule (used by AddAppScreen)
// ─────────────────────────────────────────────────────────────
final addOrUpdateAppRuleProvider = FutureProvider.autoDispose
    .family<void, AddOrUpdateRuleParams>((ref, params) async {
  final db = await ref.watch(databaseFutureProvider.future);   // ✅ fixed name

  // Check if a rule already exists for this child & app
  final existing = await db.query(
    'app_rules',
    where: 'child_id = ? AND app_id = ?',
    whereArgs: [params.childId, params.appId],
  );

  if (existing.isNotEmpty) {
    // Update
    await db.update(
      'app_rules',
      {
        'mode': params.mode,
        'daily_limit_minutes': params.dailyLimitMinutes,
        'start_time': params.startTime,
        'end_time': params.endTime,
        'version': 1,   // simplified; you might want to increment it
      },
      where: 'child_id = ? AND app_id = ?',
      whereArgs: [params.childId, params.appId],
    );
  } else {
    // Insert
    await db.insert('app_rules', {
      'child_id': params.childId,
      'app_id': params.appId,
      'mode': params.mode,
      'daily_limit_minutes': params.dailyLimitMinutes,
      'start_time': params.startTime,
      'end_time': params.endTime,
    });
  }

  // Invalidate the relevant providers so the UI refreshes
  ref.invalidate(allAppRulesProvider);
  ref.invalidate(childAppRulesProvider(params.childId));
});

class AddOrUpdateRuleParams {
  final int childId;
  final int appId;
  final String mode;
  final int dailyLimitMinutes;
  final int? startTime;
  final int? endTime;

  const AddOrUpdateRuleParams({
    required this.childId,
    required this.appId,
    required this.mode,
    required this.dailyLimitMinutes,
    this.startTime,
    this.endTime,
  });
}