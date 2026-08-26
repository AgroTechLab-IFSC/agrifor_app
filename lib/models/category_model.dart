// lib/models/category_model.dart
class CategoryModel {
  final String id;
  final String name;
  final int order;
  final bool active;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.order,
    this.active = true,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: map['name'] as String,
      order: (map['order'] as num?)?.toInt() ?? 0,
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'order': order,
        'active': active,
      };

  CategoryModel copyWith({String? name, int? order, bool? active}) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      active: active ?? this.active,
    );
  }
}