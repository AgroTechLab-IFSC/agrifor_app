import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'property_map_view.dart' show kLagesTileStore;
import '../../utils/map_bounds.dart';

/// Chame uma única vez no `main()`, antes do `runApp`, para preparar o
/// FMTC (isso só cria/abre o banco local, é rápido e não depende de rede):
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initTileCache();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initTileCache() async {
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore(kLagesTileStore).manage.create();
}

/// Busca todas as propriedades cadastradas no Firestore e retorna as
/// coordenadas (`location`) de quem já tem localização preenchida.
///
/// ATENÇÃO: confira se o nome da coleção ('properties') e do campo
/// ('location') batem com o que seu `PropertyRepository` de fato usa
/// — aqui assumimos o mesmo nome de campo usado em
/// `property.location` (GeoPoint) dentro de `PropertyMapView`. Se seu
/// projeto já tiver um jeito de buscar todas as propriedades (um
/// repositório existente), prefira usá-lo aqui em vez desta query
/// bruta, para não duplicar a lógica de acesso ao Firestore.
Future<List<LatLng>> _fetchPropertyPoints() async {
  final snapshot =
      await FirebaseFirestore.instance.collection('properties').get();

  final points = <LatLng>[];

  for (final doc in snapshot.docs) {
    final location = doc.data()['location'];
    if (location is GeoPoint) {
      points.add(LatLng(location.latitude, location.longitude));
    }
  }

  return points;
}

/// Baixa os tiles da área que engloba TODAS as propriedades cadastradas
/// no Firestore (mais uma margem de [marginKm] em cada direção) para o
/// cache local, para uso 100% offline depois.
///
/// Isso PRECISA ser executado com internet pelo menos uma vez — dá pra
/// rodar isso você mesmo em um app de desenvolvimento/debug, e depois
/// exportar a pasta do banco do FMTC (ObjectBox) para embutir como um
/// asset no app final, ou simplesmente deixar essa função rodar no
/// primeiro uso do app (com uma tela de "baixando mapa offline...").
///
/// IMPORTANTE — trade-off de ter trocado a área fixa por uma calculada
/// dinamicamente: como esse download acontece ANTES do app ser
/// publicado/distribuído, ele reflete o cadastro de propriedades NO
/// MOMENTO EM QUE RODOU. Se uma propriedade for cadastrada depois,
/// fora da área que foi calculada da última vez, os tiles dessa nova
/// região vão faltar no modo offline até essa função ser rodada de
/// novo e o cache reexportado/republicado. Ou seja, isso não se
/// autoatualiza sozinho — é preciso ter um processo (manual ou
/// automatizado) de re-rodar isso periodicamente conforme novas
/// propriedades entram em regiões não cobertas ainda.
///
/// O `minZoom` aqui vem de `kMapMinZoom` (em `map_bounds.dart`), que
/// precisa bater com o usado no `PropertyMapView` — se o mapa permitir
/// afastar até um zoom que não foi baixado, os tiles daquele nível
/// ficam em branco offline.
///
/// Retorna um record com dois streams (API da versão atual do FMTC):
/// - `downloadProgress`: progresso geral (dá pra ler `.percentageProgress`
///   pra mostrar uma barra de progresso, por exemplo).
/// - `tileEvents`: um evento por tile baixado, se quiser um log mais
///   detalhado.
///
/// Exemplo de uso:
/// ```dart
/// final download = await downloadPropertiesRegion();
/// download.downloadProgress.listen((progress) {
///   print('Baixando mapa: ${progress.percentageProgress.toStringAsFixed(0)}%');
/// });
/// ```
Future<
    ({
      Stream<DownloadProgress> downloadProgress,
      Stream<TileEvent> tileEvents
    })> downloadPropertiesRegion({double marginKm = kMapBoundsMarginKm}) async {
  final points = await _fetchPropertyPoints();

  final bounds = boundsFromPointsWithMargin(
    points,
    marginKm: marginKm,
    fallback: kFallbackMapBounds,
  );

  final region = RectangleRegion(bounds);

  final downloadableRegion = region.toDownloadable(
    minZoom: kMapMinZoom.round(),
    maxZoom: kMapMaxZoom.round(),
    options: TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.agrifor.app',
    ),
  );

  return FMTCStore(kLagesTileStore).download.startForeground(region: downloadableRegion);
}