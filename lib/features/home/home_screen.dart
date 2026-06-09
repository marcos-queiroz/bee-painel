import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme.dart';
import '../../core/url_utils.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _urlFocus = FocusNode();
  final _openFocus = FocusNode();
  String? _error;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Na Android TV o campo de texto "prende" o D-pad (as setas movem o cursor
    // do texto e nunca saem do campo). Aqui as setas cima/baixo movem o FOCO
    // para fora do campo, destravando a navegacao apos abrir/fechar o teclado.
    _urlFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.focusInDirection(TraversalDirection.down);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        node.focusInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _urlFocus.dispose();
    _openFocus.dispose();
    super.dispose();
  }

  // Ao fechar o teclado virtual na Android TV, o foco do D-pad costuma ficar
  // "perdido" (app parece travado). Detectamos o fechamento do IME e devolvemos
  // o foco para um alvo navegavel (botao Abrir).
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      final keyboardClosed = _lastBottomInset > 0 && bottom == 0;
      _lastBottomInset = bottom;
      if (keyboardClosed) {
        _urlFocus.unfocus();
        _openFocus.requestFocus();
      }
    });
  }

  Future<void> _open(String raw) async {
    if (!UrlUtils.isValid(raw)) {
      setState(() => _error = 'URL inválida. Ex.: exemplo.com ou https://exemplo.com');
      return;
    }
    final url = UrlUtils.normalize(raw);
    final notifier = ref.read(kioskConfigProvider.notifier);
    await notifier.recordOpened(url);
    if (!mounted) return;
    context.go('/kiosk?url=${Uri.encodeComponent(url)}');
  }

  Future<void> _clearRecents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar recentes'),
        content: const Text(
            'Deseja apagar todas as URLs recentes? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(kioskConfigProvider.notifier).clearRecents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(kioskConfigProvider);
    final isTv = ref.watch(isAndroidTvProvider);

    // Overscan: TVs cortam as bordas; aumenta as margens na TV.
    final size = MediaQuery.sizeOf(context);
    final hPad = isTv ? size.width * 0.06 : 32.0;
    final vPad = isTv ? size.height * 0.05 : 32.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: FocusTraversalGroup(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/icon/logo_dark.png',
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Configurações',
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(Icons.settings),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite a URL do painel para abrir em modo kiosque.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    focusNode: _urlFocus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      hintText: 'https://painel.exemplo.com',
                      prefixIcon: const Icon(Icons.link),
                      errorText: _error,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: _open,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    focusNode: _openFocus,
                    onPressed: () => _open(_controller.text),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Abrir'),
                  ),
                  if (config.recents.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text('Recentes',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearRecents,
                          icon: const Icon(Icons.delete_sweep_outlined,
                              size: 20),
                          label: const Text('Limpar tudo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...config.recents.asMap().entries.map(
                          (e) => _RecentTile(
                            url: e.value.url,
                            // Foco inicial no 1o item: na Android TV o D-pad
                            // precisa de um alvo focado (o TextField nao recebe
                            // mais autofocus, pois prendia a navegacao).
                            autofocus: e.key == 0,
                            onTap: () => _open(e.value.url),
                            onRemove: () => ref
                                .read(kioskConfigProvider.notifier)
                                .removeRecent(e.value.url),
                          ),
                        ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de URL recente com realce de foco visível para navegação por D-pad
/// (controle remoto de Android TV).
class _RecentTile extends StatefulWidget {
  const _RecentTile({
    required this.url,
    required this.onTap,
    required this.onRemove,
    this.autofocus = false,
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool autofocus;

  @override
  State<_RecentTile> createState() => _RecentTileState();
}

class _RecentTileState extends State<_RecentTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _focused ? AppTheme.honey : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        autofocus: widget.autofocus,
        onFocusChange: (f) => setState(() => _focused = f),
        leading: const Icon(Icons.history),
        title:
            Text(widget.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.close),
              onPressed: widget.onRemove,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}
