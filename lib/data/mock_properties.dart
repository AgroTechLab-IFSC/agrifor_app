/// Dados mockados de propriedades, únicos e compartilhados entre a tela
/// de busca (SearchScreen) e o mapa (PropertyMapView) — assim os dois
/// sempre mostram exatamente as mesmas propriedades.
///
/// As coordenadas (lat/lng) abaixo vieram da conversão das localizações
/// em graus/minutos/segundos (DMS) informadas nos formulários dos
/// produtores para decimal — conferir com o produtor se precisar de mais
/// precisão futuramente.
///
/// `productTypes`: string com as categorias separadas por vírgula,
/// usando os mesmos rótulos de `allProductCategories` (ex.:
/// "Frutas,Pecuária de Corte,Agroindústria"). Usado tanto pro card de
/// detalhes quanto pros filtros do mapa.
///
/// TODO: substituir por dados vindos do backend quando a estrutura do
/// banco de dados estiver definida (o formato de Map<String, String>
/// pode virar um model próprio nessa hora, se fizer sentido).
const List<Map<String, String>> mockProperties = [
  {
    'propertyName': 'Sítio Alisson Correa',
    'ownerName': 'ALISSON EDIMAR CORREA DE JESUS',
    'city': 'Lages, SC',
    'productTypes': 'Frutas,Pecuária de Corte,Agroindústria',
    'products':
        'Uva, Maçã, Goiaba, Banana, Geleias, Doces, Compotas, Gado de Corte',
    'summary':
        'Produtor integrante da Agrilages, atuando na fruticultura, '
        'pecuária de corte e agroindústria artesanal. Comercializa sua '
        'produção por diversos canais, incluindo venda direta ao consumidor '
        'e programas governamentais.',
    'productionSystem': 'Convencional',
    'association': 'Agrilages',
    'salesChannels':
        'Atravessadores, Programas Governamentais, Venda Direta ao Consumidor, '
        'Venda para Agroindústria, Colha e Pague, CEASA (R\$ 80 o espaço, '
        'paga o pessoal dos carrinhos, certificado de origem)',
    'whatsapp': '',
    'email': '',
    // Convertido de 27°45'24.3"S 50°07'12.8"W
    'lat': '-27.75675',
    'lng': '-50.120222',
  },
  {
    'propertyName': 'Sítio Fabiano Sanguanini',
    'ownerName': 'FABIANO SANGUANINI',
    'city': 'Lages, SC',
    'productTypes': 'Hortaliças,Grãos',
    'products': 'Alface, Cebola, Batata, Abóbora, Tomate, Milho Verde',
    'summary':
        'Produtor certificado orgânico com foco em horticultura e produção '
        'de milho verde. Participa de associação, cooperativa ou feira e '
        'comercializa por meio de atravessadores e programas '
        'governamentais.',
    'productionSystem': 'Orgânico Certificado',
    // TODO: produtor confirmou que participa de associação/cooperativa/
    // feira, mas não informou o nome — preencher assim que tiver.
    'association': '',
    'salesChannels': 'Atravessadores, Programas Governamentais',
    'whatsapp': '',
    'email': '',
    // Convertido de 27°47'49.3"S 50°16'02.3"W
    'lat': '-27.797028',
    'lng': '-50.267306',
  },
  {
    'propertyName': 'Sítio Lucimara Xavier',
    'ownerName': 'LUCIMARA XAVIER PATEL',
    'city': 'Lages, SC',
    'productTypes': 'Hortaliças,Frutas,Grãos,Pecuária de Corte',
    'products':
        'Alface, Cebola, Batata, Abóbora, Tomate, Uva, Maçã, Goiaba, '
        'Banana, Grãos, Gado de Corte',
    'summary':
        'Propriedade diversificada com horticultura, fruticultura, grãos e '
        'pecuária de corte, combinando sistema convencional e orgânico '
        'certificado. Comercializa em feiras, mercados, programas '
        'governamentais e diretamente ao consumidor.',
    'productionSystem': 'Convencional, Orgânico Certificado',
    // TODO: produtora confirmou que participa de associação/cooperativa/
    // feira, mas não informou o nome — preencher assim que tiver.
    'association': '',
    'salesChannels':
        'Mercados, Supermercados e Restaurantes, Feiras, '
        'Programas Governamentais, Venda Direta ao Consumidor, '
        'Colha e Pague',
    'whatsapp': '',
    'email': '',
    // Convertido de 27°44'28.9"S 50°05'53.5"W
    'lat': '-27.741361',
    'lng': '-50.098194',
  },
];

/// Todas as categorias de produção disponíveis pros filtros do mapa.
/// Mantida separada dos dados de cada propriedade pra sempre exibir
/// a lista completa de filtros, mesmo que uma categoria momentaneamente
/// não tenha nenhum produtor ativo.
const List<String> allProductCategories = [
  'Hortaliças',
  'Frutas',
  'Grãos',
  'Pecuária de Corte',
  'Pecuária Leiteira',
  'Agroindústria',
];

/// Extrai a lista de categorias de uma propriedade a partir do campo
/// `productTypes` (string separada por vírgula).
List<String> propertyProductTypes(Map<String, String> property) {
  final raw = property['productTypes'] ?? '';
  if (raw.isEmpty) return const [];
  return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}