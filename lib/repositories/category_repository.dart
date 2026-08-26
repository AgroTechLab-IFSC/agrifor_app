import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/category_model.dart';

class CategoryRepository {
  CategoryRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('categories');

  Stream<List<CategoryModel>> watchAll({bool onlyActive = true}) {
    // Sem orderBy no Firestore: orderBy + where em campos diferentes
    // exige índice composto. Coleção pequena e fixa — ordenar no
    // client evita essa dependência.
    Query<Map<String, dynamic>> query = _col;
    if (onlyActive) query = query.where('active', isEqualTo: true);

    return query.snapshots().map((snap) {
      final categories =
          snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList();
      categories.sort((a, b) => a.order.compareTo(b.order));
      return categories;
    });
  }

  Future<CategoryModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return CategoryModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> create(CategoryModel category) {
    return _col.doc(category.id).set(category.toMap());
  }

  Future<void> update(CategoryModel category) {
    return _col.doc(category.id).update(category.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({'active': active});
  }
}