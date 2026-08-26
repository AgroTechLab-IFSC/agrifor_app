import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/models/production_system_model.dart';
import 'package:agrifor_app/models/app_user_model.dart';
import 'package:agrifor_app/models/property_detail_view_data.dart';
import 'package:agrifor_app/repositories/property_repository.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';
import 'package:agrifor_app/repositories/user_repository.dart';
import 'package:agrifor_app/repositories/property_detail_resolver.dart';
import 'package:agrifor_app/services/producer_service.dart';
import 'package:agrifor_app/utils/id_name_lookup.dart';

class AdminPropertiesController extends ChangeNotifier {
  AdminPropertiesController({
    required PropertyRepository propertyRepository,
    required CategoryRepository categoryRepository,
    required ProductRepository productRepository,
    required ProductionSystemRepository productionSystemRepository,
    required UserRepository userRepository,
    required ProducerService producerService,
  }) : _propertyRepository = propertyRepository,
       _categoryRepository = categoryRepository,
       _productRepository = productRepository,
       _productionSystemRepository = productionSystemRepository,
       _userRepository = userRepository,
       _producerService = producerService,
       _detailResolver = PropertyDetailResolver(
         categoryRepository: categoryRepository,
         productRepository: productRepository,
         productionSystemRepository: productionSystemRepository,
       ) {
    // properties não tem conceito de ativo/inativo (sem campo `active`
    // no modelo) — watchAll() aqui não recebe onlyActive, diferente de
    // categories/products, que continuam tendo esse filtro.
    _propertiesSub = _propertyRepository.watchAll().listen(
      _onProperties,
      onError: _onError,
    );
    _categoriesSub = _categoryRepository.watchAll(onlyActive: false).listen((
      c,
    ) {
      categories = c;
      notifyListeners();
    }, onError: _onError);
    _productsSub = _productRepository.watchAll(onlyActive: false).listen((p) {
      products = p;
      notifyListeners();
    }, onError: _onError);
    _productionSystemsSub = _productionSystemRepository.watchAll().listen((s) {
      productionSystems = s;
      notifyListeners();
    }, onError: _onError);
  }

  final PropertyRepository _propertyRepository;
  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final ProductionSystemRepository _productionSystemRepository;
  // Continua aqui só pra watchAvailableProducers() (listar produtores
  // pro admin vincular) — leitura legítima, admin tem permissão sobre
  // /users. Não é mais usado pra resolver nome de dono de propriedade.
  final UserRepository _userRepository;
  final ProducerService _producerService;

  // Resolver compartilhado com o mapa (property_map_view.dart) e com a
  // tela de detalhes (property_detail_screen.dart) — a lógica de ids ->
  // nomes de exibição pra tela de detalhes não pertence a este
  // controller, ver PropertyDetailResolver.
  final PropertyDetailResolver _detailResolver;

  StreamSubscription<List<PropertyModel>>? _propertiesSub;
  StreamSubscription<List<CategoryModel>>? _categoriesSub;
  StreamSubscription<List<ProductModel>>? _productsSub;
  StreamSubscription<List<ProductionSystemModel>>? _productionSystemsSub;

  List<PropertyModel> properties = [];
  List<CategoryModel> categories = [];
  List<ProductModel> products = [];
  List<ProductionSystemModel> productionSystems = [];

  bool isLoading = true;
  String? errorMessage;

  void _onError(Object e) {
    errorMessage = 'Erro ao carregar dados. Tente novamente.';
    isLoading = false;
    notifyListeners();
  }

  void _onProperties(List<PropertyModel> list) {
    properties = list;
    isLoading = false;
    notifyListeners();
  }

  /// Nome(s) do(s) produtor(es) vinculado(s) — vem pronto de
  /// property.ownerNames, denormalizado no momento do vínculo (ver
  /// ProducerService.linkProducerToProperty). Síncrono, sem cache: não
  /// há mais busca em /users pra fazer aqui.
  String ownerLabelFor(PropertyModel property) {
    if (property.ownerNames.isEmpty) return 'Não vinculado';
    return property.ownerNames.join(', ');
  }

