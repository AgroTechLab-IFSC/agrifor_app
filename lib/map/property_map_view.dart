import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../../models/category_model.dart';
import '../../models/property_model.dart';
import '../../models/property_detail_view_data.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/production_system_repository.dart';
import '../../repositories/property_detail_resolver.dart';
import '../screens/property/property_detail_screen.dart';
import '../widgets/animated_property_pin.dart';
import '../widgets/map_filter_bar.dart';
import '../widgets/property_detail_card.dart';

const String kLagesTileStore = 'lagesStore';
const LatLng kLagesCenter = LatLng(-27.765, -50.163);
final LatLngBounds kLagesBounds = LatLngBounds(
  const LatLng(-27.95, -50.42),
  const LatLng(-27.59, -49.95),
);
const double kMapMinZoom = 11;

class PropertyMapView extends StatefulWidget {
  const PropertyMapView({super.key, required this.properties});

  final List<PropertyModel> properties;

  @override
  State<PropertyMapView> createState() => _PropertyMapViewState();
}

class _PropertyMapViewState extends State<PropertyMapView>
    with SingleTickerProviderStateMixin {
  // "Todos" é exclusivo: começa selecionado sozinho, some quando uma
  // categoria específica é marcada, e volta sozinho se todas as
  // categorias forem desmarcadas — mesmo padrão do filtro da busca.
  final Set<String> _activeFilters = {MapFilterBar.allFilterId};
  PropertyModel? _selectedProperty;
  final MapController _mapController = MapController();

  final CategoryRepository _categoryRepository = CategoryRepository(
    FirebaseFirestore.instance,
  );
  final ProductRepository _productRepository = ProductRepository(
    FirebaseFirestore.instance,
  );
  final ProductionSystemRepository _productionSystemRepository =
      ProductionSystemRepository(FirebaseFirestore.instance);

  // Resolver stateless que traduz ids -> nomes de exibição pra tela
  // cheia de detalhes. Sem cache de propósito (ver comentário na
  // classe) — cada abertura de detalhe busca fresco do Firestore.
  // Não depende mais de UserRepository: o nome do(s) produtor(es) já
  // vem denormalizado em property.ownerNames (gravado no vínculo, ver
  // ProducerService.linkProducerToProperty) — /users é fechado pra
  // quem não é o próprio dono ou admin, e o mapa é tela pública.
  late final PropertyDetailResolver _detailResolver = PropertyDetailResolver(
    categoryRepository: _categoryRepository,
    productRepository: _productRepository,
    productionSystemRepository: _productionSystemRepository,
  );

  List<CategoryModel> _categories = [];
  StreamSubscription<List<CategoryModel>>? _categoriesSub;

  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _cardController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);

    _categoriesSub = _categoryRepository.watchAll(onlyActive: true).listen((
      cats,
    ) {
      if (mounted) setState(() => _categories = cats);
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    _categoriesSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PropertyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedProperty != null &&
        !widget.properties.any((p) => p.id == _selectedProperty!.id)) {
      _closeCard();
    }
  }

  List<PropertyModel> get _mappableProperties =>
      widget.properties.where((p) => p.location != null).toList();

  List<PropertyModel> get _filteredProperties {
    final base = _mappableProperties;
    if (_activeFilters.contains(MapFilterBar.allFilterId)) return base;
    return base
        .where((p) => p.categoryIds.toSet().containsAll(_activeFilters))
        .toList();
  }

  List<String> _categoryNamesFor(PropertyModel property) {
    return _categories
        .where((c) => property.categoryIds.contains(c.id))
        .map((c) => c.name)
        .toList();
  }

  void _fitToMarkers() {
    final points = _filteredProperties
        .map((p) => LatLng(p.location!.latitude, p.location!.longitude))
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
        maxZoom: 15,
      ),
    );
  }

  void _toggleFilter(String categoryId) {
    setState(() {
      if (categoryId == MapFilterBar.allFilterId) {
        _activeFilters
          ..clear()
          ..add(MapFilterBar.allFilterId);
      } else {
        _activeFilters.remove(MapFilterBar.allFilterId);
        if (_activeFilters.contains(categoryId)) {
          _activeFilters.remove(categoryId);
        } else {
          _activeFilters.add(categoryId);
        }
        if (_activeFilters.isEmpty) {
          _activeFilters.add(MapFilterBar.allFilterId);
        }
      }
      if (_selectedProperty != null &&
          !_filteredProperties.any((p) => p.id == _selectedProperty!.id)) {
        _closeCard();
      }
    });
    _fitToMarkers();
  }

  void _selectProperty(PropertyModel property) {
    final isSame = _selectedProperty?.id == property.id;
    setState(() => _selectedProperty = property);
    if (!isSame) {
      _cardController.forward(from: isSame ? _cardController.value : 0);
    }
  }

  void _closeCard() {
    _cardController.reverse().then((_) {
      if (mounted) setState(() => _selectedProperty = null);
    });
  }

  /// Busca os dados resolvidos (categorias/produtos/sistema/dono já
  /// traduzidos pra nome) e só então navega pra tela cheia. Mostra um
  /// loading modal simples enquanto espera o Firestore, já que o
  /// resolver não tem cache — cada chamada é uma busca de verdade.
  Future<void> _openDetails(
    BuildContext context,
    PropertyModel property,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    PropertyDetailViewData data;
    try {
      data = await _detailResolver.resolve(property);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // fecha o loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar detalhes da propriedade.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // fecha o loading

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProperties;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: kLagesCenter,
            initialZoom: 13,
            minZoom: kMapMinZoom,
            maxZoom: 16,
            cameraConstraint: CameraConstraint.contain(bounds: kLagesBounds),
            onMapReady: () {
              _fitToMarkers();
              // Garante um segundo ajuste já com o layout 100% assentado —
              // o primeiro (onMapReady) pode disparar antes do frame
              // terminar de pintar, fazendo o flutter_map calcular o
              // viewport errado e só pedir os tiles do centro. Esse segundo
              // fitCamera, depois do primeiro frame renderizado, corrige o
              // viewport e faz o tile layer repedir tudo certo — sem precisar
              // de gesto do usuário pra "destravar".
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fitToMarkers();
              });
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) {
              if (_selectedProperty != null) _closeCard();
            },
          ),
          children: [
            TileLayer(
              tileProvider: FMTCStore(kLagesTileStore).getTileProvider(),
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agrifor.app',
              minZoom: kMapMinZoom,
              maxZoom: 16,
            ),
            MarkerLayer(
              markers: List.generate(filtered.length, (index) {
                final property = filtered[index];
                final isSelected = _selectedProperty?.id == property.id;

                return Marker(
                  point: LatLng(
                    property.location!.latitude,
                    property.location!.longitude,
                  ),
                  width: 110,
                  height: 110,
                  alignment: Alignment.topCenter,
                  rotate: true,
                  child: AnimatedPropertyPin(
                    name: property.propertyName,
                    selected: isSelected,
                    entranceDelayMs: index * 90,
                    onTap: () => _selectProperty(property),
                  ),
                );
              }),
            ),
          ],
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: MapFilterBar(
              categories: _categories,
              activeFilters: _activeFilters,
              onToggle: _toggleFilter,
            ),
          ),
        ),

        IgnorePointer(
          ignoring: _selectedProperty == null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: _selectedProperty != null ? 1 : 0,
            child: GestureDetector(
              onTap: _closeCard,
              child: Container(color: Colors.black.withOpacity(0.18)),
            ),
          ),
        ),

        if (_selectedProperty != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: PropertyDetailCard(
                  property: _selectedProperty!,
                  categoryNames: _categoryNamesFor(_selectedProperty!),
                  onClose: _closeCard,
                  onSeeMore: () {
                    final property = _selectedProperty!;
                    _closeCard();
                    _openDetails(context, property);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
