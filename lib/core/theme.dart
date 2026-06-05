import 'package:flutter/material.dart';

/// Tema do BeePainel — identidade "abelha" (amarelo/âmbar sobre fundo escuro),
/// otimizado para leitura de longe (10-foot UI em TV).
class AppTheme {
  AppTheme._();

  static const Color honey = Color(0xFFF5C518);
  static const Color amber = Color(0xFFFFB300);
  static const Color ink = Color(0xFF11151C);
  static const Color surface = Color(0xFF1B2230);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: honey,
      brightness: Brightness.dark,
    ).copyWith(
      primary: honey,
      secondary: amber,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      fontFamily: 'Roboto',
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}
