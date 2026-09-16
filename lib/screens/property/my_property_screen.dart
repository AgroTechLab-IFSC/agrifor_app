import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrifor_app/models/property_model.dart';
import 'package:agrifor_app/models/property_detail_view_data.dart';
import 'package:agrifor_app/repositories/property_repository.dart';
import 'package:agrifor_app/repositories/category_repository.dart';
import 'package:agrifor_app/repositories/product_repository.dart';
import 'package:agrifor_app/repositories/production_system_repository.dart';
import 'package:agrifor_app/repositories/property_detail_resolver.dart';
import 'package:agrifor_app/repositories/user_repository.dart';
import 'package:agrifor_app/services/producer_service.dart';
import 'package:agrifor_app/services/property_image_service.dart';
import 'package:agrifor_app/screens/property/property_detail_screen.dart';
import 'package:agrifor_app/screens/admin/widgets/property_form_sheet.dart';

/// Aba "Minha Propriedade" do produtor.
///
/// Não tem UI própria — busca a propriedade vinculada ao produtor
/// logado, resolve os dados (ids -> nomes) e renderiza o mesmo
/// PropertyDetailScreen usado pelo mapa e pelo admin, embutido sem
/// back button.
///
/// O FAB de editar abre o mesmo PropertyFormSheet do admin, só que
/// travado para o produtor não alterar vínculos de outros produtores.
class MyPropertyScreen extends StatefulWidget {
  const MyPropertyScreen({
    super.key,
    this.propertyRepository,
    this.categoryRepository,
    this.productRepository,
    this.productionSystemRepository,
    this.userRepository,
    this.producerService,
    this.propertyImageService,
  });

  final PropertyRepository? propertyRepository;
  final CategoryRepository? categoryRepository;
  final ProductRepository? productRepository;
  final ProductionSystemRepository?
      productionSystemRepository;
  final UserRepository? userRepository;
  final ProducerService? producerService;
  final PropertyImageService? propertyImageService;

  @override
  State<MyPropertyScreen> createState() =>
      _MyPropertyScreenState();
}

class _MyPropertyScreenState
    extends State<MyPropertyScreen> {
  late final _propertyRepository =
      widget.propertyRepository ??
          PropertyRepository(
            FirebaseFirestore.instance,
          );

  late final _categoryRepository =
      widget.categoryRepository ??
          CategoryRepository(
            FirebaseFirestore.instance,
          );

  late final _productRepository =
      widget.productRepository ??
          ProductRepository(
            FirebaseFirestore.instance,
          );

  late final _productionSystemRepository =
      widget.productionSystemRepository ??
          ProductionSystemRepository(
            FirebaseFirestore.instance,
          );

  late final _userRepository =
      widget.userRepository ??
          UserRepository(
            FirebaseFirestore.instance,
          );

  late final _producerService =
      widget.producerService ??
          ProducerService(
            FirebaseFirestore.instance,
          );

  late final _propertyImageService =
      widget.propertyImageService ??
          PropertyImageService();

  late final _detailResolver =
      PropertyDetailResolver(
    categoryRepository: _categoryRepository,
    productRepository: _productRepository,
    productionSystemRepository:
        _productionSystemRepository,
  );

  bool _creating = false;

  String? get _uid =>
      FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return const Center(
        child: Text(
          'Faça login para ver sua propriedade.',
        ),
      );
    }

    return StreamBuilder<PropertyModel?>(
      stream: _propertyRepository.watchByOwner(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar sua propriedade.',
            ),
          );
        }

        final property = snapshot.data;

        if (property == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.agriculture_outlined,
                    size: 48,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Você ainda não está vinculado a nenhuma propriedade.\n'
                    'Cadastre a sua ou fale com um administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _creating
                        ? null
                        : () => _openCreateSheet(
                              context,
                              uid,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF2E7D32),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Cadastrar minha propriedade',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<
            PropertyDetailViewData>(
          key: ValueKey(property.id),
          future:
              _detailResolver.resolve(property),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text(
                  'Erro ao carregar os detalhes.',
                ),
              );
            }

            if (!snap.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final data = snap.data!;

            return PropertyDetailScreen(
              data: data,

              // É uma aba do shell, então não tem botão
              // de voltar próprio.
              showBackButton: false,

              // Ao rolar, o header desaparece totalmente.
              // Não deixa a barra verde abaixo da navbar.
              showCollapsedHeader: false,

              onEdit: () =>
                  _openEditSheet(context, data),

              onResubmit:
                  data.property.isRejected
                      ? () => _resubmit(
                            context,
                            data.property,
                          )
                      : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateSheet(
    BuildContext context,
    String uid,
  ) async {
    setState(() => _creating = true);

    final categories =
        await _categoryRepository
            .watchAll(onlyActive: true)
            .first;

    final products =
        await _productRepository
            .watchAll(onlyActive: true)
            .first;

    final productionSystems =
        await _productionSystemRepository
            .watchAll()
            .first;

    final appUser =
        await _userRepository.getById(uid);

    if (!mounted) return;

    setState(() => _creating = false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => PropertyFormSheet(
        categories: categories,
        products: products,
        productionSystems:
            productionSystems,

        // O produtor não escolhe outros donos.
        availableProducers:
            const Stream.empty(),

        producerService:
            _producerService,

        imageService:
            _propertyImageService,

        readOnlyProducers: true,

        selfOwnerName:
            appUser?.name,

        onSave: (p) =>
            _producerService
                .createPropertyForProducer(
          producerUid: uid,
          property: p,
        ),
      ),
    );
  }

  /// Devolve uma propriedade rejeitada para pending.
  Future<void> _resubmit(
    BuildContext context,
    PropertyModel property,
  ) async {
    final messenger =
        ScaffoldMessenger.of(context);

    try {
      await _propertyRepository
          .setPending(property.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao submeter novamente: $e',
          ),
        ),
      );
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    PropertyDetailViewData data,
  ) async {
    final categories =
        await _categoryRepository
            .watchAll(onlyActive: false)
            .first;

    final products =
        await _productRepository
            .watchAll(onlyActive: false)
            .first;

    final productionSystems =
        await _productionSystemRepository
            .watchAll()
            .first;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => PropertyFormSheet(
        property: data.property,
        categories: categories,
        products: products,
        productionSystems:
            productionSystems,

        availableProducers:
            const Stream.empty(),

        producerService:
            _producerService,

        imageService:
            _propertyImageService,

        readOnlyProducers: true,

        onSave: (updated) async {
          await _propertyRepository
              .updateOwnEditableFields(
            updated,
          );

          return updated.id;
        },
      ),
    );
  }
}