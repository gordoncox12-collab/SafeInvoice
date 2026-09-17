package app.safeinvoice.ui.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import app.safeinvoice.SafeInvoiceApp
import app.safeinvoice.di.AppContainer

object Routes {
    const val HOME = "home"
    const val INVOICES = "invoices"
    const val CUSTOMERS = "customers"
    const val MORE = "more"
    const val BUSINESS_EDIT = "business/{id}"
    const val CUSTOMER_EDIT = "customerEdit/{id}"
    const val CUSTOMER_DETAIL = "customer/{id}"
    const val INVOICE_EDIT = "invoice/{id}"
    const val INVOICE_VIEW = "invoiceView/{id}"
    const val SIGNATURE = "signature/{id}"
    const val EXCEL = "excel"
    const val SETTINGS = "settings"
    const val TEMPLATES = "templates"
    const val TEMPLATE_EDIT = "template/{id}"
    const val TRANSACTIONS = "transactions"
    const val TRANSACTION_EDIT = "transaction/new"
    const val NOTE_EDIT = "note/{customerId}/{noteId}"
    const val FOLDER = "folder/{customerId}/{type}"
    const val SHEET_CAPTURE = "sheet/{customerId}"
}

fun businessEdit(id: String) = "business/$id"
fun customerEdit(id: String) = "customerEdit/$id"
fun customerDetail(id: String) = "customer/$id"
fun invoiceEdit(id: String) = "invoice/$id"
fun invoiceView(id: String) = "invoiceView/$id"
fun signature(id: String) = "signature/$id"
fun templateEdit(id: String) = "template/$id"
fun noteEdit(customerId: String, noteId: String) = "note/$customerId/$noteId"
fun folder(customerId: String, type: String) = "folder/$customerId/$type"
fun sheetCapture(customerId: String) = "sheet/$customerId"

@Composable
fun rememberAppContainer(): AppContainer {
    val context = LocalContext.current
    return remember(context) { (context.applicationContext as SafeInvoiceApp).container }
}

@Composable
inline fun <reified VM : ViewModel> appModel(crossinline create: (AppContainer) -> VM): VM {
    val container = rememberAppContainer()
    return viewModel(
        factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = create(container) as T
        },
    )
}
