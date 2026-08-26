import 'package:agrifor_app/models/property_model.dart';

/// Dado já resolvido (ids -> nomes de exibição) que a tela de detalhes
/// precisa pra renderizar. Modelo neutro — não pertence ao admin, é
/// usado por qualquer lugar que abra PropertyDetailScreen (mapa,
/// admin, futura área do produtor). Ver PropertyDetailResolver.resolve.
class PropertyDetailViewData {
  const PropertyDetailViewData({
    required this.property,
    required this.ownerLabel,
    required this.categoryNames,
    required this.productNames,
    required this.productionSystemNames,
  });

  final PropertyModel property;
  final String ownerLabel;
  final List<String> categoryNames;
  final List<String> productNames;
  final List<String> productionSystemNames;
}