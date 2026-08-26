import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/models/production_system_model.dart';
import 'package:agrifor_app/models/app_user_model.dart';
import 'package:agrifor_app/services/producer_service.dart';
import 'package:agrifor_app/utils/google_maps_link_parser.dart';
import 'package:agrifor_app/screens/admin/widgets/producer_picker_field.dart';

const _commonSalesChannels = [
  'Feira',
  'Venda na propriedade',
  'Entrega/Delivery',
  'Atacado',
  'Venda online',
];

/// Bottom sheet de cadastro (property == null) ou edição (property !=
/// null) de propriedade. Chama onSave com o PropertyModel resultante e
/// espera de volta o id salvo — quem decide se é create, updateFull ou
/// updateOwnEditableFields é a tela que abriu o sheet (admin ou
/// produtor, ver AdminPropertiesController / MyPropertyScreen).
///
/// Uma propriedade pode ter 0..N produtores vinculados. Quando
/// [readOnlyProducers] é false (fluxo do admin), a seleção é feita
/// pelo ProducerPickerField (busca + chips removíveis) e o submit
/// dispara link/unlink pro que mudou, via ProducerService. Quando
/// [readOnlyProducers] é true (fluxo do próprio produtor editando a
/// própria propriedade), essa seção vira só-leitura — vínculo de
/// produtor continua sendo decisão exclusiva do admin, feita por fora
/// deste form.
class PropertyFormSheet extends StatefulWidget {
  const PropertyFormSheet({
    super.key,
    this.property,
    this.currentProducers = const [],
    required this.categories,
    required this.products,
    required this.productionSystems,
    required this.availableProducers,
    required this.producerService,
    this.readOnlyProducers = false,
    required this.onSave,
  });

  final PropertyModel? property;

  /// Produtores já vinculados a esta propriedade, se houver (edição).
  /// Buscar via UserRepository.getByIds(property.ownerIds) antes de
  /// abrir o sheet. Vazio em cadastro novo, propriedade sem produtor
  /// ainda, ou quando readOnlyProducers é true (nesse caso o nome já
  /// vem pronto de property.ownerNames, não precisa buscar). Nenhum
  /// deles aparece no stream de `availableProducers` (já têm
  /// propertyId preenchido), então são injetados manualmente na lista
  /// de opções do ProducerPickerField pra continuarem
  /// visíveis/selecionados.
  final List<AppUserModel> currentProducers;

  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<ProductionSystemModel> productionSystems;

  /// UserRepository.watchAvailableProducers() — produtores com role
  /// 'producer' e ainda sem propertyId. Ignorado quando
  /// readOnlyProducers é true; pode passar Stream.empty() nesse caso.
  final Stream<List<AppUserModel>> availableProducers;

  final ProducerService producerService;

  /// true quando quem está editando é o próprio produtor: a seção
  /// "Produtor(es)" fica só-leitura (mostra property.ownerNames) e o
  /// submit não dispara link/unlink nenhum.
  final bool readOnlyProducers;

  /// Deve retornar o id da propriedade salva (create já devolve String;
  /// em update, devolver property.id depois do await).
  final Future<String> Function(PropertyModel property) onSave;

  @override
  State<PropertyFormSheet> createState() => _PropertyFormSheetState();
}

