package app.safeinvoice.ui.screens

import android.graphics.Bitmap
import android.graphics.Paint
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import app.safeinvoice.data.entity.InvoiceEntity
import app.safeinvoice.data.entity.InvoiceLineItemEntity
import app.safeinvoice.data.entity.InvoiceStatus
import app.safeinvoice.ui.components.LabeledField
import app.safeinvoice.ui.components.MoneyText
import app.safeinvoice.ui.components.SectionTitle
import app.safeinvoice.ui.components.StatusChip
import app.safeinvoice.ui.nav.AppViewModel
import app.safeinvoice.ui.nav.customerEdit
import app.safeinvoice.ui.nav.invoiceEdit
import app.safeinvoice.ui.nav.rememberAppContainer
import app.safeinvoice.ui.nav.signature
import app.safeinvoice.util.Money
import app.safeinvoice.util.Za
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceEditorScreen(rawId: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val customers by (business?.let { appVm.customers(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
        .collectAsState(initial = emptyList())
    val templates by (business?.let { repo.templates(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
        .collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val preselectCustomer = rawId.substringAfter("new:", missingDelimiterValue = "").takeIf { rawId.startsWith("new:") && it.isNotBlank() }
    val isNew = rawId == "new" || rawId.startsWith("new:")

    var invoiceId by remember { mutableStateOf(if (isNew) Za.newId() else rawId) }
    var number by remember { mutableStateOf("") }
    var status by remember { mutableStateOf(InvoiceStatus.DRAFT.name) }
    var customerId by remember { mutableStateOf(preselectCustomer.orEmpty()) }
    var currency by remember { mutableStateOf("ZAR") }
    var vatPercent by remember { mutableStateOf("15") }
    var discountAmount by remember { mutableStateOf("0") }
    var discountPercent by remember { mutableStateOf("0") }
    var notes by remember { mutableStateOf("") }
    var terms by remember { mutableStateOf("Payment due within 30 days.") }
    var templateId by remember { mutableStateOf<String?>(null) }
    var bumpNumber by remember { mutableStateOf(isNew) }
    var loaded by remember { mutableStateOf(false) }
    val items = remember { mutableStateListOf<InvoiceLineItemEntity>() }

    LaunchedEffect(rawId, business?.id) {
        val biz = business ?: return@LaunchedEffect
        if (!isNew && !loaded) {
            repo.getInvoice(rawId)?.let { details ->
                invoiceId = details.invoice.id
                number = details.invoice.number
                status = details.invoice.status
                customerId = details.invoice.customerId
                currency = details.invoice.currency
                vatPercent = details.invoice.vatPercent.toString()
                discountAmount = details.invoice.discountAmount.toString()
                discountPercent = details.invoice.discountPercent.toString()
                notes = details.invoice.notes.orEmpty()
                terms = details.invoice.terms.orEmpty()
                templateId = details.invoice.templateId
                items.clear()
                items.addAll(details.items)
                bumpNumber = false
                loaded = true
            }
        } else if (isNew && !loaded) {
            val (n, _) = repo.nextInvoiceNumber(biz)
            number = n
            currency = biz.defaultCurrency
            vatPercent = biz.defaultVatPercent.toString()
            templateId = repo.defaultTemplate(biz.id)?.id
            if (items.isEmpty()) {
                items.add(InvoiceLineItemEntity(Za.newId(), invoiceId, 0, "", 1.0, 0.0, true))
            }
            loaded = true
        }
    }

    val totals = Money.totals(
        items.map { Money.lineTotal(it.quantity, it.unitPrice) },
        discountAmount.toDoubleOrNull() ?: 0.0,
        discountPercent.toDoubleOrNull() ?: 0.0,
        vatPercent.toDoubleOrNull() ?: 15.0,
    )

    suspend fun persist(): InvoiceEntity? {
        val biz = business ?: return null
        val cid = customerId.ifBlank { return null }
        val previous = repo.getInvoice(invoiceId)?.invoice
        val invoice = InvoiceEntity(
            id = invoiceId,
            businessId = biz.id,
            customerId = cid,
            number = number,
            status = status,
            issueDate = previous?.issueDate ?: Za.todayMillis(),
            dueDate = previous?.dueDate ?: Za.plusDays(Za.todayMillis(), 30),
            currency = currency.ifBlank { "ZAR" },
            vatPercent = vatPercent.toDoubleOrNull() ?: 15.0,
            discountAmount = discountAmount.toDoubleOrNull() ?: 0.0,
            discountPercent = discountPercent.toDoubleOrNull() ?: 0.0,
            notes = notes.ifBlank { null },
            terms = terms.ifBlank { null },
            signaturePath = repo.getInvoice(invoiceId)?.invoice?.signaturePath,
            pdfPath = repo.getInvoice(invoiceId)?.invoice?.pdfPath,
            templateId = templateId,
            subtotal = totals.subtotal,
            vatAmount = totals.vat,
            total = totals.total,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
        )
        val saved = repo.saveInvoice(
            invoice,
            items.mapIndexed { idx, item -> item.copy(invoiceId = invoiceId, position = idx) },
            bumpNumber = bumpNumber,
        )
        bumpNumber = false
        return saved
    }

    Scaffold(topBar = { BackBar(if (isNew) "New invoice" else number, nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (customers.isEmpty()) {
                Text("Add a customer before you can invoice. Nothing is pre-filled — this is your live book.")
                Button(onClick = { nav.navigate(customerEdit("new")) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Add customer")
                }
            }
            DropdownField("Customer", customers.map { it.id to it.name }, customerId) { customerId = it }
            LabeledField("Number", number, { number = it })
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
                InvoiceStatus.entries.filter { it != InvoiceStatus.CANCELLED }.forEach { s ->
                    FilterChip(selected = status == s.name, onClick = { status = s.name }, label = { Text(s.name.lowercase().replaceFirstChar { it.titlecase() }) })
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LabeledField("Currency", currency, { currency = it }, modifier = Modifier.weight(1f))
                LabeledField("VAT %", vatPercent, { vatPercent = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LabeledField("Discount R", discountAmount, { discountAmount = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
                LabeledField("Discount %", discountPercent, { discountPercent = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            }
            if (templates.isNotEmpty()) {
                DropdownField("Template", templates.map { it.id to it.name }, templateId.orEmpty()) { templateId = it }
            }
            SectionTitle("Line items")
            items.forEachIndexed { idx, item ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row {
                            OutlinedTextField(
                                value = item.description,
                                onValueChange = { items[idx] = item.copy(description = it) },
                                label = { Text("Description") },
                                modifier = Modifier.weight(1f),
                            )
                            IconButton(onClick = { items.removeAt(idx) }) { Icon(Icons.Default.Delete, "Remove") }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = item.quantity.toString(),
                                onValueChange = { items[idx] = item.copy(quantity = it.toDoubleOrNull() ?: 0.0) },
                                label = { Text("Qty") },
                                modifier = Modifier.weight(1f),
                            )
                            OutlinedTextField(
                                value = item.unitPrice.toString(),
                                onValueChange = { items[idx] = item.copy(unitPrice = it.toDoubleOrNull() ?: 0.0) },
                                label = { Text("Unit price") },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        Text("Line ${Za.money(Money.lineTotal(item.quantity, item.unitPrice), currency)}")
                    }
                }
            }
            OutlinedButton(onClick = {
                items.add(InvoiceLineItemEntity(Za.newId(), invoiceId, items.size, "", 1.0, 0.0, true))
            }) { Icon(Icons.Default.Add, null); Text("  Add line") }

            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Subtotal ${Za.money(totals.subtotal, currency)}")
                    if (totals.discount > 0) Text("Discount − ${Za.money(totals.discount, currency)}")
                    Text("VAT ${Za.money(totals.vat, currency)}")
                    Text("Total ${Za.money(totals.total, currency)}", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                }
            }
            LabeledField("Notes", notes, { notes = it }, singleLine = false, minLines = 2)
            LabeledField("Terms", terms, { terms = it }, singleLine = false, minLines = 2)
            Button(
                enabled = customerId.isNotBlank() && items.any { it.description.isNotBlank() },
                onClick = {
                    scope.launch {
                        val saved = persist()
                        if (saved != null) nav.popBackStack()
                        else Toast.makeText(context, "Choose a customer", Toast.LENGTH_SHORT).show()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save invoice") }
            FilledTonalButton(onClick = {
                scope.launch {
                    persist()
                    nav.navigate(signature(invoiceId))
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Capture signature") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DropdownField(label: String, options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val text = options.firstOrNull { it.first == selected }?.second ?: ""
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = text,
            onValueChange = {},
            readOnly = true,
            label = { Text(label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
            modifier = Modifier.menuAnchor().fillMaxWidth(),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (id, name) ->
                DropdownMenuItem(text = { Text(name) }, onClick = { onSelect(id); expanded = false })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceViewScreen(id: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val container = rememberAppContainer()
    val scope = rememberCoroutineScope()
    var invoice by remember { mutableStateOf<InvoiceEntity?>(null) }
    var customerName by remember { mutableStateOf("") }
    var lines by remember { mutableStateOf(listOf<InvoiceLineItemEntity>()) }
    var message by remember { mutableStateOf<String?>(null) }

    suspend fun reload() {
        val details = repo.getInvoice(id) ?: return
        invoice = details.invoice
        lines = details.items
        customerName = repo.getCustomer(details.invoice.customerId)?.name.orEmpty()
    }
    LaunchedEffect(id) { reload() }

    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        val inv = invoice ?: return@rememberLauncherForActivityResult
        if (uri != null) {
            scope.launch {
                repo.addInvoiceImage(inv, uri, uri.lastPathSegment?.substringAfterLast('/') ?: "image.jpg")
                message = "Image attached — it will print on the PDF"
            }
        }
    }

    val inv = invoice
    Scaffold(topBar = { BackBar(inv?.number ?: "Invoice", nav) }) { padding ->
        if (inv == null) {
            Text("Loading…", modifier = Modifier.padding(padding).padding(16.dp))
            return@Scaffold
        }
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Column {
                    Text(customerName, fontWeight = FontWeight.SemiBold)
                    Text("${Za.date(inv.issueDate)}  ·  due ${Za.date(inv.dueDate)}")
                }
                StatusChip(inv.status)
            }
            MoneyText(inv.total, inv.currency)
            lines.forEach { line ->
                ListItem(
                    headlineContent = { Text(line.description) },
                    supportingContent = { Text("${line.quantity} × ${Za.money(line.unitPrice, inv.currency)}") },
                    trailingContent = { Text(Za.money(Money.lineTotal(line.quantity, line.unitPrice), inv.currency)) },
                )
            }
            message?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
                OutlinedButton(onClick = { nav.navigate(invoiceEdit(inv.id)) }) { Text("Edit") }
                OutlinedButton(onClick = { nav.navigate(signature(inv.id)) }) { Text("Sign") }
                OutlinedButton(onClick = { imagePicker.launch("image/*") }) { Text("Insert picture") }
            }
            Button(onClick = {
                scope.launch {
                    val file = repo.generatePdf(inv.id)
                    message = if (file != null) "PDF saved to customer invoices folder" else "Could not build PDF"
                    reload()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Generate PDF") }
            FilledTonalButton(onClick = {
                scope.launch {
                    val file = repo.generatePdf(inv.id) ?: return@launch
                    val customer = repo.getCustomer(inv.customerId)
                    container.share.emailPdf(
                        file,
                        "Invoice ${inv.number} from ${(appVm.activeBusiness.value)?.name ?: "SafeInvoice"}",
                        "Please find invoice ${inv.number} attached. Total ${Za.money(inv.total, inv.currency)}.",
                        customer?.email,
                    )
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Share via Email") }
            FilledTonalButton(onClick = {
                scope.launch {
                    val file = repo.generatePdf(inv.id) ?: return@launch
                    container.share.whatsappPdf(
                        file,
                        "Invoice ${inv.number} — ${Za.money(inv.total, inv.currency)}",
                    )
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Share via WhatsApp") }
            OutlinedButton(onClick = {
                scope.launch {
                    repo.setStatus(inv.id, InvoiceStatus.SENT)
                    reload()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Mark sent") }
            Button(onClick = {
                scope.launch {
                    repo.recordPayment(inv, inv.total, "EFT", null)
                    reload()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Record payment (paid in full)") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignatureScreen(invoiceId: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val scope = rememberCoroutineScope()
    val strokes = remember { mutableStateListOf<Path>() }
    var current by remember { mutableStateOf<Path?>(null) }
    var canvasW by remember { mutableFloatStateOf(1f) }
    var canvasH by remember { mutableFloatStateOf(1f) }
    Scaffold(
        topBar = { BackBar("Signature", nav) },
    ) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).fillMaxSize()) {
            Text("Sign with your finger. This is stamped onto the invoice PDF.")
            Spacer(Modifier.height(12.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White)
                    .pointerInput(Unit) {
                        detectDragGestures(
                            onDragStart = { offset ->
                                current = Path().apply { moveTo(offset.x, offset.y) }
                            },
                            onDragEnd = {
                                current?.let { strokes.add(it) }
                                current = null
                            },
                            onDragCancel = { current = null },
                            onDrag = { change, _ ->
                                val p = current
                                if (p != null) {
                                    p.lineTo(change.position.x, change.position.y)
                                    current = Path().apply { addPath(p) }
                                }
                            },
                        )
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    canvasW = size.width
                    canvasH = size.height
                    val stroke = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                    strokes.forEach { drawPath(it, Color.Black, style = stroke) }
                    current?.let { drawPath(it, Color.Black, style = stroke) }
                }
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { strokes.clear(); current = null }) { Text("Clear") }
                Button(onClick = {
                    scope.launch {
                        val details = repo.getInvoice(invoiceId) ?: return@launch
                        val bmp = Bitmap.createBitmap(900, 320, Bitmap.Config.ARGB_8888)
                        val canvas = android.graphics.Canvas(bmp)
                        canvas.drawColor(android.graphics.Color.TRANSPARENT)
                        val scaleX = if (canvasW > 0f) 900f / canvasW else 1f
                        val scaleY = if (canvasH > 0f) 320f / canvasH else 1f
                        canvas.scale(scaleX, scaleY)
                        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = android.graphics.Color.BLACK
                            style = Paint.Style.STROKE
                            strokeWidth = 8f
                            strokeCap = Paint.Cap.ROUND
                            strokeJoin = Paint.Join.ROUND
                        }
                        strokes.forEach { path ->
                            canvas.drawPath(path.asAndroidPath(), paint)
                        }
                        repo.saveSignature(details.invoice, bmp)
                        nav.popBackStack()
                    }
                }) { Text("Stamp on invoice") }
            }
        }
    }
}
