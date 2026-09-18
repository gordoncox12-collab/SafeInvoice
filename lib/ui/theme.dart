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
  Palette('Forest', AccentPalette.forest, Color(0xFF0D9488), Color(0xFFF59E0B), Color(0xFF2563EB)),
  Palette('Navy', AccentPalette.navy, Color(0xFF1D4ED8), Color(0xFF06B6D4), Color(0xFFF97316)),
  Palette('Emerald', AccentPalette.emerald, Color(0xFF10B981), Color(0xFF6366F1), Color(0xFFF59E0B)),
  Palette('Amber', AccentPalette.amber, Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF0D9488)),
  Palette('Rose', AccentPalette.rose, Color(0xFFF43F5E), Color(0xFF8B5CF6), Color(0xFF22C55E)),
  Palette('Slate', AccentPalette.slate, Color(0xFF3B82F6), Color(0xFF14B8A6), Color(0xFFF97316)),
  Palette('Indigo', AccentPalette.indigo, Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF22D3EE)),
  Palette('Teal', AccentPalette.teal, Color(0xFF14B8A6), Color(0xFFF97316), Color(0xFF8B5CF6)),
  Palette('Coral', AccentPalette.coral, Color(0xFFFF5A36), Color(0xFF2563EB), Color(0xFFFBBF24)),
  Palette('Magenta', AccentPalette.magenta, Color(0xFFE11D8C), Color(0xFF7C3AED), Color(0xFF22C55E)),
  Palette('Violet', AccentPalette.violet, Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF43F5E)),
  Palette('Azure', AccentPalette.azure, Color(0xFF2563EB), Color(0xFFF59E0B), Color(0xFFEC4899)),
  Palette('Tangerine', AccentPalette.tangerine, Color(0xFFF97316), Color(0xFF0EA5E9), Color(0xFFA855F7)),
  Palette('Fuchsia', AccentPalette.fuchsia, Color(0xFFD946EF), Color(0xFF22C55E), Color(0xFF0EA5E9)),
  Palette('Sunshine', AccentPalette.sunshine, Color(0xFFEAB308), Color(0xFFEF4444), Color(0xFF3B82F6)),
  Palette('Electric', AccentPalette.electric, Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFFF59E0B)),
  Palette('Crimson', AccentPalette.crimson, Color(0xFFE11D48), Color(0xFFF59E0B), Color(0xFF6366F1)),
  Palette('Mint', AccentPalette.mint, Color(0xFF22C55E), Color(0xFF0EA5E9), Color(0xFFF43F5E)),
];

Palette paletteOf(AccentPalette key) => palettes.firstWhere(
      (p) => p.key == key,
      orElse: () => palettes.first,
    );

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
    chipTheme: ChipThemeData(
      selectedColor: palette.primary.withValues(alpha: 0.22),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}

class ThemeLivePreview extends StatelessWidget {
  const ThemeLivePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SafeInvoice',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 4),
                Text(
                  'INV-2026-0001  ·  live preview',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  title: const Text('Consulting hour'),
                  subtitle: const Text('Catalog line · VAT on'),
                  trailing: Text('R 1 150,00', style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('Save invoice')),
                    FilledButton.tonal(onPressed: () {}, child: const Text('PDF')),
                    OutlinedButton(onPressed: () {}, child: const Text('Share')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
