import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Informações da plataforma resolvidas via canal nativo.
class PlatformInfo {
  PlatformInfo._();

  static const MethodChannel _channel = MethodChannel('beepainel/platform');

  /// `true` quando o app roda numa Android TV (UI mode television ou leanback).
  static Future<bool> isAndroidTv() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isTv');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
