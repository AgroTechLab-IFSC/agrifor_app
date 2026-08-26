import 'package:flutter/material.dart';

/// Pin padrão do mapa — visual idêntico para todos os produtores,
/// independente do tipo de produção. A diferenciação acontece só no
/// conteúdo do card de detalhes, nunca no pin.
class AnimatedPropertyPin extends StatefulWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// Atraso (ms) antes do pin aparecer — usado pra criar o efeito de
  /// entrada escalonada (staggered) quando o mapa carrega ou os
  /// filtros mudam.
  final int entranceDelayMs;

  const AnimatedPropertyPin({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
    this.entranceDelayMs = 0,
  });

  @override
  State<AnimatedPropertyPin> createState() => _AnimatedPropertyPinState();
}

class _AnimatedPropertyPinState extends State<AnimatedPropertyPin>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _selectController;
  late final Animation<double> _selectScale;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.entranceDelayMs), () {
      if (mounted) _entranceController.forward();
    });

    // Respiração sutil e contínua do pin, pra dar sensação "vivo".
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _selectScale = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOutBack),
    );
    _ringScale = Tween<double>(begin: 0.6, end: 2.0).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOut),
    );

    if (widget.selected) _selectController.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedPropertyPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _selectController.forward(from: 0);
      } else {
        _selectController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_entranceController, _pulseController, _selectController]),
        builder: (context, _) {
          final combinedScale =
              _entranceScale.value * _pulseScale.value * (1 + (_selectScale.value - 1) * 0.35 + (widget.selected ? 0 : 0));
          return Opacity(
            opacity: _entranceOpacity.value,
            child: Transform.scale(
              scale: combinedScale,
              // REMOVIDO: Column com a etiqueta do nome (AnimatedContainer + Text)
              // e o SizedBox de espaçamento — agora o pin é só o ícone.
              child: SizedBox(
                width: 92, // ALTERADO: era 80
                height: 92, // ALTERADO: era 80
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (widget.selected)
                      Opacity(
                        opacity: _ringOpacity.value,
                        child: Transform.scale(
                          scale: _ringScale.value,
                          child: Container(
                            width: 58, // ALTERADO: era 52
                            height: 58, // ALTERADO: era 52
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFA000),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      Icons.location_on,
                      color: widget.selected
                          ? const Color(0xFFFFA000)
                          : const Color(0xFF2E7D32),
                      size: widget.selected ? 58 : 52, // ALTERADO: era 52 : 46
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}