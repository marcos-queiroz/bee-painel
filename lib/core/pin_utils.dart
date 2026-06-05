import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash de PIN de saída do kiosque. Nunca armazenamos o PIN em texto puro.
class PinUtils {
  PinUtils._();

  static const String _salt = 'beepainel::exit-pin::v1';

  static String hash(String pin) {
    final bytes = utf8.encode('$_salt|${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return true;
    return hash(pin) == storedHash;
  }
}