class _PropertyFormSheetState extends State<PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _propertyNameController = TextEditingController(
    text: widget.property?.propertyName ?? '',
  );
  late final _summaryController = TextEditingController(
    text: widget.property?.summary ?? '',
  );
  late final _contactController = TextEditingController(
    text: widget.property?.whatsapp ?? '',
  );
  final _mapsLinkController = TextEditingController();

  late Set<String> _categoryIds = {...?widget.property?.categoryIds};
  late Set<String> _productIds = {...?widget.property?.productIds};
  late Set<String> _productionSystemIds = {
    ...?widget.property?.productionSystem,
  };
  late Set<String> _salesChannels = {...?widget.property?.salesChannels};

  /// Donos vinculados ANTES de abrir o form — usado só pra calcular o
  /// diff (quem entrou / quem saiu) no submit. Vem de ownerIds (fonte
  /// de verdade no Firestore), não de currentProducers, pra não
  /// depender de um doc de usuário existir. Irrelevante quando
  /// readOnlyProducers é true (diff nunca é calculado nesse caso).
  late final Set<String> _previousProducerIds = {...?widget.property?.ownerIds};

  /// Seleção atual no ProducerPickerField — pode ficar vazia
  /// (propriedade sem dono é um estado válido).
  late Set<String> _selectedProducerIds = {..._previousProducerIds};

  late GeoPoint? _location = widget.property?.location;
  bool _resolvingLocation = false;
  String? _locationError;

  bool _saving = false;

  bool get _isEditing => widget.property != null;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _summaryController.dispose();
    _contactController.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  List<ProductModel> get _availableProducts {
    if (_categoryIds.isEmpty) return widget.products;
    return widget.products
        .where((p) => _categoryIds.contains(p.categoryId))
        .toList();
  }

  Future<void> _resolveLocation() async {
    final link = _mapsLinkController.text.trim();
    if (link.isEmpty) {
      setState(() => _locationError = 'Cole um link do Google Maps');
      return;
    }

    setState(() {
      _resolvingLocation = true;
      _locationError = null;
    });

    final result = await GoogleMapsLinkParser.parse(link);

    if (!mounted) return;
    setState(() {
      _resolvingLocation = false;
      if (result != null) {
        _location = result;
        _locationError = null;
      } else {
        _locationError =
            'Não consegui extrair a localização desse link. '
            'Cole o link completo (não encurtado) ou as coordenadas direto '
            'do app do Google Maps.';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_location == null) {
      setState(() => _locationError ??= 'Defina a localização da propriedade');
      return;
    }

    setState(() => _saving = true);

    final result = PropertyModel(
      id: widget.property?.id ?? '',
      propertyName: _propertyNameController.text.trim(),
      // ownerIds/ownerNames não são editados por aqui — quem manda
      // nisso é o link/unlink via ProducerService, chamado depois do
      // save (só quando readOnlyProducers é false). Mantemos o valor
      // atual pra não zerar o array no Firestore.
      ownerIds: widget.property?.ownerIds ?? const [],
      ownerNames: widget.property?.ownerNames ?? const [],
      categoryIds: _categoryIds.toList(),
      productIds: _productIds.toList(),
      summary: _summaryController.text.trim(),
      productionSystem: _productionSystemIds.toList(),
      salesChannels: _salesChannels.toList(),
      // Campo removido do form — mantém o valor que já existia na
      // propriedade (evita zerar salesNotes no Firestore ao salvar).
      salesNotes: widget.property?.salesNotes ?? '',
      whatsapp: _contactController.text.trim(),
      location: _location,
      images: widget.property?.images ?? const [],
      createdAt: widget.property?.createdAt,
    );

    String savedId;
    try {
      savedId = await widget.onSave(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
        setState(() => _saving = false);
      }
      return;
    }

    // Produtor editando a própria propriedade não mexe em vínculo:
    // não há diff pra calcular nem link/unlink pra disparar.
    if (widget.readOnlyProducers) {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
      return;
    }

    // Diff entre quem estava vinculado antes e a seleção atual — só
    // dispara link/unlink pra quem realmente mudou.
    final toAdd = _selectedProducerIds.difference(_previousProducerIds);
    final toRemove = _previousProducerIds.difference(_selectedProducerIds);
    final linkErrors = <String>[];

    for (final uid in toAdd) {
      try {
        await widget.producerService.linkProducerToProperty(
          producerUid: uid,
          propertyId: savedId,
        );
      } catch (e) {
        // ProducerService já lança Exception com mensagem amigável.
        linkErrors.add(e.toString().replaceFirst('Exception: ', ''));
      }
    }

    for (final uid in toRemove) {
      try {
        await widget.producerService.unlinkProducerFromProperty(
          producerUid: uid,
          propertyId: savedId,
        );
      } catch (e) {
        linkErrors.add(e.toString().replaceFirst('Exception: ', ''));
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      if (linkErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Propriedade salva, mas houve erro ao atualizar produtores: '
              '${linkErrors.join('; ')}',
            ),
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing
                          ? 'Editar propriedade'
                          : 'Cadastrar propriedade',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _propertyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da propriedade *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Resumo',
                    hintText:
                        'Breve descrição da propriedade e do que ela produz',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                Text(
                  'Produtor(es)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                if (widget.readOnlyProducers)
                  _ReadOnlyProducersView(
                    names: widget.property?.ownerNames ?? const [],
                  )
                else
                  StreamBuilder<List<AppUserModel>>(
                    stream: widget.availableProducers,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'Erro ao carregar produtores disponíveis.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }

                      // Produtores já vinculados a esta propriedade não
                      // aparecem no stream (já têm propertyId) — injeta
                      // eles na lista de opções pra continuarem
                      // visíveis/selecionáveis (e removíveis) ao editar.
                      final producers = List<AppUserModel>.from(
                        snapshot.data ?? const [],
                      );
                      for (final p in widget.currentProducers) {
                        if (!producers.any(
                          (existing) => existing.uid == p.uid,
                        )) {
                          producers.add(p);
                        }
                      }

                      return ProducerPickerField(
                        allProducers: producers,
                        selectedIds: _selectedProducerIds,
                        onChanged: (ids) =>
                            setState(() => _selectedProducerIds = ids),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                Text(
                  'Localização',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mapsLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Link do Google Maps',
                    hintText: 'Cole aqui o link compartilhado do Maps',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resolvingLocation ? null : _resolveLocation,
                    icon: _resolvingLocation
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_searching),
                    label: Text(
                      _resolvingLocation ? 'Buscando...' : 'Buscar localização',
                    ),
                  ),
                ),
                if (_location != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Localização definida: '
                          '${_location!.latitude.toStringAsFixed(6)}, '
                          '${_location!.longitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_locationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                Text(
                  'Categorias',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categories.map((c) {
                    final selected = _categoryIds.contains(c.id);
                    return FilterChip(
                      label: Text(c.name),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF2E7D32),
                      backgroundColor: const Color(0xFFE8F5E9),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _categoryIds.add(c.id);
                        } else {
                          _categoryIds.remove(c.id);
                          _productIds.removeWhere((pid) {
                            final match = widget.products.where(
                              (p) => p.id == pid,
                            );
                            return match.isNotEmpty &&
                                match.first.categoryId == c.id;
                          });
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                Text('Produtos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (_categoryIds.isEmpty)
                  Text(
                    'Selecione uma categoria para ver os produtos disponíveis.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableProducts.map((p) {
                      final selected = _productIds.contains(p.id);
                      return FilterChip(
                        label: Text(p.name),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF2E7D32),
                        backgroundColor: const Color(0xFFE8F5E9),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _productIds.add(p.id);
                          } else {
                            _productIds.remove(p.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),

                Text(
                  'Sistema de produção',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.productionSystems.map((s) {
                    final selected = _productionSystemIds.contains(s.id);
                    return FilterChip(
                      label: Text(s.name),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF2E7D32),
                      backgroundColor: const Color(0xFFE8F5E9),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _productionSystemIds.add(s.id);
                        } else {
                          _productionSystemIds.remove(s.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                Text(
                  'Canais de venda',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonSalesChannels.map((ch) {
                    final selected = _salesChannels.contains(ch);
                    return FilterChip(
                      label: Text(ch),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF2E7D32),
                      backgroundColor: const Color(0xFFE8F5E9),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _salesChannels.add(ch);
                        } else {
                          _salesChannels.remove(ch);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                Text('Contato', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Contato'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Salvar alterações' : 'Cadastrar'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Visão só-leitura dos produtores vinculados, usada quando o próprio
/// produtor está editando a propriedade (readOnlyProducers = true).
/// Mostra os nomes já denormalizados em property.ownerNames — sem
/// StreamBuilder, sem seleção, sem remoção.
class _ReadOnlyProducersView extends StatelessWidget {
  const _ReadOnlyProducersView({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return Text(
        'Nenhum produtor vinculado.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: names.map((name) {
        return Chip(
          avatar: const Icon(Icons.person, size: 16, color: Color(0xFF2E7D32)),
          label: Text(name),
          backgroundColor: const Color(0xFFE8F5E9),
          labelStyle: const TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }
}
