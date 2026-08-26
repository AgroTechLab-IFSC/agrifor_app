import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'property_map_view.dart' show kLagesTileStore, kLagesBounds, kMapMinZoom;

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

/// Baixa os tiles da região das 3 propriedades reais (Lages e
/// arredores próximos — ver o comentário em `kLagesBounds`) para o
/// cache local, para uso 100% offline depois.
///
/// Isso PRECISA ser executado com internet pelo menos uma vez — dá pra
/// rodar isso você mesmo em um app de desenvolvimento/debug, e depois
/// exportar a pasta do banco do FMTC (ObjectBox) para embutir como um
/// asset no app final, ou simplesmente deixar essa função rodar no
/// primeiro uso do app (com uma tela de "baixando mapa offline...").
///
/// IMPORTANTE: o `minZoom` aqui precisa bater com `kMapMinZoom` usado no
/// `PropertyMapView` — se o mapa permitir afastar até um zoom que não
/// foi baixado, os tiles daquele nível ficam em branco offline. Se já
/// baixou a região antes com o `minZoom` antigo (12), rode essa função
/// de novo depois de mudar `kMapMinZoom`, pra completar o cache com os
/// níveis de zoom que estavam faltando.
///
/// Área pequena (~15km) e poucos zooms — ainda assim dá poucas centenas
/// de tiles, tranquilo pra caber no app.
///
/// Retorna um record com dois streams (API da versão atual do FMTC):
/// - `downloadProgress`: progresso geral (dá pra ler `.percentageProgress`
///   pra mostrar uma barra de progresso, por exemplo).
/// - `tileEvents`: um evento por tile baixado, se quiser um log mais
///   detalhado.
///
/// Exemplo de uso:
/// ```dart
/// final download = downloadLagesRegion();
/// download.downloadProgress.listen((progress) {
///   print('Baixando mapa: ${progress.percentageProgress.toStringAsFixed(0)}%');
/// });
/// ```
({Stream<DownloadProgress> downloadProgress, Stream<TileEvent> tileEvents}) downloadLagesRegion() {
  final region = RectangleRegion(kLagesBounds);

  final downloadableRegion = region.toDownloadable(
    minZoom: kMapMinZoom.round(), // ALTERADO: era 12 (fixo) — agora usa a mesma constante do mapa
    maxZoom: 16,
    options: TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.agrifor.app',
    ),
  );

  return FMTCStore(kLagesTileStore).download.startForeground(region: downloadableRegion);
}