package app.safeinvoice.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.navigation.NavHostController
import app.safeinvoice.data.entity.BusinessEntity
import app.safeinvoice.data.entity.CustomerEntity
import app.safeinvoice.data.entity.FolderType
import app.safeinvoice.data.entity.NoteEntity
import app.safeinvoice.ui.components.LabeledField
import app.safeinvoice.ui.components.SectionTitle
import app.safeinvoice.ui.nav.AppViewModel
import app.safeinvoice.ui.nav.customerEdit
import app.safeinvoice.ui.nav.folder
import app.safeinvoice.ui.nav.invoiceEdit
import app.safeinvoice.ui.nav.invoiceView
import app.safeinvoice.ui.nav.noteEdit
import app.safeinvoice.ui.nav.rememberAppContainer
import app.safeinvoice.ui.nav.sheetCapture
import app.safeinvoice.util.Za
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusinessEditScreen(id: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var trading by remember { mutableStateOf("") }
    var reg by remember { mutableStateOf("") }
    var vat by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var province by remember { mutableStateOf("") }
    var postal by remember { mutableStateOf("") }
    var bank by remember { mutableStateOf("") }
    var accountName by remember { mutableStateOf("") }
    var accountNo by remember { mutableStateOf("") }
    var branch by remember { mutableStateOf("") }
    var prefix by remember { mutableStateOf("INV") }
    var currency by remember { mutableStateOf("ZAR") }
    var vatPct by remember { mutableStateOf("15") }
    var existing by remember { mutableStateOf<BusinessEntity?>(null) }

    LaunchedEffect(id) {
        if (id != "new") {
            repo.getBusiness(id)?.let { b ->
                existing = b
                name = b.name; trading = b.tradingName.orEmpty(); reg = b.registrationNumber.orEmpty()
                vat = b.vatNumber.orEmpty(); email = b.email; phone = b.phone
                address = b.addressLine1; city = b.city; province = b.province; postal = b.postalCode
                bank = b.bankName.orEmpty(); accountName = b.bankAccountName.orEmpty()
                accountNo = b.bankAccountNumber.orEmpty(); branch = b.bankBranchCode.orEmpty()
                prefix = b.invoicePrefix; currency = b.defaultCurrency; vatPct = b.defaultVatPercent.toString()
            }
        }
    }

    Scaffold(topBar = { BackBar(if (id == "new") "New business" else "Edit business", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            LabeledField("Business name", name, { name = it })
            LabeledField("Trading name", trading, { trading = it })
            LabeledField("Registration (CIPC)", reg, { reg = it })
            LabeledField("VAT number", vat, { vat = it })
            LabeledField("Email", email, { email = it }, keyboardType = KeyboardType.Email)
            LabeledField("Phone", phone, { phone = it }, keyboardType = KeyboardType.Phone)
            LabeledField("Address", address, { address = it })
            LabeledField("City", city, { city = it })
            LabeledField("Province", province, { province = it })
            LabeledField("Postal code", postal, { postal = it })
            LabeledField("Bank", bank, { bank = it })
            LabeledField("Account name", accountName, { accountName = it })
            LabeledField("Account number", accountNo, { accountNo = it })
            LabeledField("Branch code", branch, { branch = it })
            LabeledField("Invoice prefix", prefix, { prefix = it })
            LabeledField("Currency", currency, { currency = it })
            LabeledField("Default VAT %", vatPct, { vatPct = it }, keyboardType = KeyboardType.Decimal)
            Spacer(Modifier.height(8.dp))
            Button(onClick = {
                scope.launch {
                    val now = System.currentTimeMillis()
                    val entity = (existing ?: BusinessEntity(
                        id = Za.newId(),
                        name = name,
                        tradingName = trading.ifBlank { null },
                        registrationNumber = reg.ifBlank { null },
                        vatNumber = vat.ifBlank { null },
                        email = email,
                        phone = phone,
                        addressLine1 = address,
                        addressLine2 = null,
                        city = city,
                        province = province,
                        postalCode = postal,
                        country = "South Africa",
                        bankName = bank.ifBlank { null },
                        bankAccountName = accountName.ifBlank { null },
                        bankAccountNumber = accountNo.ifBlank { null },
                        bankBranchCode = branch.ifBlank { null },
                        logoPath = null,
                        defaultCurrency = currency.ifBlank { "ZAR" },
                        defaultVatPercent = vatPct.toDoubleOrNull() ?: 15.0,
                        invoicePrefix = prefix.ifBlank { "INV" },
                        nextInvoiceNumber = 1,
                        createdAt = now,
                        updatedAt = now,
                    )).copy(
                        name = name,
                        tradingName = trading.ifBlank { null },
                        registrationNumber = reg.ifBlank { null },
                        vatNumber = vat.ifBlank { null },
                        email = email,
                        phone = phone,
                        addressLine1 = address,
                        city = city,
                        province = province,
                        postalCode = postal,
                        bankName = bank.ifBlank { null },
                        bankAccountName = accountName.ifBlank { null },
                        bankAccountNumber = accountNo.ifBlank { null },
                        bankBranchCode = branch.ifBlank { null },
                        defaultCurrency = currency.ifBlank { "ZAR" },
                        defaultVatPercent = vatPct.toDoubleOrNull() ?: 15.0,
                        invoicePrefix = prefix.ifBlank { "INV" },
                    )
                    repo.saveBusiness(entity)
                    appVm.selectBusiness(entity.id)
                    nav.popBackStack()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Save") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerEditScreen(id: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var contact by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var province by remember { mutableStateOf("") }
    var postal by remember { mutableStateOf("") }
    var vat by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var existing by remember { mutableStateOf<CustomerEntity?>(null) }

    LaunchedEffect(id) {
        if (id != "new") {
            repo.getCustomer(id)?.let { c ->
                existing = c
                name = c.name; contact = c.contactName.orEmpty(); email = c.email.orEmpty()
                phone = c.phone.orEmpty(); address = c.addressLine1.orEmpty(); city = c.city.orEmpty()
                province = c.province.orEmpty(); postal = c.postalCode.orEmpty()
                vat = c.vatNumber.orEmpty(); notes = c.notes.orEmpty()
            }
        }
    }

    Scaffold(topBar = { BackBar(if (id == "new") "New customer" else "Edit customer", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            LabeledField("Customer name", name, { name = it })
            LabeledField("Contact", contact, { contact = it })
            LabeledField("Email", email, { email = it }, keyboardType = KeyboardType.Email)
            LabeledField("Phone", phone, { phone = it }, keyboardType = KeyboardType.Phone)
            LabeledField("Address", address, { address = it })
            LabeledField("City", city, { city = it })
            LabeledField("Province", province, { province = it })
            LabeledField("Postal code", postal, { postal = it })
            LabeledField("VAT number", vat, { vat = it })
            LabeledField("Notes", notes, { notes = it }, singleLine = false, minLines = 3)
            Button(
                enabled = business != null && name.isNotBlank(),
                onClick = {
                    val biz = business ?: return@Button
                    scope.launch {
                        val now = System.currentTimeMillis()
                        val entity = (existing ?: CustomerEntity(
                            id = Za.newId(),
                            businessId = biz.id,
                            name = name,
                            contactName = contact.ifBlank { null },
                            email = email.ifBlank { null },
                            phone = phone.ifBlank { null },
                            addressLine1 = address.ifBlank { null },
                            city = city.ifBlank { null },
                            province = province.ifBlank { null },
                            postalCode = postal.ifBlank { null },
                            vatNumber = vat.ifBlank { null },
                            notes = notes.ifBlank { null },
                            createdAt = now,
                            updatedAt = now,
                        )).copy(
                            name = name,
                            contactName = contact.ifBlank { null },
                            email = email.ifBlank { null },
                            phone = phone.ifBlank { null },
                            addressLine1 = address.ifBlank { null },
                            city = city.ifBlank { null },
                            province = province.ifBlank { null },
                            postalCode = postal.ifBlank { null },
                            vatNumber = vat.ifBlank { null },
                            notes = notes.ifBlank { null },
                        )
                        repo.saveCustomer(entity)
                        nav.popBackStack()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerDetailScreen(id: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val customer by repo.customer(id).collectAsState(initial = null)
    val invoices by repo.invoicesForCustomer(id).collectAsState(initial = emptyList())
    val notes by repo.notes(id).collectAsState(initial = emptyList())
    val files by repo.allFiles(id).collectAsState(initial = emptyList())
    val c = customer
    Scaffold(topBar = { BackBar(c?.name ?: "Customer", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (c != null) {
                Text(listOfNotNull(c.contactName, c.email, c.phone, c.city).joinToString(" · "))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { nav.navigate(customerEdit(id)) }) { Text("Edit") }
                    Button(onClick = { nav.navigate(invoiceEdit("new:$id")) }) { Text("New invoice") }
                }
                SectionTitle("Folders")
                FolderType.entries.forEach { type ->
                    val count = files.count { it.folderType == type.name }
                    Card(onClick = { nav.navigate(folder(id, type.name)) }, modifier = Modifier.fillMaxWidth()) {
                        ListItem(
                            headlineContent = { Text(type.name.lowercase().replaceFirstChar { it.titlecase() }) },
                            supportingContent = { Text("$count file(s) on this device") },
                        )
                    }
                }
                FilledTonalButton(onClick = { nav.navigate(sheetCapture(id)) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Capture Excel / CSV sheet")
                }
                SectionTitle("Invoices")
                invoices.take(8).forEach { inv ->
                    InvoiceRow(inv, c.name) { nav.navigate(invoiceView(inv.id)) }
                }
                SectionTitle("Notes")
                Button(onClick = { nav.navigate(noteEdit(id, "new")) }) { Text("Add note") }
                notes.forEach { n ->
                    Card(onClick = { nav.navigate(noteEdit(id, n.id)) }, modifier = Modifier.fillMaxWidth()) {
                        ListItem(headlineContent = { Text(n.title) }, supportingContent = { Text(n.body.take(80)) })
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteEditScreen(customerId: String, noteId: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    LaunchedEffect(noteId) {
        if (noteId != "new") {
            repo.getNote(noteId)?.let { n ->
                title = n.title
                body = n.body
            }
        }
    }
    Scaffold(topBar = { BackBar("Note", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            LabeledField("Title", title, { title = it })
            LabeledField("Body", body, { body = it }, singleLine = false, minLines = 8)
            Button(onClick = {
                val biz = business ?: return@Button
                scope.launch {
                    repo.saveNote(
                        NoteEntity(
                            id = if (noteId == "new") Za.newId() else noteId,
                            businessId = biz.id,
                            customerId = customerId,
                            title = title.ifBlank { "Note" },
                            body = body,
                            createdAt = System.currentTimeMillis(),
                            updatedAt = System.currentTimeMillis(),
                        ),
                    )
                    nav.popBackStack()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Save to customer notes folder") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FolderScreen(customerId: String, typeName: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val type = runCatching { FolderType.valueOf(typeName) }.getOrDefault(FolderType.INVOICES)
    val files by repo.files(customerId, type).collectAsState(initial = emptyList())
    val customer by repo.customer(customerId).collectAsState(initial = null)
    val share = rememberAppContainer().share
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null && customer != null) {
            val name = uri.lastPathSegment?.substringAfterLast('/') ?: "file"
            scope.launch { repo.importFile(customer!!.businessId, customerId, type, uri, name) }
        }
    }
    Scaffold(topBar = { BackBar(type.name.lowercase().replaceFirstChar { it.titlecase() }, nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("${files.size} file(s) stored under this business / customer on this device.")
            Button(onClick = { picker.launch(arrayOf("*/*")) }, modifier = Modifier.fillMaxWidth()) { Text("Add file from device") }
            if (files.isEmpty()) {
                Text(
                    "This folder is empty. Add invoices, receipts, spreadsheets, images or notes — they stay on the phone.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            files.forEach { f ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        ListItem(
                            headlineContent = { Text(f.displayName) },
                            supportingContent = { Text("${f.mimeType} · ${f.sizeBytes} bytes") },
                        )
                        Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = {
                                scope.launch {
                                    val file = repo.resolveFile(f.relativePath)
                                    if (file.exists()) {
                                        val uri = FileProvider.getUriForFile(
                                            context,
                                            "${context.packageName}.fileprovider",
                                            file,
                                        )
                                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                            setDataAndType(uri, f.mimeType)
                                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        context.startActivity(android.content.Intent.createChooser(intent, f.displayName))
                                    }
                                }
                            }) { Text("Open") }
                            OutlinedButton(onClick = {
                                scope.launch {
                                    val file = repo.resolveFile(f.relativePath)
                                    if (file.exists()) share.emailFile(file, f.displayName, "Please find ${f.displayName} attached.", customer?.email)
                                }
                            }) { Text("Email") }
                            OutlinedButton(onClick = {
                                scope.launch {
                                    val file = repo.resolveFile(f.relativePath)
                                    if (file.exists()) share.whatsappFile(file, f.displayName)
                                }
                            }) { Text("WhatsApp") }
                            IconButton(onClick = { scope.launch { repo.deleteFolderFile(f) } }) {
                                Icon(Icons.Default.Delete, contentDescription = "Delete")
                            }
                        }
                    }
                }
            }
        }
    }
}
