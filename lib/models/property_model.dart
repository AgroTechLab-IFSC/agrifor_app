import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de aprovação de uma propriedade. `pending` existe tanto pro
/// autocadastro do produtor (ver ProducerService.
/// createPropertyForProducer) quanto pra propriedade `rejected` que o
/// produtor decidiu reenviar pra análise (ver PropertyRepository.
/// setPending, chamado tanto pelo admin — "marcar como pendente" numa
/// aprovada — quanto pelo produtor — "submeter novamente" numa
/// rejeitada). `rejected` só é alcançado a partir de `pending`, via
/// PropertyRepository.reject (admin). Cadastro feito pelo admin
/// (PropertyRepository.create, via PropertyFormSheet) já nasce
/// `approved`. Docs antigos, gravados antes desse campo existir, não
/// têm `status` no Firestore — tratados como `approved` (ver
/// propertyStatusFromString), então nenhuma migração é necessária.
enum PropertyStatus { pending, approved, rejected }

PropertyStatus propertyStatusFromString(String? value) {
  if (value == 'pending') return PropertyStatus.pending;
  if (value == 'rejected') return PropertyStatus.rejected;
  return PropertyStatus.approved;
}

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

  /// Telefone pra ligação direta (tel:), distinto do whatsapp — uma
  /// propriedade pode ter os dois, só um, ou nenhum. Mesma lógica de
  /// "campo opcional" do whatsapp: string vazia == não informado.
  final String phone;

  /// Usuário/handle do Instagram (sem '@', ex.: "sitio.alisson") ou a
  /// URL completa do perfil — ContactTile._instagramUrl (ver
  /// PropertyDetailScreen) normaliza os dois formatos na hora de abrir.
  final String instagram;
  final GeoPoint? location;

  /// URLs das imagens da propriedade, na ordem em que aparecem no
  /// carrossel. A ordem da lista É a estrutura de persistência da
  /// ordem — Firestore preserva a ordem de arrays, então não é preciso
  /// nenhum campo extra de índice por imagem. `images.first` (quando
  /// não vazia) é sempre a capa: usada como imagem principal no
  /// carrossel do detalhe e como thumbnail na listagem/busca (ver
  /// PropertiesScreen).
  final List<String> images;
  final PropertyStatus status;
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
    this.phone = '',
    this.instagram = '',
    this.location,
    this.images = const [],
    this.status = PropertyStatus.approved,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasOwner => ownerIds.isNotEmpty;

  bool isOwnedBy(String uid) => ownerIds.contains(uid);

  bool get isApproved => status == PropertyStatus.approved;

  bool get isPending => status == PropertyStatus.pending;

  bool get isRejected => status == PropertyStatus.rejected;

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
      phone: map['phone'] as String? ?? '',
      instagram: map['instagram'] as String? ?? '',
      location: map['location'] as GeoPoint?,
      images: List<String>.from(map['images'] ?? const []),
      status: propertyStatusFromString(map['status'] as String?),
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
        'phone': phone,
        'instagram': instagram,
        'location': location,
        'images': images,
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Campos que um PRODUTOR pode alterar na própria propriedade — tudo
  /// exceto ownerIds/ownerNames (só mudam via ProducerService, nunca
  /// direto pelo PropertyFormSheet) e `status` (só muda via
  /// PropertyRepository.approve, chamado pelo admin — ver
  /// PropertiesScreen). Omitir `status` aqui é o que garante que um
  /// produtor editando os próprios dados (summary, categorias, etc)
  /// nunca consegue, nem sem querer, tornar a própria propriedade
  /// pública. Usado por PropertyRepository.updateOwnEditableFields.
  Map<String, dynamic> toEditableMap() => {
        'propertyName': propertyName,
        'categoryIds': categoryIds,
        'productIds': productIds,
        'summary': summary,
        'productionSystem': productionSystem,
        'salesChannels': salesChannels,
        'salesNotes': salesNotes,
        'whatsapp': whatsapp,
        'phone': phone,
        'instagram': instagram,
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
    String? phone,
    String? instagram,
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
      phone: phone ?? this.phone,
      instagram: instagram ?? this.instagram,
      location: location ?? this.location,
      images: images ?? this.images,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}