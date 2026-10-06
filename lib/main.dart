// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/core/database.dart';                  // adapter
import 'package:ecap/data/datasource/local_database.dart';
import 'package:ecap/core/usage_channel_setup.dart';        // <-- NEW
import 'package:ecap/presentation/app.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;          // for deleteDatabase

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop: initialize FFI factory
  initializeDatabaseFactory();

  // Delete the old database file to force a clean schema
  final dbPath = p.join(await getDatabasesPath(), 'ecap.db');


  // Pre‑open database (creates tables fresh)
  final localDb = LocalDatabase.instance;
  await localDb.database;

  // ✅ Set up the usage channel handler so the accessibility service
  //    can call checkAppLimit immediately when it starts.
  initializeUsageChannel();

  // No device admin activation here – will be triggered from DeviceProtectionScreen
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const App();
}