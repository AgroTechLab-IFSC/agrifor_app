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

  /// Id gerado pelo Firestore (doc.add) — o CategoryModel passado aqui
  /// deve vir com id: '' (placeholder), já que toMap() não serializa
  /// id mesmo. Quem chama precisa do retorno pra saber o id real
  /// criado (ex: pra permitir editar/apagar em seguida na mesma sessão).
  Future<String> create(CategoryModel category) async {
    final ref = await _col.add(category.toMap());
    return ref.id;
  }

  Future<void> update(CategoryModel category) {
    return _col.doc(category.id).update(category.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({'active': active});
  }

  /// Exclusão definitiva. Produtos da categoria não são apagados aqui
  /// — cascata é responsabilidade do controller, que precisa ler a
  /// lista de produtos antes de decidir o que apagar.
  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}