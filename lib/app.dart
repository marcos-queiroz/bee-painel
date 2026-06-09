import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'application/providers.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/kiosk/kiosk_screen.dart';
import 'features/settings/settings_screen.dart';

class ASAPainelApp extends ConsumerWidget {
  const ASAPainelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _buildRouter(ref);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final config = ref.read(kioskConfigProvider);
            if (config.autoStart && config.hasPinnedUrl) {
              return '/kiosk?url=${Uri.encodeComponent(config.pinnedUrl!)}';
            }
            return '/home';
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/kiosk',
          builder: (context, state) {
            final url = state.uri.queryParameters['url'] ?? '';
            return KioskScreen(url: Uri.decodeComponent(url));
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
