package app.safeinvoice.data.repo

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import app.safeinvoice.data.db.AppDatabase
import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.AppSettingsEntity
import app.safeinvoice.data.entity.BusinessEntity
import app.safeinvoice.data.entity.CustomerEntity
import app.safeinvoice.data.entity.FolderFileEntity
import app.safeinvoice.data.entity.FolderType
import app.safeinvoice.data.entity.InvoiceEntity
import app.safeinvoice.data.entity.InvoiceImageEntity
import app.safeinvoice.data.entity.InvoiceLineItemEntity
import app.safeinvoice.data.entity.InvoiceStatus
import app.safeinvoice.data.entity.InvoiceTemplateEntity
import app.safeinvoice.data.entity.LogoAlignment
import app.safeinvoice.data.entity.MarginPreset
import app.safeinvoice.data.entity.NoteEntity
import app.safeinvoice.data.entity.PicturePlacement
import app.safeinvoice.data.entity.TemplateLayout
import app.safeinvoice.data.entity.ThemeMode
import app.safeinvoice.data.entity.TransactionEntity
import app.safeinvoice.data.entity.TransactionType
import app.safeinvoice.data.excel.ExcelService
import app.safeinvoice.data.files.LocalStorage
import app.safeinvoice.data.pdf.InvoicePdfGenerator
import app.safeinvoice.util.Money
import app.safeinvoice.util.Za
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.io.File
import java.io.FileOutputStream
import java.time.Year

