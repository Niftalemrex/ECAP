package com.example.ecap

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import android.widget.*
import java.io.File
import java.security.MessageDigest

class AppUsageAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "eCap"
    }

    private var currentPackage: String? = null
    private var currentStartTime: Long? = null
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private val handler = Handler(Looper.getMainLooper())

    private var blockedPackage: String? = null
    private val imePackages = mutableListOf<String>()

    // System packages that should NOT dismiss the overlay
    private val systemPackages = setOf(
        "com.android.settings",
        "com.android.systemui",
        "com.android.phone",
        "com.android.incallui"
    )

    // 🚫 Protected packages (always require PIN to access)
    private val protectedPackages = setOf(
        "com.android.settings",           // Settings app
        "com.android.packageinstaller"    // Uninstall / package installer dialogs
    )

    // Database
    private var db: SQLiteDatabase? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")

        // Open the same database your Flutter app uses
        try {
            val dbPath = File(filesDir.parent, "databases/ecap.db").absolutePath
            db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
            Log.d(TAG, "Database opened successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open database: ${e.message}")
        }

        // Collect enabled keyboards
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val imeList = imm.enabledInputMethodList
        for (ime in imeList) {
            imePackages.add(ime.packageName)
        }
        Log.d(TAG, "Enabled keyboards: $imePackages")

        // Start the foreground monitor service (notification)
        val intent = Intent(this, AppMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        db?.close()
        removeOverlay()
        handler.removeCallbacksAndMessages(null)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val newPackage = event.packageName?.toString() ?: return
            Log.d(TAG, "Window changed to: $newPackage")

            // 1. Ignore changes to our own app (overlay itself)
            if (blockedPackage != null && newPackage == packageName) {
                Log.d(TAG, "Ignoring window change to own app")
                return
            }

            // 2. Ignore keyboards
            if (blockedPackage != null && imePackages.contains(newPackage)) {
                Log.d(TAG, "Ignoring window change to keyboard: $newPackage")
                return
            }

            // 3. Ignore system packages (Settings, SystemUI, etc.)
            if (blockedPackage != null && systemPackages.contains(newPackage)) {
                Log.d(TAG, "Ignoring window change to system package: $newPackage")
                return
            }

            // 4. If we're blocking and the user really switches to a different *real* app → remove overlay
            if (blockedPackage != null && newPackage != blockedPackage) {
                Log.d(TAG, "Real switch to $newPackage – removing overlay")
                removeOverlay()
                blockedPackage = null
                currentPackage = null
                currentStartTime = null
            }

            // 5. Normal tracking
            if (newPackage == currentPackage) return

            if (currentPackage != null && currentStartTime != null) {
                onAppClosed(currentPackage!!, currentStartTime!!)
            }

            onAppOpened(newPackage)
        }
    }

    override fun onInterrupt() {}

    // ───── App opened handling ─────
    private fun onAppOpened(packageName: String) {
        Log.d(TAG, "Checking limit for: $packageName")

        // Check if the package is protected (always blocked) or has a database rule
        if (isAppBlocked(packageName) || protectedPackages.contains(packageName)) {
            blockedPackage = packageName
            showPinOverlay(packageName)
        } else {
            currentPackage = packageName
            currentStartTime = System.currentTimeMillis()
        }
    }

    private fun onAppClosed(packageName: String, startTime: Long) {
        val durationSeconds = (System.currentTimeMillis() - startTime) / 1000
        Log.d(TAG, "Logging usage: $packageName for $durationSeconds sec")
        currentPackage = null
        currentStartTime = null
    }

    // ───── Native database queries ─────
    private fun isAppBlocked(packageName: String): Boolean {
        val database = db ?: return false
        try {
            // Find app_id
            val cursor = database.rawQuery(
                "SELECT id FROM apps WHERE package_name = ?",
                arrayOf(packageName)
            )
            if (!cursor.moveToFirst()) {
                cursor.close()
                return false
            }
            val appId = cursor.getInt(0)
            cursor.close()

            // Check for any 'blocked' rule for that app
            val ruleCursor = database.rawQuery(
                "SELECT id FROM app_rules WHERE app_id = ? AND mode = 'blocked'",
                arrayOf(appId.toString())
            )
            val blocked = ruleCursor.moveToFirst()
            ruleCursor.close()
            Log.d(TAG, "Block check for $packageName: $blocked")
            return blocked
        } catch (e: Exception) {
            Log.e(TAG, "Error querying DB: ${e.message}")
            return false
        }
    }

    // SHA‑256 hashing (native)
    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(input.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    // Verify PIN: hash the entered PIN and compare with stored hash
    private fun verifyParentPin(pin: String): Boolean {
        val database = db ?: return false
        try {
            val cursor = database.rawQuery(
                "SELECT pin_hash FROM users WHERE role IN ('super_admin','parent') LIMIT 1",
                null
            )
            if (!cursor.moveToFirst()) {
                cursor.close()
                return false
            }
            val storedHash = cursor.getString(0)
            cursor.close()

            val enteredHash = sha256(pin)
            Log.d(TAG, "Stored hash: $storedHash, Entered hash: $enteredHash")
            return storedHash == enteredHash
        } catch (e: Exception) {
            Log.e(TAG, "PIN verify error: ${e.message}")
            return false
        }
    }

    // ───── PIN Overlay (unchanged UI) ─────
    private fun showPinOverlay(packageName: String) {
        if (overlayView != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        // ── Root layout (semi‑transparent black) ──
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.argb(200, 0, 0, 0))
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // Top spacer
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        })

        // Lock icon
        val lockIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
        }
        root.addView(lockIcon)
        root.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 24) })

        // Title
        val title = TextView(this).apply {
            text = "App Locked"
            setTextColor(Color.WHITE)
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        root.addView(title)
        root.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 12) })

        // Subtitle
        val subtitle = TextView(this).apply {
            text = "Enter the parent PIN to unlock"
            setTextColor(Color.argb(255, 209, 209, 214))
            textSize = 15f
            gravity = Gravity.CENTER
        }
        root.addView(subtitle)
        root.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 32) })

        // PIN field
        val pinField = EditText(this).apply {
            hint = "PIN"
            setHintTextColor(Color.argb(255, 142, 142, 147))
            setTextColor(Color.BLACK)
            setBackgroundColor(Color.WHITE)
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            val fieldShape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = 16f
            }
            background = fieldShape
            layoutParams = LinearLayout.LayoutParams(500, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        root.addView(pinField)
        root.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 20) })

        // Unlock button
        val unlockButton = Button(this).apply {
            text = "Unlock"
            setTextColor(Color.WHITE)
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            val buttonShape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#007AFF"))
                cornerRadius = 24f
            }
            background = buttonShape
            setPadding(0, 16, 0, 16)
            layoutParams = LinearLayout.LayoutParams(500, LinearLayout.LayoutParams.WRAP_CONTENT)
            setOnClickListener {
                val pin = pinField.text.toString()
                if (verifyParentPin(pin)) {
                    Toast.makeText(this@AppUsageAccessibilityService, "Unlocked", Toast.LENGTH_SHORT).show()
                    blockedPackage = null
                    removeOverlay()
                    currentPackage = packageName
                    currentStartTime = System.currentTimeMillis()
                } else {
                    Toast.makeText(this@AppUsageAccessibilityService, "Wrong PIN", Toast.LENGTH_SHORT).show()
                }
            }
        }
        root.addView(unlockButton)

        // Bottom spacer
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        })

        // "Powered by NiCol" footer
        val footer = TextView(this).apply {
            text = "Powered by NiCol"
            setTextColor(Color.argb(120, 255, 255, 255))
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        root.addView(footer)

        // Block back button
        root.isFocusableInTouchMode = true
        root.requestFocus()
        root.setOnKeyListener { _, keyCode, event ->
            if (keyCode == android.view.KeyEvent.KEYCODE_BACK && event.action == android.view.KeyEvent.ACTION_UP) true
            else false
        }

        overlayView = root
        windowManager?.addView(overlayView, params)
        Log.d(TAG, "PIN overlay displayed on $packageName")
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
            Log.d(TAG, "Overlay removed")
        }
    }
}