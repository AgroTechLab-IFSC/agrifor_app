import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:agrifor_app/models/app_user_model.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/models/production_system_model.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';
import 'package:agrifor_app/repositories/property_repository.dart';
import 'package:agrifor_app/repositories/property_detail_resolver.dart';
import 'package:agrifor_app/repositories/user_repository.dart';
import 'package:agrifor_app/services/auth_service.dart';
import 'package:agrifor_app/services/producer_service.dart';
import 'package:agrifor_app/screens/admin/widgets/property_form_sheet.dart';

import 'property_detail_screen.dart';

/// Tela única de propriedades — pública por padrão, com ações de admin
/// (cadastrar, editar, excluir) reveladas automaticamente quando o
/// usuário logado tem role == admin. Não existe tela separada pro
/// admin: a decisão "mostra ação de admin?" é resolvida aqui dentro,
/// a partir de quem está logado — não por uma flag passada de fora.
///
/// - `ownerLabel` vem direto de `property.ownerNames`, denormalizado no
///   vínculo (ver ProducerService.linkProducerToProperty) — não lemos
///   /users aqui pra isso, coleção fechada pra quem não é dono ou
///   admin. Usado só na busca por texto, não é exibido no card.
/// - Categorias/produtos vêm de CategoryRepository/ProductRepository
///   (mesma fonte usada no form de cadastro), sempre onlyActive: true
///   — tanto pro público quanto pro admin, já que não faz sentido
///   atribuir uma categoria/produto desativado a uma propriedade nova.
/// - Não existe soft delete de propriedade (sem campo `active`):
///   excluir é sempre definitivo e desvincula todos os produtores
///   antes de apagar, pra não deixar users/{uid}.propertyId órfão.
class PropertiesScreen extends StatefulWidget {
  PropertiesScreen({
    super.key,
    FirebaseFirestore? firestore,
    CategoryRepository? categoryRepository,
    ProductRepository? productRepository,
    ProductionSystemRepository? productionSystemRepository,
    PropertyRepository? propertyRepository,
    UserRepository? userRepository,
    ProducerService? producerService,
    AuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _categoryRepository =
           categoryRepository ??
           CategoryRepository(firestore ?? FirebaseFirestore.instance),
       _productRepository =
           productRepository ??
           ProductRepository(firestore ?? FirebaseFirestore.instance),
       _productionSystemRepository =
           productionSystemRepository ??
           ProductionSystemRepository(firestore ?? FirebaseFirestore.instance),
       _propertyRepository =
           propertyRepository ??
           PropertyRepository(firestore ?? FirebaseFirestore.instance),
       _userRepository =
           userRepository ??
           UserRepository(firestore ?? FirebaseFirestore.instance),
       _producerService =
           producerService ??
           ProducerService(firestore ?? FirebaseFirestore.instance),
       _authService = authService ?? AuthService();

  // Guardado só pra permitir criar os repositórios default acima; não
  // é usado diretamente no resto da tela.
  // ignore: unused_field
  final FirebaseFirestore _firestore;

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final ProductionSystemRepository _productionSystemRepository;
  final PropertyRepository _propertyRepository;
  final UserRepository _userRepository;
  final ProducerService _producerService;
  final AuthService _authService;

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Multi-seleção de categorias. "Todos" é o estado padrão/exclusivo.
  final Set<String> _selectedFilters = {'Todos'};

  late final PropertyDetailResolver _resolver = PropertyDetailResolver(
    categoryRepository: widget._categoryRepository,
    productRepository: widget._productRepository,
    productionSystemRepository: widget._productionSystemRepository,
  );

  // Streams da LISTA principal — criadas uma vez e escutadas o tempo
  // todo pelo StreamBuilder do build(). ATENÇÃO: são streams broadcast
  // do Firestore; um listener novo que entra depois do primeiro evento
  // não recebe esse evento retroativamente. Por isso o modal de
  // cadastro/edição (_openForm) NÃO reusa essas streams — ele pede
  // streams novas na hora de abrir (ver comentário lá embaixo). Bug já
  // vivido: reusar essas aqui deixava categorias/produtos vazios no
  // form, porque o StreamBuilder do modal chegava tarde demais.
  late final Stream<List<CategoryModel>> _categoriesStream = widget
      ._categoryRepository
      .watchAll(onlyActive: true);
  late final Stream<List<ProductModel>> _productsStream = widget
      ._productRepository
      .watchAll(onlyActive: true);
  late final Stream<List<ProductionSystemModel>> _productionSystemsStream =
      widget._productionSystemRepository.watchAll();

  // Uma stream só de propriedades, criada UMA VEZ (não dentro do
  // build/StreamBuilder) — o mesmo cuidado já tomado no form pra não
  // recriar streams a cada rebuild. Sem distinção ativo/inativo: todo
  // mundo (público e admin) vê a mesma lista.
  late final Stream<List<PropertyModel>> _propertiesStream = widget
      ._propertyRepository
      .watchAll();

  bool _resolvingDetail = false;

  // Estado de admin resolvido de forma imperativa (não via StreamBuilder
  // aninhado) — um StreamBuilder aninhado cujo `stream:` é calculado
  // dentro do builder de outro StreamBuilder recria a stream a cada
  // rebuild do pai (ex: a cada tecla digitada na busca), o que reseta
  // o estado. Ouvindo authStateChanges manualmente em initState, isso
  // só muda quando o login de fato muda.
  StreamSubscription<User?>? _authSub;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _authSub = widget._authService.authStateChanges.listen(_onAuthChanged);
    _onAuthChanged(widget._authService.currentUser);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      if (_isAdmin && mounted) setState(() => _isAdmin = false);
      return;
    }

    // Busca única (não fica "escutando" mudança de role em tempo real
    // — UserRepository não expõe watchById hoje). Se o papel do usuário
    // mudar enquanto o app está aberto, só reflete no próximo login.
    final appUser = await widget._userRepository.getById(user.uid);
    if (!mounted) return;

    final admin = appUser?.isAdmin ?? false;
    if (admin != _isAdmin) setState(() => _isAdmin = admin);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// property.ownerNames já vem pronto do Firestore — nada de cache
  /// nem fetch assíncrono aqui. Usado apenas para a busca por texto;
  /// não é mais exibido no card de resultado.
  String _ownerLabelFor(PropertyModel property) {
    if (property.ownerNames.isEmpty) return 'Não vinculado';
    return property.ownerNames.join(', ');
  }

  List<String> _categoryNamesFor(
    PropertyModel property,
    Map<String, CategoryModel> categoriesById,
  ) {
    return property.categoryIds
        .map((id) => categoriesById[id]?.name)
        .whereType<String>()
        .toList();
  }

  List<String> _productNamesFor(
    PropertyModel property,
    Map<String, ProductModel> productsById,
  ) {
    return property.productIds
        .map((id) => productsById[id]?.name)
        .whereType<String>()
        .toList();
  }

  List<PropertyModel> _filterProperties(
    List<PropertyModel> properties,
    Map<String, CategoryModel> categoriesById,
    Map<String, ProductModel> productsById,
  ) {
    final query = _searchController.text.toLowerCase();

    return properties.where((property) {
      final categoryNames = _categoryNamesFor(property, categoriesById);
      final productNames = _productNamesFor(property, productsById);
      final ownerLabel = _ownerLabelFor(property);

      final matchesSearch =
          query.isEmpty ||
          property.propertyName.toLowerCase().contains(query) ||
          ownerLabel.toLowerCase().contains(query) ||
          productNames.any((name) => name.toLowerCase().contains(query)) ||
          categoryNames.any((name) => name.toLowerCase().contains(query));

      final matchesFilter =
          _selectedFilters.contains('Todos') ||
          _selectedFilters.every((f) => categoryNames.contains(f));

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _onFilterSelected(String filter) {
    setState(() {
      if (filter == 'Todos') {
        _selectedFilters
          ..clear()
          ..add('Todos');
        return;
      }

      _selectedFilters.remove('Todos');
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }

      if (_selectedFilters.isEmpty) {
        _selectedFilters.add('Todos');
      }
    });
  }

  Future<void> _openDetail(PropertyModel property) async {
    if (_resolvingDetail) return;
    setState(() => _resolvingDetail = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await _resolver.resolve(property);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => PropertyDetailScreen(data: data)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir os detalhes da propriedade.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingDetail = false);
    }
  }

  Future<void> _openForm({PropertyModel? property}) async {
    // Busca TODOS os produtores já vinculados (não só o primeiro) antes
    // de abrir o sheet, pra pré-selecionar todos no ProducerPickerField.
    List<AppUserModel> currentProducers = const [];
    if (property != null && property.ownerIds.isNotEmpty) {
      currentProducers = await widget._userRepository.getByIds(
        property.ownerIds,
      );
    }

    if (!mounted) return;

    // Streams criadas AGORA, na abertura do modal — mesmo padrão já
    // usado em availableProducers. NÃO reusa _categoriesStream/
    // _productsStream/_productionSystemsStream (campos da classe,
    // escutados desde o início da tela): como são streams broadcast do
    // Firestore, um StreamBuilder novo que assina depois do primeiro
    // evento não recebe esse evento retroativamente e ficaria esperando
    // pra sempre. Pedindo streams novas aqui, o watchAll() já entrega o
    // snapshot atual assim que alguém assina.
    final availableProducers = widget._userRepository.watchAvailableProducers();
    final formCategories = widget._categoryRepository.watchAll(
      onlyActive: true,
    );
    final formProducts = widget._productRepository.watchAll(onlyActive: true);
    final formProductionSystems =
        widget._productionSystemRepository.watchAll();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StreamBuilder<List<CategoryModel>>(
        stream: formCategories,
        builder: (context, categorySnap) {
          return StreamBuilder<List<ProductModel>>(
            stream: formProducts,
            builder: (context, productSnap) {
              return StreamBuilder<List<ProductionSystemModel>>(
                stream: formProductionSystems,
                builder: (context, systemSnap) {
                  return PropertyFormSheet(
                    property: property,
                    currentProducers: currentProducers,
                    categories: categorySnap.data ?? const [],
                    products: productSnap.data ?? const [],
                    productionSystems: systemSnap.data ?? const [],
                    availableProducers: availableProducers,
                    producerService: widget._producerService,
                    onSave: property == null
                        ? (p) => widget._propertyRepository.create(p)
                        : (p) async {
                            await widget._propertyRepository.updateFull(p);
                            return p.id;
                          },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(PropertyModel property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir propriedade'),
        content: Text(
          'Tem certeza que deseja excluir "${property.propertyName}"? '
          'Essa ação não pode ser desfeita'
          '${property.ownerIds.isNotEmpty ? ' e vai desvincular ${property.ownerIds.length > 1 ? 'os produtores vinculados' : 'o produtor vinculado'}' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Desvincula todos os donos ANTES de apagar — evita
      // users/{uid}.propertyId apontando pra um documento inexistente.
      for (final uid in property.ownerIds) {
        await widget._producerService.unlinkProducerFromProperty(
          producerUid: uid,
          propertyId: property.id,
        );
      }
      await widget._propertyRepository.delete(property.id);

      if (!mounted) return;
      Navigator.of(context).pop(); // fecha o loading
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // fecha o loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Cadastrar propriedade',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar propriedade, produtor ou produto...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF2E7D32),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // FILTROS + LISTA
            Expanded(
              child: StreamBuilder<List<CategoryModel>>(
                stream: _categoriesStream,
                builder: (context, categorySnap) {
                  if (categorySnap.hasError) {
                    return const _CenteredMessage(
                      'Erro ao carregar categorias.',
                    );
                  }
                  if (!categorySnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = categorySnap.data!;
                  final categoriesById = {for (final c in categories) c.id: c};
                  final filters = ['Todos', ...categories.map((c) => c.name)];

                  return StreamBuilder<List<ProductModel>>(
                    stream: _productsStream,
                    builder: (context, productSnap) {
                      if (productSnap.hasError) {
                        return const _CenteredMessage(
                          'Erro ao carregar produtos.',
                        );
                      }
                      if (!productSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final productsById = {
                        for (final p in productSnap.data!) p.id: p,
                      };

                      return StreamBuilder<List<PropertyModel>>(
                        stream: _propertiesStream,
                        builder: (context, propertySnap) {
                          if (propertySnap.hasError) {
                            return const _CenteredMessage(
                              'Erro ao carregar propriedades.',
                            );
                          }
                          if (!propertySnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final allProperties = propertySnap.data!;
                          final filtered = _filterProperties(
                            allProperties,
                            categoriesById,
                            productsById,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FilterChips(
                                filters: filters,
                                selected: _selectedFilters,
                                onSelected: _onFilterSelected,
                              ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const _CenteredMessage(
                                        'Nenhuma propriedade encontrada.',
                                      )
                                    : ListView.separated(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          _isAdmin ? 96 : 16,
                                        ),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final property = filtered[index];
                                          return _PropertyResultTile(
                                            property: property,
                                            categoryNames: _categoryNamesFor(
                                              property,
                                              categoriesById,
                                            ),
                                            onTap: () => _openDetail(property),
                                            adminActions: _isAdmin
                                                ? [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 20,
                                                      ),
                                                      tooltip: 'Editar',
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      onPressed: () =>
                                                          _openForm(
                                                            property: property,
                                                          ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                        color: Colors.red,
                                                      ),
                                                      tooltip: 'Excluir',
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      onPressed: () =>
                                                          _confirmDelete(
                                                            property,
                                                          ),
                                                    ),
                                                  ]
                                                : null,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final Set<String> selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selected.contains(filter);
          return GestureDetector(
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2E7D32) : Colors.black12,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PropertyResultTile extends StatelessWidget {
  const _PropertyResultTile({
    required this.property,
    required this.categoryNames,
    required this.onTap,
    this.adminActions,
  });

  final PropertyModel property;
  final List<String> categoryNames;
  final VoidCallback onTap;

  /// Ações extras (editar, excluir) empilhadas verticalmente no canto
  /// direito do card. Só aparece quando não-nulo — decidido pela tela
  /// (quem está logado), não por uma flag interna deste widget.
  final List<Widget>? adminActions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Placeholder pra imagem da propriedade — sem imagem
            // programada ainda, só o quadradinho reservando o lugar.
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.propertyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  if (categoryNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categoryNames.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (adminActions != null)
              // Empilhados (editar em cima, excluir embaixo) em vez de
              // lado a lado — ocupa bem menos largura no card, que já
              // divide espaço com a imagem e o texto.
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: adminActions!
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: action,
                      ),
                    )
                    .toList(),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.black45)),
    );
  }
}