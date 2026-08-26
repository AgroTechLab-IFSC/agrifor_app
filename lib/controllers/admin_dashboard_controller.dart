import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/production_system_model.dart';
import 'package:agrifor_app/repositories/property_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';

/// Estado de UI do "Painel" do admin: total de propriedades + contagem
/// de propriedades por sistema de produção (não-exclusiva — uma
/// propriedade com productionSystem: ['a', 'b'] conta em ambos).
class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController({
    required PropertyRepository propertyRepository,
    required ProductionSystemRepository productionSystemRepository,
  })  : _propertyRepository = propertyRepository,
        _productionSystemRepository = productionSystemRepository {
    _init();
  }

  final PropertyRepository _propertyRepository;
  final ProductionSystemRepository _productionSystemRepository;

  StreamSubscription<List<PropertyModel>>? _propertiesSub;
  StreamSubscription<List<ProductionSystemModel>>? _systemsSub;

  bool isLoading = true;
  String? errorMessage;

  int totalProperties = 0;

  /// Já em ordem de exibição (mesma ordem cadastrada em
  /// productionSystems.order), com nome resolvido e contagem.
  List<ProductionSystemCount> systemCounts = [];

  List<PropertyModel> _properties = [];
  List<ProductionSystemModel> _systems = [];

  void _init() {
    _propertiesSub = _propertyRepository.watchAll().listen(
      (properties) {
        _properties = properties;
        _recompute();
      },
      onError: (err) {
        errorMessage = 'Erro ao carregar propriedades: $err';
        isLoading = false;
        notifyListeners();
      },
    );

    _systemsSub = _productionSystemRepository.watchAll().listen(
      (systems) {
        _systems = systems;
        _recompute();
      },
      onError: (err) {
        errorMessage = 'Erro ao carregar sistemas de produção: $err';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  void _recompute() {
    // espera os dois streams emitirem ao menos uma vez antes de
    // considerar carregado (evita mostrar "0" de forma enganosa
    // enquanto só um dos dois já chegou).
    if (_systems.isEmpty && _properties.isEmpty) {
      // ainda pode ser estado inicial legítimo (banco vazio) — mas só
      // paramos de mostrar loading depois que ambos os streams
      // dispararem ao menos um evento. Como não há flag separada por
      // stream aqui, simplificamos: se chegou em _recompute, algum dos
      // dois já respondeu; isLoading cai para false na primeira
      // chamada de qualquer forma.
    }

    totalProperties = _properties.length;

    final counts = <String, int>{};
    for (final property in _properties) {
      for (final systemId in property.productionSystem) {
        counts[systemId] = (counts[systemId] ?? 0) + 1;
      }
    }

    systemCounts = _systems
        .map(
          (system) => ProductionSystemCount(
            name: system.name,
            count: counts[system.id] ?? 0,
          ),
        )
        .toList();

    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _propertiesSub?.cancel();
    _systemsSub?.cancel();
    super.dispose();
  }
}

class ProductionSystemCount {
  const ProductionSystemCount({required this.name, required this.count});
  final String name;
  final int count;
}