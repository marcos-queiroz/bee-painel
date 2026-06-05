import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Abstração sobre [FlutterTts] usada pela ponte de narração (SDD-003).
///
/// IMPORTANTE (Windows): o `flutter_tts` no Windows, com
/// `awaitSpeakCompletion(true)`, chama `result->Success()` duas vezes
/// ("Ignoring duplicate result"), o que derruba o app em release. Por isso
/// mantemos `awaitSpeakCompletion(false)` e usamos o callback de conclusão
/// real (`setCompletionHandler`) para saber, com precisão, quando a fala
/// termina — o que é essencial para o polyfill JS tocar uma narração por vez
/// (sem cortar nem sobrepor/"reverb").
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  /// Id da utterance em reprodução. O polyfill serializa as falas (só envia a
  /// próxima após `fireEnd`), então há no máximo uma ativa por vez.
  int? _currentId;

  /// Dedup: evita tocar a MESMA frase duas vezes em sequência rápida (ex.: o
  /// painel re-anuncia a senha atual ao recarregar/re-renderizar), o que
  /// causava o efeito de eco.
  String? _lastText;
  DateTime _lastSpeakAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _dedupWindow = Duration(seconds: 2);

  /// Disparado quando a fala correspondente ao `id` termina (de verdade).
  void Function(int id)? onComplete;

  /// Disparado em caso de erro de síntese.
  void Function(int id, String message)? onError;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // NÃO usar true no Windows (ver doc acima).
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {}

    _tts.setCompletionHandler(() {
      final id = _currentId;
      _currentId = null;
      if (id != null) onComplete?.call(id);
    });

    _tts.setErrorHandler((dynamic message) {
      final id = _currentId;
      _currentId = null;
      if (id != null) onError?.call(id, message?.toString() ?? 'synthesis-failed');
    });

    _tts.setCancelHandler(() {
      _currentId = null;
    });
  }

  Future<void> speak({
    required int id,
    required String text,
    String? lang,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    // Dedup de frase idêntica em janela curta → ignora, mas devolve o
    // `onComplete` para o polyfill avançar a fila normalmente.
    final now = DateTime.now();
    if (text == _lastText && now.difference(_lastSpeakAt) < _dedupWindow) {
      Future.delayed(const Duration(milliseconds: 50), () => onComplete?.call(id));
      return;
    }
    _lastText = text;
    _lastSpeakAt = now;

    _currentId = id;

    if (lang != null && lang.isNotEmpty) {
      try {
        await _tts.setLanguage(lang);
      } catch (_) {/* idioma indisponível: usa o padrão */}
    }
    try {
      await _tts.setSpeechRate(_mapRate(rate));
      await _tts.setPitch(pitch.clamp(0.5, 2.0).toDouble());
      await _tts.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await _tts.speak(text);
    } catch (e) {
      final cid = _currentId;
      _currentId = null;
      if (cid != null) onError?.call(cid, e.toString());
    }
    // O `onComplete` é disparado pelo setCompletionHandler quando a fala
    // realmente termina, garantindo a serialização correta da fila.
  }

  /// Web Speech `rate` (0.1–10, padrão 1.0) → flutter_tts (0.0–1.0).
  double _mapRate(double webRate) => (webRate * 0.5).clamp(0.1, 1.0).toDouble();

  Future<void> stop() async {
    _currentId = null;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {/* nem toda plataforma suporta */}
  }

  Future<void> resume() async {
    // flutter_tts não tem resume universal; tratado como no-op documentado.
  }

  Future<List<Map<String, dynamic>>> voices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is List) {
        return raw.map<Map<String, dynamic>>((dynamic v) {
          final map = (v as Map).cast<dynamic, dynamic>();
          return {
            'name': map['name']?.toString() ?? '',
            'lang': (map['locale'] ?? map['lang'])?.toString() ?? '',
            'default': false,
          };
        }).where((e) => (e['name'] as String).isNotEmpty).toList();
      }
    } catch (_) {/* ignore */}
    return const [];
  }

  void dispose() {}
}
