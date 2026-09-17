package app.safeinvoice.data.excel

import android.content.Context
import android.net.Uri
import app.safeinvoice.util.Money
import org.apache.poi.hssf.usermodel.HSSFWorkbook
import org.apache.poi.ss.usermodel.CellType
import org.apache.poi.ss.usermodel.DateUtil
import org.apache.poi.ss.usermodel.Workbook
import org.apache.poi.ss.usermodel.WorkbookFactory
import org.apache.poi.xssf.usermodel.XSSFWorkbook
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Locale

data class SheetPreview(
    val fileName: String,
    val sheetName: String,
    val headers: List<String>,
    val rows: List<List<String>>,
)

class ExcelService(private val context: Context) {

    fun preview(uri: Uri, displayName: String): SheetPreview {
        val name = displayName.lowercase(Locale.ROOT)
        return if (name.endsWith(".csv")) {
            val (headers, rows) = readCsv(uri)
            SheetPreview(displayName, "CSV", headers, rows.take(25))
        } else {
            context.contentResolver.openInputStream(uri)?.use { input ->
                WorkbookFactory.create(input).use { wb ->
                    val sheet = wb.getSheetAt(0)
                    val headers = rowValues(sheet.getRow(0))
                    val rows = (1..minOf(sheet.lastRowNum, 25)).map { r ->
                        rowValues(sheet.getRow(r), headers.size)
                    }
                    SheetPreview(displayName, sheet.sheetName ?: "Sheet1", headers, rows)
                }
            } ?: SheetPreview(displayName, "", emptyList(), emptyList())
        }
    }

    fun readAll(uri: Uri, displayName: String): Pair<List<String>, List<List<String>>> {
        val name = displayName.lowercase(Locale.ROOT)
        return if (name.endsWith(".csv")) {
            readCsv(uri)
        } else {
            context.contentResolver.openInputStream(uri)?.use { input ->
                WorkbookFactory.create(input).use { wb ->
                    val sheet = wb.getSheetAt(0)
                    val headers = rowValues(sheet.getRow(0))
                    val rows = (1..sheet.lastRowNum).map { r ->
                        rowValues(sheet.getRow(r), headers.size)
                    }.filter { row -> row.any { it.isNotBlank() } }
                    headers to rows
                }
            } ?: (emptyList<String>() to emptyList())
        }
    }

    fun writeWorkbook(
        dest: File,
        sheets: Map<String, Pair<List<String>, List<List<String>>>>,
        xls: Boolean = false,
    ): File {
        dest.parentFile?.mkdirs()
        val wb: Workbook = if (xls) HSSFWorkbook() else XSSFWorkbook()
        sheets.forEach { (name, content) ->
            val sheet = wb.createSheet(name.take(31))
            val headerRow = sheet.createRow(0)
            content.first.forEachIndexed { i, h -> headerRow.createCell(i).setCellValue(h) }
            content.second.forEachIndexed { r, row ->
                val excelRow = sheet.createRow(r + 1)
                row.forEachIndexed { c, v -> excelRow.createCell(c).setCellValue(v) }
            }
            content.first.indices.forEach { sheet.setColumnWidth(it, 18 * 256) }
        }
        dest.outputStream().use { wb.write(it) }
        wb.close()
        return dest
    }

    fun writeCsv(dest: File, headers: List<String>, rows: List<List<String>>): File {
        dest.parentFile?.mkdirs()
        dest.writeText(buildString {
            appendLine(headers.joinToString(",") { csvEscape(it) })
            rows.forEach { row ->
                appendLine(row.joinToString(",") { csvEscape(it) })
            }
        }, StandardCharsets.UTF_8)
        return dest
    }

    fun cell(row: List<String>, mapping: Map<String, Int>, key: String): String {
        val idx = mapping[key] ?: return ""
        if (idx < 0 || idx >= row.size) return ""
        return row[idx].trim()
    }

    fun parseAmount(raw: String): Double {
        val cleaned = raw.replace("R", "", ignoreCase = true)
            .replace("ZAR", "", ignoreCase = true)
            .replace(",", "")
            .replace("\\s".toRegex(), "")
            .trim()
        return cleaned.toDoubleOrNull()?.let { Money.round(it) } ?: 0.0
    }

    private fun readCsv(uri: Uri): Pair<List<String>, List<List<String>>> {
        val lines = context.contentResolver.openInputStream(uri)?.use { input ->
            BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).readLines()
        } ?: return emptyList<String>() to emptyList()
        if (lines.isEmpty()) return emptyList<String>() to emptyList()
        val headers = splitCsv(lines.first())
        val rows = lines.drop(1).map { splitCsv(it, headers.size) }.filter { row -> row.any { it.isNotBlank() } }
        return headers to rows
    }

    private fun rowValues(row: org.apache.poi.ss.usermodel.Row?, minSize: Int = 0): List<String> {
        if (row == null) return List(minSize) { "" }
        val last = maxOf(row.lastCellNum.toInt(), minSize)
        return (0 until last).map { i ->
            val cell = row.getCell(i) ?: return@map ""
            when (cell.cellType) {
                CellType.STRING -> cell.stringCellValue.orEmpty()
                CellType.BOOLEAN -> cell.booleanCellValue.toString()
                CellType.NUMERIC -> {
                    if (DateUtil.isCellDateFormatted(cell)) {
                        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cell.dateCellValue)
                    } else {
                        val n = cell.numericCellValue
                        if (n % 1.0 == 0.0) n.toLong().toString() else n.toString()
                    }
                }
                CellType.FORMULA -> try {
                    cell.stringCellValue
                } catch (_: Exception) {
                    cell.numericCellValue.toString()
                }
                else -> ""
            }
        }
    }

    private fun splitCsv(line: String, minSize: Int = 0): List<String> {
        val out = mutableListOf<String>()
        val cur = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' && inQuotes && i + 1 < line.length && line[i + 1] == '"' -> {
                    cur.append('"'); i++
                }
                c == '"' -> inQuotes = !inQuotes
                c == ',' && !inQuotes -> {
                    out += cur.toString(); cur.clear()
                }
                else -> cur.append(c)
            }
            i++
        }
        out += cur.toString()
        while (out.size < minSize) out += ""
        return out
    }

    private fun csvEscape(value: String): String {
        return if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            "\"${value.replace("\"", "\"\"")}\""
        } else value
    }
}

object CustomerImportFields {
    val fields = listOf(
        "name" to "Customer name",
        "contactName" to "Contact",
        "email" to "Email",
        "phone" to "Phone",
        "addressLine1" to "Address",
        "city" to "City",
        "province" to "Province",
        "postalCode" to "Postal code",
        "vatNumber" to "VAT number",
        "notes" to "Notes",
    )
}

object InvoiceImportFields {
    val fields = listOf(
        "customerName" to "Customer name",
        "number" to "Invoice number",
        "status" to "Status",
        "issueDate" to "Issue date",
        "dueDate" to "Due date",
        "description" to "Line description",
        "quantity" to "Quantity",
        "unitPrice" to "Unit price",
        "total" to "Total",
        "notes" to "Notes",
    )
}

fun guessMapping(headers: List<String>, fields: List<Pair<String, String>>): Map<String, Int> {
    val normalized = headers.map { it.lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "") }
    return fields.associate { (key, label) ->
        val aliases = listOf(key, label).map { it.lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "") }
        val idx = normalized.indexOfFirst { h -> aliases.any { a -> h.contains(a) || a.contains(h) } }
        key to idx
    }
}
