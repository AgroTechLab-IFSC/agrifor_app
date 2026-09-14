import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';

/// Estado da tela de admin de Categorias: lista de categorias +
/// produtos, com CRUD completo — sem inativação, só exclusão
/// definitiva (em cascata: apagar uma categoria apaga os produtos
/// dela). onlyActive: false só porque o método do repository exige o
/// parâmetro; toda categoria/produto criado por aqui nasce e permanece
/// com active: true (default do model), o campo simplesmente não é
/// mais editável por esta tela.
class AdminCategoriesController extends ChangeNotifier {
  AdminCategoriesController({
    required CategoryRepository categoryRepository,
    required ProductRepository productRepository,
  }) : _categoryRepository = categoryRepository,
       _productRepository = productRepository {
    _categoriesSub = _categoryRepository.watchAll(onlyActive: false).listen((
      list,
    ) {
      categories = list;
      isLoading = false;
      notifyListeners();
    }, onError: _onError);
    _productsSub = _productRepository.watchAll(onlyActive: false).listen((
      list,
    ) {
      products = list;
      notifyListeners();
    }, onError: _onError);
  }

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;

  StreamSubscription<List<CategoryModel>>? _categoriesSub;
  StreamSubscription<List<ProductModel>>? _productsSub;

  List<CategoryModel> categories = [];
  List<ProductModel> products = [];

  bool isLoading = true;
  String? errorMessage;

  void _onError(Object e) {
    errorMessage = 'Erro ao carregar categorias/produtos. Tente novamente.';
    isLoading = false;
    notifyListeners();
  }

  /// Produtos de uma categoria, ordenados por nome — usado pra
  /// expandir cada categoria na lista e também pra saber quantos
  /// serão apagados numa exclusão em cascata (ver deleteCategory).
  List<ProductModel> productsFor(String categoryId) {
    final list = products.where((p) => p.categoryId == categoryId).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // ---- Categorias --------------------------------------------------------

  Future<String> createCategory(String name) {
    return _categoryRepository.create(
      CategoryModel(id: '', name: name.trim(), order: categories.length),
    );
  }

  Future<void> renameCategory(CategoryModel category, String newName) {
    return _categoryRepository.update(
      category.copyWith(name: newName.trim()),
    );
  }

  /// Exclusão definitiva EM CASCATA: apaga primeiro todos os produtos
  /// da categoria (sequencial, mesma abordagem do
  /// AdminPropertiesController.linkProducers — se um falhar no meio,
  /// os anteriores já ficam apagados e o erro sobe pra quem chamou
  /// tratar), só depois apaga a categoria. Quem chama deve confirmar
  /// com o usuário ANTES (ex: via productsFor(category.id).length no
  /// diálogo de confirmação), esta função não pergunta nada.
  Future<void> deleteCategory(CategoryModel category) async {
    for (final product in productsFor(category.id)) {
      await _productRepository.delete(product.id);
    }
    await _categoryRepository.delete(category.id);
  }

  // ---- Produtos -----------------------------------------------------------

  Future<String> createProduct({
    required String name,
    required String categoryId,
  }) {
    return _productRepository.create(
      ProductModel(id: '', name: name.trim(), categoryId: categoryId),
    );
  }

  Future<void> renameProduct(ProductModel product, String newName) {
    return _productRepository.update(product.copyWith(name: newName.trim()));
  }

  Future<void> deleteProduct(String id) {
    return _productRepository.delete(id);
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }
}