class CategoryModel {
  final String id;
  final String name;
  final String unit; // 'bag' | 'ton' | 'piece' | 'cubic_ft' | 'kg'
  final List<String> brands;
  final List<String> grades;
  final int activeMaterialsCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.brands,
    required this.grades,
    this.activeMaterialsCount = 0,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? unit,
    List<String>? brands,
    List<String>? grades,
    int? activeMaterialsCount,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      brands: brands ?? this.brands,
      grades: grades ?? this.grades,
      activeMaterialsCount: activeMaterialsCount ?? this.activeMaterialsCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'brands': brands,
      'grades': grades,
      'activeMaterialsCount': activeMaterialsCount,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      brands: List<String>.from(map['brands'] ?? []),
      grades: List<String>.from(map['grades'] ?? []),
      activeMaterialsCount: map['activeMaterialsCount'] as int? ?? 0,
    );
  }
}
