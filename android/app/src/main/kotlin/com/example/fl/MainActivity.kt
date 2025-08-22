package com.example.fl

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.fl/downloads"

    private var pendingBytes: ByteArray? = null
    private var pendingMime: String = "application/octet-stream"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingFileName: String = "document"
    private val REQUEST_CREATE_DOCUMENT = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Using deprecated startActivityForResult for broad compatibility

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (bytes == null || fileName == null) {
                        result.error("BAD_ARGS", "bytes or fileName is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                            val itemUri = contentResolver.insert(collection, values)
                                ?: throw IllegalStateException("Failed to insert in MediaStore")
                            contentResolver.openOutputStream(itemUri)?.use { os ->
                                os.write(bytes)
                                os.flush()
                            }
                            // Mark as not pending
                            values.clear()
                            values.put(MediaStore.Downloads.IS_PENDING, 0)
                            contentResolver.update(itemUri, values, null, null)
                            itemUri
                        } else {
                            // Legacy: write directly to public Downloads
                            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            if (!downloads.exists()) downloads.mkdirs()
                            val outFile = File(downloads, fileName)
                            FileOutputStream(outFile).use { fos ->
                                fos.write(bytes)
                                fos.flush()
                            }
                            // Return a file:// uri string
                            android.net.Uri.fromFile(outFile)
                        }
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "pickAndSaveDocument" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (bytes == null || fileName == null) {
                        result.error("BAD_ARGS", "bytes or fileName is null", null)
                        return@setMethodCallHandler
                    }
                    // Launch system Save dialog (SAF)
                    pendingBytes = bytes
                    pendingMime = mimeType
                    pendingResult = result
                    pendingFileName = fileName
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = pendingMime
                            putExtra(Intent.EXTRA_TITLE, pendingFileName)
                        }
                        startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
                    } catch (e: Exception) {
                        pendingBytes = null
                        pendingResult = null
                        result.error("PICKER_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CREATE_DOCUMENT) {
            val res = pendingResult
            val bytes = pendingBytes
            pendingBytes = null
            pendingResult = null
            if (resultCode != RESULT_OK || data?.data == null || res == null || bytes == null) {
                res?.error("CANCELLED", "User cancelled or no data", null)
                return
            }
            val uri = data.data
            try {
                contentResolver.openOutputStream(uri!!)?.use { os ->
                    os.write(bytes)
                    os.flush()
                }
                res.success(uri.toString())
            } catch (e: Exception) {
                res.error("SAVE_FAILED", e.message, null)
            }
        }
    }
}
