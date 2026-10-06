package com.example.ecap

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val APPS_CHANNEL = "com.example.ecap/apps"
        private const val USAGE_CHANNEL = "com.example.ecap/usage"
        private const val ADMIN_CHANNEL = "com.example.ecap/admin"

        @JvmStatic
        var appsChannel: MethodChannel? = null
        @JvmStatic
        var usageChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Installed apps channel ──
        appsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL)
        appsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val includeSystemApps = call.argument<Boolean>("includeSystemApps") ?: false
                    result.success(getInstalledApps(includeSystemApps))
                }
                "startMonitorService" -> {
                    startMonitorService()
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                else -> result.notImplemented()
            }
        }

        // ── Usage tracking channel (no longer used for block/PIN, native DB handles it) ──
        usageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)

        // ── Device Admin & Accessibility channel ──
        val adminChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADMIN_CHANNEL)
        adminChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                        ComponentName(this, AdminReceiver::class.java))
                    intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "✨ This helps keep your child safe.\n\n" +
                                "Prevents eCap from being uninstalled without your parent PIN."
                    )
                    startActivityForResult(intent, 100)
                    result.success(true)
                }
                "isAdminEnabled" -> {
                    val dpm = getSystemService(DevicePolicyManager::class.java)
                    val admin = ComponentName(this, AdminReceiver::class.java)
                    result.success(dpm.isAdminActive(admin))
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(includeSystemApps: Boolean): List<Map<String, Any?>> {
        val pm: PackageManager = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        return apps
            .filter { includeSystemApps || (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
            .map { app ->
                mapOf(
                    "package_name" to app.packageName,
                    "app_name" to pm.getApplicationLabel(app).toString(),
                    "is_system_app" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                )
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponent = ComponentName(this, AppUsageAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(expectedComponent.flattenToString()) ?: false
    }

    private fun startMonitorService() {
        Log.d("eCap", "Starting monitor service")
        val intent = Intent(this, AppMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}