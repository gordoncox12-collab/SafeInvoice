package app.safeinvoice.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.ThemeMode

data class Palette(
    val name: String,
    val key: AccentPalette,
    val primary: Color,
    val secondary: Color,
    val tertiary: Color,
)

val Palettes = listOf(
    Palette("Forest", AccentPalette.FOREST, Color(0xFF0F766E), Color(0xFFD4A017), Color(0xFF1D4ED8)),
    Palette("Navy", AccentPalette.NAVY, Color(0xFF1E3A5F), Color(0xFF0F766E), Color(0xFFD4A017)),
    Palette("Emerald", AccentPalette.EMERALD, Color(0xFF047857), Color(0xFF1E3A5F), Color(0xFFB45309)),
    Palette("Amber", AccentPalette.AMBER, Color(0xFFB45309), Color(0xFF0F766E), Color(0xFF7C2D12)),
    Palette("Rose", AccentPalette.ROSE, Color(0xFF9F1239), Color(0xFF0F766E), Color(0xFF1E3A5F)),
    Palette("Slate", AccentPalette.SLATE, Color(0xFF334155), Color(0xFF0F766E), Color(0xFFD4A017)),
    Palette("Indigo", AccentPalette.INDIGO, Color(0xFF3730A3), Color(0xFF0F766E), Color(0xFFD4A017)),
    Palette("Teal", AccentPalette.TEAL, Color(0xFF0E7490), Color(0xFFD4A017), Color(0xFF047857)),
)

private fun light(p: Palette) = lightColorScheme(
    primary = p.primary,
    onPrimary = Color.White,
    primaryContainer = p.primary.copy(alpha = 0.14f),
    onPrimaryContainer = p.primary,
    secondary = p.secondary,
    onSecondary = Color.White,
    tertiary = p.tertiary,
    background = Color(0xFFF4F7F6),
    surface = Color(0xFFFBFCFB),
    surfaceVariant = Color(0xFFE4EEEC),
    onBackground = Color(0xFF15201E),
    onSurface = Color(0xFF15201E),
    outline = Color(0xFF849490),
)

private fun dark(p: Palette) = darkColorScheme(
    primary = p.primary.copy(
        red = (p.primary.red + 0.16f).coerceAtMost(1f),
        green = (p.primary.green + 0.12f).coerceAtMost(1f),
        blue = (p.primary.blue + 0.10f).coerceAtMost(1f),
    ),
    onPrimary = Color(0xFF06201C),
    primaryContainer = p.primary.copy(alpha = 0.35f),
    secondary = p.secondary,
    tertiary = p.tertiary,
    background = Color(0xFF101816),
    surface = Color(0xFF18221F),
    surfaceVariant = Color(0xFF24302C),
    onBackground = Color(0xFFE8F0EE),
    onSurface = Color(0xFFE8F0EE),
    outline = Color(0xFF7A8A84),
)

fun paletteOf(key: AccentPalette): Palette = Palettes.first { it.key == key }

@Composable
fun SafeInvoiceTheme(
    themeMode: ThemeMode,
    accent: AccentPalette,
    content: @Composable () -> Unit,
) {
    val palette = paletteOf(accent)
    val dark = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }
    val scheme: ColorScheme = if (dark) dark(palette) else light(palette)
    MaterialTheme(colorScheme = scheme, content = content)
}
