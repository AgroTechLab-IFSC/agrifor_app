/// Resolve uma lista de ids pra nomes de exibição, buscando cada id numa
/// lista de itens já carregada em memória, com fallback pra id que não
/// existe mais (registro removido).
///
/// Centraliza a lógica que se repetia entre PropertyDetailResolver
/// (busca fresca, sem cache) e AdminPropertiesController (lista síncrona
/// já em memória via stream) — o algoritmo de mapeamento é idêntico nos
/// dois casos, só muda de onde vem `items`.
List<String> namesFor<T>(
  List<String> ids,
  List<T> items, {
  required String Function(T) idOf,
  required String Function(T) nameOf,
  required String fallback,
}) {
  return ids.map((id) {
    final match = items.where((item) => idOf(item) == id);
    return match.isEmpty ? fallback : nameOf(match.first);
  }).toList();
}