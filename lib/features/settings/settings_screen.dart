import 'package:flutter/material.dart';
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
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Definir PIN de saída'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Deixe vazio para remover o PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(kioskConfigProvider.notifier).setExitPin(result);
    }
  }
}
