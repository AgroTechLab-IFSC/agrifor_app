import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/product_model.dart';

class ProductRepository {
  ProductRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  Stream<List<ProductModel>> watchAll({bool onlyActive = true}) {
    Query<Map<String, dynamic>> query = _col;
    if (onlyActive) query = query.where('active', isEqualTo: true);
    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => ProductModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<ProductModel>> watchByCategory(String categoryId) {
    return _col
        .where('categoryId', isEqualTo: categoryId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
  }

  /// Id gerado pelo Firestore (doc.add) — mesma lógica do
  /// CategoryRepository.create (ver comentário lá).
  Future<String> create(ProductModel product) async {
    final ref = await _col.add(product.toMap());
    return ref.id;
  }

  Future<void> update(ProductModel product) {
    return _col.doc(product.id).update(product.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({'active': active});
  }

  /// Exclusão definitiva.
  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}