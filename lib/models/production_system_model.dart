/// Representa um registro fixo em `productionSystems/{id}` (ex:
/// "Convencional", "Orgânico Certificado"). Não tem `active` de
/// propósito — essa coleção não tem CRUD pelo app, é cadastrada só via
/// seed/console e não deve sofrer alteração; se um dia precisar
/// desativar um sistema sem apagar (pra não quebrar propriedades já
/// vinculadas a ele), adicionar `active` na hora, não antes.
class ProductionSystemModel {
  const ProductionSystemModel({
    required this.id,
    required this.name,
    required this.order,
  });

  final String id;
  final String name;
  final int order;

  factory ProductionSystemModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductionSystemModel(
      id: id,
      name: map['name'] as String,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'order': order};
}