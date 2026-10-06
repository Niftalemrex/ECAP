import '../entities/user.dart';

abstract class IAuthRepository {
  /// Returns a [User] if PIN matches, otherwise `null`.
  Future<User?> login(String pin);

  /// Creates a new user (and family) and returns the created [User].
  Future<User> register({
    required String name,
    required UserRole role,
    required String pin,
    String? familyName,
  });

  /// Returns the most recent non‑expired session token, if any.
  Future<String?> getActiveSessionToken();

  /// Deletes all sessions (full logout).
  Future<void> clearSession();
}