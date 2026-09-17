package app.safeinvoice.data.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import app.safeinvoice.data.entity.BusinessEntity
import app.safeinvoice.data.entity.CustomerEntity
import app.safeinvoice.data.entity.InvoiceTemplateEntity
import app.safeinvoice.data.entity.InvoiceWithDetails
import app.safeinvoice.data.entity.LogoAlignment
import app.safeinvoice.data.entity.MarginPreset
import app.safeinvoice.data.entity.PicturePlacement
import app.safeinvoice.data.entity.TemplateLayout
import app.safeinvoice.data.files.LocalStorage
import app.safeinvoice.util.Money
import app.safeinvoice.util.Za
import java.io.File
import java.io.FileOutputStream

class InvoicePdfGenerator(
    private val context: Context,
    private val storage: LocalStorage,
) {
    fun generate(
        invoice: InvoiceWithDetails,
        business: BusinessEntity,
        customer: CustomerEntity,
        template: InvoiceTemplateEntity?,
        dest: File,
    ): File {
        dest.parentFile?.mkdirs()
        val pageWidth = 595
        val pageHeight = 842
        val doc = PdfDocument()
        var pageNumber = 1
        var page = doc.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
        var canvas = page.canvas

        val primary = Color.parseColor(toHex(template?.primaryColor ?: 0xFF0F766E))
        val accent = Color.parseColor(toHex(template?.accentColor ?: 0xFFD4A017))
        val layout = runCatching { TemplateLayout.valueOf(template?.layout ?: TemplateLayout.CLASSIC.name) }
            .getOrDefault(TemplateLayout.CLASSIC)
        val logoAlign = runCatching { LogoAlignment.valueOf(template?.logoAlignment ?: LogoAlignment.LEFT.name) }
            .getOrDefault(LogoAlignment.LEFT)
        val marginPreset = runCatching { MarginPreset.valueOf(template?.marginPreset ?: MarginPreset.NORMAL.name) }
            .getOrDefault(MarginPreset.NORMAL)
        val picturePlacement = runCatching {
            PicturePlacement.valueOf(template?.picturePlacement ?: PicturePlacement.AFTER_ITEMS.name)
        }.getOrDefault(PicturePlacement.AFTER_ITEMS)
        val headerBanner = template?.headerBanner != false
        val showSignatureLine = template?.showSignatureLine != false
        val m = when (marginPreset) {
            MarginPreset.TIGHT -> 24f
            MarginPreset.NORMAL -> 36f
            MarginPreset.WIDE -> 52f
        }
        val compact = layout == TemplateLayout.COMPACT || layout == TemplateLayout.MINIMAL
        val titleSize = when (layout) {
            TemplateLayout.COMPACT -> 16f
            TemplateLayout.MINIMAL -> 18f
            TemplateLayout.LETTERHEAD -> 20f
            TemplateLayout.MODERN -> 22f
            TemplateLayout.CLASSIC -> 22f
        }

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (layout == TemplateLayout.LETTERHEAD) Color.WHITE else primary
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = titleSize
        }
        val heading = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primary
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = if (compact) 10f else 11f
        }
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1F2933")
            textSize = if (compact) 8.5f else 9.5f
        }
        val muted = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#52606D")
            textSize = if (compact) 8f else 8.5f
        }
        val white = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = if (compact) 8f else 9f
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = primary }
        val band = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
        val letterTitle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textSize = 11f
        }

        var y = m

        fun newPage() {
            doc.finishPage(page)
            pageNumber += 1
            page = doc.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
            canvas = page.canvas
            y = m
        }

        if (layout == TemplateLayout.LETTERHEAD) {
            canvas.drawRect(RectF(0f, 0f, pageWidth.toFloat(), 96f), fill)
            canvas.drawRect(RectF(0f, 96f, pageWidth.toFloat(), 102f), band)
            y = 28f
        } else if (headerBanner && layout != TemplateLayout.MINIMAL) {
            val top = if (layout == TemplateLayout.MODERN) 14f else 8f
            canvas.drawRect(RectF(0f, 0f, pageWidth.toFloat(), top), fill)
            canvas.drawRect(RectF(0f, top, pageWidth.toFloat(), top + 4f), band)
        }

        val logoPath = template?.logoPath ?: business.logoPath
        val logoBmp = logoPath?.takeIf { it.isNotBlank() }?.let { decode(it) }
        val headerBmp = template?.headerImagePath?.takeIf { it.isNotBlank() }?.let { decode(it) }
        val extraBmpPath = template?.extraImagePath

        if (picturePlacement == PicturePlacement.HEADER && headerBmp != null) {
            canvas.drawBitmap(headerBmp, null, Rect(pageWidth - 150, y.toInt(), pageWidth - m.toInt(), y.toInt() + 52), null)
        } else if (layout == TemplateLayout.MODERN && headerBmp != null) {
            canvas.drawBitmap(headerBmp, null, Rect(pageWidth - 150, 20, pageWidth - m.toInt(), 72), null)
        }

        if (logoBmp != null) {
            val h = if (compact) 36 else 48
            val w = (logoBmp.width.toFloat() / logoBmp.height * h).toInt().coerceIn(36, 130)
            val left = when (logoAlign) {
                LogoAlignment.LEFT -> m.toInt()
                LogoAlignment.CENTER -> (pageWidth - w) / 2
                LogoAlignment.RIGHT -> pageWidth - m.toInt() - w
            }
            val top = if (layout == TemplateLayout.LETTERHEAD) 18 else y.toInt()
            canvas.drawBitmap(logoBmp, null, Rect(left, top, left + w, top + h), null)
            y = maxOf(y, (top + h + 10).toFloat())
        }

        val nameX = when {
            layout == TemplateLayout.LETTERHEAD -> m
            logoAlign == LogoAlignment.CENTER -> (pageWidth - titlePaint.measureText(business.name)) / 2f
            else -> m
        }
        if (layout == TemplateLayout.LETTERHEAD) {
            canvas.drawText(business.name, nameX, 44f, titlePaint)
            canvas.drawText("TAX INVOICE  ${invoice.invoice.number}", pageWidth - m - letterTitle.measureText("TAX INVOICE  ${invoice.invoice.number}"), 44f, letterTitle)
            canvas.drawText("Status ${invoice.invoice.status}", pageWidth - m - muted.measureText("Status ${invoice.invoice.status}"), 62f, Paint(muted).apply { color = Color.WHITE })
            y = 118f
        } else {
            canvas.drawText(business.name, nameX, y + 16f, titlePaint)
            val invoiceLabel = if (layout == TemplateLayout.MINIMAL) "Invoice" else "TAX INVOICE"
            canvas.drawText(invoiceLabel, pageWidth - m - titlePaint.measureText(invoiceLabel), m + 12f, Paint(titlePaint).apply { color = primary; textSize = if (compact) 14f else 18f })
            canvas.drawText(invoice.invoice.number, pageWidth - m - body.measureText(invoice.invoice.number), m + 30f, body)
            canvas.drawText("Status: ${invoice.invoice.status}", pageWidth - m - muted.measureText("Status: ${invoice.invoice.status}"), m + 44f, muted)
            y += 28f
        }

        listOfNotNull(
            business.tradingName?.takeIf { it.isNotBlank() && it != business.name }?.let { "t/a $it" },
            business.addressLine1.takeIf { it.isNotBlank() },
            listOfNotNull(business.addressLine2, listOf(business.city, business.province, business.postalCode).filter { it.isNotBlank() }.joinToString(" ").ifBlank { null }).joinToString(" ").ifBlank { null },
            business.country.takeIf { it.isNotBlank() },
            listOfNotNull(business.phone.takeIf { it.isNotBlank() }?.let { "Tel $it" }, business.email.takeIf { it.isNotBlank() }).joinToString("  ·  ").ifBlank { null },
            business.vatNumber?.let { "VAT $it" },
            business.registrationNumber?.let { "Reg $it" },
        ).forEach {
            canvas.drawText(it, m, y, muted)
            y += if (compact) 11f else 12f
        }

        y += 8f
        if (layout != TemplateLayout.MINIMAL) {
            canvas.drawRect(RectF(m, y, pageWidth - m, y + 22f), fill)
            canvas.drawText("Bill to", m + 8f, y + 15f, white)
            y += 36f
        } else {
            canvas.drawText("Bill to", m, y, heading)
            y += 14f
        }
        canvas.drawText(customer.name, m, y, heading)
        y += 14f
        listOfNotNull(
            customer.contactName?.let { "Attn: $it" },
            customer.addressLine1,
            listOfNotNull(customer.city, customer.province, customer.postalCode).joinToString(", ").ifBlank { null },
            customer.email,
            customer.phone,
            customer.vatNumber?.let { "VAT $it" },
        ).forEach {
            canvas.drawText(it, m, y, body)
            y += if (compact) 11f else 12f
        }

        y += 8f
        canvas.drawText("Issue date  ${Za.date(invoice.invoice.issueDate)}", m, y, body)
        canvas.drawText("Due date  ${Za.date(invoice.invoice.dueDate)}", 280f, y, body)
        canvas.drawText(invoice.invoice.currency, pageWidth - m - heading.measureText(invoice.invoice.currency), y, heading)
        y += 18f

        val inner = pageWidth - m
        val cols = floatArrayOf(m, m + 214f, m + 294f, m + 374f, inner)
        canvas.drawRect(RectF(m, y, inner, y + 18f), fill)
        canvas.drawText("Description", cols[0] + 6f, y + 13f, white)
        canvas.drawText("Qty", cols[1] + 6f, y + 13f, white)
        canvas.drawText("Unit", cols[2] + 6f, y + 13f, white)
        canvas.drawText("Amount", cols[3] + 6f, y + 13f, white)
        y += 22f

        invoice.items.sortedBy { it.position }.forEachIndexed { index, item ->
            if (y > 720f) newPage()
            if (index % 2 == 1 && layout != TemplateLayout.MINIMAL) {
                val zebra = Paint().apply { color = Color.parseColor("#F4F7F6") }
                canvas.drawRect(RectF(m, y - 10f, inner, y + 8f), zebra)
            }
            val line = Money.lineTotal(item.quantity, item.unitPrice)
            canvas.drawText(item.description.take(42), cols[0] + 6f, y, body)
            canvas.drawText(trimNum(item.quantity), cols[1] + 6f, y, body)
            canvas.drawText(Za.money(item.unitPrice, invoice.invoice.currency), cols[2] + 6f, y, body)
            canvas.drawText(Za.money(line, invoice.invoice.currency), cols[3] + 6f, y, body)
            y += if (compact) 14f else 16f
        }

        y += 10f
        val totals = Money.totals(
            invoice.items.map { Money.lineTotal(it.quantity, it.unitPrice) },
            invoice.invoice.discountAmount,
            invoice.invoice.discountPercent,
            invoice.invoice.vatPercent,
        )
        fun totalRow(label: String, value: String, bold: Boolean = false) {
            val p = if (bold) heading else body
            canvas.drawText(label, 360f, y, p)
            canvas.drawText(value, 480f, y, p)
            y += 14f
        }
        totalRow("Subtotal", Za.money(totals.subtotal, invoice.invoice.currency))
        if (totals.discount > 0) totalRow("Discount", "- ${Za.money(totals.discount, invoice.invoice.currency)}")
        totalRow("VAT ${trimNum(invoice.invoice.vatPercent)}%", Za.money(totals.vat, invoice.invoice.currency))
        canvas.drawRect(RectF(350f, y - 4f, inner, y + 16f), fill)
        canvas.drawText("Total", 360f, y + 10f, white)
        canvas.drawText(Za.money(totals.total, invoice.invoice.currency), 460f, y + 10f, white)
        y += 32f

        fun drawAttached(path: String, label: String) {
            if (y > 700f) newPage()
            canvas.drawText(label, m, y, heading)
            y += 6f
            decode(path)?.let { bmp ->
                val maxW = 240
                val maxH = 140
                val scale = minOf(maxW / bmp.width.toFloat(), maxH / bmp.height.toFloat(), 1f)
                val w = (bmp.width * scale).toInt()
                val h = (bmp.height * scale).toInt()
                canvas.drawBitmap(bmp, null, Rect(m.toInt(), y.toInt(), m.toInt() + w, y.toInt() + h), null)
                y += h + 12f
            }
        }

        if (picturePlacement == PicturePlacement.AFTER_ITEMS) {
            extraBmpPath?.takeIf { it.isNotBlank() }?.let { drawAttached(it, "Template image") }
            invoice.images.sortedBy { it.sortOrder }.forEach { img ->
                drawAttached(img.path, "Attached image")
            }
        }

        invoice.invoice.notes?.takeIf { it.isNotBlank() }?.let {
            canvas.drawText("Notes", m, y, heading)
            y += 14f
            wrap(it, body, 360f).forEach { line ->
                canvas.drawText(line, m, y, body)
                y += 12f
            }
            y += 8f
        }
        invoice.invoice.terms?.takeIf { it.isNotBlank() }?.let {
            canvas.drawText("Terms", m, y, heading)
            y += 14f
            wrap(it, body, 360f).forEach { line ->
                canvas.drawText(line, m, y, body)
                y += 12f
            }
            y += 8f
        }

        if (template?.showBankDetails != false) {
            canvas.drawText("Bank details", m, y, heading)
            y += 14f
            listOfNotNull(
                business.bankName,
                business.bankAccountName?.let { "Account name: $it" },
                business.bankAccountNumber?.let { "Account no: $it" },
                business.bankBranchCode?.let { "Branch: $it" },
            ).forEach {
                canvas.drawText(it, m, y, body)
                y += 12f
            }
            y += 8f
        }

        val sig = invoice.invoice.signaturePath
        if (!sig.isNullOrBlank()) {
            if (y > 680f) newPage()
            canvas.drawText("Authorised signature", m, y, heading)
            y += 6f
            decode(sig)?.let { bmp ->
                canvas.drawBitmap(bmp, null, Rect(m.toInt(), y.toInt(), m.toInt() + 164, y.toInt() + 54), null)
            }
            y += 64f
        } else if (showSignatureLine) {
            if (y > 720f) newPage()
            canvas.drawText("Authorised signature", m, y, heading)
            y += 28f
            canvas.drawLine(m, y, m + 160f, y, muted)
            y += 16f
        }

        if (picturePlacement != PicturePlacement.AFTER_ITEMS) {
            extraBmpPath?.takeIf { it.isNotBlank() }?.let { drawAttached(it, "Template image") }
            invoice.images.sortedBy { it.sortOrder }.forEach { img ->
                drawAttached(img.path, "Attached image")
            }
        }

        val footer = template?.footerText?.takeIf { it.isNotBlank() }
            ?: "Generated offline by SafeInvoice  ·  ${business.name}"
        canvas.drawText(footer.take(90), m, pageHeight - 28f, muted)
        if (layout != TemplateLayout.MINIMAL) {
            canvas.drawRect(RectF(0f, pageHeight - 8f, pageWidth.toFloat(), pageHeight.toFloat()), fill)
        }

        doc.finishPage(page)
        FileOutputStream(dest).use { doc.writeTo(it) }
        doc.close()
        return dest
    }

    private fun decode(relativeOrAbsolute: String): Bitmap? {
        val file = File(relativeOrAbsolute).takeIf { it.exists() }
            ?: storage.resolve(context, relativeOrAbsolute)
        if (!file.exists()) return null
        return BitmapFactory.decodeFile(file.absolutePath)
    }

    private fun toHex(color: Long): String {
        val v = (color and 0xFFFFFFL).toInt()
        return String.format("#%06X", v)
    }

    private fun trimNum(value: Double): String =
        if (value % 1.0 == 0.0) value.toInt().toString() else Money.round(value).toString()

    private fun wrap(text: String, paint: Paint, maxWidth: Float): List<String> {
        val words = text.split(Regex("\\s+"))
        val lines = mutableListOf<String>()
        var current = ""
        for (w in words) {
            val trial = if (current.isEmpty()) w else "$current $w"
            if (paint.measureText(trial) > maxWidth && current.isNotEmpty()) {
                lines += current
                current = w
            } else {
                current = trial
            }
        }
        if (current.isNotEmpty()) lines += current
        return lines
    }
}
