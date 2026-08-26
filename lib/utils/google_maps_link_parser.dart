import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Extrai um GeoPoint (latitude/longitude) a partir de um link do
/// Google Maps colado pelo admin. Cobre os formatos mais comuns:
/// - .../@-27.816,-50.326,15z    (posição central do mapa)
/// - ...?q=-27.816,-50.326        (marcador via query param)
/// - ...!3d-27.816!4d-50.326      (parâmetro interno de "place")
/// - links encurtados (maps.app.goo.gl, goo.gl/maps) -> resolve o
///   redirecionamento HTTP e tenta de novo na URL final.
///
/// Retorna null se não conseguir extrair nada (a UI mostra o fallback:
/// pedir pro admin colar o link completo, não o encurtado, ou copiar
/// as coordenadas direto do app do Google Maps).
class GoogleMapsLinkParser {
  static final _atPattern = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
  static final _queryPattern = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
  static final _placePattern = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');

  static GeoPoint? _tryExtract(String url) {
    for (final pattern in [_atPattern, _queryPattern, _placePattern]) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) return GeoPoint(lat, lng);
      }
    }
    return null;
  }

  static Future<GeoPoint?> parse(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return null;

    // caminho rápido: link já completo, não precisa de rede
    final direct = _tryExtract(url);
    if (direct != null) return direct;

    // link encurtado (maps.app.goo.gl, goo.gl/maps, g.co/...) -> segue
    // o redirecionamento HTTP manualmente pra pegar a URL final e
    // tenta extrair de novo
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      var currentUrl = url;

      for (var i = 0; i < 5; i++) {
        final request = await client.getUrl(Uri.parse(currentUrl));
        request.followRedirects = false;
        final response = await request.close();

        if (!response.isRedirect) {
          await response.drain();
          break;
        }

        final location = response.headers.value('location');
        await response.drain();
        if (location == null) break;

        currentUrl = location;
        final found = _tryExtract(currentUrl);
        if (found != null) return found;
      }
    } catch (_) {
      // sem internet, link inválido, timeout etc. — cai no null e a UI
      // mostra a mensagem de fallback manual.
    } finally {
      client?.close();
    }

    return null;
  }
}