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

  /// Entra em Lock Task Mode (fixacao de tela) no Android: bloqueia a tecla
  /// HOME e a troca para apps nativos enquanto o kiosque estiver ativo.
  static Future<void> startLockTask() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('startLockTask');
    } catch (_) {}
  }

  /// Sai do Lock Task Mode (libera HOME e troca de apps).
  static Future<void> stopLockTask() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopLockTask');
    } catch (_) {}
  }
}
