import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Overlay amigável exibido quando o carregamento falha (rede/offline).
class ErrorOverlay extends StatelessWidget {
  const ErrorOverlay({
    super.key,
    required this.message,
    required this.retryInSeconds,
    required this.onRetryNow,
  });

  final String message;
  final int retryInSeconds;
  final VoidCallback onRetryNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.honey, size: 72),
          const SizedBox(height: 24),
          Text(
            'Não foi possível carregar o painel',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('Nova tentativa em ${retryInSeconds}s…',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetryNow,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar agora'),
          ),
        ],
      ),
    );
  }
}
