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

  // produtor
  Future<void> updateOwnEditableFields(PropertyModel property) {
    return _col.doc(property.id).update({
      ...property.toEditableMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}