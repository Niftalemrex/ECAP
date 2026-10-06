// lib/data/repositories/auth_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/core/database.dart';
import 'package:ecap/domain/entities/user.dart';
import 'package:ecap/domain/repositories/i_auth_repository.dart';
import 'package:ecap/presentation/providers/database_provider.dart';

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final dbFuture = ref.read(databaseFutureProvider.future);  // Future<Database>
  return AuthRepository(dbFuture);
});

class AuthRepository implements IAuthRepository {
  final Future<Database> _dbFuture;
  AuthRepository(this._dbFuture);

  // Helper to get DB once
  Future<Database> get _db => _dbFuture;

  @override
  Future<User?> login(String pin) async {
    final db = await _db;
    // Hash the PIN before comparing! For now we compare plain text.
    final rows = await db.query('users',
        where: 'pin_hash = ?',
        whereArgs: [pin]);   // TODO: use hash
    if (rows.isEmpty) return null;

    final user = User.fromMap(rows.first);
    await _createSession(db, user.id);
    return user;
  }

  @override
  Future<User> register({
    required String name,
    required UserRole role,
    required String pin,
    String? familyName,
  }) async {
    final db = await _db;

    // 1. Create family
    final int familyId;
    if (role == UserRole.super_admin) {
      familyId = await db.insert('family', {
        'name': familyName ?? 'Admin Family',
      });
    } else {
      familyId = await db.insert('family', {
        'name': familyName ?? 'Default Family',
      });
    }

    // 2. Insert user (store the PIN – not hashed yet)
    final userId = await db.insert('users', {
      'name': name,
      'role': role == UserRole.super_admin ? 'super_admin' : 'parent',
      'pin_hash': pin,   // TODO: hash pin
      'family_id': familyId,
    });

    return User(id: userId, name: name, role: role, familyId: familyId);
  }

  // ──────────────────────────────────────────
  // Session helpers
  // ──────────────────────────────────────────
  Future<void> _createSession(Database db, int userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    await db.insert('sessions', {
      'user_id': userId,
      'token': token,
      'created_at': now,
      'expires_at': expires,
    });
  }

  @override
  Future<String?> getActiveSessionToken() async {
    final db = await _db;
    final rows = await db.query('sessions',
        where: 'expires_at > ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['token'] as String;
  }

  @override
  Future<void> clearSession() async {
    final db = await _db;
    await db.delete('sessions');
  }
}