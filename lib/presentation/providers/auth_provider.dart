// lib/presentation/providers/auth_provider.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/domain/entities/user.dart';
import 'package:ecap/data/repositories/auth_repository.dart';
import 'package:ecap/presentation/providers/database_provider.dart';

// ─────────────────────────────────────────────────────────────
// Auth Notifier
// ─────────────────────────────────────────────────────────────
final authStateProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getActiveSessionToken();
    if (token == null) return null;
    // TODO: validate token and fetch user
    return null; // manual login for now
  }

  Future<void> login(String pin) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);

      // ✅ Hash the entered PIN before sending to repository
      final bytes = utf8.encode(pin);
      final hash = sha256.convert(bytes).toString();

      final user = await repo.login(hash);   // repo now checks against stored hash
      if (user == null) throw Exception('Invalid PIN');
      return user;
    });
  }

  Future<void> signUp({
    required String name,
    required UserRole role,
    required String pin,
    String? familyName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);

      // ✅ Hash the PIN before storing
      final bytes = utf8.encode(pin);
      final hash = sha256.convert(bytes).toString();

      await repo.register(
        name: name,
        role: role,
        pin: hash,                 // store the hash, not the plain PIN
        familyName: familyName,
      );
      return null;   // stay logged out
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.clearSession();
    state = const AsyncData(null);
  }
}

// ─────────────────────────────────────────────────────────────
// Derived providers
// ─────────────────────────────────────────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.role;
});

final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoading;
});

final currentFamilyIdProvider = Provider<int?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.familyId;
});

// ─────────────────────────────────────────────────────────────
// Family name provider (used in the parent home screen)
// ─────────────────────────────────────────────────────────────
final familyNameProvider = FutureProvider<String?>((ref) async {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return null;
  final db = await ref.read(databaseFutureProvider.future);
  final rows = await db.query('family',
      where: 'id = ?',
      whereArgs: [familyId]);
  if (rows.isEmpty) return null;
  return rows.first['name'] as String?;
});