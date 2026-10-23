package com.example.watsolution_mobil

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import android.view.WindowManager
import android.app.Activity
import android.content.Intent
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.net.Uri
import android.content.ClipData
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingPdf: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var receiptPrinter: ReceiptPrinter

    private fun openSavedPdf(uri: Uri) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                clipData = ClipData.newRawUri("PDF", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
        } catch (_: Exception) {
            Toast.makeText(this, "PDF guardado. No se pudo abrir un visor de PDF en este dispositivo.", Toast.LENGTH_LONG).show()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        receiptPrinter = ReceiptPrinter(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "watsolution/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                } else if (pendingResult != null) {
                    result.error("BUSY", "Ya hay un documento abierto", null)
                } else {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("INVALID", "Documento inválido", null)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val name = (call.argument<String>("name") ?: "comprobante.pdf")
                            .replace(Regex("[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ _.()-]"), "_")
                        Thread {
                            var uri: android.net.Uri? = null
                            try {
                                val values = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                                    put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                }
                                uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                    ?: throw IllegalStateException("Destino no disponible")
                                val stream = contentResolver.openOutputStream(uri)
                                    ?: throw IllegalStateException("Destino no disponible")
                                stream.use { it.write(bytes) }
                                contentResolver.update(uri, ContentValues().apply {
                                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                                }, null, null)
                                val savedUri = uri
                                runOnUiThread {
                                    result.success(true)
                                    openSavedPdf(savedUri)
                                }
                            } catch (_: Exception) {
                                uri?.let { try { contentResolver.delete(it, null, null) } catch (_: Exception) {} }
                                runOnUiThread { result.error("SAVE", "No se pudo guardar en Descargas", null) }
                            }
                        }.start()
                    } else {
                        pendingPdf = bytes
                        pendingResult = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "comprobante.pdf")
                            }, 4012)
                        } catch (_: Exception) {
                            pendingPdf = null
                            pendingResult = null
                            result.error("SAVE", "No se pudo abrir el selector", null)
                        }
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4012) return
        val result = pendingResult
        val bytes = pendingPdf
        pendingResult = null
        pendingPdf = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
            result?.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(data.data!!)
                ?: throw IllegalStateException("Destino no disponible")
            stream.use { it.write(bytes) }
            result?.success(true)
            openSavedPdf(data.data!!)
        } catch (_: Exception) {
            result?.error("SAVE", "No se pudo guardar el documento", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::receiptPrinter.isInitialized) receiptPrinter.permissionResult(requestCode)
    }

    override fun onDestroy() {
        if (::receiptPrinter.isInitialized) receiptPrinter.close()
        super.onDestroy()
    }
}
