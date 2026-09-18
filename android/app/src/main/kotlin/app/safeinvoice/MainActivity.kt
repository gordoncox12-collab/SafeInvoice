package app.safeinvoice

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
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
                        val mime = call.argument<String>("mime") ?: "*/*"
                        val title = call.argument<String>("title") ?: "Share"
                        val body = call.argument<String>("body") ?: ""
                        val email = call.argument<String>("email")
                        val target = call.argument<String>("target") ?: "chooser"
                        shareFile(path, mime, title, body, email, target, result)
                    }
                    "clipboardImage" -> result.success(clipboardImagePng())
                    else -> result.notImplemented()
                }
            }
    }

    private fun uriFor(file: File): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

    private fun shareFile(
        path: String,
        mime: String,
        title: String,
        body: String,
        email: String?,
        target: String,
        result: MethodChannel.Result,
    ) {
        val file = File(path)
        if (!file.exists()) {
            result.error("missing", "File not found", path)
            return
        }
        val uri = uriFor(file)
        fun intentFor(pkg: String?): Intent {
            return Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, title)
                putExtra(Intent.EXTRA_TEXT, body)
                if (!email.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (pkg != null) setPackage(pkg)
            }
        }
        try {
            when (target) {
                "whatsapp" -> {
                    for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                        val intent = intentFor(pkg)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                            return
                        }
                    }
                    startActivity(Intent.createChooser(intentFor(null), title))
                    result.success(true)
                }
                "email" -> {
                    val emailIntent = intentFor(null).apply { type = "message/rfc822" }
                    startActivity(Intent.createChooser(emailIntent, title))
                    result.success(true)
                }
                else -> {
                    startActivity(Intent.createChooser(intentFor(null), title))
                    result.success(true)
                }
            }
        } catch (_: ActivityNotFoundException) {
            result.error("no_app", "No app found to share", target)
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
