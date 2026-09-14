import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrifor_app/controllers/admin_categories_controller.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';
import 'package:agrifor_app/screens/admin/widgets/category_form_sheet.dart';
import 'package:agrifor_app/screens/admin/widgets/product_form_sheet.dart';

const _kBrandGreen = Color(0xFF2E7D32);
const _kBrandLight = Color(0xFFE8F5E9);

/// CRUD de categorias e produtos pro admin: lista de categorias, cada
/// uma expansível mostrando (e permitindo criar/editar/excluir) os
/// produtos dela.
///
/// Sem inativação — só exclusão definitiva (Firestore .delete()).
/// Apagar uma categoria apaga em cascata todos os produtos dela, com
/// confirmação prévia avisando quantos serão removidos junto (ver
/// AdminCategoriesController.deleteCategory).
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late final AdminCategoriesController _controller = AdminCategoriesController(
    categoryRepository: CategoryRepository(FirebaseFirestore.instance),
    productRepository: ProductRepository(FirebaseFirestore.instance),
  );

  /// Ids das categorias expandidas — controlado por fora do
  /// ExpansionTile só pra poder girar o ícone de seta no `trailing`
  /// (o ExpansionTile não expõe o próprio estado de expansão pra fora).
  final Set<String> _expandedCategoryIds = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCategoryForm({CategoryModel? category}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        category: category,
        onSave: (name) => category == null
            ? _controller.createCategory(name)
            : _controller.renameCategory(category, name),
      ),
    );
  }

  Future<void> _openProductForm({
    required CategoryModel category,
    ProductModel? product,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFormSheet(
        product: product,
        categoryName: category.name,
        onSave: (name) => product == null
            ? _controller.createProduct(name: name, categoryId: category.id)
            : _controller.renameProduct(product, name),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(CategoryModel category) async {
    final productCount = _controller.productsFor(category.id).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir categoria?'),
        content: Text(
          productCount == 0
              ? 'A categoria "${category.name}" será excluída definitivamente. '
                    'Essa ação não pode ser desfeita.'
              : 'A categoria "${category.name}" e os $productCount '
                    'produto${productCount == 1 ? '' : 's'} cadastrados nela '
                    'serão excluídos definitivamente. Essa ação não pode ser '
                    'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _expandedCategoryIds.remove(category.id);
      await _controller.deleteCategory(category);
    } catch (e) {
      _showError('Erro ao excluir categoria: $e');
    }
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          'O produto "${product.name}" será excluído definitivamente. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _controller.deleteProduct(product.id);
    } catch (e) {
      _showError('Erro ao excluir produto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null) {
          return Center(child: Text(_controller.errorMessage!));
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: _kBrandGreen,
            onPressed: () => _openCategoryForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Cadastrar categoria',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: _controller.categories.isEmpty
              ? const Center(child: Text('Nenhuma categoria cadastrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: _controller.categories.length,
                  itemBuilder: (context, index) {
                    final category = _controller.categories[index];
                    final categoryProducts = _controller.productsFor(
                      category.id,
                    );
                    final isExpanded = _expandedCategoryIds.contains(
                      category.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        onExpansionChanged: (expanded) => setState(() {
                          if (expanded) {
                            _expandedCategoryIds.add(category.id);
                          } else {
                            _expandedCategoryIds.remove(category.id);
                          }
                        }),
                        // Ícone fixo de categoria — deixa claro que a
                        // linha inteira é uma categoria clicável, não
                        // só texto solto.
                        leading: const Icon(
                          Icons.category_outlined,
                          color: _kBrandGreen,
                        ),
                        title: Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${categoryProducts.length} produto'
                          '${categoryProducts.length == 1 ? '' : 's'}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        // trailing custom (edição/exclusão) some com o
                        // "arrow" padrão do ExpansionTile, então
                        // recolocamos uma seta própria no final, que
                        // gira 180° ao expandir — reforça visualmente
                        // que tocar a linha abre/fecha os produtos.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar',
                              onPressed: () =>
                                  _openCategoryForm(category: category),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Excluir',
                              onPressed: () =>
                                  _confirmDeleteCategory(category),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.expand_more,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          for (final product in categoryProducts)
                            ListTile(
                              dense: true,
                              tileColor: _kBrandLight,
                              title: Text(product.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    tooltip: 'Editar',
                                    onPressed: () => _openProductForm(
                                      category: category,
                                      product: product,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Excluir',
                                    onPressed: () =>
                                        _confirmDeleteProduct(product),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _openProductForm(category: category),
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar produto'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}