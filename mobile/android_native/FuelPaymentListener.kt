package com.carbontrace.app

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Zero-touch litres capture: listens for payment notifications (UPI apps,
 * bank SMS relays, card alerts), keeps the ones that look like fuel
 * purchases, and queues them for the Flutter side, which converts the
 * rupee amount to litres via the stored fuel price and logs the fill-up
 * automatically — no typing at the pump.
 *
 * Privacy: runs entirely on-device; only notifications matching fuel
 * keywords are stored, and only amount + timestamp + source text.
 * Requires the user to grant Notification Access explicitly.
 */
class FuelPaymentListener : NotificationListenerService() {

    companion object {
        private val AMOUNT = Regex("""(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.\d{1,2})?)""", RegexOption.IGNORE_CASE)
        private val FUEL_HINTS = listOf(
            "petrol", "diesel", "fuel", "filling", "iocl", "indian oil", "indianoil",
            "hpcl", "hp pay", "bpcl", "bharat petroleum", "hindustan petroleum",
            "shell", "nayara", "jio-bp", "jiobp", "petro",
        )
        const val PREFS = "FlutterSharedPreferences"
        const val KEY = "flutter.pending_fuel_payments"
        const val MAX_PENDING = 10
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val extras = sbn.notification.extras
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val text = listOfNotNull(
                extras.getCharSequence("android.text")?.toString(),
                extras.getCharSequence("android.bigText")?.toString(),
            ).joinToString(" ")
            val hay = "$title $text".lowercase()

            if (FUEL_HINTS.none { hay.contains(it) }) return
            val amount = AMOUNT.find("$title $text")
                ?.groupValues?.get(1)?.replace(",", "")?.toDoubleOrNull() ?: return
            if (amount < 50 || amount > 20000) return  // not a plausible fuel purchase

            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString(KEY, "[]") ?: "[]")
            val entry = JSONObject()
                .put("t", System.currentTimeMillis() / 1000.0)
                .put("amount_inr", amount)
                .put("source", "${sbn.packageName}: $title")
            arr.put(entry)
            // keep only the newest few
            val trimmed = JSONArray()
            val start = maxOf(0, arr.length() - MAX_PENDING)
            for (i in start until arr.length()) trimmed.put(arr.get(i))
            prefs.edit().putString(KEY, trimmed.toString()).apply()
        } catch (_: Exception) {
            // never crash inside a notification listener
        }
    }
}
