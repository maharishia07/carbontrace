package com.carbontrace.carbontrace

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * The auto-start trigger.
 *
 * When the phone connects to the car's Bluetooth (ignition on), start the
 * foreground trip-recording service; when it disconnects (ignition off),
 * ask it to stop. The user selects which paired device is "the car" during
 * onboarding (stored in SharedPreferences as `car_bt_address`).
 */
class BluetoothTripReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            ?: return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val carAddress = prefs.getString("flutter.car_bt_address", null)
        // If no car is chosen yet, react to any hands-free device connect.
        if (carAddress != null && device.address != carAddress) return

        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> {
                val svc = Intent(context, TripRecordingService::class.java)
                    .putExtra("reason", "bluetooth_connect")
                ContextCompat.startForegroundService(context, svc)
            }
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                context.startService(
                    Intent(context, TripRecordingService::class.java)
                        .setAction(TripRecordingService.ACTION_STOP)
                )
            }
        }
    }
}

