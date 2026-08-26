import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/production_system_model.dart';

/// Só leitura de propósito. productionSystems é uma tabela fixa,
/// cadastrada via seed/console — não existe (nem deve existir) tela de
/// admin pra criar/editar/desativar sistema de produção. Se isso mudar
/// no futuro, adicionar create/update aqui seguindo o padrão de
/// CategoryRepository, não antes.
class ProductionSystemRepository {
  ProductionSystemRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('productionSystems');

  Stream<List<ProductionSystemModel>> watchAll() {
    return _col.orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((d) => ProductionSystemModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Útil pra resolver id -> nome em telas de exibição (card, detalhe,
  /// Painel) sem precisar re-percorrer o stream toda vez.
  Future<Map<String, String>> getIdToNameMap() async {
    final snap = await _col.get();
    return {
      for (final d in snap.docs) d.id: (d.data()['name'] as String),
    };
  }
}