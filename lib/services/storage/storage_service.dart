import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Limpeza de dados do site (cookies/cache/web storage). Só é chamado por ação
/// explícita do operador em Settings — nunca no boot, para preservar o login.
class StorageService {
  Future<void> clearSiteData() async {
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {}
    try {
      await InAppWebViewController.clearAllCache();
    } catch (_) {}
  }
}
