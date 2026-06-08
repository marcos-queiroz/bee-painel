import '../../core/constants.dart';
import '../models/kiosk_config.dart';
import '../models/recent_url.dart';
import '../sources/prefs_source.dart';

/// Regras de leitura/escrita da configuração do kiosque.
class KioskSettingsRepository {
  KioskSettingsRepository(this._source);

  final PrefsSource _source;

  KioskConfig load() => _source.load();

  Future<KioskConfig> save(KioskConfig config) async {
    await _source.save(config);
    return config;
  }

  /// Adiciona/atualiza uma URL na lista de recentes (mais recente primeiro).
  Future<KioskConfig> addRecent(KioskConfig config, String url) async {
    final now = DateTime.now();
    final filtered = config.recents.where((r) => r.url != url).toList();
    final updated = <RecentUrl>[
      RecentUrl(url: url, lastOpened: now),
      ...filtered,
    ].take(AppConstants.maxRecents).toList();
    return save(config.copyWith(recents: updated));
  }

  /// Remove uma URL específica da lista de recentes.
  Future<KioskConfig> removeRecent(KioskConfig config, String url) async {
    final updated = config.recents.where((r) => r.url != url).toList();
    return save(config.copyWith(recents: updated));
  }

  /// Limpa toda a lista de recentes.
  Future<KioskConfig> clearRecents(KioskConfig config) async {
    return save(config.copyWith(recents: const []));
  }

  Future<KioskConfig> pin(KioskConfig config, String url) {
    return save(config.copyWith(pinnedUrl: url, autoStart: true));
  }

  Future<KioskConfig> unpin(KioskConfig config) {
    return save(config.copyWith(clearPinnedUrl: true, autoStart: false));
  }
}
