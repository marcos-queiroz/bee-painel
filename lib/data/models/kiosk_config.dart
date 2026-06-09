import 'recent_url.dart';

/// Configuração persistente do ASAPainel.
class KioskConfig {
  const KioskConfig({
    this.pinnedUrl,
    this.autoStart = false,
    this.ttsBridgeEnabled = true,
    this.autoplayAudio = true,
    this.lockToInitialOrigin = true,
    this.exitPinHash,
    this.recents = const [],
  });

  /// URL fixada. `null` = sem URL fixada (abre a HomeScreen).
  final String? pinnedUrl;

  /// Abrir direto na [pinnedUrl] na inicialização.
  final bool autoStart;

  /// Forçar a ponte de narração nativa (substitui `speechSynthesis`).
  final bool ttsBridgeEnabled;

  /// Permitir autoplay de áudio/vídeo sem gesto do usuário.
  final bool autoplayAudio;

  /// Travar a navegação no domínio (origin) inicial.
  final bool lockToInitialOrigin;

  /// Hash (sha256+salt) do PIN de saída. `null` = sem PIN.
  final String? exitPinHash;

  final List<RecentUrl> recents;

  bool get hasPinnedUrl => pinnedUrl != null && pinnedUrl!.trim().isNotEmpty;

  KioskConfig copyWith({
    String? pinnedUrl,
    bool clearPinnedUrl = false,
    bool? autoStart,
    bool? ttsBridgeEnabled,
    bool? autoplayAudio,
    bool? lockToInitialOrigin,
    String? exitPinHash,
    bool clearExitPin = false,
    List<RecentUrl>? recents,
  }) {
    return KioskConfig(
      pinnedUrl: clearPinnedUrl ? null : (pinnedUrl ?? this.pinnedUrl),
      autoStart: autoStart ?? this.autoStart,
      ttsBridgeEnabled: ttsBridgeEnabled ?? this.ttsBridgeEnabled,
      autoplayAudio: autoplayAudio ?? this.autoplayAudio,
      lockToInitialOrigin: lockToInitialOrigin ?? this.lockToInitialOrigin,
      exitPinHash: clearExitPin ? null : (exitPinHash ?? this.exitPinHash),
      recents: recents ?? this.recents,
    );
  }

  Map<String, dynamic> toJson() => {
        'pinnedUrl': pinnedUrl,
        'autoStart': autoStart,
        'ttsBridgeEnabled': ttsBridgeEnabled,
        'autoplayAudio': autoplayAudio,
        'lockToInitialOrigin': lockToInitialOrigin,
        'exitPinHash': exitPinHash,
        'recents': recents.map((e) => e.toJson()).toList(),
      };

  factory KioskConfig.fromJson(Map<String, dynamic> json) => KioskConfig(
        pinnedUrl: json['pinnedUrl'] as String?,
        autoStart: json['autoStart'] as bool? ?? false,
        ttsBridgeEnabled: json['ttsBridgeEnabled'] as bool? ?? true,
        autoplayAudio: json['autoplayAudio'] as bool? ?? true,
        lockToInitialOrigin: json['lockToInitialOrigin'] as bool? ?? true,
        exitPinHash: json['exitPinHash'] as String?,
        recents: (json['recents'] as List<dynamic>? ?? [])
            .map((e) => RecentUrl.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
