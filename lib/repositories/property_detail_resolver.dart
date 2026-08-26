import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/property_detail_view_data.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';
import 'package:agrifor_app/utils/id_name_lookup.dart';

/// Resolve um PropertyModel (cheio de ids) num PropertyDetailViewData
/// (cheio de nomes de exibição), consultando Firestore sob demanda.
///
/// De propósito NÃO guarda estado nem cache entre chamadas — cada
/// resolve() busca fresco. Isso o torna seguro de instanciar em
/// qualquer tela (mapa, admin, futura tela do produtor) sem se
/// preocupar com ciclo de vida ou dado desatualizado. Se o custo de
/// reconsultar Firestore a cada abertura de detalhe virar um problema
/// real de performance/custo, considerar cache AQUI DENTRO (não fora,
/// pra não vazar essa decisão pra quem chama).
///
/// Não depende mais de UserRepository: o nome do(s) produtor(es) já vem
/// denormalizado em property.ownerNames (gravado no vínculo por
/// ProducerService.linkProducerToProperty), porque /users é fechado
/// pra quem não é o próprio dono ou admin — visitante/mapa nunca teria
/// permissão de ler users/{uid} de qualquer forma.
class PropertyDetailResolver {
  PropertyDetailResolver({
    required CategoryRepository categoryRepository,
    required ProductRepository productRepository,
    required ProductionSystemRepository productionSystemRepository,
  })  : _categoryRepository = categoryRepository,
        _productRepository = productRepository,
        _productionSystemRepository = productionSystemRepository;

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final ProductionSystemRepository _productionSystemRepository;

  Future<PropertyDetailViewData> resolve(PropertyModel property) async {
    // Dispara tudo em paralelo antes de dar await em qualquer um —
    // custo de rede é pago uma vez só, não em série.
    final categoriesFuture =
        _categoryRepository.watchAll(onlyActive: false).first;
    final productsFuture =
        _productRepository.watchAll(onlyActive: false).first;
    final productionSystemsFuture = _productionSystemRepository.watchAll().first;

    final categories = await categoriesFuture;
    final products = await productsFuture;
    final productionSystems = await productionSystemsFuture;

    return PropertyDetailViewData(
      property: property,
      ownerLabel: _ownerLabel(property.ownerNames),
      categoryNames: namesFor(
        property.categoryIds,
        categories,
        idOf: (c) => c.id,
        nameOf: (c) => c.name,
        fallback: '(categoria removida)',
      ),
      productNames: namesFor(
        property.productIds,
        products,
        idOf: (p) => p.id,
        nameOf: (p) => p.name,
        fallback: '(produto removido)',
      ),
      productionSystemNames: namesFor(
        property.productionSystem,
        productionSystems,
        idOf: (s) => s.id,
        nameOf: (s) => s.name,
        fallback: '(sistema removido)',
      ),
    );
  }

  String _ownerLabel(List<String> ownerNames) {
    if (ownerNames.isEmpty) return 'Não vinculado';
    return ownerNames.join(', ');
  }
}