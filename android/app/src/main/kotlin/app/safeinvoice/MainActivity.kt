package app.safeinvoice

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "app.safeinvoice/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        val title = call.argument<String>("title") ?: "Share"
                        val body = call.argument<String>("body") ?: ""
                        val email = call.argument<String>("email")
                        val target = call.argument<String>("target") ?: "chooser"
                        val displayName = call.argument<String>("displayName")
                        shareFile(path, mime, title, body, email, target, displayName, result)
                    }
                    "clipboardImage" -> result.success(clipboardImagePng())
                    "openWhatsAppChat" -> {
                        val number = call.argument<String>("number") ?: ""
                        openWhatsAppChat(number, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun digitsOnly(raw: String): String {
        val stripped = raw.filter { it.isDigit() }
        return when {
            stripped.startsWith("00") -> stripped.drop(2)
            stripped.startsWith("0") && stripped.length in 9..11 -> "27${stripped.drop(1)}"
            else -> stripped
        }
    }

    private fun openWhatsAppChat(raw: String, result: MethodChannel.Result) {
        val digits = digitsOnly(raw)
        if (digits.length < 8) {
            result.error("bad_number", "Enter a WhatsApp or phone number first.", raw)
            return
        }
        val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { isInstalled(it) }
        if (pkg == null) {
            result.error(
                "no_whatsapp",
                "WhatsApp is not installed on this phone. Install WhatsApp, then try again.",
                null,
            )
            return
        }
        val uri = Uri.parse("https://wa.me/$digits")
        try {
            startActivity(
                Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(pkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error(
                "no_whatsapp",
                "WhatsApp is not installed on this phone. Install WhatsApp, then try again.",
                null,
            )
        }
    }

    private fun uriFor(file: File): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

    private fun grantToResolvers(intent: Intent, uri: Uri) {
        val matches = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }
        for (info in matches) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
    }

    private fun isInstalled(pkg: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(pkg, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun shareFile(
        path: String,
        mime: String,
        title: String,
        body: String,
        email: String?,
        target: String,
        displayName: String?,
        result: MethodChannel.Result,
    ) {
        val source = File(path)
        if (!source.exists() || source.length() < 100) {
            result.error("missing", "The invoice PDF file was not found.", path)
            return
        }
        val safeName = (displayName ?: source.name).replace(Regex("[^A-Za-z0-9._-]"), "_")
        val staged = File(cacheDir, if (safeName.isBlank()) "Invoice.pdf" else safeName)
        source.copyTo(staged, overwrite = true)
        val uri = uriFor(staged)
        val sendMime = if (mime.isBlank()) "application/pdf" else mime

        fun intentFor(pkg: String?): Intent {
            return Intent(Intent.ACTION_SEND).apply {
                type = sendMime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, title)
                putExtra(Intent.EXTRA_TEXT, body)
                putExtra(Intent.EXTRA_TITLE, staged.name)
                clipData = ClipData.newRawUri(staged.name, uri)
                if (!email.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (pkg != null) {
                    setPackage(pkg)
                    grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    grantToResolvers(this, uri)
                }
            }
        }

        try {
            when (target) {
                "whatsapp" -> {
                    val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { isInstalled(it) }
                    if (pkg == null) {
                        result.error(
                            "no_whatsapp",
                            "WhatsApp is not installed on this phone. Install WhatsApp, then share the PDF again.",
                            null,
                        )
                        return
                    }
                    startActivity(intentFor(pkg))
                    result.success(true)
                }
                "email" -> {
                    val emailIntent = intentFor(null)
                    startActivity(Intent.createChooser(emailIntent, title))
                    result.success(true)
                }
                else -> {
                    startActivity(Intent.createChooser(intentFor(null), title))
                    result.success(true)
                }
            }
        } catch (_: ActivityNotFoundException) {
            val code = if (target == "whatsapp") "no_whatsapp" else "no_app"
            val message = if (target == "whatsapp") {
                "WhatsApp is not installed on this phone. Install WhatsApp, then share the PDF again."
            } else {
                "No app was found to share this invoice."
            }
            result.error(code, message, target)
        }
    }

    private fun clipboardImagePng(): ByteArray? {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        val clip: ClipData = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val item = clip.getItemAt(0)
        val uri = item.uri ?: return null
        return try {
            val bitmap = if (Build.VERSION.SDK_INT >= 28) {
                ImageDecoder.decodeBitmap(ImageDecoder.createSource(contentResolver, uri))
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Images.Media.getBitmap(contentResolver, uri)
            }
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        } catch (_: Exception) {
            null
        }
    }
}
