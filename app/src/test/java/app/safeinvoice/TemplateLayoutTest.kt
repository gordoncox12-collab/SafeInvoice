package app.safeinvoice

import app.safeinvoice.data.entity.AccentPalette
import app.safeinvoice.data.entity.FolderType
import app.safeinvoice.data.entity.LogoAlignment
import app.safeinvoice.data.entity.MarginPreset
import app.safeinvoice.data.entity.PicturePlacement
import app.safeinvoice.data.entity.TemplateLayout
import app.safeinvoice.data.entity.ThemeMode
import app.safeinvoice.data.excel.CustomerImportFields
import app.safeinvoice.data.excel.InvoiceImportFields
import app.safeinvoice.data.excel.guessMapping
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TemplateLayoutTest {
    @Test
    fun adjustableLayoutsArePresent() {
        val names = TemplateLayout.entries.map { it.name }.toSet()
        assertTrue(names.containsAll(setOf("CLASSIC", "MODERN", "COMPACT", "LETTERHEAD", "MINIMAL")))
    }

    @Test
    fun layoutKnobsExist() {
        assertEquals(3, LogoAlignment.entries.size)
        assertEquals(3, MarginPreset.entries.size)
        assertEquals(3, PicturePlacement.entries.size)
        assertEquals(3, ThemeMode.entries.size)
        assertTrue(AccentPalette.entries.size >= 8)
        assertTrue(FolderType.entries.map { it.name }.containsAll(listOf("INVOICES", "RECEIPTS", "EXCEL", "IMAGES", "NOTES")))
    }

    @Test
    fun excelColumnGuessMapsCustomerName() {
        val mapping = guessMapping(listOf("Customer Name", "Email", "Phone"), CustomerImportFields.fields)
        assertEquals(0, mapping["name"])
        assertEquals(1, mapping["email"])
        assertEquals(2, mapping["phone"])
    }

    @Test
    fun excelColumnGuessMapsInvoiceLines() {
        val mapping = guessMapping(
            listOf("Invoice number", "Customer name", "Line description", "Qty", "Unit price"),
            InvoiceImportFields.fields,
        )
        assertEquals(0, mapping["number"])
        assertEquals(1, mapping["customerName"])
        assertEquals(2, mapping["description"])
        assertEquals(3, mapping["quantity"])
        assertEquals(4, mapping["unitPrice"])
    }
}
