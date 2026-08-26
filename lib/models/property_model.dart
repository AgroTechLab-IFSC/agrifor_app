import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyModel {
  final String id;
  final String propertyName;
  final List<String> ownerIds;
  final List<String> ownerNames;
  final List<String> categoryIds;
  final List<String> productIds;
  final String summary;
  final List<String> productionSystem;
  final List<String> salesChannels;
  final String salesNotes;
  final String whatsapp;
  final GeoPoint? location;
  final List<String> images;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PropertyModel({
    required this.id,
    required this.propertyName,
    this.ownerIds = const [],
    this.ownerNames = const [],
    this.categoryIds = const [],
    this.productIds = const [],
    this.summary = '',
    this.productionSystem = const [],
    this.salesChannels = const [],
    this.salesNotes = '',
    this.whatsapp = '',
    this.location,
    this.images = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get hasOwner => ownerIds.isNotEmpty;

  bool isOwnedBy(String uid) => ownerIds.contains(uid);

  factory PropertyModel.fromMap(String id, Map<String, dynamic> map) {
    return PropertyModel(
      id: id,
      propertyName: map['propertyName'] as String? ?? '',
      ownerIds: List<String>.from(map['ownerIds'] ?? const []),
      ownerNames: List<String>.from(map['ownerNames'] ?? const []),
      categoryIds: List<String>.from(map['categoryIds'] ?? const []),
      productIds: List<String>.from(map['productIds'] ?? const []),
      summary: map['summary'] as String? ?? '',
      productionSystem: List<String>.from(map['productionSystem'] ?? const []),
      salesChannels: List<String>.from(map['salesChannels'] ?? const []),
      salesNotes: map['salesNotes'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? '',
      location: map['location'] as GeoPoint?,
      images: List<String>.from(map['images'] ?? const []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'propertyName': propertyName,
        'ownerIds': ownerIds,
        'ownerNames': ownerNames,
        'categoryIds': categoryIds,
        'productIds': productIds,
        'summary': summary,
        'productionSystem': productionSystem,
        'salesChannels': salesChannels,
        'salesNotes': salesNotes,
        'whatsapp': whatsapp,
        'location': location,
        'images': images,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Campos que um PRODUTOR pode alterar na própria propriedade — tudo
  /// exceto ownerIds/ownerNames, que só mudam via ProducerService
  /// (link/unlink), nunca direto pelo PropertyFormSheet. Usado por
  /// PropertyRepository.updateOwnEditableFields.
  Map<String, dynamic> toEditableMap() => {
        'propertyName': propertyName,
        'categoryIds': categoryIds,
        'productIds': productIds,
        'summary': summary,
        'productionSystem': productionSystem,
        'salesChannels': salesChannels,
        'salesNotes': salesNotes,
        'whatsapp': whatsapp,
        'location': location,
        'images': images,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  PropertyModel copyWith({
    String? propertyName,
    List<String>? categoryIds,
    List<String>? productIds,
    String? summary,
    List<String>? productionSystem,
    List<String>? salesChannels,
    String? salesNotes,
    String? whatsapp,
    GeoPoint? location,
    List<String>? images,
  }) {
    return PropertyModel(
      id: id,
      propertyName: propertyName ?? this.propertyName,
      ownerIds: ownerIds,
      ownerNames: ownerNames,
      categoryIds: categoryIds ?? this.categoryIds,
      productIds: productIds ?? this.productIds,
      summary: summary ?? this.summary,
      productionSystem: productionSystem ?? this.productionSystem,
      salesChannels: salesChannels ?? this.salesChannels,
      salesNotes: salesNotes ?? this.salesNotes,
      whatsapp: whatsapp ?? this.whatsapp,
      location: location ?? this.location,
      images: images ?? this.images,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}