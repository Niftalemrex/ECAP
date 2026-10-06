import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/presentation/providers/database_provider.dart';

final usageChannelProvider = Provider<MethodChannel>((ref) {
  const channel = MethodChannel('com.example.ecap/usage');
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'checkAppLimit':
        final packageName = call.arguments as String;
        print('🔍 checkAppLimit called for: $packageName');
        final blocked = await _checkAppLimit(ref, packageName);
        print('🔍 checkAppLimit result: blocked=$blocked');
        return blocked;

      case 'logAppUsage':
        final args = call.arguments as Map<dynamic, dynamic>;
        final packageName = args['package_name'] as String;
        final startTime = args['start_time'] as int;
        final durationSeconds = args['duration_seconds'] as int;
        print('📊 logAppUsage: $packageName, $durationSeconds seconds');
        await _logAppUsage(ref, packageName, startTime, durationSeconds);
        return true;

      default:
        throw MissingPluginException();
    }
  });
  return channel;
});

Future<bool> _checkAppLimit(Ref ref, String packageName) async {
  final db = await ref.read(databaseFutureProvider.future);

  // Find the app ID
  final appRows = await db.query(
    'apps',
    columns: ['id'],
    where: 'package_name = ?',
    whereArgs: [packageName],
  );
  if (appRows.isEmpty) {
    print('❌ App not tracked: $packageName');
    return false;
  }
  final appId = appRows.first['id'] as int;

  // Check if ANY block rule exists for this app (global)
  final ruleRows = await db.query(
    'app_rules',
    where: 'app_id = ? AND mode = ?',
    whereArgs: [appId, 'blocked'],
  );

  if (ruleRows.isNotEmpty) {
    print('🚫 App is blocked globally');
    return true;
  }

  // (Optional) add 'limited' mode logic here if needed
  print('✅ No blocking rule found');
  return false;
}

Future<void> _logAppUsage(Ref ref, String packageName, int startTime, int durationSeconds) async {
  // Same as before – finds the app and logs usage
  final db = await ref.read(databaseFutureProvider.future);
  final appRows = await db.query('apps', columns: ['id'],
      where: 'package_name = ?', whereArgs: [packageName]);
  if (appRows.isEmpty) return;
  final appId = appRows.first['id'] as int;

  // Use childId = 0 or null if no child required; you could also log without a child
  await db.insert('usage_logs', {
    'child_id': 0,   // or null – adjust schema if needed
    'app_id': appId,
    'start_time': startTime,
    'duration_seconds': durationSeconds,
  });
}