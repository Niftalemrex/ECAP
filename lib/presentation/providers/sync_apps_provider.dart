// lib/presentation/providers/sync_apps_provider.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/presentation/providers/database_provider.dart';

final syncInstalledAppsProvider = FutureProvider.autoDispose
    .family<int, bool>((ref, includeSystemApps) async {
  final db = await ref.read(databaseFutureProvider.future);

  const channel = MethodChannel('com.example.ecap/apps');
  final List<dynamic> installed = await channel.invokeMethod(
    'getInstalledApps',
    {'includeSystemApps': includeSystemApps},
  );

  final existingRows = await db.query('apps', columns: ['package_name']);
  final existingPackages = existingRows
      .map((row) => row['package_name'] as String)
      .toSet();

  int added = 0;
  for (final app in installed) {
    final packageName = app['package_name'] as String;
    final appName = app['app_name'] as String;
    final isSystemApp = (app['is_system_app'] as bool) ? 1 : 0;

    if (!existingPackages.contains(packageName)) {
      await db.insert('apps', {
        'package_name': packageName,
        'app_name': appName,
        'is_system_app': isSystemApp,
      });
      added++;
    }
  }
  return added;
});