import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrifor_app/services/location_service.dart';
import 'package:agrifor_app/utils/google_maps_link_parser.dart';

class PropertyLocationField extends StatefulWidget {
  const PropertyLocationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final GeoPoint? value;
  final ValueChanged<GeoPoint> onChanged;
  final String? errorText;

  @override
  State<PropertyLocationField> createState() =>
      _PropertyLocationFieldState();
}

class _PropertyLocationFieldState
    extends State<PropertyLocationField> {
  final _mapsLinkController =
      TextEditingController();

  bool _gettingCurrentLocation = false;
  bool _resolvingLink = false;

  double? _accuracy;

  String? _warning;
  String? _error;

  LocationCaptureIssue? _issue;

  bool get _busy =>
      _gettingCurrentLocation ||
      _resolvingLink;

  @override
  void dispose() {
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gettingCurrentLocation = true;
      _warning = null;
      _error = null;
      _issue = null;
    });

    final result =
        await LocationService.getCurrentLocation();

    if (!mounted) {
      return;
    }

    setState(() {
      _gettingCurrentLocation = false;
      _issue = result.issue;

      if (!result.isSuccess) {
        _error = switch (result.issue) {
          LocationCaptureIssue.serviceDisabled =>
            'A localização do aparelho está desligada. Ative o GPS e tente novamente.',

          LocationCaptureIssue.permissionDenied =>
            'Permissão de localização negada. Toque novamente e permita o acesso.',

          LocationCaptureIssue.permissionDeniedForever =>
            'A permissão de localização foi bloqueada. Libere o acesso nas configurações do aplicativo.',

          LocationCaptureIssue.timeout =>
            'Não foi possível obter o GPS a tempo. Vá para um local aberto e tente novamente.',

          _ =>
            'Não foi possível obter sua localização atual. Tente novamente.',
        };

        return;
      }

      // GPS substitui qualquer link digitado anteriormente.
      _mapsLinkController.clear();

      _accuracy = result.accuracy;
      _issue = null;
      _error = null;

      if (result.isReducedAccuracy) {
        _warning =
            'O aparelho forneceu uma localização aproximada. Ative a localização precisa e tente novamente.';
      } else if ((result.accuracy ?? 0) > 50) {
        _warning =
            'Sinal de GPS fraco (precisão de aproximadamente ${result.accuracy!.round()} m). Tente novamente em local aberto.';
      } else if ((result.accuracy ?? 0) > 20) {
        _warning =
            'Precisão aproximada de ${result.accuracy!.round()} m. Tente novamente em local aberto para marcar melhor a entrada.';
      } else {
        _warning = null;
      }
    });

    widget.onChanged(result.point!);
  }

  Future<void> _useMapsLink() async {
    final link =
        _mapsLinkController.text.trim();

    if (link.isEmpty) {
      setState(() {
        _error =
            'Cole um link do Google Maps';
      });

      return;
    }

    setState(() {
      _resolvingLink = true;
      _warning = null;
      _error = null;
      _issue = null;
    });

    final point =
        await GoogleMapsLinkParser.parse(link);

    if (!mounted) {
      return;
    }

    setState(() {
      _resolvingLink = false;
      _accuracy = null;

      if (point == null) {
        _error =
            'Não consegui identificar o ponto. No Google Maps, marque a entrada da propriedade, toque em Compartilhar e cole aqui o link gerado.';
      } else {
        _error = null;
      }
    });

    if (point != null) {
      widget.onChanged(point);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error =
        _error ?? widget.errorText;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _busy
                    ? null
                    : _useCurrentLocation,
            icon: _gettingCurrentLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                  ),
            label: Text(
              _gettingCurrentLocation
                  ? 'Obtendo localização...'
                  : 'Usar minha localização atual',
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Ideal se você estiver na entrada da propriedade.',
          style:
              Theme.of(context)
                  .textTheme
                  .bodySmall,
        ),

        const Padding(
          padding:
              EdgeInsets.symmetric(
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Divider(),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                child: Text('ou'),
              ),
              Expanded(
                child: Divider(),
              ),
            ],
          ),
        ),

        TextFormField(
          controller:
              _mapsLinkController,
          decoration:
              const InputDecoration(
            labelText:
                'Link do Google Maps',
            hintText:
                'Cole aqui o link compartilhado do Maps',
          ),
          keyboardType:
              TextInputType.url,
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _busy
                    ? null
                    : _useMapsLink,
            icon: _resolvingLink
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .add_location_alt_outlined,
                  ),
            label: Text(
              _resolvingLink
                  ? 'Lendo link...'
                  : 'Usar link do Google Maps',
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'No Maps, marque a entrada, toque em Compartilhar e copie o link.',
          style:
              Theme.of(context)
                  .textTheme
                  .bodySmall,
        ),

        if (widget.value != null) ...[
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color:
                    Color(0xFF2E7D32),
                size: 18,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  'Localização definida: '
                  '${widget.value!.latitude.toStringAsFixed(6)}, '
                  '${widget.value!.longitude.toStringAsFixed(6)}'
                  '${_accuracy == null ? '' : ' • precisão ~${_accuracy!.round()} m'}',
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall,
                ),
              ),
            ],
          ),
        ],

        if (_warning != null) ...[
          const SizedBox(height: 8),

          Text(
            _warning!,
            style: TextStyle(
              color:
                  Colors.orange.shade800,
              fontSize: 12,
            ),
          ),
        ],

        if (error != null) ...[
          const SizedBox(height: 8),

          Text(
            error,
            style: TextStyle(
              color:
                  Theme.of(context)
                      .colorScheme
                      .error,
            ),
          ),
        ],

        if (_issue ==
            LocationCaptureIssue
                .serviceDisabled)
          TextButton.icon(
            onPressed: () async {
              await LocationService
                  .openLocationSettings();
            },
            icon: const Icon(
              Icons.settings_outlined,
            ),
            label: const Text(
              'Abrir configurações de localização',
            ),
          ),

        if (_issue ==
            LocationCaptureIssue
                .permissionDeniedForever)
          TextButton.icon(
            onPressed: () async {
              await LocationService
                  .openAppSettings();
            },
            icon: const Icon(
              Icons.settings_outlined,
            ),
            label: const Text(
              'Abrir configurações do aplicativo',
            ),
          ),
      ],
    );
  }
}