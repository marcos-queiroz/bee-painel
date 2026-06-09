import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

/// Controla tela cheia / modo kiosque e o wakelock, por plataforma (SDD-004).
class KioskModeService {
  bool _active = false;
  bool get isActive => _active;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Inicialização única do window_manager (chamada no bootstrap, desktop).
  static Future<void> ensureDesktopWindow() async {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'ASA Painel',
      titleBarStyle: TitleBarStyle.normal,
      size: Size(1280, 800),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> enter() async {
    if (_active) return;
    _active = true;

    await WakelockPlus.enable();

    if (_isDesktop) {
      await windowManager.setFullScreen(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> exit() async {
    if (!_active) return;
    _active = false;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    if (_isDesktop) {
      await windowManager.setFullScreen(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  /// Encerra o aplicativo (sai do kiosque antes de fechar).
  Future<void> quitApp() async {
    await exit();
    if (_isDesktop) {
      await windowManager.destroy();
    } else {
      await SystemNavigator.pop();
    }
  }
}
