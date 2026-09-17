package app.safeinvoice.data.files

import android.content.Context
import app.safeinvoice.data.entity.FolderType
import java.io.File
import java.io.InputStream

class LocalStorage(context: Context) {
    private val root: File = File(context.filesDir, "businesses").apply { mkdirs() }

    fun businessDir(businessId: String): File =
        File(root, businessId).apply { mkdirs() }

    fun customerDir(businessId: String, customerId: String): File =
        File(businessDir(businessId), "customers/$customerId").apply { mkdirs() }

    fun folder(businessId: String, customerId: String, type: FolderType): File =
        File(customerDir(businessId, customerId), type.name.lowercase()).apply { mkdirs() }

    fun templatesDir(businessId: String): File =
        File(businessDir(businessId), "templates").apply { mkdirs() }

    fun logosDir(businessId: String): File =
        File(businessDir(businessId), "logos").apply { mkdirs() }

    fun relativeToFiles(file: File, context: Context): String =
        file.relativeTo(context.filesDir).path

    fun resolve(context: Context, relativePath: String): File =
        File(context.filesDir, relativePath)

    fun copyInto(input: InputStream, dest: File): File {
        dest.parentFile?.mkdirs()
        dest.outputStream().use { out -> input.copyTo(out) }
        return dest
    }

    fun uniqueFile(dir: File, baseName: String): File {
        val safe = baseName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        var candidate = File(dir, safe)
        if (!candidate.exists()) return candidate
        val dot = safe.lastIndexOf('.')
        val stem = if (dot > 0) safe.substring(0, dot) else safe
        val ext = if (dot > 0) safe.substring(dot) else ""
        var i = 2
        while (candidate.exists()) {
            candidate = File(dir, "${stem}_$i$ext")
            i++
        }
        return candidate
    }
}
