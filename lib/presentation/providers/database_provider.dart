import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/core/database.dart';
import 'package:ecap/data/datasource/local_database.dart';

final databaseFutureProvider = FutureProvider<Database>((ref) async {
  final localDb = LocalDatabase.instance;
  return localDb.database;
});