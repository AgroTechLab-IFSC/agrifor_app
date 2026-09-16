import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinkService {
  const ExternalLinkService._();

  /// Abre uma conversa no WhatsApp.
  ///
  /// Se o número tiver 10 ou 11 dígitos, considera um número
  /// brasileiro e adiciona automaticamente o DDI 55.
  static Future<void> openWhatsApp(
    BuildContext context,
    String phone,
  ) async {
    final digits = _digitsOnly(phone);

    if (digits.isEmpty) {
      _showError(context);
      return;
    }

    final normalizedPhone = _normalizeWhatsAppNumber(digits);

    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone',
    );

    await _openExternal(context, uri);
  }

  /// Abre o discador do telefone.
  static Future<void> callPhone(
    BuildContext context,
    String phone,
  ) async {
    final digits = _digitsOnly(phone);

    if (digits.isEmpty) {
      _showError(context);
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: digits,
    );

    await _openExternal(context, uri);
  }

  /// Abre o perfil do Instagram.
  ///
  /// Aceita:
  /// @usuario
  /// usuario
  /// https://instagram.com/usuario
  static Future<void> openInstagram(
    BuildContext context,
    String instagram,
  ) async {
    final value = instagram.trim();

    if (value.isEmpty) {
      _showError(context);
      return;
    }

    Uri uri;

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      uri = Uri.parse(value);
    } else {
      final handle = value.startsWith('@')
          ? value.substring(1)
          : value;

      if (handle.isEmpty) {
        _showError(context);
        return;
      }

      uri = Uri.parse(
        'https://www.instagram.com/$handle/',
      );
    }

    await _openExternal(context, uri);
  }

  /// Abre o Google Maps criando uma rota até a propriedade.
  static Future<void> openGoogleMaps(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude',
    );

    await _openExternal(context, uri);
  }

  /// Tenta abrir a URI diretamente no aplicativo externo.
  ///
  /// Não usa canLaunchUrl porque no Android 11+ essa consulta
  /// pode retornar false mesmo quando existe um aplicativo capaz
  /// de abrir o link.
  static Future<void> _openExternal(
    BuildContext context,
    Uri uri,
  ) async {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context);
      }
    }
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(
      RegExp(r'\D'),
      '',
    );
  }

  static String _normalizeWhatsAppNumber(
    String digits,
  ) {
    // Número brasileiro sem DDI:
    // 49 99911-4096 -> 5549999114096
    if (digits.length == 10 ||
        digits.length == 11) {
      return '55$digits';
    }

    // Se já veio com DDI, mantém como está.
    return digits;
  }

  static void _showError(
    BuildContext context,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o aplicativo.',
        ),
      ),
    );
  }
}