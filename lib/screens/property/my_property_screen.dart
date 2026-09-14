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
import 'package:agrifor_app/screens/property/property_detail_screen.dart';
import 'package:agrifor_app/screens/admin/widgets/property_form_sheet.dart';

/// Aba "Minha Propriedade" do produtor.
///
/// Não tem UI própria — busca a propriedade vinculada ao produtor
/// logado, resolve os dados (ids -> nomes) e renderiza o mesmo
/// PropertyDetailScreen usado pelo mapa e pelo admin, embutido sem
/// back button (é conteúdo de aba, não uma tela empurrada). O FAB de
/// editar abre o mesmo PropertyFormSheet do admin, só que travado
/// (produtor não muda vínculo de outros produtores, ver
/// readOnlyProducers) e salvando via updateOwnEditableFields em vez de
/// updateFull.
///
/// Quando o produtor ainda não tem propriedade nenhuma, mostra um
/// botão de autocadastro em vez da mensagem "fale com um
/// administrador" — abre o mesmo PropertyFormSheet, mas salvando via
/// ProducerService.createPropertyForProducer, que já cria a
/// propriedade vinculada ao próprio criador e sempre como `pending`
/// (ver comentário lá). Assim que salva, watchByOwner já pega o novo
/// doc e PropertyDetailScreen mostra o aviso de pendência sozinho
/// (baseado em property.isPending), sem precisar de estado extra aqui.
class MyPropertyScreen extends StatefulWidget {
  const MyPropertyScreen({
    super.key,
    this.propertyRepository,
    this.categoryRepository,
    this.productRepository,
    this.productionSystemRepository,
    this.userRepository,
    this.producerService,
  });

  final PropertyRepository? propertyRepository;
  final CategoryRepository? categoryRepository;
  final ProductRepository? productRepository;
  final ProductionSystemRepository? productionSystemRepository;
  final UserRepository? userRepository;
  final ProducerService? producerService;

  @override
  State<MyPropertyScreen> createState() => _MyPropertyScreenState();
}

class _MyPropertyScreenState extends State<MyPropertyScreen> {
  late final _propertyRepository =
      widget.propertyRepository ?? PropertyRepository(FirebaseFirestore.instance);
  late final _categoryRepository =
      widget.categoryRepository ?? CategoryRepository(FirebaseFirestore.instance);
  late final _productRepository =
      widget.productRepository ?? ProductRepository(FirebaseFirestore.instance);
  late final _productionSystemRepository = widget.productionSystemRepository ??
      ProductionSystemRepository(FirebaseFirestore.instance);
  late final _userRepository =
      widget.userRepository ?? UserRepository(FirebaseFirestore.instance);
  late final _producerService =
      widget.producerService ?? ProducerService(FirebaseFirestore.instance);

  late final _detailResolver = PropertyDetailResolver(
    categoryRepository: _categoryRepository,
    productRepository: _productRepository,
    productionSystemRepository: _productionSystemRepository,
  );

  bool _creating = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      // Não deveria acontecer (esta aba só existe pro shell de
      // produtor logado), mas evita null-check em cascata se rolar.
      return const Scaffold(
        body: Center(child: Text('Faça login para ver sua propriedade.')),
      );
    }

    return StreamBuilder<PropertyModel?>(
      stream: _propertyRepository.watchByOwner(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Erro ao carregar sua propriedade.')),
          );
        }

        final property = snapshot.data;
        if (property == null) {
          return Scaffold(
            body: Center(
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
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _creating ? null : () => _openCreateSheet(context, uid),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar minha propriedade'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return FutureBuilder<PropertyDetailViewData>(
          // property.id como key: se o produtor for desvinculado e
          // vinculado a outra propriedade, o FutureBuilder não fica
          // preso mostrando o resultado resolvido da anterior.
          key: ValueKey(property.id),
          future: _detailResolver.resolve(property),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Scaffold(
                body: Center(child: Text('Erro ao carregar os detalhes.')),
              );
            }
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snap.data!;
            return PropertyDetailScreen(
              data: data,
              showBackButton: false,
              onEdit: () => _openEditSheet(context, data),
              onResubmit: data.property.isRejected
                  ? () => _resubmit(context, data.property)
                  : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateSheet(BuildContext context, String uid) async {
    setState(() => _creating = true);

    final categories = await _categoryRepository.watchAll(onlyActive: true).first;
    final products = await _productRepository.watchAll(onlyActive: true).first;
    final productionSystems = await _productionSystemRepository.watchAll().first;
    final appUser = await _userRepository.getById(uid);

    if (!mounted) return;
    setState(() => _creating = false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => PropertyFormSheet(
        categories: categories,
        products: products,
        productionSystems: productionSystems,
        // Mesma razão do _openEditSheet: produtor não escolhe outros
        // donos por aqui, então um stream vazio é suficiente.
        availableProducers: const Stream.empty(),
        producerService: _producerService,
        readOnlyProducers: true,
        selfOwnerName: appUser?.name,
        onSave: (p) => _producerService.createPropertyForProducer(
          producerUid: uid,
          property: p,
        ),
      ),
    );
  }

  /// "Submeter novamente" — devolve uma propriedade `rejected` pro
  /// estado `pending`, fazendo-a voltar pra fila de análise do admin
  /// (ver PropertyRepository.setPending). Não pede confirmação: é uma
  /// ação reversível do ponto de vista do produtor (a propriedade
  /// continua com ele e pode ser rejeitada de novo, se for o caso).
  Future<void> _resubmit(BuildContext context, PropertyModel property) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _propertyRepository.setPending(property.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao submeter novamente: $e')),
      );
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    PropertyDetailViewData data,
  ) async {
    final categories = await _categoryRepository.watchAll(onlyActive: false).first;
    final products = await _productRepository.watchAll(onlyActive: false).first;
    final productionSystems = await _productionSystemRepository.watchAll().first;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => PropertyFormSheet(
        property: data.property,
        categories: categories,
        products: products,
        productionSystems: productionSystems,
        // Produtor não vê/edita a lista de produtores disponíveis —
        // readOnlyProducers esconde o StreamBuilder que consumiria
        // isso, então um stream vazio é suficiente aqui.
        availableProducers: const Stream.empty(),
        producerService: _producerService,
        readOnlyProducers: true,
        onSave: (updated) async {
          await _propertyRepository.updateOwnEditableFields(updated);
          return updated.id;
        },
      ),
    );
  }
}