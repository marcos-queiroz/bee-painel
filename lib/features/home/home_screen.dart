import 'package:flutter/material.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  bool _pin = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    if (!UrlUtils.isValid(raw)) {
      setState(() => _error = 'URL inválida. Ex.: exemplo.com ou https://exemplo.com');
      return;
    }
    final url = UrlUtils.normalize(raw);
    final notifier = ref.read(kioskConfigProvider.notifier);
    await notifier.recordOpened(url);
    if (_pin) await notifier.pin(url);
    if (!mounted) return;
    context.go('/kiosk?url=${Uri.encodeComponent(url)}');
  }

  void _openDemo() {
    context.go('/kiosk?url=${Uri.encodeComponent('asset://demo')}');
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: FocusTraversalGroup(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hexagon_rounded,
                          color: AppTheme.honey, size: 40),
                      const SizedBox(width: 12),
                      Text('BeePainel',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Configurações',
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings),
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
                    autofocus: true,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _pin,
                    onChanged: (v) => setState(() => _pin = v),
                    title: const Text('Fixar esta URL'),
                    subtitle: const Text(
                        'O app abrirá direto nela nas próximas inicializações.'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _open(_controller.text),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Abrir'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openDemo,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Abrir demo de senha (teste de narração)'),
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
                    ...config.recents.map(
                      (r) => _RecentTile(
                        url: r.url,
                        onTap: () => _open(r.url),
                        onRemove: () => ref
                            .read(kioskConfigProvider.notifier)
                            .removeRecent(r.url),
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
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