class InvoiceRepository(
    private val context: Context,
    private val db: AppDatabase,
    val storage: LocalStorage,
    val excel: ExcelService,
    val pdf: InvoicePdfGenerator,
) {
    val businesses = db.businessDao().observeAll()
    val settings: Flow<AppSettingsEntity> = db.settingsDao().observe().map {
        it ?: AppSettingsEntity(activeBusinessId = null)
    }

    fun customers(businessId: String) = db.customerDao().observeForBusiness(businessId)
    fun invoices(businessId: String) = db.invoiceDao().observeForBusiness(businessId)
    fun invoicesForCustomer(customerId: String) = db.invoiceDao().observeForCustomer(customerId)
    fun transactions(businessId: String) = db.transactionDao().observeForBusiness(businessId)
    fun customerTransactions(customerId: String) = db.transactionDao().observeForCustomer(customerId)
    fun notes(customerId: String) = db.noteDao().observeForCustomer(customerId)
    fun files(customerId: String, type: FolderType) = db.folderFileDao().observe(customerId, type.name)
    fun allFiles(customerId: String) = db.folderFileDao().observeAll(customerId)
    fun templates(businessId: String) = db.templateDao().observeForBusiness(businessId)
    fun customer(id: String) = db.customerDao().observe(id)

    suspend fun getBusiness(id: String) = db.businessDao().get(id)
    suspend fun getCustomer(id: String) = db.customerDao().get(id)
    suspend fun getInvoice(id: String) = db.invoiceDao().getWithDetails(id)
    suspend fun getTemplate(id: String) = db.templateDao().get(id)
    suspend fun getNote(id: String) = db.noteDao().get(id)
    suspend fun defaultTemplate(businessId: String) = db.templateDao().defaultFor(businessId)
    suspend fun getSettings() = db.settingsDao().get() ?: AppSettingsEntity(activeBusinessId = null)
    suspend fun allCustomers(businessId: String) = db.customerDao().forBusiness(businessId)
    suspend fun allInvoices(businessId: String) = db.invoiceDao().forBusiness(businessId)

    suspend fun saveSettings(
        themeMode: ThemeMode? = null,
        accent: AccentPalette? = null,
        businessId: String? = null,
    ) {
        val current = getSettings()
        db.settingsDao().upsert(
            current.copy(
                themeMode = themeMode?.name ?: current.themeMode,
                accentPalette = accent?.name ?: current.accentPalette,
                activeBusinessId = businessId ?: current.activeBusinessId,
            ),
        )
    }

    suspend fun saveBusiness(entity: BusinessEntity) {
        val isNew = db.businessDao().get(entity.id) == null
        storage.businessDir(entity.id)
        db.businessDao().upsert(entity.copy(updatedAt = System.currentTimeMillis()))
        val settings = getSettings()
        if (settings.activeBusinessId == null) {
            db.settingsDao().upsert(settings.copy(activeBusinessId = entity.id))
        }
        if (isNew && db.templateDao().forBusiness(entity.id).isEmpty()) {
            val now = System.currentTimeMillis()
            db.templateDao().upsert(
                InvoiceTemplateEntity(
                    id = Za.newId(),
                    businessId = entity.id,
                    name = "Standard",
                    isDefault = true,
                    primaryColor = 0xFF0F766E,
                    accentColor = 0xFFD4A017,
                    logoPath = null,
                    layout = TemplateLayout.CLASSIC.name,
                    showBankDetails = true,
                    footerText = "${entity.name}  ·  invoices stored on this device",
                    headerImagePath = null,
                    extraImagePath = null,
                    logoAlignment = LogoAlignment.LEFT.name,
                    marginPreset = MarginPreset.NORMAL.name,
                    picturePlacement = PicturePlacement.AFTER_ITEMS.name,
                    showSignatureLine = true,
                    headerBanner = true,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
        }
    }

    suspend fun deleteBusiness(entity: BusinessEntity) {
        db.businessDao().delete(entity)
        storage.businessDir(entity.id).deleteRecursively()
    }

    suspend fun saveCustomer(entity: CustomerEntity) {
        storage.customerDir(entity.businessId, entity.id)
        FolderType.entries.forEach { storage.folder(entity.businessId, entity.id, it) }
        db.customerDao().upsert(entity.copy(updatedAt = System.currentTimeMillis()))
    }

    suspend fun deleteCustomer(entity: CustomerEntity) {
        db.customerDao().delete(entity)
        storage.customerDir(entity.businessId, entity.id).deleteRecursively()
    }

    suspend fun nextInvoiceNumber(business: BusinessEntity): Pair<String, Long> {
        val year = Year.now(Za.zone).value
        val seq = business.nextInvoiceNumber
        val number = "%s-%d-%04d".format(business.invoicePrefix, year, seq)
        return number to seq + 1
    }

    suspend fun saveInvoice(
        invoice: InvoiceEntity,
        items: List<InvoiceLineItemEntity>,
        bumpNumber: Boolean,
    ): InvoiceEntity {
        val totals = Money.totals(
            items.map { Money.lineTotal(it.quantity, it.unitPrice) },
            invoice.discountAmount,
            invoice.discountPercent,
            invoice.vatPercent,
        )
        val saved = invoice.copy(
            subtotal = totals.subtotal,
            vatAmount = totals.vat,
            total = totals.total,
            updatedAt = System.currentTimeMillis(),
        )
        db.invoiceDao().upsert(saved)
        db.invoiceDao().deleteItems(saved.id)
        items.forEach { db.invoiceDao().upsertItem(it.copy(invoiceId = saved.id)) }
        if (bumpNumber) {
            db.businessDao().get(saved.businessId)?.let { biz ->
                db.businessDao().upsert(biz.copy(nextInvoiceNumber = biz.nextInvoiceNumber + 1, updatedAt = System.currentTimeMillis()))
            }
        }
        return saved
    }

    suspend fun deleteInvoice(invoice: InvoiceEntity) {
        db.invoiceDao().delete(invoice)
    }

    suspend fun setStatus(invoiceId: String, status: InvoiceStatus) {
        db.invoiceDao().updateStatus(invoiceId, status.name, System.currentTimeMillis())
    }

    suspend fun markOverdue() {
        val now = Za.todayMillis()
        db.businessDao().getAll().forEach { biz ->
            db.invoiceDao().forBusiness(biz.id).forEach { inv ->
                if (inv.status == InvoiceStatus.SENT.name && inv.dueDate < now) {
                    db.invoiceDao().updateStatus(inv.id, InvoiceStatus.OVERDUE.name, System.currentTimeMillis())
                }
            }
        }
    }

    suspend fun saveSignature(invoice: InvoiceEntity, bitmap: Bitmap): String {
        val dir = storage.folder(invoice.businessId, invoice.customerId, FolderType.IMAGES)
        val file = storage.uniqueFile(dir, "${invoice.number}_signature.png")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        val rel = storage.relativeToFiles(file, context)
        db.invoiceDao().updateSignature(invoice.id, rel, System.currentTimeMillis())
        indexFile(invoice.businessId, invoice.customerId, FolderType.IMAGES, file, "image/png")
        return rel
    }

    suspend fun addInvoiceImage(invoice: InvoiceEntity, uri: Uri, displayName: String): InvoiceImageEntity {
        val dir = storage.folder(invoice.businessId, invoice.customerId, FolderType.IMAGES)
        val dest = storage.uniqueFile(dir, displayName.ifBlank { "image.jpg" })
        context.contentResolver.openInputStream(uri)?.use { storage.copyInto(it, dest) }
        val rel = storage.relativeToFiles(dest, context)
        val entity = InvoiceImageEntity(
            id = Za.newId(),
            invoiceId = invoice.id,
            path = rel,
            sortOrder = db.invoiceDao().images(invoice.id).size,
        )
        db.invoiceDao().upsertImage(entity)
        indexFile(invoice.businessId, invoice.customerId, FolderType.IMAGES, dest, guessMime(displayName))
        return entity
    }

    suspend fun generatePdf(invoiceId: String): File? {
        val details = db.invoiceDao().getWithDetails(invoiceId) ?: return null
        val business = db.businessDao().get(details.invoice.businessId) ?: return null
        val customer = db.customerDao().get(details.invoice.customerId) ?: return null
        val template = details.invoice.templateId?.let { db.templateDao().get(it) }
            ?: db.templateDao().defaultFor(business.id)
        val dir = storage.folder(business.id, customer.id, FolderType.INVOICES)
        val dest = File(dir, "${details.invoice.number}.pdf")
        pdf.generate(details, business, customer, template, dest)
        val rel = storage.relativeToFiles(dest, context)
        db.invoiceDao().updatePdf(details.invoice.id, rel, System.currentTimeMillis())
        indexFile(business.id, customer.id, FolderType.INVOICES, dest, "application/pdf")
        return dest
    }

    suspend fun recordPayment(
        invoice: InvoiceEntity,
        amount: Double,
        method: String,
        reference: String?,
    ) {
        val tx = TransactionEntity(
            id = Za.newId(),
            businessId = invoice.businessId,
            customerId = invoice.customerId,
            invoiceId = invoice.id,
            type = TransactionType.PAYMENT.name,
            amount = amount,
            currency = invoice.currency,
            occurredAt = System.currentTimeMillis(),
            method = method,
            reference = reference,
            notes = "Payment for ${invoice.number}",
            receiptPath = null,
            createdAt = System.currentTimeMillis(),
        )
        db.transactionDao().upsert(tx)
        if (amount >= invoice.total) {
            setStatus(invoice.id, InvoiceStatus.PAID)
        }
    }

    suspend fun saveTransaction(entity: TransactionEntity) {
        db.transactionDao().upsert(entity)
        if (!entity.receiptPath.isNullOrBlank()) {
            val file = storage.resolve(context, entity.receiptPath)
            if (file.exists() && entity.customerId != null) {
                indexFile(entity.businessId, entity.customerId, FolderType.RECEIPTS, file, guessMime(file.name))
            }
        }
    }

    suspend fun saveNote(entity: NoteEntity) {
        db.noteDao().upsert(entity.copy(updatedAt = System.currentTimeMillis()))
        val dir = storage.folder(entity.businessId, entity.customerId, FolderType.NOTES)
        val file = File(dir, "${entity.title.replace(Regex("[^A-Za-z0-9]+"), "_").take(40)}.txt")
        file.writeText("${entity.title}\n\n${entity.body}\n")
        indexFile(entity.businessId, entity.customerId, FolderType.NOTES, file, "text/plain")
    }

    suspend fun deleteNote(entity: NoteEntity) = db.noteDao().delete(entity)

    suspend fun importFile(
        businessId: String,
        customerId: String,
        type: FolderType,
        uri: Uri,
        displayName: String,
    ): FolderFileEntity {
        val dir = storage.folder(businessId, customerId, type)
        val dest = storage.uniqueFile(dir, displayName.ifBlank { "file" })
        context.contentResolver.openInputStream(uri)?.use { storage.copyInto(it, dest) }
        return indexFile(businessId, customerId, type, dest, guessMime(displayName))
    }

    suspend fun saveTemplate(entity: InvoiceTemplateEntity) {
        if (entity.isDefault) db.templateDao().clearDefaults(entity.businessId)
        db.templateDao().upsert(entity.copy(updatedAt = System.currentTimeMillis()))
    }

    suspend fun copyUriToTemplate(businessId: String, uri: Uri, name: String): String {
        val dest = storage.uniqueFile(storage.templatesDir(businessId), name)
        context.contentResolver.openInputStream(uri)?.use { storage.copyInto(it, dest) }
        return storage.relativeToFiles(dest, context)
    }

    suspend fun copyUriToLogo(businessId: String, uri: Uri, name: String): String {
        val dest = storage.uniqueFile(storage.logosDir(businessId), name)
        context.contentResolver.openInputStream(uri)?.use { storage.copyInto(it, dest) }
        return storage.relativeToFiles(dest, context)
    }

    suspend fun exportBusinessWorkbook(businessId: String, dest: File, csv: Boolean = false): File {
        val biz = db.businessDao().get(businessId) ?: error("Missing business")
        val customers = db.customerDao().forBusiness(businessId)
        val invoices = db.invoiceDao().forBusiness(businessId)
        val customerHeaders = listOf("Name", "Contact", "Email", "Phone", "Address", "City", "Province", "Postal", "VAT", "Notes")
        val customerRows = customers.map {
            listOf(
                it.name, it.contactName.orEmpty(), it.email.orEmpty(), it.phone.orEmpty(),
                it.addressLine1.orEmpty(), it.city.orEmpty(), it.province.orEmpty(),
                it.postalCode.orEmpty(), it.vatNumber.orEmpty(), it.notes.orEmpty(),
            )
        }
        val invoiceHeaders = listOf(
            "Number", "Customer", "Status", "Issue date", "Due date", "Currency",
            "Subtotal", "VAT", "Total", "Notes",
        )
        val invoiceRows = invoices.map { inv ->
            val customerName = customers.firstOrNull { it.id == inv.customerId }?.name.orEmpty()
            listOf(
                inv.number, customerName, inv.status, Za.date(inv.issueDate), Za.date(inv.dueDate),
                inv.currency, inv.subtotal.toString(), inv.vatAmount.toString(), inv.total.toString(),
                inv.notes.orEmpty(),
            )
        }
        return if (csv) {
            excel.writeCsv(dest, invoiceHeaders, invoiceRows)
        } else {
            excel.writeWorkbook(
                dest,
                mapOf(
                    "Invoices" to (invoiceHeaders to invoiceRows),
                    "Customers" to (customerHeaders to customerRows),
                    "Business" to (
                        listOf("Field", "Value") to listOf(
                            listOf("Name", biz.name),
                            listOf("VAT", biz.vatNumber.orEmpty()),
                            listOf("Email", biz.email),
                            listOf("Phone", biz.phone),
                            listOf("Currency", biz.defaultCurrency),
                        )
                        ),
                ),
            )
        }
    }

    suspend fun importCustomers(
        businessId: String,
        uri: Uri,
        displayName: String,
        mapping: Map<String, Int>,
    ): Int {
        val (_, rows) = excel.readAll(uri, displayName)
        var count = 0
        val now = System.currentTimeMillis()
        rows.forEach { row ->
            val name = excel.cell(row, mapping, "name")
            if (name.isBlank()) return@forEach
            val entity = CustomerEntity(
                id = Za.newId(),
                businessId = businessId,
                name = name,
                contactName = excel.cell(row, mapping, "contactName").ifBlank { null },
                email = excel.cell(row, mapping, "email").ifBlank { null },
                phone = excel.cell(row, mapping, "phone").ifBlank { null },
                addressLine1 = excel.cell(row, mapping, "addressLine1").ifBlank { null },
                city = excel.cell(row, mapping, "city").ifBlank { null },
                province = excel.cell(row, mapping, "province").ifBlank { null },
                postalCode = excel.cell(row, mapping, "postalCode").ifBlank { null },
                vatNumber = excel.cell(row, mapping, "vatNumber").ifBlank { null },
                notes = excel.cell(row, mapping, "notes").ifBlank { null },
                createdAt = now,
                updatedAt = now,
            )
            saveCustomer(entity)
            count++
        }
        return count
    }

    suspend fun importInvoiceLines(
        businessId: String,
        uri: Uri,
        displayName: String,
        mapping: Map<String, Int>,
    ): Int {
        val customers = db.customerDao().forBusiness(businessId).associateBy { it.name.lowercase() }
        val grouped = linkedMapOf<String, MutableList<List<String>>>()
        val (_, rows) = excel.readAll(uri, displayName)
        rows.forEach { row ->
            val key = excel.cell(row, mapping, "number").ifBlank {
                excel.cell(row, mapping, "customerName") + "|" + excel.cell(row, mapping, "issueDate")
            }
            grouped.getOrPut(key) { mutableListOf() }.add(row)
        }
        var count = 0
        val now = System.currentTimeMillis()
        grouped.forEach { (_, group) ->
            val first = group.first()
            val customerName = excel.cell(first, mapping, "customerName")
            val customer = customers[customerName.lowercase()] ?: return@forEach
            val id = Za.newId()
            val items = group.mapIndexed { idx, row ->
                val qty = excel.parseAmount(excel.cell(row, mapping, "quantity")).takeIf { it > 0 } ?: 1.0
                val unit = excel.parseAmount(excel.cell(row, mapping, "unitPrice")).takeIf { it > 0 }
                    ?: excel.parseAmount(excel.cell(row, mapping, "total"))
                InvoiceLineItemEntity(
                    id = Za.newId(),
                    invoiceId = id,
                    position = idx,
                    description = excel.cell(row, mapping, "description").ifBlank { "Imported line" },
                    quantity = qty,
                    unitPrice = unit,
                    taxable = true,
                )
            }
            val totals = Money.totals(items.map { Money.lineTotal(it.quantity, it.unitPrice) }, 0.0, 0.0, 15.0)
            val invoice = InvoiceEntity(
                id = id,
                businessId = businessId,
                customerId = customer.id,
                number = excel.cell(first, mapping, "number").ifBlank { "IMP-${count + 1}" },
                status = excel.cell(first, mapping, "status").ifBlank { InvoiceStatus.DRAFT.name }.uppercase(),
                issueDate = now,
                dueDate = Za.plusDays(now, 30),
                currency = "ZAR",
                vatPercent = 15.0,
                discountAmount = 0.0,
                discountPercent = 0.0,
                notes = excel.cell(first, mapping, "notes").ifBlank { null },
                terms = "Payment due within 30 days.",
                signaturePath = null,
                pdfPath = null,
                templateId = null,
                subtotal = totals.subtotal,
                vatAmount = totals.vat,
                total = totals.total,
                createdAt = now,
                updatedAt = now,
            )
            saveInvoice(invoice, items, bumpNumber = false)
            count++
        }
        return count
    }

    suspend fun writeCaptureSheet(
        businessId: String,
        customerId: String,
        fileName: String,
        headers: List<String>,
        rows: List<List<String>>,
        csv: Boolean,
    ): File {
        val dir = storage.folder(businessId, customerId, FolderType.EXCEL)
        val dest = storage.uniqueFile(dir, fileName)
        val file = if (csv) excel.writeCsv(dest, headers, rows) else excel.writeWorkbook(dest, mapOf("Capture" to (headers to rows)))
        indexFile(businessId, customerId, FolderType.EXCEL, file, if (csv) "text/csv" else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        return file
    }

    suspend fun deleteFolderFile(entity: FolderFileEntity) {
        storage.resolve(context, entity.relativePath).delete()
        db.folderFileDao().delete(entity)
    }

    suspend fun attachReceipt(
        businessId: String,
        customerId: String?,
        uri: Uri,
        displayName: String,
    ): String {
        val cid = customerId ?: return ""
        val dir = storage.folder(businessId, cid, FolderType.RECEIPTS)
        val dest = storage.uniqueFile(dir, displayName.ifBlank { "receipt.jpg" })
        context.contentResolver.openInputStream(uri)?.use { storage.copyInto(it, dest) }
        indexFile(businessId, cid, FolderType.RECEIPTS, dest, guessMime(displayName))
        return storage.relativeToFiles(dest, context)
    }

    suspend fun resolveFile(relative: String): File = storage.resolve(context, relative)

    private suspend fun indexFile(
        businessId: String,
        customerId: String,
        type: FolderType,
        file: File,
        mime: String,
    ): FolderFileEntity {
        val entity = FolderFileEntity(
            id = Za.newId(),
            businessId = businessId,
            customerId = customerId,
            folderType = type.name,
            displayName = file.name,
            mimeType = mime,
            relativePath = storage.relativeToFiles(file, context),
            sizeBytes = file.length(),
            createdAt = System.currentTimeMillis(),
        )
        db.folderFileDao().upsert(entity)
        return entity
    }

    private fun guessMime(name: String): String {
        val n = name.lowercase()
        return when {
            n.endsWith(".pdf") -> "application/pdf"
            n.endsWith(".png") -> "image/png"
            n.endsWith(".jpg") || n.endsWith(".jpeg") -> "image/jpeg"
            n.endsWith(".webp") -> "image/webp"
            n.endsWith(".xlsx") -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            n.endsWith(".xls") -> "application/vnd.ms-excel"
            n.endsWith(".csv") -> "text/csv"
            n.endsWith(".txt") -> "text/plain"
            else -> "application/octet-stream"
        }
    }
}
