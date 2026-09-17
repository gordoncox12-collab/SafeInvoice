package app.safeinvoice.data.share

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.core.content.FileProvider
import java.io.File

class ShareHelper(private val context: Context) {
    private fun uriFor(file: File) = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )

    fun mimeOf(file: File): String {
        val ext = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: when (ext) {
                "pdf" -> "application/pdf"
                "png" -> "image/png"
                "jpg", "jpeg" -> "image/jpeg"
                "webp" -> "image/webp"
                "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                "xls" -> "application/vnd.ms-excel"
                "csv" -> "text/csv"
                else -> "application/octet-stream"
            }
    }

    fun shareFile(file: File, title: String, body: String, email: String? = null, mime: String = mimeOf(file)) {
        val uri = uriFor(file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, title)
            putExtra(Intent.EXTRA_TEXT, body)
            if (!email.isNullOrBlank()) putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Share $title").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun sharePdf(file: File, title: String, body: String, email: String? = null) =
        shareFile(file, title, body, email, "application/pdf")

    fun emailFile(file: File, title: String, body: String, email: String?, mime: String = mimeOf(file)) {
        val uri = uriFor(file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, title)
            putExtra(Intent.EXTRA_TEXT, body)
            if (!email.isNullOrBlank()) putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(Intent.createChooser(intent, "Email $title").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(context, "No email app found", Toast.LENGTH_SHORT).show()
        }
    }

    fun emailPdf(file: File, title: String, body: String, email: String?) =
        emailFile(file, title, body, email, "application/pdf")

    fun whatsappFile(file: File, body: String, mime: String = mimeOf(file)) {
        val uri = uriFor(file)
        val packages = listOf("com.whatsapp", "com.whatsapp.w4b")
        for (pkg in packages) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                setPackage(pkg)
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, body)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                return
            }
        }
        shareFile(file, file.name, body, null, mime)
    }

    fun whatsappPdf(file: File, body: String) = whatsappFile(file, body, "application/pdf")
}
