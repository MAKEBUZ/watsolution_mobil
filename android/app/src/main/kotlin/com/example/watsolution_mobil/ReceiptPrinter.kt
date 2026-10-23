package com.example.watsolution_mobil

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.*
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Paired Bluetooth Classic SPP printers only. No scanning or location access. */
class ReceiptPrinter(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "watsolution/printer")
    private val busy = AtomicBoolean(false)
    @Volatile private var socket: BluetoothSocket? = null
    private var permissionReply: MethodChannel.Result? = null
    private val timer = Executors.newSingleThreadScheduledExecutor()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(null)
                }
                "devices" -> {
                    if (!hasPermission()) {
                        if (permissionReply != null) result.error("BUSY", "Espera el permiso Bluetooth.", null)
                        else {
                            permissionReply = result
                            activity.requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 4013)
                        }
                    } else devices(result)
                }
                "print" -> {
                    val address = call.argument<String>("address")
                    val lines = call.argument<List<String>>("lines")
                    if (!hasPermission()) result.error("PERMISSION", "Autoriza Bluetooth primero.", null)
                    else if (address == null || lines == null || lines.isEmpty() || lines.size > 150 || lines.any { it.length > 512 })
                        result.error("INVALID", "Comprobante inválido.", null)
                    else printReceipt(address, lines, result)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun hasPermission() = Build.VERSION.SDK_INT < 31 ||
        activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    fun permissionResult(code: Int) {
        if (code != 4013) return
        val result = permissionReply ?: return
        permissionReply = null
        if (hasPermission()) devices(result)
        else result.error("PERMISSION", "Permite dispositivos cercanos para imprimir.", null)
    }
    private fun adapter() = activity.getSystemService(BluetoothManager::class.java)?.adapter

    private fun devices(result: MethodChannel.Result) {
        try {
            val adapter = adapter() ?: throw IllegalStateException()
            if (!adapter.isEnabled) {
                result.error("OFF", "Activa Bluetooth en la tablet.", null)
                return
            }
            result.success(adapter.bondedDevices.map { mapOf("name" to (it.name ?: "Impresora"), "address" to it.address) })
        } catch (_: Exception) { result.error("BLUETOOTH", "No se pudo consultar Bluetooth.", null) }
    }

    private fun printReceipt(address: String, lines: List<String>, result: MethodChannel.Result) {
        if (!busy.compareAndSet(false, true)) {
            result.error("BUSY", "Hay una impresión en curso.", null)
            return
        }
        Thread {
            var sent = false
            var connection: BluetoothSocket? = null
            var timeout: java.util.concurrent.ScheduledFuture<*>? = null
            try {
                val device = adapter()?.bondedDevices?.firstOrNull { it.address == address }
                    ?: throw IllegalStateException()
                val active = device.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
                connection = active
                socket = active
                timeout = timer.schedule({ try { active.close() } catch (_: Exception) {} }, 45, TimeUnit.SECONDS)
                active.connect()
                val output = active.outputStream
                output.write(byteArrayOf(27, 64))
                // Rasterize locally so accents do not depend on firmware code pages.
                val paint = Paint().apply { color = Color.BLACK; textSize = 24f; typeface = Typeface.MONOSPACE; isAntiAlias = false }
                val renderedLines = lines.flatMap { original ->
                    val isTotal = original.startsWith("TOTAL ESTIMADO:")
                    paint.textSize = if (isTotal) 30f else 24f
                    val parts = if (isTotal) listOf("TOTAL ESTIMADO", original.substringAfter(':').trim()) else listOf(original)
                    parts.flatMap { part ->
                    if (part.isNotEmpty() && part.all { it == '-' }) listOf(part)
                    else {
                        val wrapped = mutableListOf<String>()
                        var remaining = part
                        while (paint.measureText(remaining) > 368f) {
                            val fits = paint.breakText(remaining, true, 368f, null).coerceAtLeast(1)
                            val space = remaining.lastIndexOf(' ', fits)
                            val end = if (space > 0) space else fits
                            wrapped.add(remaining.substring(0, end))
                            remaining = remaining.substring(end).trimStart()
                        }
                        wrapped.add(remaining)
                        wrapped
                    }
                    }.map { Pair(it, isTotal) }
                }
                for ((lineIndex, rendered) in renderedLines.withIndex()) {
                    val (line, isTotal) = rendered
                    val isTitle = lineIndex < 2
                    paint.isFakeBoldText = isTitle || isTotal
                    paint.textSize = if (isTotal) 30f else 24f
                    val bandHeight = if (isTotal) 44 else 36
                    val bitmap = Bitmap.createBitmap(384, bandHeight, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    canvas.drawColor(Color.WHITE)
                    // Small, equal insets; separators span the full content width.
                    if (line.isNotEmpty() && line.all { it == '-' }) {
                        var x = 8f
                        while (x < 376f) {
                            canvas.drawRect(x, 18f, minOf(x + 6f, 376f), 20f, paint)
                            x += 10f
                        }
                    } else {
                        val left = if (isTitle) (384f - paint.measureText(line)) / 2f else 8f
                        canvas.drawText(line, left, if (isTotal) 34f else 28f, paint)
                    }
                    val raster = ByteArray(48 * bandHeight)
                    for (y in 0 until bandHeight) for (x in 0 until 384) {
                        if (Color.red(bitmap.getPixel(x, y)) < 128) {
                            val i = y * 48 + x / 8
                            raster[i] = (raster[i].toInt() or (128 shr (x % 8))).toByte()
                        }
                    }
                    bitmap.recycle()
                    sent = true
                    output.write(byteArrayOf(29, 118, 48, 0, 48, 0, bandHeight.toByte(), 0))
                    output.write(raster)
                    output.flush()
                    // Allow a slow portable printer to consume each raster band.
                    Thread.sleep(120)
                }
                // Send the margin as raster too: some clones do not honor ESC J
                // consistently after raster graphics. Two blank bands = 80 dots (~1 cm).
                repeat(2) {
                    output.write(byteArrayOf(29, 118, 48, 0, 48, 0, 40, 0))
                    output.write(ByteArray(48 * 40))
                    output.flush()
                    Thread.sleep(120)
                }
                // flush() only flushes the socket; leave time for the final bands
                // to reach the device before closing the Bluetooth connection.
                Thread.sleep(2000)
                activity.runOnUiThread { result.success(null) }
            } catch (_: Exception) {
                val message = if (sent) "Envío interrumpido. Revisa el papel antes de repetir: puede haberse impreso una parte."
                    else "No se pudo conectar. Enciende la impresora, cierra Thermer y comprueba que esté vinculada."
                activity.runOnUiThread { result.error("PRINT", message, null) }
            } finally {
                timeout?.cancel(false)
                try { connection?.close() } catch (_: Exception) {}
                socket = null
                busy.set(false)
            }
        }.start()
    }
    fun close() {
        channel.setMethodCallHandler(null)
        try { socket?.close() } catch (_: Exception) {}
        timer.shutdownNow()
        permissionReply?.error("CLOSED", "Pantalla cerrada.", null)
        permissionReply = null
    }
}
