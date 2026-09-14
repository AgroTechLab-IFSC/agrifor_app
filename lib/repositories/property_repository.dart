import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/property_model.dart';

class PropertyRepository {
  PropertyRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('properties');

  Stream<List<PropertyModel>> watchAll() {
    return _col.snapshots().map((snap) =>
        snap.docs.map((d) => PropertyModel.fromMap(d.id, d.data())).toList());
  }

  /// Só propriedades aprovadas — usado por qualquer tela pública (mapa,
  /// lista pra quem não é admin). Filtra no client, não com um
  /// `.where('status', ...)` no Firestore, pelo mesmo motivo do
  /// filtro de categoria/produto ativo: evita depender de índice
  /// composto e, principalmente, mantém docs antigos sem o campo
  /// `status` visíveis (tratados como aprovados — ver
  /// PropertyModel.fromMap/propertyStatusFromString). Pendente e
  /// rejeitada nunca aparecem aqui, nem pro admin: quem precisa ver
  /// esses status usa watchAll() direto (ver PropertiesScreen).
  Stream<List<PropertyModel>> watchApproved() {
    return watchAll().map((list) => list.where((p) => p.isApproved).toList());
  }

  Stream<PropertyModel?> watchById(String id) {
    return _col.doc(id).snapshots().map(
        (doc) => doc.exists ? PropertyModel.fromMap(doc.id, doc.data()!) : null);
  }

  Future<PropertyModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PropertyModel.fromMap(doc.id, doc.data()!);
  }

  Future<List<PropertyModel>> getByCategory(String categoryId) async {
    final snap =
        await _col.where('categoryIds', arrayContains: categoryId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.id, d.data())).toList();
  }

  /// Propriedade vinculada a um produtor específico — usado pela aba
  /// "Minha Propriedade". Produtor só pode estar vinculado a UMA
  /// propriedade por vez (ver ProducerService.linkProducerToProperty),
  /// então a primeira correspondência já é a única possível.
  Stream<PropertyModel?> watchByOwner(String uid) {
    return _col
        .where('ownerIds', arrayContains: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : PropertyModel.fromMap(snap.docs.first.id, snap.docs.first.data()));
  }

  // admin
  Future<String> create(PropertyModel property) async {
    final ref = await _col.add({
      ...property.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateFull(PropertyModel property) {
    return _col.doc(property.id).update({
      ...property.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Exclusão definitiva. Quem chama isso precisa desvincular todos os
  /// ownerIds ANTES de chamar delete (ver ProducerService.
  /// unlinkProducerFromProperty pra cada uid), senão o(s) produtor(es)
  /// ficam com users/{uid}.propertyId apontando pra um documento que
  /// não existe mais.
  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }

  /// Aprova uma propriedade (`pending` ou `rejected`), tornando-a
  /// pública (visível no mapa e na lista pública). Chamado tanto pra
  /// aprovar um cadastro pendente quanto pra aprovar direto uma
  /// rejeitada, sem esperar o produtor reenviá-la primeiro (ver ícone
  /// "Aprovar" em PropertiesScreen, presente nos dois status). Só o
  /// admin deve poder chamar isso — a tela (PropertiesScreen) já só
  /// mostra o botão "Aprovar" quando `_isAdmin`, e as Firestore rules
  /// precisam reforçar a mesma regra do lado do servidor (ver nota no
  /// ProducerService sobre rules pendentes).
  Future<void> approve(String id) {
    return _col.doc(id).update({
      'status': PropertyStatus.approved.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rejeita uma propriedade pendente. Ao contrário do fluxo antigo
  /// (que apagava o documento e desvinculava o produtor), rejeitar
  /// agora é reversível: a propriedade só muda de status, continua
  /// vinculada ao(s) mesmo(s) produtor(es) e some da listagem/mapa
  /// público (watchApproved só inclui `approved`), mas continua
  /// visível pro dono via watchByOwner e pro admin via watchAll. O
  /// produtor pode revisar e reenviar pra análise (ver setPending).
  /// Só o admin deve poder chamar isso — mesma observação de
  /// [approve] sobre reforçar a regra nas Firestore rules.
  Future<void> reject(String id) {
    return _col.doc(id).update({
      'status': PropertyStatus.rejected.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Volta uma propriedade pro estado `pending`, mandando-a de novo
  /// pra fila de análise do admin. Dois chamadores possíveis, ambos
  /// legítimos:
  ///   - o admin, numa propriedade `approved`, pra tirá-la do ar sem
  ///     precisar excluir (ver "marcar como pendente" em
  ///     PropertiesScreen);
  ///   - o próprio produtor, numa propriedade `rejected` (botão
  ///     "Submeter novamente" em MyPropertyScreen/PropertyDetailScreen),
  ///     depois de revisar o cadastro.
  /// Não valida o status atual antes de gravar — quem decide quando
  /// chamar isso é a UI (só mostra a ação nos status certos).
  Future<void> setPending(String id) {
    return _col.doc(id).update({
      'status': PropertyStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // produtor
  Future<void> updateOwnEditableFields(PropertyModel property) {
    return _col.doc(property.id).update({
      ...property.toEditableMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}