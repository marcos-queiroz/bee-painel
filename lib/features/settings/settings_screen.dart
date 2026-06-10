import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(kioskConfigProvider);
    final notifier = ref.read(kioskConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          if (config.hasPinnedUrl)
            TextButton.icon(
              onPressed: () => context.go(
                  '/kiosk?url=${Uri.encodeComponent(config.pinnedUrl!)}'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Voltar ao kiosque'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.push_pin),
              title: const Text('URL fixada'),
              subtitle: Text(config.pinnedUrl ?? 'Nenhuma'),
              trailing: config.hasPinnedUrl
                  ? IconButton(
                      tooltip: 'Desafixar',
                      icon: const Icon(Icons.link_off),
                      onPressed: () async {
                        await notifier.unpin();
                        if (context.mounted) context.go('/home');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Permitir autoplay de áudio'),
            subtitle: const Text('Necessário para narração HTML automática.'),
            value: config.autoplayAudio,
            onChanged: notifier.setAutoplayAudio,
          ),
          SwitchListTile(
            title: const Text('Ponte de narração nativa (TTS)'),
            subtitle: const Text(
                'Substitui speechSynthesis para funcionar em Android TV.'),
            value: config.ttsBridgeEnabled,
            onChanged: notifier.setTtsBridgeEnabled,
          ),
          SwitchListTile(
            title: const Text('Travar no domínio inicial'),
            subtitle:
                const Text('Bloqueia navegação para fora do site carregado.'),
            value: config.lockToInitialOrigin,
            onChanged: notifier.setLockToInitialOrigin,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('PIN de saída do kiosque'),
            subtitle: Text(config.exitPinHash == null
                ? 'Sem PIN (saída livre via gesto)'
                : 'PIN definido'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editPin(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpar dados do site'),
            subtitle: const Text('Remove cookies e cache (apaga o login).'),
            onTap: () async {
              await ref.read(storageServiceProvider).clearSiteData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados do site limpos.')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Ir para a tela inicial'),
            onTap: () => context.go('/home'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPin(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _SetPinDialog(),
    );
    if (result != null) {
      await ref.read(kioskConfigProvider.notifier).setExitPin(result);
    }
  }
}

/// Diálogo para definir/alterar o PIN de saída.
///
/// Na Android TV o `TextField` "prende" o D-pad (as setas movem o cursor do
/// texto e nunca saem do campo), e ao fechar o teclado virtual o foco fica
/// perdido. Por isso este diálogo:
/// - mapeia setas cima/baixo para mover o FOCO para fora do campo;
/// - ao fechar o IME, devolve o foco para o botão Salvar;
/// - permite confirmar direto pelo botão "concluir" (done) do teclado.
class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _saveFocus = FocusNode();
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fieldFocus.onKeyEvent = (node, event) {
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
    _fieldFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      final keyboardClosed = _lastBottomInset > 0 && bottom == 0;
      _lastBottomInset = bottom;
      if (keyboardClosed) {
        _fieldFocus.unfocus();
        _saveFocus.requestFocus();
      }
    });
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir PIN de saída'),
      content: TextField(
        controller: _controller,
        focusNode: _fieldFocus,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'Deixe vazio para remover o PIN',
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          focusNode: _saveFocus,
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
