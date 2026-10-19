package com.example.archivador_digital

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "simplista/overlay"
    private var pendingQuickAction: String? = null
    private var pendingQuickText: String? = null
    private var pendingQuickPortada: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let {
            pendingQuickAction = it.getStringExtra("quick_action")
            pendingQuickText = it.getStringExtra("quick_text")
            pendingQuickPortada = it.getStringExtra("quick_portada")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val accion = intent.getStringExtra("quick_action")
        val texto = intent.getStringExtra("quick_text")
        val portada = intent.getStringExtra("quick_portada")

        if (accion != null) {
            pendingQuickAction = accion
            pendingQuickText = texto
            pendingQuickPortada = portada
            val map = mapOf(
                "action" to accion,
                "text" to (texto ?: ""),
                "portada" to (portada ?: "")
            )
            methodChannel?.invokeMethod("onQuickPayload", map)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(granted)
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "startOverlay" -> {
                    val lado = call.argument<String>("lado") ?: "derecha"
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
                        val srvIntent = Intent(this, XiaomiOverlayService::class.java).apply {
                            putExtra("lado", lado)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(srvIntent)
                        } else {
                            startService(srvIntent)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopOverlay" -> {
                    val srvIntent = Intent(this, XiaomiOverlayService::class.java)
                    stopService(srvIntent)
                    result.success(true)
                }
                "consumeQuickAction" -> {
                    val action = pendingQuickAction
                    val map = if (action != null) {
                        mapOf(
                            "action" to action,
                            "text" to (pendingQuickText ?: ""),
                            "portada" to (pendingQuickPortada ?: "")
                        )
                    } else {
                        null
                    }
                    pendingQuickAction = null
                    pendingQuickText = null
                    pendingQuickPortada = null
                    result.success(map)
                }
                else -> result.notImplemented()
            }
        }
    }
}
