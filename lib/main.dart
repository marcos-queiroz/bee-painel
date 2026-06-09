import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'application/providers.dart';
import 'services/kiosk/kiosk_mode_service.dart';
import 'services/platform/platform_info.dart';
import 'services/webview/webview_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await KioskModeService.ensureDesktopWindow();
  await initWebViewEnvironment();

  final prefs = await SharedPreferences.getInstance();
  final isAndroidTv = await PlatformInfo.isAndroidTv();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isAndroidTvProvider.overrideWithValue(isAndroidTv),
      ],
      child: const _Initializer(child: ASAPainelApp()),
    ),
  );
}

/// Inicializa serviços que dependem do container Riverpod após o primeiro frame.
class _Initializer extends ConsumerStatefulWidget {
  const _Initializer({required this.child});
  final Widget child;

  @override
  ConsumerState<_Initializer> createState() => _InitializerState();
}

class _InitializerState extends ConsumerState<_Initializer> {
  @override
  void initState() {
    super.initState();
    ref.read(ttsServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
