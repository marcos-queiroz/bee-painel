import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Ambiente do WebView2 (Windows) com pasta de dados persistente.
///
/// Sem um `userDataFolder` gravável e explícito, o WebView2 no Windows pode
/// renderizar uma tela cinza/em branco e não persistir login (RF-05). Esta
/// instância global é passada ao `InAppWebView` no Windows.
WebViewEnvironment? webViewEnvironment;

Future<void> initWebViewEnvironment() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    final dir = await getApplicationSupportDirectory();
    final userDataFolder = '${dir.path}${Platform.pathSeparator}webview2';
    await Directory(userDataFolder).create(recursive: true);
    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
    );
  } catch (e) {
    debugPrint('Falha ao criar WebViewEnvironment: $e');
  }
}
