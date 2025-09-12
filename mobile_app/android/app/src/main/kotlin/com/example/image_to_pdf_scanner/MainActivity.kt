package com.example.image_to_pdf_scanner

import android.content.ActivityNotFoundException
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
                    shareEmail(path, subject, body)
                    result.success(null)
                }
                "sms" -> {
                    val body = args["body"] as? String ?: ""
                    shareSms(path, body)
                    result.success(null)
                }
                "whatsapp" -> {
                    shareWhatsApp(path)
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

    private fun shareEmail(path: String, subject: String, body: String) {
        val uri = fileUri(path)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "message/rfc822"
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Email"))
    }

    private fun shareSms(path: String, body: String) {
        val uri = fileUri(path)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_TEXT, body)
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // Prefer Google Messages if available
            setPackage("com.google.android.apps.messaging")
        }
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent.createChooser(intent, "SMS"))
        }
    }

    private fun shareWhatsApp(path: String) {
        val uri = fileUri(path)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            setPackage("com.whatsapp")
        }
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent.createChooser(intent, "WhatsApp"))
        }
    }
}
