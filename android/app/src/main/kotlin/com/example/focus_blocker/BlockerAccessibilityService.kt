package com.example.focus_blocker

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class BlockerAccessibilityService : AccessibilityService() {

    companion object {
        var isLocked: Boolean = false
        var blockedPackages: MutableSet<String> = mutableSetOf()
        var whitelistMode: Boolean = false
        var allowedPackages: MutableSet<String> = mutableSetOf(
            "com.example.focus_blocker",
            "com.android.phone",
            "com.google.android.dialer",
            "com.samsung.android.dialer"
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isLocked || event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            // Kendi uygulamamız veya acil arama ise engelleme
            if (packageName == "com.example.focus_blocker" || 
                packageName == "com.android.phone" || 
                packageName == "com.google.android.dialer" ||
                packageName == "com.samsung.android.dialer") {
                return
            }

            var shouldBlock = false
            if (whitelistMode) {
                // Beyaz liste modu: İzin verilenler DIŞINDAKİ her şey yasak
                if (!allowedPackages.contains(packageName)) {
                    shouldBlock = true
                }
            } else {
                // Kara liste modu: Engellenenler listesindeyse yasak
                if (blockedPackages.contains(packageName)) {
                    shouldBlock = true
                }
            }

            // Ayrıca ayarlara gidip uygulamayı durdurmasını önlemek için sistem ayarları kontrolü
            if (packageName == "com.android.settings") {
                shouldBlock = true
            }

            if (shouldBlock) {
                // Kullanıcıyı hemen Focus Blocker Kilit Ekranına yönlendir
                val lockIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("TRIGGERED_BY_BLOCK", true)
                    putExtra("BLOCKED_APP", packageName)
                }
                startActivity(lockIntent)
            }
        }
    }

    override fun onInterrupt() {
        // Servis kesintiye uğradığında
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Servis bağlandığında SharedPreferences'dan durumu yükle
        val prefs = getSharedPreferences("FocusBlockerPrefs", Context.MODE_PRIVATE)
        isLocked = prefs.getBoolean("is_locked", false)
        whitelistMode = prefs.getBoolean("whitelist_mode", false)
        blockedPackages = prefs.getStringSet("blocked_packages", emptySet())?.toMutableSet() ?: mutableSetOf()
    }
}
