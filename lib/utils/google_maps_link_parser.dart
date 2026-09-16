import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Extrai um GeoPoint (latitude/longitude) a partir de um link do
/// Google Maps colado pelo admin, ou de coordenadas coladas diretamente.
///
/// Formatos suportados:
/// - "-27.816, -50.326"           (coordenadas coladas direto)
/// - .../@-27.816,-50.326,15z     (posição central do mapa / pino solto)
/// - ...?q=-27.816,-50.326        (marcador via query param)
/// - ...!3d-27.816!4d-50.326      (pino solto compartilhado pelo app)
/// - links encurtados (maps.app.goo.gl, goo.gl/maps) -> resolve o
///   redirecionamento HTTP e tenta de novo na URL final.
///
/// NÃO cobre links de "ficha de estabelecimento" (com CID, tipo
/// .../place/Nome/data=!4m2!3m1!1s0x...:0x...!...), pois esses links
/// não trazem coordenada nenhuma na URL — só o Google consegue
/// resolver isso internamente. Para esses casos, orientamos o
/// usuário a compartilhar um pino solto (toque e segure no mapa)
/// em vez da ficha do estabelecimento, ou colar as coordenadas
/// direto (ele mesmo consegue copiar isso no app do Maps).
///
/// Retorna null se não conseguir extrair — a UI deve mostrar
/// [GoogleMapsLinkParser.errorMessage] nesse caso.
class GoogleMapsLinkParser {
  static const errorMessage =
      'Não conseguimos identificar as coordenadas desse link.\n\n'
      'No Google Maps, toque e segure o ponto exato no mapa (isso solta '
      'um pino) antes de compartilhar — em vez de compartilhar direto '
      'pela ficha do estabelecimento. Você também pode copiar as '
      'coordenadas (ex: -27.816, -50.326) direto do cartão do pino e '
      'colar aqui.';

  static final _coordinatesPattern = RegExp(
    r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  );
  static final _placePattern = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
  static final _queryPattern = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
  static final _atPattern = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');

  static bool _validCoordinates(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static GeoPoint? _tryDirectCoordinates(String value) {
    final match = _coordinatesPattern.firstMatch(value);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (!_validCoordinates(lat, lng)) return null;

    return GeoPoint(lat, lng);
  }

  static GeoPoint? _tryExtractFromUrl(String url) {
    // Ordem importa: !3d/!4d é o ponto exato do pino, mais preciso
    // que @lat,lng (que é só o centro da viewport do mapa).
    for (final pattern in [_placePattern, _queryPattern, _atPattern]) {
      final match = pattern.firstMatch(url);
      if (match == null) continue;

      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && _validCoordinates(lat, lng)) {
        return GeoPoint(lat, lng);
      }
    }
    return null;
  }

  /// Segue redirects manualmente (sem depender de pacote externo),
  /// testando a URL a cada salto — resolve links encurtados.
  static Future<String> _resolveRedirects(String url) async {
    HttpClient? client;
    var currentUrl = url;

    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

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
      }
    } catch (_) {
      // sem internet, link inválido, timeout etc. — mantém a última
      // URL alcançada e deixa o chamador decidir o que fazer.
    } finally {
      client?.close();
    }

    return currentUrl;
  }

  static Future<GeoPoint?> parse(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    // 1. Coordenadas coladas diretamente.
    final direct = _tryDirectCoordinates(value);
    if (direct != null) return direct;

    // 2. Link já completo, sem precisar seguir redirect.
    final fromUrl = _tryExtractFromUrl(value);
    if (fromUrl != null) return fromUrl;

    // 3. Link encurtado -> segue redirects e tenta de novo na URL final.
    final finalUrl = await _resolveRedirects(value);
    return _tryExtractFromUrl(finalUrl);
  }
}