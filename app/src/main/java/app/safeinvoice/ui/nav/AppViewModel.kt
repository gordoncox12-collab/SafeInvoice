package app.safeinvoice.ui.nav

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.entity.InvoiceStatus
import app.safeinvoice.data.entity.ThemeMode
import app.safeinvoice.data.repo.InvoiceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AppViewModel(private val repo: InvoiceRepository) : ViewModel() {
    private val _hydrated = MutableStateFlow(false)
    val hydrated = _hydrated.asStateFlow()

    val settings = repo.settings.stateIn(viewModelScope, SharingStarted.Eagerly, AppSettingsEntity(activeBusinessId = null))
    val businesses = repo.businesses
        .onEach { _hydrated.value = true }
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val activeBusiness = combine(settings, businesses) { s, list ->
        list.firstOrNull { it.id == s.activeBusinessId } ?: list.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun selectBusiness(id: String) = viewModelScope.launch { repo.saveSettings(businessId = id) }
    fun setTheme(mode: ThemeMode) = viewModelScope.launch { repo.saveSettings(themeMode = mode) }
    fun setAccent(palette: AccentPalette) = viewModelScope.launch { repo.saveSettings(accent = palette) }

    fun invoices(businessId: String) = repo.invoices(businessId)
    fun customers(businessId: String) = repo.customers(businessId)
    fun transactions(businessId: String) = repo.transactions(businessId)

    fun outstanding(invoices: List<app.safeinvoice.data.entity.InvoiceEntity>): Double =
        invoices.filter { it.status == InvoiceStatus.SENT.name || it.status == InvoiceStatus.OVERDUE.name }
            .sumOf { it.total }

    val repository: InvoiceRepository get() = repo
}
