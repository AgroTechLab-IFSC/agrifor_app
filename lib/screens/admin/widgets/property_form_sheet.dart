import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/category_model.dart';
import 'package:agrifor_app/models/product_model.dart';
import 'package:agrifor_app/models/production_system_model.dart';
import 'package:agrifor_app/models/app_user_model.dart';
import 'package:agrifor_app/services/producer_service.dart';
import 'package:agrifor_app/services/property_image_service.dart';
import 'package:agrifor_app/screens/admin/widgets/producer_picker_field.dart';
import 'package:agrifor_app/screens/admin/widgets/property_images_field.dart';
import 'package:agrifor_app/screens/admin/widgets/property_location_field.dart';

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
    this.imageService,
    this.readOnlyProducers = false,
    this.selfOwnerName,
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

  /// Upload/remoção das fotos no Firebase Storage.
  final PropertyImageService? imageService;

  /// true quando quem está editando é o próprio produtor.
  final bool readOnlyProducers;

  /// Nome a mostrar na seção "Produtor(es)" quando o próprio produtor
  /// ainda está cadastrando sua primeira propriedade.
  final String? selfOwnerName;

  /// Deve retornar o id da propriedade salva.
  final Future<String> Function(
    PropertyModel property,
  ) onSave;

  @override
  State<PropertyFormSheet> createState() =>
      _PropertyFormSheetState();
}

