// lib/core/database.dart
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as desktop;
import 'package:path/path.dart' as p;

/// Call once before any database operation (typically in main()).
void initializeDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    desktop.sqfliteFfiInit();
    desktop.databaseFactory = desktop.databaseFactoryFfi;
  }
  // Android/iOS use the built‑in factory – no action needed.
}

/// Re‑export the functions your app needs, hiding the back‑end.
Future<String> getDatabasesPath() {
  // Using the mobile package here works because the factory has been set
  // for desktop. Both packages expose the same top‑level functions.
  return mobile.getDatabasesPath();
}

// Re‑export Database and friends from the mobile package
typedef Database = mobile.Database;
typedef DatabaseExecutor = mobile.DatabaseExecutor;
typedef Transaction = mobile.Transaction;
typedef Batch = mobile.Batch;
typedef ConflictAlgorithm = mobile.ConflictAlgorithm;

// Wrapper around openDatabase that delegates to the correct factory
Future<Database> openDatabase(
    String path, {
      int? version,
      Future<void> Function(Database db, int version)? onCreate,
      Future<void> Function(Database db, int oldVersion, int newVersion)? onUpgrade,
      Future<void> Function(Database db)? onConfigure,
    }) {
  return mobile.openDatabase(
    path,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
    onConfigure: onConfigure,
  );
}