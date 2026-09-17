package app.safeinvoice

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.entity.ThemeMode
import app.safeinvoice.ui.screens.SafeInvoiceRoot
import app.safeinvoice.ui.theme.SafeInvoiceTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as SafeInvoiceApp
        setContent {
            val settings by app.container.repo.settings.collectAsState(
                initial = AppSettingsEntity(activeBusinessId = null),
            )
            val mode = runCatching { ThemeMode.valueOf(settings.themeMode) }.getOrDefault(ThemeMode.SYSTEM)
            val accent = runCatching { AccentPalette.valueOf(settings.accentPalette) }.getOrDefault(AccentPalette.FOREST)
            SafeInvoiceTheme(themeMode = mode, accent = accent) {
                SafeInvoiceRoot(app.container)
            }
        }
    }
}
