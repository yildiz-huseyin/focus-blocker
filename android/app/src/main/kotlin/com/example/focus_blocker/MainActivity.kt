package com.example.focus_blocker

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.focus_blocker/native_blocker"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("FocusBlockerPrefs", Context.MODE_PRIVATE)

            when (call.method) {
                "setLockStatus" -> {
                    val locked = call.argument<Boolean>("isLocked") ?: false
                    val whitelist = call.argument<Boolean>("whitelistMode") ?: false
                    val blockedList = call.argument<List<String>>("blockedPackages") ?: emptyList()

                    BlockerAccessibilityService.isLocked = locked
                    BlockerAccessibilityService.whitelistMode = whitelist
                    BlockerAccessibilityService.blockedPackages = blockedList.toMutableSet()

                    prefs.edit()
                        .putBoolean("is_locked", locked)
                        .putBoolean("whitelist_mode", whitelist)
                        .putStringSet("blocked_packages", blockedList.toSet())
                        .apply()

                    result.success(true)
                }

                "checkPermissions" -> {
                    val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else true

                    val hasAccessibility = isAccessibilityServiceEnabled()

                    val status = mapOf(
                        "overlay" to hasOverlay,
                        "accessibility" to hasAccessibility
                    )
                    result.success(status)
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }

                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }

                "getInstalledApps" -> {
                    val pm = packageManager
                    val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                    val appsList = mutableListOf<Map<String, String>>()

                    for (app in packages) {
                        // Sistem uygulamalarını (varsayılan kritik olanlar hariç) veya üçüncü parti uygulamaları al
                        val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                        val appName = pm.getApplicationLabel(app).toString()
                        val pkgName = app.packageName

                        if (!isSystem || pkgName == "com.google.android.youtube" || pkgName == "com.android.chrome") {
                            appsList.add(
                                mapOf(
                                    "appName" to appName,
                                    "packageName" to pkgName
                                )
                            )
                        }
                    }
                    result.success(appsList)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedServiceName = "$packageName/${BlockerAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.contains(expectedServiceName) || enabledServices.contains(BlockerAccessibilityService::class.java.simpleName)
    }
}
