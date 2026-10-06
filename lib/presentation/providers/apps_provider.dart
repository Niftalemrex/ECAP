// lib/presentation/providers/apps_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasource/local_database.dart';
import 'package:ecap/presentation/providers/database_provider.dart';      // <-- your file

// ─────────────────────────────────────────────────────────────
// App model
// ─────────────────────────────────────────────────────────────
class App {
  final int id;
  final String packageName;
  final String appName;
  final String? icon;       // base64 encoded string (or null)
  final String? category;
  final bool isSystemApp;

  const App({
    required this.id,
    required this.packageName,
    required this.appName,
    this.icon,
    this.category,
    required this.isSystemApp,
  });

  factory App.fromMap(Map<String, dynamic> map) {
    return App(
      id: map['id'] as int,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      icon: map['icon'] as String?,
      category: map['category'] as String?,
      isSystemApp: (map['is_system_app'] as int) == 1,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Provider: all apps
// ─────────────────────────────────────────────────────────────
final appsProvider = FutureProvider<List<App>>((ref) async {
  // Use the database future provider you already defined
  final db = await ref.watch(databaseFutureProvider.future);
  final List<Map<String, dynamic>> maps = await db.query('apps');
  return maps.map((map) => App.fromMap(map)).toList();
});