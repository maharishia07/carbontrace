package com.carbontrace.carbontrace

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * ECU access over an ELM327 OBD-II Bluetooth adapter (classic SPP).
 *
 * Optional pro path: the core product needs no hardware, but with a
 * commodity ELM327 dongle plugged into the car's OBD port this bridge
 * reads live ECU data â€” RPM, coolant temperature, MAF airflow (=> real
 * fuel burn), fuel level. Experimental: written to the ELM327 protocol
 * spec, needs an adapter to validate against.
 */
class ObdBridge(private val activity: Activity) {
    companion object {
        val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        const val PERMISSION_REQ = 4411
    }

    private var socket: BluetoothSocket? = null

    fun ensurePermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val ok = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED
        if (!ok) {
            ActivityCompat.requestPermissions(
                activity, arrayOf(Manifest.permission.BLUETOOTH_CONNECT), PERMISSION_REQ
            )
        }
        return ok
    }

    fun pairedDevices(): List<Map<String, String>> {
        if (!ensurePermission()) return emptyList()
        val adapter = activity.getSystemService(BluetoothManager::class.java)?.adapter
            ?: return emptyList()
        return try {
            adapter.bondedDevices.map { mapOf("name" to (it.name ?: "?"), "address" to it.address) }
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    fun connect(address: String): Boolean {
        if (!ensurePermission()) return false
        val adapter = activity.getSystemService(BluetoothManager::class.java)?.adapter
            ?: return false
        return try {
            val device = adapter.getRemoteDevice(address)
            val s = device.createRfcommSocketToServiceRecord(SPP_UUID)
            adapter.cancelDiscovery()
            s.connect()
            socket = s
            // ELM327 init: reset, echo/linefeed/spaces off, auto protocol
            for (cmd in listOf("ATZ", "ATE0", "ATL0", "ATS0", "ATSP0")) {
                command(cmd)
            }
            true
        } catch (_: Exception) {
            socket = null
            false
        }
    }

    fun disconnect() {
        try { socket?.close() } catch (_: Exception) {}
        socket = null
    }

    val connected: Boolean get() = socket?.isConnected == true

    /** One ECU snapshot; null values where the car doesn't answer a PID. */
    fun readSnapshot(): Map<String, Double?> {
        return mapOf(
            "rpm" to pid("010C") { a, b -> (a * 256 + b) / 4.0 },
            "coolant_c" to pid("0105") { a, _ -> a - 40.0 },
            "maf_g_s" to pid("0110") { a, b -> (a * 256 + b) / 100.0 },
            "fuel_level_pct" to pid("012F") { a, _ -> a * 100.0 / 255.0 },
            "speed_kmh" to pid("010D") { a, _ -> a.toDouble() },
        )
    }

    private fun pid(cmd: String, decode: (Int, Int) -> Double): Double? {
        val raw = command(cmd) ?: return null
        // expected like "410C1AF8" (ATS0 strips spaces); find the echo of the PID
        val hex = raw.replace(Regex("[^0-9A-Fa-f]"), "")
        val marker = "41" + cmd.substring(2)
        val at = hex.indexOf(marker)
        if (at < 0 || hex.length < at + marker.length + 2) return null
        val data = hex.substring(at + marker.length)
        val a = data.substring(0, 2).toIntOrNull(16) ?: return null
        val b = if (data.length >= 4) data.substring(2, 4).toIntOrNull(16) ?: 0 else 0
        return decode(a, b)
    }

    /** Send a command, read until the ELM '>' prompt (2s budget). */
    private fun command(cmd: String): String? {
        val s = socket ?: return null
        return try {
            s.outputStream.write((cmd + "\r").toByteArray())
            s.outputStream.flush()
            val buf = StringBuilder()
            val start = System.currentTimeMillis()
            while (System.currentTimeMillis() - start < 2000) {
                if (s.inputStream.available() > 0) {
                    val c = s.inputStream.read()
                    if (c == '>'.code) return buf.toString()
                    buf.append(c.toChar())
                } else {
                    Thread.sleep(20)
                }
            }
            buf.toString().ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    /** Wire this bridge onto a MethodChannel (calls run off the UI thread). */
    fun attach(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            Thread {
                val out: Any? = when (call.method) {
                    "pairedDevices" -> pairedDevices()
                    "connect" -> connect(call.argument<String>("address") ?: "")
                    "disconnect" -> { disconnect(); true }
                    "connected" -> connected
                    "read" -> if (connected) readSnapshot() else null
                    else -> null
                }
                activity.runOnUiThread {
                    if (call.method in listOf("pairedDevices", "connect", "disconnect", "connected", "read")) {
                        result.success(out)
                    } else {
                        result.notImplemented()
                    }
                }
            }.start()
        }
    }
}

