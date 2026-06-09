// Converte o fundo preto do logo (assets/icon/logo_dark.png) em transparencia.
//
// Estrategia: para cada pixel, define o canal alfa como o componente mais claro
// (max de R, G, B). Em fundo preto puro o alfa fica 0 (transparente); no texto
// branco/azul fica alto (opaco e vivo); nas bordas anti-aliased fica parcial,
// preservando suavidade. As cores (RGB) sao mantidas.
//
// Uso: dart run tool/transparentize_logo.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const path = 'assets/icon/logo_dark.png';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Arquivo nao encontrado: $path');
    exit(1);
  }

  final src = img.decodeImage(file.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Falha ao decodificar a imagem.');
    exit(1);
  }

  final out = src.convert(numChannels: 4);
  for (final p in out) {
    final maxC = [p.r, p.g, p.b].reduce((a, b) => a > b ? a : b);
    p.a = maxC;
  }

  file.writeAsBytesSync(img.encodePng(out));
  stdout.writeln('OK: fundo preto convertido em transparencia em $path');
}
