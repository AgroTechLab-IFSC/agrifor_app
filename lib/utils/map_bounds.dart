import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Configuração e utilitário de área do mapa compartilhados entre a
/// tela do mapa (`PropertyMapView`) e o script de pré-download de
/// tiles offline (`map_region_setup.dart`).
///
/// A área do mapa (limite de pan e região baixada para cache offline)
/// é calculada DINAMICAMENTE a partir das coordenadas das propriedades
/// cadastradas no Firestore, mais uma margem extra — em vez de uma
/// região fixa "chumbada" no código como antes.
///
/// IMPORTANTE: como o cache de tiles offline é baixado antecipadamente
/// (ver docstring de `downloadPropertiesRegion`), se uma propriedade for
/// cadastrada fora da área que foi calculada no momento do último
/// download, os tiles dessa nova área vão faltar no modo offline até
/// que o download seja rodado de novo e republicado no app.

// Reduzido de 11 para 9: com o filtro "Todos" ativo, o cluster de
// propriedades cadastradas pode ser grande o suficiente para exigir um
// zoom menor que 11 para caber inteiro na tela (junto com o padding da
// barra de filtro/card). Um piso de zoom mais alto do que o necessário
// fazia o CameraFit.bounds ficar "clampado" nesse mínimo, cortando
// propriedades fora da área visível.
//
// IMPORTANTE: como essa constante também é usada em
// `map_region_setup.dart` para o pré-download de tiles offline, essa
// mudança amplia a faixa de zoom que precisa ser (re)baixada — rode
// `downloadPropertiesRegion()` de novo após ajustar este valor.
const double kMapMinZoom = 9;
const double kMapMaxZoom = 16;

/// Quanto de margem extra (além do ponto mais distante cadastrado) o
/// mapa deixa disponível para pan/zoom-out e para o cache offline.
const double kMapBoundsMarginKm = 5;

/// Usado apenas como último recurso — se ainda não houver nenhuma
/// propriedade cadastrada com localização (banco vazio, ou antes do
/// Firestore responder). Mesma área que era fixa antes desta mudança.
final LatLngBounds kFallbackMapBounds = LatLngBounds(
  const LatLng(-27.95, -50.42),
  const LatLng(-27.59, -49.95),
);

const double _kmPerDegreeLat = 111.0;

/// Calcula um [LatLngBounds] que engloba todos os [points], expandido
/// por [marginKm] quilômetros em cada direção (norte/sul/leste/oeste).
///
/// Se [points] estiver vazio, retorna [fallback] sem modificação — não
/// faz sentido aplicar margem a uma lista vazia.
///
/// A conversão de km para graus de longitude leva em conta a latitude
/// média dos pontos (perto do equador, 1° de longitude ≈ 111km; mais
/// longe da linha do equador, bem menos) — sem isso, a margem ficaria
/// "espremida" ou "esticada" dependendo de onde no mundo o app roda.
LatLngBounds boundsFromPointsWithMargin(
  List<LatLng> points, {
  required double marginKm,
  required LatLngBounds fallback,
}) {
  if (points.isEmpty) return fallback;

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final point in points.skip(1)) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }

  final avgLatRad = ((minLat + maxLat) / 2) * math.pi / 180;
  final latMarginDeg = marginKm / _kmPerDegreeLat;
  final kmPerDegreeLng = _kmPerDegreeLat * math.cos(avgLatRad).abs();
  final lngMarginDeg = kmPerDegreeLng == 0 ? 0.0 : marginKm / kmPerDegreeLng;

  return LatLngBounds(
    LatLng(minLat - latMarginDeg, minLng - lngMarginDeg),
    LatLng(maxLat + latMarginDeg, maxLng + lngMarginDeg),
  );
}