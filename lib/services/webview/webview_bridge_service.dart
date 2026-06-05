import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/constants.dart';
import '../tts/tts_service.dart';

/// Conecta a Web Speech API (via polyfill JS) ao TTS nativo.
///
/// Registra os handlers `tts.*` no [InAppWebViewController] e devolve os eventos
/// de término/erro ao JS chamando `window.__ttsBridge.*`.
class WebViewBridgeService {
  WebViewBridgeService(this._tts);

  final TtsService _tts;
  InAppWebViewController? _controller;

  void attach(InAppWebViewController controller) {
    _controller = controller;

    _tts.onComplete = (id) {
      _eval('window.__ttsBridge && window.__ttsBridge.fireEnd($id);');
    };
    _tts.onError = (id, message) {
      final safe = jsonEncode(message);
      _eval('window.__ttsBridge && window.__ttsBridge.fireError($id, $safe);');
    };

    controller.addJavaScriptHandler(
      handlerName: AppConstants.hTtsSpeak,
      callback: (args) async {
        final m = _firstMap(args);
        if (m == null) return;
        await _tts.speak(
          id: (m['id'] as num).toInt(),
          text: m['text']?.toString() ?? '',
          lang: m['lang']?.toString(),
          rate: _toDouble(m['rate'], 1.0),
          pitch: _toDouble(m['pitch'], 1.0),
          volume: _toDouble(m['volume'], 1.0),
        );
      },
    );

    controller.addJavaScriptHandler(
      handlerName: AppConstants.hTtsCancel,
      callback: (_) => _tts.stop(),
    );
    controller.addJavaScriptHandler(
      handlerName: AppConstants.hTtsPause,
      callback: (_) => _tts.pause(),
    );
    controller.addJavaScriptHandler(
      handlerName: AppConstants.hTtsResume,
      callback: (_) => _tts.resume(),
    );
    controller.addJavaScriptHandler(
      handlerName: AppConstants.hTtsGetVoices,
      callback: (_) async {
        final voices = await _tts.voices();
        final json = jsonEncode(voices);
        await _eval('window.__ttsBridge && window.__ttsBridge.setVoices($json);');
      },
    );
  }

  Future<void> _eval(String source) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.evaluateJavascript(source: source);
    } catch (_) {/* documento pode ter mudado */}
  }

  Map<dynamic, dynamic>? _firstMap(List<dynamic> args) {
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is Map) return first;
    if (first is String) {
      try {
        return jsonDecode(first) as Map<dynamic, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}