  String categoryLabelsFor(PropertyModel property) {
    final names = categoryNamesFor(property);
    return names.isEmpty ? '—' : names.join(', ');
  }

  /// Mesma resolução usada por categoryLabelsFor, mas em lista — usado
  /// em telas do admin que renderizam cada categoria como um chip
  /// separado. Delega pro util compartilhado com PropertyDetailResolver.
  List<String> categoryNamesFor(PropertyModel property) => namesFor(
    property.categoryIds,
    categories,
    idOf: (c) => c.id,
    nameOf: (c) => c.name,
    fallback: '(categoria removida)',
  );

  List<String> productNamesFor(PropertyModel property) => namesFor(
    property.productIds,
    products,
    idOf: (p) => p.id,
    nameOf: (p) => p.name,
    fallback: '(produto removido)',
  );

  List<String> productionSystemNamesFor(PropertyModel property) => namesFor(
    property.productionSystem,
    productionSystems,
    idOf: (s) => s.id,
    nameOf: (s) => s.name,
    fallback: '(sistema removido)',
  );

  /// Delega pro resolver compartilhado com o mapa — o controller não
  /// monta mais esse dado sozinho a partir do cache em memória.
  ///
  /// ATENÇÃO: é Future (não síncrono). Quem chama isso pra abrir a tela
  /// de detalhes precisa de `await` ou FutureBuilder.
  Future<PropertyDetailViewData> detailDataFor(PropertyModel property) {
    return _detailResolver.resolve(property);
  }

  Stream<List<AppUserModel>> watchAvailableProducers() =>
      _userRepository.watchAvailableProducers();

  /// Retorna o id gerado pelo Firestore — essencial pro caller poder
  /// chamar linkProducer logo em seguida numa propriedade recém-criada
  /// (o PropertyModel local não tem id até esse ponto).
  Future<String> createProperty(PropertyModel property) {
    return _propertyRepository.create(property);
  }

  Future<void> updateProperty(PropertyModel property) {
    return _propertyRepository.updateFull(property);
  }

  /// Propaga a Exception do ProducerService (mensagem já amigável) pra
  /// quem chamou tratar (snackbar) — sem mapeamento extra aqui.
  Future<void> linkProducer({
    required String producerUid,
    required String propertyId,
  }) {
    return _producerService.linkProducerToProperty(
      producerUid: producerUid,
      propertyId: propertyId,
    );
  }

  @override
  void dispose() {
    _propertiesSub?.cancel();
    _categoriesSub?.cancel();
    _productsSub?.cancel();
    _productionSystemsSub?.cancel();
    super.dispose();
  }

  /// Busca os AppUserModel dos donos já vinculados a uma propriedade
  /// (property.ownerIds) — usado pra pré-popular o multi-select do
  /// PropertyFormSheet na edição.
  Future<List<AppUserModel>> getProducersByIds(List<String> uids) {
    return _userRepository.getByIds(uids);
  }

  /// Vincula vários produtores de uma vez (chamado pelo LinkProducerSheet
  /// quando o admin seleciona mais de um). Sequencial: se um falhar no
  /// meio (ex: produtor já vinculado por outro admin em paralelo), os
  /// anteriores já ficam vinculados e o erro sobe pra quem chamou tratar.
  Future<void> linkProducers({
    required List<String> producerUids,
    required String propertyId,
  }) async {
    for (final uid in producerUids) {
      await _producerService.linkProducerToProperty(
        producerUid: uid,
        propertyId: propertyId,
      );
    }
  }

  /// Propaga a Exception do ProducerService (mensagem já amigável) pra
  /// quem chamou tratar (snackbar).
  Future<void> unlinkProducer({
    required String producerUid,
    required String propertyId,
  }) {
    return _producerService.unlinkProducerFromProperty(
      producerUid: producerUid,
      propertyId: propertyId,
    );
  }
}