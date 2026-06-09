import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/constants.dart';
import '../../core/url_utils.dart';
import '../../services/kiosk/kiosk_mode_service.dart';
import '../../services/webview/webview_environment.dart';
import '../settings/pin_dialog.dart';
import 'widgets/error_overlay.dart';
import 'widgets/kiosk_controls.dart';

class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key, required this.url});

  final String url;

  bool get isDemo => url == 'asset://demo';

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  InAppWebViewController? _controller;
  KioskModeService? _kioskMode;
  String? _polyfill;
  String? _initialOrigin;
  String? _currentUrl;

  // O trava-origem so passa a valer DEPOIS do primeiro carregamento concluir.
  // Assim, atalhos/URLs que redirecionam (ex.: 302 do servidor) chegam ao
  // destino final sem serem bloqueados, e a origem travada e re-baseada para
  // a pagina onde o load efetivamente caiu.
  bool _initialLoadSettled = false;

  // Widget do WebView memoizado: criado UMA vez para evitar que rebuilds
  // (setState de loading/erro/conectividade) recriem a plataforma e recarreguem
  // a página — o reload fazia o painel re-anunciar a senha (causando eco).
  InAppWebView? _webView;

  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  int _retryAttempt = 0;
  int _retryCountdown = 0;
  Timer? _retryTimer;
  Timer? _loadWatchdog;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Gesto de saída: 5 toques no canto superior esquerdo em 3s.
  final Queue<DateTime> _cornerTaps = Queue<DateTime>();

  // Sinaliza a abertura do menu de controles (acionado pela tecla VOLTAR do
  // controle remoto na Android TV). Cada incremento dispara o listener.
  final ValueNotifier<int> _openControls = ValueNotifier<int>(0);

  // Foco raiz do kiosque: mantem o Flutter recebendo as setas do controle
  // (para mover o cursor) em vez de o WebView nativo captura-las.
  final FocusNode _rootFocus = FocusNode(debugLabel: 'kiosk-root');

  // --- Cursor virtual controlado pelo D-pad (TV sem tela de toque) ---
  // Posicao do cursor RELATIVA a area do WebView (logical px ~ CSS px).
  Offset? _cursorPos;
  bool _cursorVisible = false;
  Size _webArea = Size.zero;

  @override
  void initState() {
    super.initState();
    _initialOrigin = widget.isDemo ? null : UrlUtils.origin(widget.url);
    _currentUrl = widget.isDemo ? null : widget.url;
    _kioskMode = ref.read(kioskModeServiceProvider);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1) Carrega o polyfill PRIMEIRO — é o que libera a criação do WebView.
    //    Em caso de falha, segue com string vazia para nunca travar na tela de loading.
    try {
      _polyfill = await rootBundle.loadString(AppConstants.speechPolyfillAsset);
    } catch (_) {
      _polyfill = '';
    }
    if (mounted) setState(() {});

    // 2) Entra em modo kiosque SEM bloquear a renderização do WebView.
    try {
      await _kioskMode?.enter();
    } catch (_) {}

    // 3) Monitora conectividade para retry automático.
    try {
      _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    } catch (_) {}
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online && _error) _reloadNow();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _loadWatchdog?.cancel();
    _connSub?.cancel();
    _openControls.dispose();
    _rootFocus.dispose();
    _kioskMode?.exit();
    super.dispose();
  }

  void _clearLoading() {
    _loadWatchdog?.cancel();
    if (mounted && _loading) setState(() => _loading = false);
  }

  /// Garante que o overlay de loading nunca fique preso, mesmo quando os
  /// callbacks de carregamento do WebView não disparam (comum no Windows).
  void _startLoadWatchdog() {
    _loadWatchdog?.cancel();
    _loadWatchdog = Timer(const Duration(seconds: 8), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  // --- Carregamento / retry ---

  void _scheduleRetry() {
    final backoff = AppConstants.retryBackoffSeconds;
    final seconds = backoff[_retryAttempt.clamp(0, backoff.length - 1)];
    _retryAttempt++;
    setState(() => _retryCountdown = seconds);
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _retryCountdown--);
      if (_retryCountdown <= 0) {
        t.cancel();
        _reloadNow();
      }
    });
  }

  Future<void> _reloadNow() async {
    _retryTimer?.cancel();
    setState(() {
      _error = false;
      _loading = true;
    });
    await _controller?.reload();
  }

  // --- Gesto de saída ---

  void _onCornerTap() {
    final now = DateTime.now();
    _cornerTaps.addLast(now);
    while (_cornerTaps.isNotEmpty &&
        now.difference(_cornerTaps.first) > const Duration(seconds: 3)) {
      _cornerTaps.removeFirst();
    }
    if (_cornerTaps.length >= 5) {
      _cornerTaps.clear();
      _goSettings();
    }
  }

  /// Tratamento das teclas do controle remoto / teclado no kiosque:
  /// - Setas: movem o cursor virtual sobre a pagina (TV sem tela de toque).
  /// - OK/Enter: clica no ponto do cursor (despachado via JS na pagina).
  /// - MENU: abre Configuracoes (passa por PIN). Ctrl+Shift+Q: encerra.
  ///
  /// Movimento do cursor so age quando o foco raiz esta ativo (WebView). Quando
  /// o menu de controles esta aberto, as setas navegam entre os botoes.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final cursorActive = _rootFocus.hasPrimaryFocus;

    if (cursorActive) {
      const step = 45.0;
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveCursor(-step, 0);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveCursor(step, 0);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveCursor(0, -step);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveCursor(0, step);
        return KeyEventResult.handled;
      }
      if (_cursorVisible &&
          (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.gameButtonA)) {
        _clickAtCursor();
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.contextMenu) {
      _goSettings();
      return KeyEventResult.handled;
    }

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
    final shift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    if (ctrl && shift && key == LogicalKeyboardKey.keyQ) {
      _quitApp();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusWebView() {
    if (mounted) _rootFocus.requestFocus();
  }

  void _moveCursor(double dx, double dy) {
    if (_webArea.isEmpty) return;
    setState(() {
      _cursorVisible = true;
      final cur = _cursorPos ??
          Offset(_webArea.width / 2, _webArea.height / 2);
      _cursorPos = Offset(
        (cur.dx + dx).clamp(0.0, _webArea.width),
        (cur.dy + dy).clamp(0.0, _webArea.height),
      );
    });
  }

  /// Despacha um clique sintetico no ponto do cursor, direto na pagina. Usa a
  /// FRACAO da posicao (0..1) e multiplica por window.innerWidth/Height, para
  /// funcionar independente de escala/viewport. elementFromPoint + sequencia de
  /// eventos de mouse cobre tambem SPAs (React etc.).
  Future<void> _clickAtCursor() async {
    final pos = _cursorPos;
    final controller = _controller;
    if (pos == null || controller == null || _webArea.isEmpty) return;
    final fracX = (pos.dx / _webArea.width).clamp(0.0, 1.0);
    final fracY = (pos.dy / _webArea.height).clamp(0.0, 1.0);
    try {
      await controller.evaluateJavascript(source: '''
        (function(){
          var w = window.innerWidth || document.documentElement.clientWidth;
          var h = window.innerHeight || document.documentElement.clientHeight;
          var x = Math.round($fracX * w);
          var y = Math.round($fracY * h);
          var el = document.elementFromPoint(x, y);
          if(!el){return;}
          var opts = {bubbles:true, cancelable:true, clientX:x, clientY:y, view:window};
          ['pointerover','mouseover','pointerdown','mousedown','pointerup','mouseup','click']
            .forEach(function(t){
              var ev;
              try{ ev = new MouseEvent(t, opts); }
              catch(e){ ev = document.createEvent('MouseEvents'); ev.initEvent(t, true, true); }
              el.dispatchEvent(ev);
            });
          if(typeof el.focus === 'function'){ try{ el.focus(); }catch(e){} }
        })();
      ''');
    } catch (_) {}
  }

  Future<bool> _passPin() async {
    final config = ref.read(kioskConfigProvider);
    return PinDialog.show(context, config.exitPinHash);
  }

  Future<void> _goSettings() async {
    if (!await _passPin() || !mounted) return;
    context.go('/settings');
  }

  Future<void> _goHome() async {
    if (!await _passPin() || !mounted) return;
    context.go('/home');
  }

  Future<void> _quitApp() async {
    if (!await _passPin() || !mounted) return;
    await _kioskMode?.quitApp();
  }

  /// Fixa a URL atualmente exibida (já com eventuais redirecionamentos
  /// aplicados) ou desafixa, caso ela já esteja fixada.
  Future<void> _togglePin() async {
    final notifier = ref.read(kioskConfigProvider.notifier);
    final config = ref.read(kioskConfigProvider);

    // Prefere a URL viva do WebView; cai para a última conhecida.
    final live = (await _controller?.getUrl())?.toString();
    final url = (live != null && live.isNotEmpty) ? live : _currentUrl;
    if (url == null || url.isEmpty) return;

    final alreadyPinned = config.autoStart && config.pinnedUrl == url;
    if (alreadyPinned) {
      await notifier.unpin();
    } else {
      await notifier.pin(url);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            alreadyPinned
                ? 'URL desafixada. O app voltará a abrir na tela inicial.'
                : 'URL fixada: $url',
          ),
        ),
      );
  }

  // --- WebView config ---

  InAppWebViewSettings _buildSettings() {
    final config = ref.read(kioskConfigProvider);
    return InAppWebViewSettings(
      mediaPlaybackRequiresUserGesture: !config.autoplayAudio,
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: false,
      supportZoom: false,
      transparentBackground: false,
      useShouldOverrideUrlLoading: true,
      // Persistência (RF-05)
      cacheEnabled: true,
      // Android
      domStorageEnabled: true,
      databaseEnabled: true,
      useHybridComposition: true,
      // Android: honra o atributo `width` da meta viewport (necessario para
      // forcar o layout "desktop" na TV) e ajusta a pagina a largura da tela
      // ao carregar, evitando rolagem/conteudo cortado.
      useWideViewPort: true,
      loadWithOverviewMode: true,
      // NAO deixa o WebView capturar o foco nativo: o Flutter precisa receber
      // as setas do controle para mover o cursor virtual.
      needInitialFocus: false,
    );
  }

  UnmodifiableListView<UserScript> _userScripts() {
    final config = ref.read(kioskConfigProvider);
    final isTv = ref.read(isAndroidTvProvider);
    final scripts = <UserScript>[];

    if (config.ttsBridgeEnabled && _polyfill != null && _polyfill!.isNotEmpty) {
      scripts.add(
        UserScript(
          source: _polyfill!,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }

    // Na TV, o WebView reporta um viewport CSS estreito (largura em dp), o que
    // faz paineis responsivos caírem no layout "mobile" (empilhado) e em escala
    // ruim. Forcamos a largura FISICA da tela (ex.: 1920 em 1080p) para que a
    // pagina seja renderizada como um desktop Full HD: layout lado-a-lado e
    // escala ajustada a tela (junto de useWideViewPort/loadWithOverviewMode).
    if (isTv) {
      final mq = MediaQuery.of(context);
      final width = (mq.size.width * mq.devicePixelRatio).round();
      scripts.add(
        UserScript(
          source: _forceViewportScript(width),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }

    return UnmodifiableListView<UserScript>(scripts);
  }

  /// JS injetado no document start que fixa a meta viewport em [width] CSS px e
  /// reaplica caso a propria pagina defina/altere a sua (via MutationObserver).
  String _forceViewportScript(int width) {
    return '''
(function () {
  var W = $width;
  var CONTENT = 'width=' + W + ', user-scalable=no';
  function enforce() {
    var head = document.head || document.getElementsByTagName('head')[0];
    if (!head) return;
    var metas = document.querySelectorAll('meta[name="viewport"]');
    var meta;
    if (metas.length === 0) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      head.appendChild(meta);
    } else {
      meta = metas[0];
      for (var i = 1; i < metas.length; i++) {
        if (metas[i].parentNode) metas[i].parentNode.removeChild(metas[i]);
      }
    }
    if (meta.getAttribute('content') !== CONTENT) {
      meta.setAttribute('content', CONTENT);
    }
  }
  enforce();
  if (document.addEventListener) {
    document.addEventListener('DOMContentLoaded', enforce);
  }
  try {
    var mo = new MutationObserver(function () { enforce(); });
    (function start() {
      if (document.head) {
        mo.observe(document.head, { childList: true, subtree: true, attributes: true });
      } else {
        setTimeout(start, 50);
      }
    })();
  } catch (e) {
    var n = 0;
    var iv = setInterval(function () { enforce(); if (++n > 40) clearInterval(iv); }, 250);
  }
})();
''';
  }

  Future<NavigationActionPolicy> _shouldOverride(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final config = ref.read(kioskConfigProvider);
    final target = action.request.url?.toString() ?? '';
    if (target.isEmpty) return NavigationActionPolicy.ALLOW;

    final uri = Uri.tryParse(target);
    final scheme = uri?.scheme ?? '';
    // Bloqueia esquemas externos (intent, tel, mailto, etc.)
    if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'file') {
      return NavigationActionPolicy.CANCEL;
    }

    if (config.lockToInitialOrigin &&
        _initialLoadSettled &&
        _initialOrigin != null &&
        (action.isForMainFrame)) {
      if (scheme == 'http' || scheme == 'https') {
        if (!UrlUtils.sameOrigin(target, _initialOrigin!)) {
          return NavigationActionPolicy.CANCEL;
        }
      }
    }
    return NavigationActionPolicy.ALLOW;
  }

  /// Constrói o widget do WebView UMA única vez (memoizado em [_webView]).
  /// Evita recriação da plataforma/reload da página em rebuilds.
  InAppWebView _buildWebView() {
    return InAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialUrlRequest:
          widget.isDemo ? null : URLRequest(url: WebUri(widget.url)),
      initialFile: widget.isDemo ? AppConstants.demoPageAsset : null,
      initialSettings: _buildSettings(),
      initialUserScripts: _userScripts(),
      onWebViewCreated: (controller) {
        _controller = controller;
        ref.read(webViewBridgeServiceProvider).attach(controller);
        _startLoadWatchdog();
      },
      onLoadStart: (controller, url) {
        if (mounted) setState(() => _loading = true);
        _startLoadWatchdog();
      },
      onProgressChanged: (controller, progress) {
        if (progress >= 100) {
          if (mounted) setState(() => _retryAttempt = 0);
          _clearLoading();
        }
      },
      onLoadStop: (controller, url) {
        if (mounted) {
          setState(() {
            _error = false;
            _retryAttempt = 0;
            if (url != null) {
              _currentUrl = url.toString();
              // Re-baseia a origem travada para onde o load caiu (apos seguir
              // eventuais redirects do atalho) e ativa o trava-origem.
              _initialOrigin = UrlUtils.origin(url.toString()) ?? _initialOrigin;
              _initialLoadSettled = true;
            }
          });
        }
        _clearLoading();
        // Garante o foco raiz (Flutter) para o cursor responder ao controle.
        _focusWebView();
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        _loadWatchdog?.cancel();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
            _errorMessage = error.description;
          });
          _scheduleRetry();
        }
      },
      shouldOverrideUrlLoading: _shouldOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_polyfill == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final webView = _webView ??= _buildWebView();

    final config = ref.watch(kioskConfigProvider);
    final isPinned = config.autoStart &&
        config.pinnedUrl != null &&
        config.pinnedUrl == _currentUrl;

    return PopScope(
      canPop: false,
      // Tecla VOLTAR do controle remoto: nao sai do kiosque; em vez disso abre
      // e foca o menu de controles, dando acesso por D-pad a Opcoes/Config/etc.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _openControls.value++;
      },
      child: Focus(
        // Foco raiz do kiosque: mantem o Flutter recebendo as setas (para mover
        // o cursor virtual) e trata atalhos (MENU / Ctrl+Shift+Q).
        focusNode: _rootFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, constraints) {
            _webArea = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
          children: [
            Positioned.fill(child: webView),
            if (_loading && !_error)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_error)
              Positioned.fill(
                child: ErrorOverlay(
                  message: _errorMessage,
                  retryInSeconds: _retryCountdown,
                  onRetryNow: _reloadNow,
                ),
              ),
            // Cursor virtual controlado pelo D-pad (so aparece apos uso do
            // controle; em telas de toque permanece oculto).
            if (_cursorVisible && _cursorPos != null)
              Positioned(
                left: _cursorPos!.dx - _VirtualCursor.size / 2,
                top: _cursorPos!.dy - _VirtualCursor.size / 2,
                child: const IgnorePointer(child: _VirtualCursor()),
              ),
            // Área invisível extra (canto superior esquerdo): 5 toques em 3s.
            Positioned(
              top: 0,
              left: 0,
              width: 96,
              height: 96,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onCornerTap,
              ),
            ),
            // Controle visível e discreto de sair/voltar.
            KioskControls(
              onSettings: _goSettings,
              onHome: _goHome,
              onQuit: _quitApp,
              onTogglePin: widget.isDemo ? null : _togglePin,
              onRefresh: _reloadNow,
              isPinned: isPinned,
              openSignal: _openControls,
              onClosed: _focusWebView,
            ),
          ],
            );
          }),
        ),
      ),
    );
  }
}

/// Cursor virtual (bolinha) desenhado sobre o WebView, centralizado no ponto de
/// clique. Tem contorno escuro para ficar visivel sobre qualquer fundo.
class _VirtualCursor extends StatelessWidget {
  const _VirtualCursor();

  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black54, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
