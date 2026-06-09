import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'tetris_loader.dart';

/// Tela de preload exibida sobre o WebView enquanto a página (URL) carrega.
///
/// Visual moderno: ao FUNDO, uma animação de Tetris (peças caindo e
/// empilhando) com leve blur e opacidade reduzida; por CIMA, nítidos e
/// centralizados, o ícone (com brilho pulsante) e a logo da ASA. Tudo entra
/// com um fade/scale-in elegante na primeira aparição.
class SplashLoader extends StatefulWidget {
  const SplashLoader({super.key});

  @override
  State<SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<SplashLoader>
    with TickerProviderStateMixin {
  // Animação contínua: respiro da logo + barra de progresso deslizante.
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();

  // Entrada única: fade + leve scale-in ao aparecer.
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
        ..forward();

  late final Animation<double> _introCurve =
      CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const cell = 30.0;
    const gap = 4.0;
    final step = cell + gap;
    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base: gradiente escuro.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [Color(0xFF18202B), AppTheme.ink],
              ),
            ),
          ),
          // Fundo: Tetris em tela cheia, com leve blur e opacidade reduzida.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Opacity(
                opacity: 0.5,
                child: TetrisLoader(
                  cols: cols,
                  rows: rows,
                  cell: cell,
                  gap: gap,
                  fallMs: 85,
                  background: true,
                ),
              ),
            ),
          ),
          // Escurecimento sutil para destacar o conteúdo central.
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          ),
          // Conteúdo nítido: ícone (com brilho pulsante) + logo.
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, _intro]),
              builder: (context, _) {
                final t = _loop.value; // 0..1 contínuo
                final wave = math.sin(t * 2 * math.pi); // -1..1
                final scale = 1 + 0.025 * wave;
                final glow = 0.35 + 0.35 * ((wave + 1) / 2); // 0.35..0.70

                final intro = _introCurve.value; // 0..1 (uma vez)
                final introScale = 0.92 + 0.08 * intro;

                return Opacity(
                  opacity: intro,
                  child: Transform.scale(
                    scale: introScale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.brand
                                      .withValues(alpha: glow * 0.5),
                                  blurRadius: 48,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/symbol.png',
                              width: 132,
                              height: 132,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Image.asset(
                          'assets/icon/logo_dark.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
