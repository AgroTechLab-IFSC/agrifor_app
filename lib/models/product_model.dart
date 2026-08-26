// lib/models/product_model.dart
class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final bool active;

  const ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.active = true,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] as String,
      categoryId: map['categoryId'] as String,
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'categoryId': categoryId,
        'active': active,
      };

  ProductModel copyWith({String? name, String? categoryId, bool? active}) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      active: active ?? this.active,
    );
  }
}