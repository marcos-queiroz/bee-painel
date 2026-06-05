/// Normalização e validação de URLs digitadas pelo operador.
class UrlUtils {
  UrlUtils._();

  /// Garante esquema; aceita "exemplo.com", "exemplo.com/x", "https://...".
  static String normalize(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s);
    if (!hasScheme) s = 'https://$s';
    return s;
  }

  static bool isValid(String input) {
    final s = normalize(input);
    final uri = Uri.tryParse(s);
    if (uri == null) return false;
    if (!uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Origem (scheme://host:port) usada para travar a navegação no kiosque.
  static String? origin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static bool sameOrigin(String a, String b) {
    final oa = origin(a);
    final ob = origin(b);
    return oa != null && oa == ob;
  }
}
