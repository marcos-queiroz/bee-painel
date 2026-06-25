// Gera tv_banner (320x180) e app_icon (512x512) a partir dos PNGs da ASA.
//
// Uso: dart run tool/generate_android_assets.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const _iconDir = 'assets/icon';
const _tvBannerOut = 'android/app/src/main/res/drawable/tv_banner.png';

void main() {
  _generateAppIcon();
  _generateTvBanner();
  stdout.writeln('OK: assets Android gerados.');
}

void _generateAppIcon() {
  const srcPath = '$_iconDir/fav-blue.png';
  const outPath = '$_iconDir/app_icon.png';

  final src = _decode(srcPath);
  final size = 512;
  final out = img.copyResize(
    src,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  File(outPath).writeAsBytesSync(img.encodePng(out));
  stdout.writeln('  app_icon.png (${out.width}x${out.height})');
}

void _generateTvBanner() {
  // Wordmark horizontal branco/azul sobre fundo preto — ideal para a home da TV.
  const srcPath = '$_iconDir/asasaude-white-reduz.png';
  const w = 320;
  const h = 180;

  final src = _decode(srcPath);
  final canvas = img.Image(width: w, height: h);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));

  const padH = 20.0;
  final maxW = w - padH * 2;
  final maxH = h * 0.55;
  final scale = (maxW / src.width).clamp(0.0, maxH / src.height);
  final tw = (src.width * scale).round();
  final th = (src.height * scale).round();
  final resized = img.copyResize(
    src,
    width: tw,
    height: th,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    canvas,
    resized,
    dstX: (w - tw) ~/ 2,
    dstY: (h - th) ~/ 2,
  );

  File(_tvBannerOut).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('  tv_banner.png (${canvas.width}x${canvas.height})');
}

img.Image _decode(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Arquivo nao encontrado: $path');
    exit(1);
  }
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Falha ao decodificar: $path');
    exit(1);
  }
  return decoded;
}