class _PropertyFormSheetState
    extends State<PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _imageService =
      widget.imageService ??
      PropertyImageService();

  late final _propertyNameController =
      TextEditingController(
    text:
        widget.property?.propertyName ??
        '',
  );

  late final _summaryController =
      TextEditingController(
    text: widget.property?.summary ?? '',
  );

  late final _contactController =
      TextEditingController(
    text:
        widget.property?.whatsapp ?? '',
  );

  late final _phoneController =
      TextEditingController(
    text: widget.property?.phone ?? '',
  );

  late final _instagramController =
      TextEditingController(
    text:
        widget.property?.instagram ?? '',
  );

  late final String _imagesFolderId =
      widget.property?.id.isNotEmpty ==
              true
          ? widget.property!.id
          : 'new_${DateTime.now().microsecondsSinceEpoch}';

  late List<PropertyImageItem>
      _imageItems = [
    for (final url
        in widget.property?.images ??
            const [])
      PropertyImageItem.existing(url),
  ];

  final List<String>
      _removedImageUrls = [];

  bool _uploadingImages = false;

  late Set<String> _categoryIds = {
    ...?widget.property?.categoryIds,
  };

  late Set<String> _productIds = {
    ...?widget.property?.productIds,
  };

  late Set<String>
      _productionSystemIds = {
    ...?widget
        .property
        ?.productionSystem,
  };

  late Set<String> _salesChannels = {
    ...?widget.property?.salesChannels,
  };

  late final Set<String>
      _previousProducerIds = {
    ...?widget.property?.ownerIds,
  };

  late Set<String>
      _selectedProducerIds = {
    ..._previousProducerIds,
  };

  late GeoPoint? _location =
      widget.property?.location;

  String? _locationError;

  bool _saving = false;

  bool get _isEditing =>
      widget.property != null;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _summaryController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();

    super.dispose();
  }

  List<ProductModel>
      get _availableProducts {
    if (_categoryIds.isEmpty) {
      return widget.products;
    }

    return widget.products
        .where(
          (p) =>
              _categoryIds.contains(
            p.categoryId,
          ),
        )
        .toList();
  }

  Future<void> _pickImages() async {
    final picked =
        await _imageService.pickImages();

    if (picked.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _imageItems = [
        ..._imageItems,
        for (final file in picked)
          PropertyImageItem.pending(
            file,
          ),
      ];
    });
  }

  void _onImagesChanged(
    List<PropertyImageItem> next,
  ) {
    final nextUrls = next
        .map((i) => i.url)
        .whereType<String>()
        .toSet();

    for (final item in _imageItems) {
      if (item.url != null &&
          !nextUrls.contains(
            item.url,
          )) {
        _removedImageUrls.add(
          item.url!,
        );
      }
    }

    setState(() {
      _imageItems = next;
    });
  }

  Future<List<String>>
      _uploadPendingImages() async {
    final urls = <String>[];

    for (final item in _imageItems) {
      if (item.isPending) {
        urls.add(
          await _imageService.upload(
            folderId:
                _imagesFolderId,
            file: item.file!,
          ),
        );
      } else {
        urls.add(item.url!);
      }
    }

    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_location == null) {
      setState(() {
        _locationError ??=
            'Defina a localização da propriedade';
      });

      return;
    }

    setState(() {
      _saving = true;
      _uploadingImages = true;
    });

    List<String> imageUrls;

    try {
      imageUrls =
          await _uploadPendingImages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao enviar as fotos: $e',
            ),
          ),
        );

        setState(() {
          _saving = false;
          _uploadingImages = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _uploadingImages = false;
      });
    }

    final result = PropertyModel(
      id: widget.property?.id ?? '',
      propertyName:
          _propertyNameController.text
              .trim(),
      ownerIds:
          widget.property?.ownerIds ??
          const [],
      ownerNames:
          widget.property?.ownerNames ??
          const [],
      categoryIds:
          _categoryIds.toList(),
      productIds:
          _productIds.toList(),
      summary:
          _summaryController.text
              .trim(),
      productionSystem:
          _productionSystemIds
              .toList(),
      salesChannels:
          _salesChannels.toList(),
      salesNotes:
          widget
              .property
              ?.salesNotes ??
          '',
      whatsapp:
          _contactController.text
              .trim(),
      phone:
          _phoneController.text.trim(),
      instagram:
          _instagramController.text
              .trim(),
      location: _location,
      images: imageUrls,
      status:
          widget.property?.status ??
          PropertyStatus.approved,
      createdAt:
          widget.property?.createdAt,
    );

    String savedId;

    try {
      savedId =
          await widget.onSave(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao salvar: $e',
            ),
          ),
        );

        setState(() {
          _saving = false;
        });
      }

      return;
    }

    if (_removedImageUrls
        .isNotEmpty) {
      unawaited(
        _imageService.deleteAll(
          _removedImageUrls,
        ),
      );
    }

    if (widget.readOnlyProducers) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        Navigator.pop(context);
      }

      return;
    }

    final toAdd =
        _selectedProducerIds
            .difference(
      _previousProducerIds,
    );

    final toRemove =
        _previousProducerIds
            .difference(
      _selectedProducerIds,
    );

    final linkErrors = <String>[];

    for (final uid in toAdd) {
      try {
        await widget.producerService
            .linkProducerToProperty(
          producerUid: uid,
          propertyId: savedId,
        );
      } catch (e) {
        linkErrors.add(
          e
              .toString()
              .replaceFirst(
                'Exception: ',
                '',
              ),
        );
      }
    }

    for (final uid in toRemove) {
      try {
        await widget.producerService
            .unlinkProducerFromProperty(
          producerUid: uid,
          propertyId: savedId,
        );
      } catch (e) {
        linkErrors.add(
          e
              .toString()
              .replaceFirst(
                'Exception: ',
                '',
              ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _saving = false;
      });

      if (linkErrors.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
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
    final viewInsets =
        MediaQuery.of(context)
            .viewInsets;

    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom,
      ),
      child:
          DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (
          context,
          scrollController,
        ) {
          return Form(
            key: _formKey,
            child: ListView(
              controller:
                  scrollController,
              padding:
                  const EdgeInsets.all(
                20,
              ),
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Text(
                      _isEditing
                          ? 'Editar propriedade'
                          : 'Cadastrar propriedade',
                      style:
                          Theme.of(
                            context,
                          )
                              .textTheme
                              .titleLarge,
                    ),
                    IconButton(
                      icon:
                          const Icon(
                        Icons.close,
                      ),
                      onPressed: () =>
                          Navigator.pop(
                        context,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _propertyNameController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Nome da propriedade *',
                  ),
                  validator: (v) =>
                      (v == null ||
                              v
                                  .trim()
                                  .isEmpty)
                          ? 'Obrigatório'
                          : null,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Imagens',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 8,
                ),

                PropertyImagesField(
                  items: _imageItems,
                  onChanged:
                      _onImagesChanged,
                  onAddPressed:
                      _pickImages,
                  uploading:
                      _uploadingImages,
                ),

                const SizedBox(
                  height: 20,
                ),

                TextFormField(
                  controller:
                      _summaryController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Resumo',
                    hintText:
                        'Breve descrição da propriedade e do que ela produz',
                    alignLabelWithHint:
                        true,
                  ),
                  maxLines: 3,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Produtor(es)',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 4,
                ),

                if (widget
                    .readOnlyProducers)
                  _ReadOnlyProducersView(
                    names:
                        widget.property !=
                                null
                            ? widget
                                .property!
                                .ownerNames
                            : [
                                if (widget
                                        .selfOwnerName !=
                                    null)
                                  widget
                                      .selfOwnerName!,
                              ],
                  )
                else
                  StreamBuilder<
                      List<AppUserModel>>(
                    stream: widget
                        .availableProducers,
                    builder: (
                      context,
                      snapshot,
                    ) {
                      if (snapshot
                              .connectionState ==
                          ConnectionState
                              .waiting) {
                        return const Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            vertical: 12,
                          ),
                          child: Center(
                            child:
                                SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            ),
                          ),
                        );
                      }

                      if (snapshot
                          .hasError) {
                        return Text(
                          'Erro ao carregar produtores disponíveis.',
                          style:
                              TextStyle(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .error,
                          ),
                        );
                      }

                      final producers =
                          List<
                              AppUserModel>.from(
                        snapshot.data ??
                            const [],
                      );

                      for (final p
                          in widget
                              .currentProducers) {
                        if (!producers.any(
                          (existing) =>
                              existing
                                  .uid ==
                              p.uid,
                        )) {
                          producers.add(
                            p,
                          );
                        }
                      }

                      return ProducerPickerField(
                        allProducers:
                            producers,
                        selectedIds:
                            _selectedProducerIds,
                        onChanged:
                            (ids) =>
                                setState(
                          () =>
                              _selectedProducerIds =
                                  ids,
                        ),
                      );
                    },
                  ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Localização',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 8,
                ),

                PropertyLocationField(
                  value: _location,
                  errorText:
                      _locationError,
                  onChanged:
                      (location) =>
                          setState(
                    () {
                      _location =
                          location;

                      _locationError =
                          null;
                    },
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Categorias',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 8,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget
                      .categories
                      .map(
                    (c) {
                      final selected =
                          _categoryIds
                              .contains(
                        c.id,
                      );

                      return FilterChip(
                        label:
                            Text(
                          c.name,
                        ),
                        selected:
                            selected,
                        showCheckmark:
                            false,
                        selectedColor:
                            const Color(
                          0xFF2E7D32,
                        ),
                        backgroundColor:
                            const Color(
                          0xFFE8F5E9,
                        ),
                        labelStyle:
                            TextStyle(
                          color: selected
                              ? Colors
                                  .white
                              : const Color(
                                  0xFF2E7D32,
                                ),
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                        onSelected:
                            (v) =>
                                setState(
                          () {
                            if (v) {
                              _categoryIds
                                  .add(
                                c.id,
                              );
                            } else {
                              _categoryIds
                                  .remove(
                                c.id,
                              );

                              _productIds
                                  .removeWhere(
                                (pid) {
                                  final match = widget
                                      .products
                                      .where(
                                    (p) =>
                                        p.id ==
                                        pid,
                                  );

                                  return match
                                          .isNotEmpty &&
                                      match
                                              .first
                                              .categoryId ==
                                          c.id;
                                },
                              );
                            }
                          },
                        ),
                      );
                    },
                  ).toList(),
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Produtos',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 4,
                ),

                if (_categoryIds
                    .isEmpty)
                  Text(
                    'Selecione uma categoria para ver os produtos disponíveis.',
                    style:
                        Theme.of(
                          context,
                        )
                            .textTheme
                            .bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _availableProducts
                            .map(
                      (p) {
                        final selected =
                            _productIds
                                .contains(
                          p.id,
                        );

                        return FilterChip(
                          label:
                              Text(
                            p.name,
                          ),
                          selected:
                              selected,
                          showCheckmark:
                              false,
                          selectedColor:
                              const Color(
                            0xFF2E7D32,
                          ),
                          backgroundColor:
                              const Color(
                            0xFFE8F5E9,
                          ),
                          labelStyle:
                              TextStyle(
                            color: selected
                                ? Colors
                                    .white
                                : const Color(
                                    0xFF2E7D32,
                                  ),
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                          onSelected:
                              (v) =>
                                  setState(
                            () {
                              if (v) {
                                _productIds
                                    .add(
                                  p.id,
                                );
                              } else {
                                _productIds
                                    .remove(
                                  p.id,
                                );
                              }
                            },
                          ),
                        );
                      },
                    ).toList(),
                  ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Sistema de produção',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 4,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget
                      .productionSystems
                      .map(
                    (s) {
                      final selected =
                          _productionSystemIds
                              .contains(
                        s.id,
                      );

                      return FilterChip(
                        label:
                            Text(
                          s.name,
                        ),
                        selected:
                            selected,
                        showCheckmark:
                            false,
                        selectedColor:
                            const Color(
                          0xFF2E7D32,
                        ),
                        backgroundColor:
                            const Color(
                          0xFFE8F5E9,
                        ),
                        labelStyle:
                            TextStyle(
                          color: selected
                              ? Colors
                                  .white
                              : const Color(
                                  0xFF2E7D32,
                                ),
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                        onSelected:
                            (v) =>
                                setState(
                          () {
                            if (v) {
                              _productionSystemIds
                                  .add(
                                s.id,
                              );
                            } else {
                              _productionSystemIds
                                  .remove(
                                s.id,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ).toList(),
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Canais de venda',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 8,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _commonSalesChannels
                          .map(
                    (ch) {
                      final selected =
                          _salesChannels
                              .contains(
                        ch,
                      );

                      return FilterChip(
                        label:
                            Text(ch),
                        selected:
                            selected,
                        showCheckmark:
                            false,
                        selectedColor:
                            const Color(
                          0xFF2E7D32,
                        ),
                        backgroundColor:
                            const Color(
                          0xFFE8F5E9,
                        ),
                        labelStyle:
                            TextStyle(
                          color: selected
                              ? Colors
                                  .white
                              : const Color(
                                  0xFF2E7D32,
                                ),
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                        onSelected:
                            (v) =>
                                setState(
                          () {
                            if (v) {
                              _salesChannels
                                  .add(
                                ch,
                              );
                            } else {
                              _salesChannels
                                  .remove(
                                ch,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ).toList(),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'Contato',
                  style:
                      Theme.of(
                        context,
                      )
                          .textTheme
                          .titleSmall,
                ),

                const SizedBox(
                  height: 4,
                ),

                TextFormField(
                  controller:
                      _contactController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'WhatsApp',
                    hintText:
                        'Número com DDD, ex.: 49999999999',
                  ),
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(
                  height: 12,
                ),

                TextFormField(
                  controller:
                      _phoneController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Telefone',
                    hintText:
                        'Número com DDD, ex.: 4932211122',
                  ),
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(
                  height: 12,
                ),

                TextFormField(
                  controller:
                      _instagramController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Instagram',
                    hintText:
                        '@usuario ou link do perfil',
                  ),
                  keyboardType:
                      TextInputType.url,
                ),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _saving
                            ? null
                            : _submit,
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF2E7D32,
                      ),
                      foregroundColor:
                          Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color: Colors
                                  .white,
                            ),
                          )
                        : Text(
                            _isEditing
                                ? 'Salvar alterações'
                                : 'Cadastrar',
                          ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReadOnlyProducersView
    extends StatelessWidget {
  const _ReadOnlyProducersView({
    required this.names,
  });

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return Text(
        'Nenhum produtor vinculado.',
        style:
            Theme.of(context)
                .textTheme
                .bodySmall,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: names.map(
        (name) {
          return Chip(
            avatar: const Icon(
              Icons.person,
              size: 16,
              color:
                  Color(0xFF2E7D32),
            ),
            label: Text(name),
            backgroundColor:
                const Color(
              0xFFE8F5E9,
            ),
            labelStyle:
                const TextStyle(
              color:
                  Color(0xFF2E7D32),
              fontWeight:
                  FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide.none,
          );
        },
      ).toList(),
    );
  }
}