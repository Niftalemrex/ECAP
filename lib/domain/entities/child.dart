class Child {
  final int id;
  final String name;
  final String? avatar;
  final int familyId;

  const Child({
    required this.id,
    required this.name,
    this.avatar,
    required this.familyId,
  });

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'] as int,
      name: map['name'] as String,
      avatar: map['avatar'] as String?,
      familyId: map['family_id'] as int,
    );
  }
}