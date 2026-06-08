import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey, rootBundle;
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

  /// Atalhos de teclado/controle remoto para sair do kiosque sem toque
  /// (essencial no Android TV, onde nao ha tela sensivel ao toque):
  /// - Tecla MENU do controle remoto -> abre Configuracoes (passa por PIN).
  /// - Ctrl+Shift+Q (teclado/desktop) -> encerra o app (passa por PIN).
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
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
    );
  }

  UnmodifiableListView<UserScript> _userScripts() {
    final config = ref.read(kioskConfigProvider);
    if (!config.ttsBridgeEnabled || _polyfill == null || _polyfill!.isEmpty) {
      return UnmodifiableListView<UserScript>(const []);
    }
    return UnmodifiableListView<UserScript>([
      UserScript(
        source: _polyfill!,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ]);
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
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
        body: Stack(
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
              isPinned: isPinned,
              openSignal: _openControls,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
