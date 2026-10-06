enum UserRole { super_admin, parent }

class User {
  final int id;
  final String name;
  final UserRole role;
  final int familyId;

  const User({
    required this.id,
    required this.name,
    required this.role,
    required this.familyId,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      name: map['name'] as String,
      role: map['role'] == 'super_admin' ? UserRole.super_admin : UserRole.parent,
      familyId: map['family_id'] as int,
    );
  }
}