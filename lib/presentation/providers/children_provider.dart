// lib/presentation/providers/children_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/core/database.dart';
import 'package:ecap/domain/entities/child.dart';
import 'package:ecap/domain/entities/family.dart';      // FamilyModel class
import 'package:ecap/presentation/providers/database_provider.dart';
import 'package:ecap/presentation/providers/auth_provider.dart';

// ─────────────── Existing providers (used by parent) ─────────

final childrenListProvider = FutureProvider<List<Child>>((ref) async {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return [];

  final dbAsync = ref.watch(databaseFutureProvider);
  final db = await dbAsync.value!;

  final rows = await db.query(
    'children',
    where: 'family_id = ?',
    whereArgs: [familyId],
  );
  return rows.map((e) => Child.fromMap(e)).toList();
});

final selectedChildIdProvider = StateProvider<int?>((ref) => null);

// ✅ NEW: Fetches child directly from the database, no longer depends on parent login.
final currentChildProvider = FutureProvider.family<Child?, int?>((ref, childId) async {
  if (childId == null) return null;
  final dbAsync = ref.watch(databaseFutureProvider);
  final db = await dbAsync.value!;
  final rows = await db.query(
    'children',
    where: 'id = ?',
    whereArgs: [childId],
  );
  if (rows.isEmpty) return null;
  return Child.fromMap(rows.first);
});

// ─────────────── New providers for child login ───────────────

// All families (no login required)
final allFamiliesProvider = FutureProvider<List<FamilyModel>>((ref) async {
  final dbAsync = ref.watch(databaseFutureProvider);
  final db = await dbAsync.value!;
  final rows = await db.query('family');
  return rows.map((e) => FamilyModel.fromMap(e)).toList();
});

// Children of a specific family (used in child login)
final childrenForFamilyProvider =
FutureProvider.family<List<Child>, int>((ref, familyId) async {
  final dbAsync = ref.watch(databaseFutureProvider);
  final db = await dbAsync.value!;
  final rows = await db.query(
    'children',
    where: 'family_id = ?',
    whereArgs: [familyId],
  );
  return rows.map((e) => Child.fromMap(e)).toList();
});