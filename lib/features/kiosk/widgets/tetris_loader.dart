import 'dart:math';

import 'package:flutter/material.dart';

/// Loader animado no estilo Tetris: peças (tetrominós) caem do topo e se
/// empilham preenchendo um pequeno tabuleiro; ao encher, o tabuleiro "limpa"
/// com um flash e a animação reinicia em loop. Usado no preload.
class TetrisLoader extends StatefulWidget {
  const TetrisLoader({
    super.key,
    this.cols = 11,
    this.rows = 6,
    this.cell = 11,
    this.gap = 2,
    this.fallMs = 150,
    this.background = false,
  });

  final int cols;
  final int rows;
  final double cell;
  final double gap;

  /// Duração da queda de cada peça (ms). Menor = mais rápido/denso.
  final int fallMs;

  /// Modo de fundo: ocupa todo o espaço, sem painel/borda (para usar atrás do
  /// conteúdo, geralmente com blur e opacidade reduzida).
  final bool background;

  @override
  State<TetrisLoader> createState() => _TetrisLoaderState();
}

class _TetrisLoaderState extends State<TetrisLoader>
    with SingleTickerProviderStateMixin {
  // Tempos (ms) de cada fase do ciclo.
  static const int _holdMs = 650; // tabuleiro cheio, antes de limpar
  static const int _clearMs = 450; // limpeza (flash + fade)

  // Formas (x para a direita, y para CIMA a partir da base da peça) + cor.
  static const List<List<List<int>>> _shapes = [
    [[0, 0], [1, 0], [2, 0], [3, 0]], // I
    [[0, 0], [1, 0], [0, 1], [1, 1]], // O
    [[0, 0], [1, 0], [2, 0], [1, 1]], // T
    [[0, 0], [1, 0], [2, 0], [0, 1]], // J
    [[0, 0], [1, 0], [2, 0], [2, 1]], // L
    [[0, 0], [1, 0], [1, 1], [2, 1]], // S
    [[1, 0], [2, 0], [0, 1], [1, 1]], // Z
  ];

  static const List<Color> _colors = [
    Color(0xFF38BDF8), // I - ciano
    Color(0xFFFACC15), // O - amarelo
    Color(0xFFA855F7), // T - roxo
    Color(0xFF3B82F6), // J - azul
    Color(0xFFFB923C), // L - laranja
    Color(0xFF22C55E), // S - verde
    Color(0xFFEF4444), // Z - vermelho
  ];

  late final AnimationController _c;
  final List<_Placed> _placed = [];
  late int _totalMs;

  @override
  void initState() {
    super.initState();
    _simulate();
    _totalMs = _placed.length * widget.fallMs + _holdMs + _clearMs;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..repeat();
  }

  /// Pré-computa o empilhamento: escolhe peças/colunas (determinístico) e
  /// calcula onde cada uma "descansa" sobre as alturas atuais das colunas.
  void _simulate() {
    final heights = List<int>.filled(widget.cols, 0);
    final rng = Random(7);
    var guard = 0;
    while (guard++ < 200) {
      final shapeIdx = rng.nextInt(_shapes.length);
      final shape = _shapes[shapeIdx];
      final w = shape.map((c) => c[0]).reduce(max) + 1;
      if (w > widget.cols) continue;
      final cx = rng.nextInt(widget.cols - w + 1);

      final colLow = <int, int>{};
      final colHigh = <int, int>{};
      for (final c in shape) {
        final col = cx + c[0];
        final dy = c[1];
        colLow[col] = min(colLow[col] ?? 99, dy);
        colHigh[col] = max(colHigh[col] ?? -1, dy);
      }

      var base = 0;
      colLow.forEach((col, low) => base = max(base, heights[col] - low));

      var topRow = 0;
      colHigh.forEach((col, high) => topRow = max(topRow, base + high));
      if (topRow >= widget.rows) break; // não cabe mais → tabuleiro "cheio"

      final cells = [for (final c in shape) Point(cx + c[0], base + c[1])];
      colHigh.forEach(
          (col, high) => heights[col] = max(heights[col], base + high + 1));
      _placed.add(_Placed(cells, _colors[shapeIdx]));
    }
    // Fallback de segurança: garante alguma animação mesmo em casos extremos.
    if (_placed.isEmpty) {
      _placed.add(_Placed([const Point(0, 0)], _colors.first));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.cell + widget.gap;
    final boardW = widget.cols * widget.cell + (widget.cols - 1) * widget.gap;
    final boardH = widget.rows * widget.cell + (widget.rows - 1) * widget.gap;

    final painter = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: Size(boardW, boardH),
          painter: _TetrisPainter(
            placed: _placed,
            elapsedMs: _c.value * _totalMs,
            fallMs: widget.fallMs,
            holdMs: _holdMs,
            clearMs: _clearMs,
            rows: widget.rows,
            cell: widget.cell,
            step: step,
          ),
        );
      },
    );

    if (widget.background) {
      // Ocupa todo o espaço; tabuleiro centralizado.
      return RepaintBoundary(
        child: ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: painter,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: boardW + 16,
          height: boardH + 16,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRect(child: painter),
        ),
      ),
    );
  }
}

class _Placed {
  const _Placed(this.cells, this.color);
  final List<Point<int>> cells;
  final Color color;
}

class _TetrisPainter extends CustomPainter {
  _TetrisPainter({
    required this.placed,
    required this.elapsedMs,
    required this.fallMs,
    required this.holdMs,
    required this.clearMs,
    required this.rows,
    required this.cell,
    required this.step,
  });

  final List<_Placed> placed;
  final double elapsedMs;
  final int fallMs;
  final int holdMs;
  final int clearMs;
  final int rows;
  final double cell;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final fillEndMs = placed.length * fallMs;
    final clearStartMs = fillEndMs + holdMs;

    // Opacidade global durante a fase de limpeza (flash + fade-out).
    double boardOpacity = 1;
    if (elapsedMs >= clearStartMs) {
      final p = ((elapsedMs - clearStartMs) / clearMs).clamp(0.0, 1.0);
      boardOpacity = 1 - p;
    }

    for (var i = 0; i < placed.length; i++) {
      final piece = placed[i];
      final appearMs = i * fallMs;
      if (elapsedMs < appearMs) continue; // ainda não surgiu

      // Deslocamento vertical da queda (em pixels), com aceleração (gravidade).
      double dyPx = 0;
      final settleMs = appearMs + fallMs;
      if (elapsedMs < settleMs) {
        final t = ((elapsedMs - appearMs) / fallMs).clamp(0.0, 1.0);
        final eased = 1 - (1 - t) * (1 - t); // easeOut → assenta suave
        dyPx = -(1 - eased) * (rows + 2) * step;
      }

      final paint = Paint()
        ..color = piece.color.withValues(alpha: boardOpacity)
        ..style = PaintingStyle.fill;
      final hl = Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * boardOpacity);

      for (final c in piece.cells) {
        final x = c.x * step;
        final y = (rows - 1 - c.y) * step + dyPx;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cell, cell),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(rect, paint);
        // Brilho no topo do bloco (efeito 3D leve).
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1.5, y + 1.5, cell - 3, (cell - 3) * 0.32),
            const Radius.circular(2),
          ),
          hl,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TetrisPainter old) =>
      old.elapsedMs != elapsedMs;
}
