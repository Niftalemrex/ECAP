class FamilyModel {
  final int id;
  final String name;

  const FamilyModel({required this.id, required this.name});

  factory FamilyModel.fromMap(Map<String, dynamic> map) {
    return FamilyModel(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}