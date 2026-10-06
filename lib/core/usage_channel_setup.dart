import 'package:flutter/services.dart';
import 'package:ecap/data/datasource/local_database.dart';

/// Call this once in main() before runApp().
void initializeUsageChannel() {
  const channel = MethodChannel('com.example.ecap/usage');

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'checkAppLimit':
        final packageName = call.arguments as String;
        print('🔍 checkAppLimit called for: $packageName');
        final blocked = await _checkAppLimitGlobal(packageName);
        print('🔍 checkAppLimit result: blocked=$blocked');
        return blocked;

      case 'logAppUsage':
        final args = call.arguments as Map<dynamic, dynamic>;
        final packageName = args['package_name'] as String;
        final startTime = args['start_time'] as int;
        final durationSeconds = args['duration_seconds'] as int;
        print('📊 logAppUsage: $packageName, $durationSeconds seconds');
        await _logAppUsageGlobal(packageName, startTime, durationSeconds);
        return true;

      case 'checkParentPin':
        final pin = call.arguments as String;
        print('🔑 checkParentPin called');
        final valid = await _verifyParentPin(pin);
        print('🔑 checkParentPin result: $valid');
        return valid;

      default:
        throw MissingPluginException();
    }
  });
}

// ─────────────────────────────────────────────────────────────
// App‑limit logic (unchanged)
// ─────────────────────────────────────────────────────────────
Future<bool> _checkAppLimitGlobal(String packageName) async {
  final db = await LocalDatabase.instance.database;

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

  final ruleRows = await db.query(
    'app_rules',
    where: 'app_id = ? AND mode = ?',
    whereArgs: [appId, 'blocked'],
  );

  if (ruleRows.isNotEmpty) {
    print('🚫 App is blocked globally');
    return true;
  }

  print('✅ No blocking rule found');
  return false;
}

Future<void> _logAppUsageGlobal(
    String packageName, int startTime, int durationSeconds) async {
  final db = await LocalDatabase.instance.database;

  final appRows = await db.query(
    'apps',
    columns: ['id'],
    where: 'package_name = ?',
    whereArgs: [packageName],
  );
  if (appRows.isEmpty) return;
  final appId = appRows.first['id'] as int;

  await db.insert('usage_logs', {
    'child_id': 0, // global
    'app_id': appId,
    'start_time': startTime,
    'duration_seconds': durationSeconds,
  });
}

// ─────────────────────────────────────────────────────────────
// PIN verification – compares directly (your sign‑up stores raw PIN)
// ─────────────────────────────────────────────────────────────
Future<bool> _verifyParentPin(String pin) async {
  final db = await LocalDatabase.instance.database;

  final users = await db.query(
    'users',
    where: 'role IN (?, ?)',
    whereArgs: ['super_admin', 'parent'],
    limit: 1,
  );

  if (users.isEmpty) {
    print('❌ No parent user found');
    return false;
  }

  final storedPin = users.first['pin_hash'] as String;
  print('Stored pin: $storedPin, Entered pin: $pin');

  // Direct comparison – no hashing needed
  return storedPin == pin;
}