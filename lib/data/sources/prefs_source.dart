import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../models/kiosk_config.dart';

/// Acesso de baixo nível à configuração persistida em SharedPreferences.
class PrefsSource {
  PrefsSource(this._prefs);

  final SharedPreferences _prefs;

  KioskConfig load() {
    final raw = _prefs.getString(AppConstants.prefsConfigKey);
    if (raw == null || raw.isEmpty) return const KioskConfig();
    try {
      return KioskConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const KioskConfig();
    }
  }

  Future<void> save(KioskConfig config) async {
    await _prefs.setString(
      AppConstants.prefsConfigKey,
      jsonEncode(config.toJson()),
    );
  }
}
