import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/app_user_model.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  Future<AppUserModel?> getById(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return AppUserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<AppUserModel?> watchById(String uid) {
    return _col
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? AppUserModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Chamado pelo próprio app do produtor logo após o cadastro no
  /// Firebase Auth (email/senha ou Google). Grava exatamente os campos
  /// que as Firestore rules exigem para o self-signup: role fixo como
  /// 'producer', propertyId null, name obrigatório, e nada além disso
  /// — qualquer campo extra ou role diferente é rejeitado pelas rules
  /// antes mesmo de chegar aqui.
  ///
  /// `name` vem de origens diferentes dependendo do fluxo de login:
  /// - email/senha: campo "Nome completo" digitado na RegisterScreen
  /// - Google: user.displayName, já vindo pronto da conta Google
  Future<void> createProducerDoc({
    required String uid,
    required String email,
    required String name,
  }) {
    return _col.doc(uid).set({
      'email': email,
      'name': name,
      'role': UserRole.producer.name,
      'propertyId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Produtores com role 'producer' e ainda SEM propriedade vinculada —
  /// é a lista que alimenta o select do modal "vincular produtor".
  /// Exige índice composto (role + propertyId); na primeira execução o
  /// console do Firebase acusa e dá o link pra criar automaticamente.
  Stream<List<AppUserModel>> watchAvailableProducers() {
    return _col
        .where('role', isEqualTo: UserRole.producer.name)
        .where('propertyId', isNull: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUserModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Busca vários usuários de uma vez, pra pré-popular o multi-select de
  /// donos já vinculados na edição (esses uids não aparecem em
  /// watchAvailableProducers porque já têm propertyId preenchido).
  /// Usa getById em paralelo — listas de donos por propriedade tendem a
  /// ser pequenas, não compensa a complexidade de um `whereIn`.
  /// uids inexistentes ou docs deletados são silenciosamente ignorados
  /// no resultado (não lança erro).
  Future<List<AppUserModel>> getByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final results = await Future.wait(uids.map(getById));
    return results.whereType<AppUserModel>().toList();
  }
}
