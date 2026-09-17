import 'package:flutter/material.dart';

import '../domain/models.dart';

class Palette {
  const Palette(this.name, this.key, this.primary, this.secondary, this.tertiary);

  final String name;
  final AccentPalette key;
  final Color primary;
  final Color secondary;
  final Color tertiary;
}

const palettes = <Palette>[
  Palette('Forest', AccentPalette.forest, Color(0xFF0F766E), Color(0xFFD4A017), Color(0xFF1D4ED8)),
  Palette('Navy', AccentPalette.navy, Color(0xFF1E3A5F), Color(0xFF0F766E), Color(0xFFD4A017)),
  Palette('Emerald', AccentPalette.emerald, Color(0xFF047857), Color(0xFF1E3A5F), Color(0xFFB45309)),
  Palette('Amber', AccentPalette.amber, Color(0xFFB45309), Color(0xFF0F766E), Color(0xFF7C2D12)),
  Palette('Rose', AccentPalette.rose, Color(0xFF9F1239), Color(0xFF0F766E), Color(0xFF1E3A5F)),
  Palette('Slate', AccentPalette.slate, Color(0xFF334155), Color(0xFF0F766E), Color(0xFFD4A017)),
  Palette('Indigo', AccentPalette.indigo, Color(0xFF3730A3), Color(0xFF0F766E), Color(0xFFD4A017)),
  Palette('Teal', AccentPalette.teal, Color(0xFF0E7490), Color(0xFFD4A017), Color(0xFF047857)),
];

Palette paletteOf(AccentPalette key) => palettes.firstWhere((p) => p.key == key);

ThemeData safeInvoiceTheme({
  required ThemeModeOption mode,
  required AccentPalette accent,
  required Brightness platformBrightness,
}) {
  final palette = paletteOf(accent);
  final dark = switch (mode) {
    ThemeModeOption.light => false,
    ThemeModeOption.dark => true,
    ThemeModeOption.system => platformBrightness == Brightness.dark,
  };
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: palette.primary,
    secondary: palette.secondary,
    tertiary: palette.tertiary,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? scheme.surface : palette.primary,
      foregroundColor: dark ? scheme.onSurface : Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.secondary,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: palette.primary.withValues(alpha: 0.18),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
