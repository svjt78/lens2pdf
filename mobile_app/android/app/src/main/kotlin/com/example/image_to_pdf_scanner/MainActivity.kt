package com.example.image_to_pdf_scanner

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "share_targets"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            val path = args?.get("path") as? String
            if (path == null) {
                result.error("BAD_ARGS", "missing path", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "email" -> {
                    val subject = args["subject"] as? String ?: "My Scan"
                    val body = args["body"] as? String ?: ""
                    val summary = args["summaryText"] as? String ?: ""
                    val metadataPath = args["metadataPath"] as? String
                    val metadataMime = args["metadataMime"] as? String ?: "application/json"
                    shareEmail(path, subject, body, summary, metadataPath, metadataMime)
                    result.success(null)
                }
                "sms" -> {
                    val body = args["body"] as? String ?: ""
                    val summary = args["summaryText"] as? String ?: ""
                    val metadataPath = args["metadataPath"] as? String
                    shareSms(path, body, summary, metadataPath)
                    result.success(null)
                }
                "whatsapp" -> {
                    val summary = args["summaryText"] as? String ?: ""
                    val metadataPath = args["metadataPath"] as? String
                    shareWhatsApp(path, summary, metadataPath)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun fileUri(path: String): Uri {
        val file = File(path)
        return FileProvider.getUriForFile(this, applicationContext.packageName + ".fileprovider", file)
    }

    private fun shareEmail(
        path: String,
        subject: String,
        body: String,
        summary: String,
        metadataPath: String?,
        metadataMime: String
    ) {
        val pdfUri = fileUri(path)
        val metadataUri = metadataPath?.let { maybePath ->
            val file = File(maybePath)
            if (file.exists()) fileUri(file.path) else null
        }
        val uris = arrayListOf(pdfUri)
        metadataUri?.let { uris.add(it) }

        val composedBody = when {
            body.isBlank() && summary.isNotBlank() -> summary
            summary.isBlank() -> body
            body.isBlank() -> summary
            else -> "$body\n\n$summary"
        }

        val intent = if (uris.size > 1) Intent(Intent.ACTION_SEND_MULTIPLE) else Intent(Intent.ACTION_SEND)
        intent.type = if (uris.size > 1) "*/*" else "application/pdf"
        intent.putExtra(Intent.EXTRA_SUBJECT, subject)
        intent.putExtra(Intent.EXTRA_TEXT, composedBody)
        if (uris.size > 1) {
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        } else {
            intent.putExtra(Intent.EXTRA_STREAM, pdfUri)
        }
        val clip = ClipData.newUri(contentResolver, "pdf", pdfUri)
        if (metadataUri != null) {
            clip.addItem(ClipData.Item(metadataUri))
            intent.type = "*/*"
        }
        intent.clipData = clip
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        metadataUri?.let {
            intent.type = "*/*"
            intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", metadataMime))
        }
        startActivity(Intent.createChooser(intent, "Email"))
    }

    private fun shareSms(path: String, body: String, summary: String, metadataPath: String?) {
        val pdfUri = fileUri(path)
        val metadataUri = metadataPath?.let { maybePath ->
            val file = File(maybePath)
            if (file.exists()) fileUri(file.path) else null
        }
        val uris = arrayListOf(pdfUri)
        metadataUri?.let { uris.add(it) }

        val composedBody = when {
            body.isBlank() && summary.isNotBlank() -> summary
            summary.isBlank() -> body
            body.isBlank() -> summary
            else -> "$body\n\n$summary"
        }

        val intent = if (uris.size > 1) Intent(Intent.ACTION_SEND_MULTIPLE) else Intent(Intent.ACTION_SEND)
        intent.type = if (uris.size > 1) "*/*" else "application/pdf"
        intent.putExtra(Intent.EXTRA_TEXT, composedBody)
        if (uris.size > 1) {
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        } else {
            intent.putExtra(Intent.EXTRA_STREAM, pdfUri)
        }
        val clip = ClipData.newUri(contentResolver, "pdf", pdfUri)
        if (metadataUri != null) {
            clip.addItem(ClipData.Item(metadataUri))
            intent.type = "*/*"
        }
        intent.clipData = clip
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.setPackage("com.google.android.apps.messaging")
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent.createChooser(intent, "SMS"))
        }
    }

    private fun shareWhatsApp(path: String, summary: String, metadataPath: String?) {
        val pdfUri = fileUri(path)
        val metadataUri = metadataPath?.let { maybePath ->
            val file = File(maybePath)
            if (file.exists()) fileUri(file.path) else null
        }
        val uris = arrayListOf(pdfUri)
        metadataUri?.let { uris.add(it) }

        val intent = if (uris.size > 1) Intent(Intent.ACTION_SEND_MULTIPLE) else Intent(Intent.ACTION_SEND)
        intent.type = if (uris.size > 1) "*/*" else "application/pdf"
        intent.putExtra(Intent.EXTRA_TEXT, summary)
        if (uris.size > 1) {
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
        } else {
            intent.putExtra(Intent.EXTRA_STREAM, pdfUri)
        }
        val clip = ClipData.newUri(contentResolver, "pdf", pdfUri)
        if (metadataUri != null) {
            clip.addItem(ClipData.Item(metadataUri))
            intent.type = "*/*"
        }
        intent.clipData = clip
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.setPackage("com.whatsapp")
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent.createChooser(intent, "WhatsApp"))
        }
    }
}
