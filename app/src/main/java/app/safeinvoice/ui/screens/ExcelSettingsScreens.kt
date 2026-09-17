package app.safeinvoice.ui.screens

import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import app.safeinvoice.BuildConfig
import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.FolderType
import app.safeinvoice.data.entity.InvoiceTemplateEntity
import app.safeinvoice.data.entity.LogoAlignment
import app.safeinvoice.data.entity.MarginPreset
import app.safeinvoice.data.entity.PicturePlacement
import app.safeinvoice.data.entity.TemplateLayout
import app.safeinvoice.data.entity.ThemeMode
import app.safeinvoice.data.entity.TransactionEntity
import app.safeinvoice.data.entity.TransactionType
import app.safeinvoice.data.excel.CustomerImportFields
import app.safeinvoice.data.excel.InvoiceImportFields
import app.safeinvoice.data.excel.SheetPreview
import app.safeinvoice.data.excel.guessMapping
import app.safeinvoice.ui.components.EmptyState
import app.safeinvoice.ui.components.LabeledField
import app.safeinvoice.ui.components.SectionTitle
import app.safeinvoice.ui.nav.AppViewModel
import app.safeinvoice.ui.nav.Routes
import app.safeinvoice.ui.nav.rememberAppContainer
import app.safeinvoice.ui.nav.sheetCapture
import app.safeinvoice.ui.nav.templateEdit
import app.safeinvoice.ui.theme.Palettes
import app.safeinvoice.util.Za
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(appVm: AppViewModel, nav: NavHostController) {
    val settings by appVm.settings.collectAsState()
    val mode = runCatching { ThemeMode.valueOf(settings.themeMode) }.getOrDefault(ThemeMode.SYSTEM)
    val accent = runCatching { AccentPalette.valueOf(settings.accentPalette) }.getOrDefault(AccentPalette.FOREST)
    val selected = Palettes.firstOrNull { it.key == accent } ?: Palettes.first()
    Scaffold(topBar = { BackBar("Settings", nav) }) { padding ->
        Column(
            Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionTitle("Appearance")
            Text(
                "Light, dark or follow the phone. Accents colour buttons, the home stats and new invoice templates.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                ThemeChoice("Light", ThemeMode.LIGHT, mode, Icons.Default.LightMode, Modifier.weight(1f), appVm::setTheme)
                ThemeChoice("Dark", ThemeMode.DARK, mode, Icons.Default.DarkMode, Modifier.weight(1f), appVm::setTheme)
                ThemeChoice("System", ThemeMode.SYSTEM, mode, Icons.Default.PhoneAndroid, Modifier.weight(1f), appVm::setTheme)
            }
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Live preview", fontWeight = FontWeight.SemiBold)
                    Text("SafeInvoice  ·  ${selected.name}", style = MaterialTheme.typography.labelMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(Modifier.size(36.dp).clip(CircleShape).background(selected.primary))
                        Box(Modifier.size(36.dp).clip(CircleShape).background(selected.secondary))
                        Box(Modifier.size(36.dp).clip(CircleShape).background(selected.tertiary))
                    }
                    Button(onClick = { }, modifier = Modifier.fillMaxWidth()) { Text("Primary button") }
                    OutlinedButton(onClick = { }, modifier = Modifier.fillMaxWidth()) { Text("Secondary action") }
                }
            }
            SectionTitle("Accent palettes")
            Palettes.forEach { p ->
                val selectedPalette = accent == p.key
                Card(
                    onClick = { appVm.setAccent(p.key) },
                    modifier = Modifier.fillMaxWidth().then(
                        if (selectedPalette) Modifier.border(2.dp, p.primary, RoundedCornerShape(12.dp)) else Modifier,
                    ),
                ) {
                    ListItem(
                        headlineContent = { Text(p.name, fontWeight = if (selectedPalette) FontWeight.SemiBold else FontWeight.Normal) },
                        supportingContent = { Text(if (selectedPalette) "In use across the app" else "Tap to apply") },
                        leadingContent = {
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Box(Modifier.size(22.dp).clip(CircleShape).background(p.primary))
                                Box(Modifier.size(22.dp).clip(CircleShape).background(p.secondary))
                                Box(Modifier.size(22.dp).clip(CircleShape).background(p.tertiary))
                            }
                        },
                    )
                }
            }
            SectionTitle("Invoice look")
            Card(onClick = { nav.navigate(Routes.TEMPLATES) }, modifier = Modifier.fillMaxWidth()) {
                ListItem(
                    headlineContent = { Text("Adjust invoice layouts") },
                    supportingContent = { Text("Classic, modern, compact, letterhead or minimal — plus margins, logo position and pictures.") },
                )
            }
            SectionTitle("Privacy")
            Text(
                "SafeInvoice is local-only. Invoices, customers, Excel files, signatures and receipts stay in this phone’s private storage. There is no account and no server.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text("SafeInvoice ${BuildConfig.VERSION_NAME}  ·  ${BuildConfig.APPLICATION_ID}", style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun ThemeChoice(
    label: String,
    value: ThemeMode,
    selected: ThemeMode,
    icon: ImageVector,
    modifier: Modifier,
    onSelect: (ThemeMode) -> Unit,
) {
    Card(
        onClick = { onSelect(value) },
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(icon, contentDescription = label, tint = if (selected == value) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(6.dp))
            Text(label, fontWeight = if (selected == value) FontWeight.SemiBold else FontWeight.Normal)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TemplateListScreen(appVm: AppViewModel, nav: NavHostController) {
    val business by appVm.activeBusiness.collectAsState()
    val templates by (business?.let { appVm.repository.templates(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
        .collectAsState(initial = emptyList())
    Scaffold(topBar = { BackBar("Templates", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { nav.navigate(templateEdit("new")) }, modifier = Modifier.fillMaxWidth()) { Text("New template") }
            templates.forEach { t ->
                Card(onClick = { nav.navigate(templateEdit(t.id)) }, modifier = Modifier.fillMaxWidth()) {
                    ListItem(
                        headlineContent = { Text(t.name) },
                        supportingContent = { Text("${t.layout}${if (t.isDefault) " · default" else ""}") },
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TemplateEditScreen(id: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var name by remember { mutableStateOf("Custom template") }
    var layout by remember { mutableStateOf(TemplateLayout.CLASSIC.name) }
    var footer by remember { mutableStateOf("") }
    var showBank by remember { mutableStateOf(true) }
    var isDefault by remember { mutableStateOf(false) }
    var primary by remember { mutableStateOf(0xFF0F766E) }
    var accent by remember { mutableStateOf(0xFFD4A017) }
    var logoPath by remember { mutableStateOf<String?>(null) }
    var headerPath by remember { mutableStateOf<String?>(null) }
    var extraPath by remember { mutableStateOf<String?>(null) }
    var logoAlign by remember { mutableStateOf(LogoAlignment.LEFT.name) }
    var margin by remember { mutableStateOf(MarginPreset.NORMAL.name) }
    var picturePlace by remember { mutableStateOf(PicturePlacement.AFTER_ITEMS.name) }
    var showSignature by remember { mutableStateOf(true) }
    var headerBanner by remember { mutableStateOf(true) }
    var existing by remember { mutableStateOf<InvoiceTemplateEntity?>(null) }

    LaunchedEffect(id) {
        if (id != "new") {
            repo.getTemplate(id)?.let { t ->
                existing = t
                name = t.name; layout = t.layout; footer = t.footerText.orEmpty()
                showBank = t.showBankDetails; isDefault = t.isDefault
                primary = t.primaryColor; accent = t.accentColor
                logoPath = t.logoPath; headerPath = t.headerImagePath; extraPath = t.extraImagePath
                logoAlign = t.logoAlignment; margin = t.marginPreset; picturePlace = t.picturePlacement
                showSignature = t.showSignatureLine; headerBanner = t.headerBanner
            }
        }
    }

    val logoPick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val biz = business ?: return@rememberLauncherForActivityResult
        if (uri != null) scope.launch { logoPath = repo.copyUriToTemplate(biz.id, uri, "logo.png") }
    }
    val headerPick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val biz = business ?: return@rememberLauncherForActivityResult
        if (uri != null) scope.launch { headerPath = repo.copyUriToTemplate(biz.id, uri, "header.jpg") }
    }
    val extraPick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val biz = business ?: return@rememberLauncherForActivityResult
        if (uri != null) scope.launch { extraPath = repo.copyUriToTemplate(biz.id, uri, "picture.jpg") }
    }

    Scaffold(topBar = { BackBar("Template", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            LabeledField("Name", name, { name = it })
            SectionTitle("Layout style")
            Text(
                layoutBlurb(layout),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TemplateLayout.entries.forEach { l ->
                    FilterChip(selected = layout == l.name, onClick = { layout = l.name }, label = { Text(l.name.lowercase().replaceFirstChar { it.titlecase() }) })
                }
            }
            LayoutPreview(layout, logoAlign, margin)
            SectionTitle("Adjustable layout")
            Text("Logo position")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LogoAlignment.entries.forEach { a ->
                    FilterChip(selected = logoAlign == a.name, onClick = { logoAlign = a.name }, label = { Text(a.name.lowercase().replaceFirstChar { it.titlecase() }) })
                }
            }
            Text("Page margins")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MarginPreset.entries.forEach { a ->
                    FilterChip(selected = margin == a.name, onClick = { margin = a.name }, label = { Text(a.name.lowercase().replaceFirstChar { it.titlecase() }) })
                }
            }
            Text("Pictures print")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PicturePlacement.entries.forEach { a ->
                    FilterChip(
                        selected = picturePlace == a.name,
                        onClick = { picturePlace = a.name },
                        label = { Text(a.name.lowercase().replace('_', ' ').replaceFirstChar { it.titlecase() }) },
                    )
                }
            }
            SectionTitle("Colours")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Palettes.forEach { p ->
                    Box(
                        Modifier.size(36.dp).clip(CircleShape).background(p.primary)
                            .border(
                                if ((primary and 0xFFFFFFL) == (p.primary.toArgb().toLong() and 0xFFFFFFL)) 3.dp else 0.dp,
                                Color.Black,
                                CircleShape,
                            )
                            .clickable {
                                primary = p.primary.toArgb().toLong() and 0xFFFFFFFFL
                                accent = p.secondary.toArgb().toLong() and 0xFFFFFFFFL
                            },
                    )
                }
            }
            LabeledField("Footer", footer, { footer = it }, singleLine = false, minLines = 2)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = showBank, onClick = { showBank = !showBank }, label = { Text("Show bank details") })
                FilterChip(selected = showSignature, onClick = { showSignature = !showSignature }, label = { Text("Signature line") })
                FilterChip(selected = headerBanner, onClick = { headerBanner = !headerBanner }, label = { Text("Colour banner") })
                FilterChip(selected = isDefault, onClick = { isDefault = !isDefault }, label = { Text("Default for this business") })
            }
            SectionTitle("Pictures")
            OutlinedButton(onClick = { logoPick.launch("image/*") }) { Text(if (logoPath == null) "Insert logo" else "Logo added") }
            OutlinedButton(onClick = { headerPick.launch("image/*") }) { Text(if (headerPath == null) "Insert header picture" else "Header picture added") }
            OutlinedButton(onClick = { extraPick.launch("image/*") }) { Text(if (extraPath == null) "Insert extra picture" else "Extra picture added") }
            OutlinedButton(onClick = {
                val clip = context.getSystemService(android.content.ClipboardManager::class.java)
                val item = clip?.primaryClip?.getItemAt(0)
                val uri = item?.uri
                val biz = business
                if (uri != null && biz != null) {
                    scope.launch { extraPath = repo.copyUriToTemplate(biz.id, uri, "pasted.jpg") }
                } else {
                    Toast.makeText(context, "Copy an image first, then paste here", Toast.LENGTH_SHORT).show()
                }
            }) { Text("Paste picture from clipboard") }
            Button(onClick = {
                val biz = business ?: return@Button
                scope.launch {
                    val now = System.currentTimeMillis()
                    repo.saveTemplate(
                        (existing ?: InvoiceTemplateEntity(
                            id = Za.newId(),
                            businessId = biz.id,
                            name = name,
                            isDefault = isDefault,
                            primaryColor = primary,
                            accentColor = accent,
                            logoPath = logoPath,
                            layout = layout,
                            showBankDetails = showBank,
                            footerText = footer.ifBlank { null },
                            headerImagePath = headerPath,
                            extraImagePath = extraPath,
                            logoAlignment = logoAlign,
                            marginPreset = margin,
                            picturePlacement = picturePlace,
                            showSignatureLine = showSignature,
                            headerBanner = headerBanner,
                            createdAt = now,
                            updatedAt = now,
                        )).copy(
                            name = name,
                            isDefault = isDefault,
                            primaryColor = primary,
                            accentColor = accent,
                            logoPath = logoPath,
                            layout = layout,
                            showBankDetails = showBank,
                            footerText = footer.ifBlank { null },
                            headerImagePath = headerPath,
                            extraImagePath = extraPath,
                            logoAlignment = logoAlign,
                            marginPreset = margin,
                            picturePlacement = picturePlace,
                            showSignatureLine = showSignature,
                            headerBanner = headerBanner,
                        ),
                    )
                    nav.popBackStack()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Save template") }
        }
    }
}

private fun layoutBlurb(layout: String) = when (layout) {
    TemplateLayout.MODERN.name -> "Strong accent header, logo and optional picture on the right."
    TemplateLayout.COMPACT.name -> "Tighter type and spacing for short invoices."
    TemplateLayout.LETTERHEAD.name -> "Full-width colour banner with the invoice number in the header."
    TemplateLayout.MINIMAL.name -> "Quiet layout without colour bars — good for letterheads you already print."
    else -> "Traditional South African tax invoice with a colour rule and bill-to band."
}

@Composable
private fun LayoutPreview(layout: String, logoAlign: String, margin: String) {
    val scheme = MaterialTheme.colorScheme
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Preview", fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelLarge)
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(92.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(scheme.surfaceVariant)
                    .padding(
                        horizontal = if (margin == MarginPreset.WIDE.name) 20.dp else if (margin == MarginPreset.TIGHT.name) 6.dp else 12.dp,
                        vertical = 8.dp,
                    ),
            ) {
                if (layout == TemplateLayout.LETTERHEAD.name) {
                    Box(Modifier.fillMaxWidth().height(22.dp).align(Alignment.TopCenter).background(scheme.primary))
                }
                val logoMod = when (logoAlign) {
                    LogoAlignment.RIGHT.name -> Modifier.align(Alignment.TopEnd)
                    LogoAlignment.CENTER.name -> Modifier.align(Alignment.TopCenter)
                    else -> Modifier.align(Alignment.TopStart)
                }
                Box(logoMod.size(width = 36.dp, height = 12.dp).background(scheme.primary, RoundedCornerShape(2.dp)))
                Box(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(8.dp).background(scheme.secondary.copy(alpha = 0.4f)))
            }
            Text(
                "${layout.lowercase().replaceFirstChar { it.titlecase() }}  ·  logo ${logoAlign.lowercase()}  ·  ${margin.lowercase()} margins",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExcelHubScreen(appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var preview by remember { mutableStateOf<SheetPreview?>(null) }
    var pickedUri by remember { mutableStateOf<Uri?>(null) }
    var pickedName by remember { mutableStateOf("") }
    var mode by remember { mutableStateOf("customers") }
    var mapping by remember { mutableStateOf<Map<String, Int>>(emptyMap()) }
    var status by remember { mutableStateOf<String?>(null) }
    val fields = if (mode == "customers") CustomerImportFields.fields else InvoiceImportFields.fields

    val opener = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            pickedUri = uri
            pickedName = uri.lastPathSegment?.substringAfterLast('/') ?: "sheet"
            scope.launch(Dispatchers.IO) {
                val p = repo.excel.preview(uri, pickedName)
                preview = p
                mapping = guessMapping(p.headers, fields)
            }
        }
    }

    Scaffold(topBar = { BackBar("Excel", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Import .xlsx, .xls or CSV. Columns are mapped before anything is written locally.")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = mode == "customers", onClick = { mode = "customers" }, label = { Text("Customers") })
                FilterChip(selected = mode == "invoices", onClick = { mode = "invoices" }, label = { Text("Invoices") })
            }
            Button(onClick = {
                opener.launch(
                    arrayOf(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                        "application/vnd.ms-excel",
                        "text/csv",
                        "text/comma-separated-values",
                        "*/*",
                    ),
                )
            }, modifier = Modifier.fillMaxWidth()) { Text("Choose spreadsheet") }
            preview?.let { p ->
                Text("${p.fileName}  ·  ${p.sheetName}  ·  ${p.headers.size} columns")
                p.headers.forEachIndexed { i, h -> Text("Col ${i + 1}: $h") }
                SectionTitle("Column mapping")
                fields.forEach { (key, label) ->
                    val selected = mapping[key] ?: -1
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(label, modifier = Modifier.padding(top = 10.dp))
                        FilterChip(selected = selected < 0, onClick = { mapping = mapping + (key to -1) }, label = { Text("Skip") })
                        p.headers.forEachIndexed { idx, header ->
                            FilterChip(
                                selected = selected == idx,
                                onClick = { mapping = mapping + (key to idx) },
                                label = { Text(header.ifBlank { "Col ${idx + 1}" }.take(16)) },
                            )
                        }
                    }
                }
                Button(onClick = {
                    val biz = business ?: return@Button
                    val uri = pickedUri ?: return@Button
                    scope.launch {
                        val n = if (mode == "customers") {
                            repo.importCustomers(biz.id, uri, pickedName, mapping)
                        } else {
                            repo.importInvoiceLines(biz.id, uri, pickedName, mapping)
                        }
                        status = "Imported $n record(s) offline"
                    }
                }, modifier = Modifier.fillMaxWidth()) { Text("Import") }
            }
            status?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            SectionTitle("Export this business")
            OutlinedButton(onClick = {
                val biz = business ?: return@OutlinedButton
                scope.launch {
                    val dest = File(context.cacheDir, "${biz.invoicePrefix}-export.xlsx")
                    repo.exportBusinessWorkbook(biz.id, dest, csv = false)
                    containerShare(context, dest, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Export XLSX") }
            OutlinedButton(onClick = {
                val biz = business ?: return@OutlinedButton
                scope.launch {
                    val dest = File(context.cacheDir, "${biz.invoicePrefix}-invoices.csv")
                    repo.exportBusinessWorkbook(biz.id, dest, csv = true)
                    containerShare(context, dest, "text/csv")
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Export CSV") }
            val customers by (business?.let { appVm.customers(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
                .collectAsState(initial = emptyList())
            SectionTitle("Capture a sheet into a customer folder")
            customers.take(8).forEach { c ->
                Card(onClick = { nav.navigate(sheetCapture(c.id)) }, modifier = Modifier.fillMaxWidth()) {
                    ListItem(headlineContent = { Text(c.name) }, supportingContent = { Text("Write Excel/CSV into their folder") })
                }
            }
        }
    }
}

private fun containerShare(context: android.content.Context, file: File, mime: String) {
    val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
        type = mime
        putExtra(android.content.Intent.EXTRA_STREAM, uri)
        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(android.content.Intent.createChooser(intent, file.name))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SheetCaptureScreen(customerId: String, appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val customer by repo.customer(customerId).collectAsState(initial = null)
    val scope = rememberCoroutineScope()
    var fileName by remember { mutableStateOf("capture.xlsx") }
    val headers = remember { mutableStateListOf("Item", "Qty", "Amount", "Notes") }
    val rows = remember {
        mutableStateListOf(
            mutableStateListOf("", "", "", ""),
            mutableStateListOf("", "", "", ""),
            mutableStateListOf("", "", "", ""),
        )
    }
    Scaffold(topBar = { BackBar("Capture sheet", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Typed here is written into this customer's Excel folder on device storage.")
            LabeledField("File name", fileName, { fileName = it })
            headers.forEachIndexed { i, h ->
                OutlinedTextField(value = h, onValueChange = { headers[i] = it }, label = { Text("Column ${i + 1}") }, modifier = Modifier.fillMaxWidth())
            }
            SectionTitle("Rows")
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    row.forEachIndexed { c, v ->
                        OutlinedTextField(
                            value = v,
                            onValueChange = { row[c] = it },
                            modifier = Modifier.weight(1f),
                            label = { Text(headers.getOrNull(c) ?: "") },
                        )
                    }
                }
            }
            OutlinedButton(onClick = { rows.add(mutableStateListOf("", "", "", "")) }) { Text("Add row") }
            Button(onClick = {
                val c = customer ?: return@Button
                scope.launch {
                    val csv = fileName.endsWith(".csv", true)
                    val name = if (fileName.contains('.')) fileName else "$fileName.xlsx"
                    repo.writeCaptureSheet(
                        c.businessId,
                        c.id,
                        name,
                        headers.toList(),
                        rows.map { it.toList() },
                        csv,
                    )
                    nav.popBackStack()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("Save to customer folder") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionListScreen(appVm: AppViewModel, nav: NavHostController) {
    val business by appVm.activeBusiness.collectAsState()
    val txs by (business?.let { appVm.transactions(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
        .collectAsState(initial = emptyList())
    val share = rememberAppContainer().share
    val scope = rememberCoroutineScope()
    Scaffold(
        topBar = { BackBar("Transactions", nav) },
        floatingActionButton = {
            FloatingActionButton(onClick = { nav.navigate(Routes.TRANSACTION_EDIT) }) {
                Icon(Icons.Default.Add, contentDescription = "Record transaction")
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Every payment, expense and receipt is stored on this phone. Share a receipt via Email or WhatsApp.")
            if (txs.isEmpty()) {
                EmptyState("No transactions yet", "Record a payment or expense, optionally attach a receipt, then share it.")
            }
            txs.forEach { tx ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(bottom = 8.dp)) {
                        ListItem(
                            headlineContent = { Text("${tx.type}  ${Za.money(tx.amount, tx.currency)}") },
                            supportingContent = {
                                Text(listOfNotNull(tx.method, tx.reference, tx.notes, Za.date(tx.occurredAt)).joinToString(" · "))
                            },
                        )
                        if (!tx.receiptPath.isNullOrBlank()) {
                            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = {
                                    scope.launch {
                                        val file = appVm.repository.resolveFile(tx.receiptPath!!)
                                        if (file.exists()) share.emailFile(file, "Receipt ${tx.reference ?: tx.id.take(8)}", "Receipt attached.", null)
                                    }
                                }) { Text("Email") }
                                OutlinedButton(onClick = {
                                    scope.launch {
                                        val file = appVm.repository.resolveFile(tx.receiptPath!!)
                                        if (file.exists()) share.whatsappFile(file, "Receipt ${Za.money(tx.amount, tx.currency)}")
                                    }
                                }) { Text("WhatsApp") }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionEditScreen(appVm: AppViewModel, nav: NavHostController) {
    val repo = appVm.repository
    val business by appVm.activeBusiness.collectAsState()
    val customers by (business?.let { appVm.customers(it.id) } ?: kotlinx.coroutines.flow.flowOf(emptyList()))
        .collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()
    var type by remember { mutableStateOf(TransactionType.PAYMENT.name) }
    var amount by remember { mutableStateOf("") }
    var method by remember { mutableStateOf("EFT") }
    var reference by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var customerId by remember { mutableStateOf<String?>(null) }
    var receiptPath by remember { mutableStateOf<String?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val biz = business ?: return@rememberLauncherForActivityResult
        if (uri != null) {
            val name = uri.lastPathSegment?.substringAfterLast('/') ?: "receipt.jpg"
            scope.launch {
                receiptPath = repo.attachReceipt(biz.id, customerId, uri, name).ifBlank { null }
                    ?: repo.attachReceipt(biz.id, customers.firstOrNull()?.id, uri, name).ifBlank { null }
            }
        }
    }
    Scaffold(topBar = { BackBar("Record transaction", nav) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TransactionType.entries.forEach { t ->
                    FilterChip(selected = type == t.name, onClick = { type = t.name }, label = { Text(t.name.lowercase().replaceFirstChar { it.titlecase() }) })
                }
            }
            LabeledField("Amount (ZAR)", amount, { amount = it })
            LabeledField("Method", method, { method = it })
            LabeledField("Reference", reference, { reference = it })
            LabeledField("Notes", notes, { notes = it }, singleLine = false, minLines = 2)
            if (customers.isNotEmpty()) {
                Text("Customer (for the receipts folder)")
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = customerId == null, onClick = { customerId = null }, label = { Text("None") })
                    customers.forEach { c ->
                        FilterChip(selected = customerId == c.id, onClick = { customerId = c.id }, label = { Text(c.name.take(18)) })
                    }
                }
            }
            OutlinedButton(onClick = { picker.launch(arrayOf("image/*", "application/pdf", "*/*")) }, modifier = Modifier.fillMaxWidth()) {
                Text(if (receiptPath == null) "Attach receipt" else "Receipt attached")
            }
            Button(
                enabled = amount.toDoubleOrNull() != null && business != null,
                onClick = {
                    val biz = business ?: return@Button
                    scope.launch {
                        repo.saveTransaction(
                            TransactionEntity(
                                id = Za.newId(),
                                businessId = biz.id,
                                customerId = customerId,
                                invoiceId = null,
                                type = type,
                                amount = amount.toDoubleOrNull() ?: 0.0,
                                currency = biz.defaultCurrency,
                                occurredAt = System.currentTimeMillis(),
                                method = method.ifBlank { null },
                                reference = reference.ifBlank { null },
                                notes = notes.ifBlank { null },
                                receiptPath = receiptPath,
                                createdAt = System.currentTimeMillis(),
                            ),
                        )
                        nav.popBackStack()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Save transaction") }
        }
    }
}
