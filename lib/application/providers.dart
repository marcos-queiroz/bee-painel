import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pin_utils.dart';
import '../data/models/kiosk_config.dart';
import '../data/repositories/kiosk_settings_repository.dart';
import '../data/sources/prefs_source.dart';
import '../services/kiosk/kiosk_mode_service.dart';
import '../services/storage/storage_service.dart';
import '../services/tts/tts_service.dart';
import '../services/webview/webview_bridge_service.dart';

/// Sobrescrito no bootstrap (main) com a instância carregada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider não inicializado'),
);

final prefsSourceProvider = Provider<PrefsSource>(
  (ref) => PrefsSource(ref.watch(sharedPreferencesProvider)),
);

final kioskSettingsRepositoryProvider = Provider<KioskSettingsRepository>(
  (ref) => KioskSettingsRepository(ref.watch(prefsSourceProvider)),
);

// --- Serviços ---
final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final kioskModeServiceProvider =
    Provider<KioskModeService>((ref) => KioskModeService());
final webViewBridgeServiceProvider = Provider<WebViewBridgeService>(
  (ref) => WebViewBridgeService(ref.watch(ttsServiceProvider)),
);

/// Estado da configuração do kiosque + ações de mutação.
class KioskConfigNotifier extends Notifier<KioskConfig> {
  KioskSettingsRepository get _repo => ref.read(kioskSettingsRepositoryProvider);

  @override
  KioskConfig build() => _repo.load();

  Future<void> recordOpened(String url) async {
    state = await _repo.addRecent(state, url);
  }

  Future<void> pin(String url) async {
    state = await _repo.pin(state, url);
  }

  Future<void> unpin() async {
    state = await _repo.unpin(state);
  }

  Future<void> setExitPin(String? pin) async {
    final hash = (pin == null || pin.trim().isEmpty) ? null : PinUtils.hash(pin);
    state = await _repo.save(
      hash == null
          ? state.copyWith(clearExitPin: true)
          : state.copyWith(exitPinHash: hash),
    );
  }

  Future<void> setAutoplayAudio(bool value) async {
    state = await _repo.save(state.copyWith(autoplayAudio: value));
  }

  Future<void> setTtsBridgeEnabled(bool value) async {
    state = await _repo.save(state.copyWith(ttsBridgeEnabled: value));
  }

  Future<void> setLockToInitialOrigin(bool value) async {
    state = await _repo.save(state.copyWith(lockToInitialOrigin: value));
  }
}

final kioskConfigProvider =
    NotifierProvider<KioskConfigNotifier, KioskConfig>(KioskConfigNotifier.new);
