/// Constantes globais do BeePainel.
class AppConstants {
  AppConstants._();

  static const String appName = 'ASA Painel';

  /// Chave do JSON de configuração em SharedPreferences.
  static const String prefsConfigKey = 'beepainel_config_v1';

  /// Caminho do polyfill de narração (asset).
  static const String speechPolyfillAsset = 'assets/js/speech_polyfill.js';

  /// Página de teste embutida (sistema de senha de exemplo).
  static const String demoPageAsset = 'assets/test/senha_demo.html';

  /// Nomes dos canais (handlers) da ponte JS ⇄ Flutter.
  static const String hTtsSpeak = 'tts.speak';
  static const String hTtsCancel = 'tts.cancel';
  static const String hTtsPause = 'tts.pause';
  static const String hTtsResume = 'tts.resume';
  static const String hTtsGetVoices = 'tts.getVoices';

  /// Máximo de URLs recentes guardadas.
  static const int maxRecents = 8;

  /// URL pré-carregada na lista de recentes (painel de senhas da ASA Saúde).
  static const String seedRecentUrl =
      'https://sistema-app.asasaude.app.br/painel/display';

  /// Backoff de retry (em segundos) ao falhar o carregamento.
  static const List<int> retryBackoffSeconds = [2, 5, 10, 15];
}
