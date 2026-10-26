package com.example.archivador_digital

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "simplista/overlay"
    private val REQ_CREATE_DOCUMENT = 9901
    private val REQ_OPEN_DOCUMENT = 9902

    private var pendingQuickAction: String? = null
    private var pendingQuickTitle: String? = null
    private var pendingQuickText: String? = null
    private var pendingQuickPortada: String? = null
    private var pendingQuickFichaId: Long? = null
    private var pendingQuickCategoriaId: Long? = null
    private var methodChannel: MethodChannel? = null

    private var pendingSaveContent: String? = null
    private var pendingSafResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let {
            pendingQuickAction = it.getStringExtra("quick_action")
            pendingQuickTitle = it.getStringExtra("quick_title")
            pendingQuickText = it.getStringExtra("quick_text")
            pendingQuickPortada = it.getStringExtra("quick_portada")
            if (it.hasExtra("quick_ficha_id")) pendingQuickFichaId = it.getLongExtra("quick_ficha_id", -1L)
            if (it.hasExtra("quick_categoria_id")) pendingQuickCategoriaId = it.getLongExtra("quick_categoria_id", -1L)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val accion = intent.getStringExtra("quick_action")
        val titulo = intent.getStringExtra("quick_title")
        val texto = intent.getStringExtra("quick_text")
        val portada = intent.getStringExtra("quick_portada")
        val fichaId = if (intent.hasExtra("quick_ficha_id")) intent.getLongExtra("quick_ficha_id", -1L) else null
        val categoriaId = if (intent.hasExtra("quick_categoria_id")) intent.getLongExtra("quick_categoria_id", -1L) else null

        if (accion != null) {
            pendingQuickAction = accion
            pendingQuickTitle = titulo
            pendingQuickText = texto
            pendingQuickPortada = portada
            pendingQuickFichaId = fichaId
            pendingQuickCategoriaId = categoriaId
            val map = mapOf(
                "action" to accion,
                "title" to (titulo ?: ""),
                "text" to (texto ?: ""),
                "portada" to (portada ?: ""),
                "fichaId" to (fichaId ?: -1L),
                "categoriaId" to (categoriaId ?: -1L)
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
                            "title" to (pendingQuickTitle ?: ""),
                            "text" to (pendingQuickText ?: ""),
                            "portada" to (pendingQuickPortada ?: ""),
                            "fichaId" to (pendingQuickFichaId ?: -1L),
                            "categoriaId" to (pendingQuickCategoriaId ?: -1L)
                        )
                    } else {
                        null
                    }
                    pendingQuickAction = null
                    pendingQuickTitle = null
                    pendingQuickText = null
                    pendingQuickPortada = null
                    pendingQuickFichaId = null
                    pendingQuickCategoriaId = null
                    result.success(map)
                }
                "saveBackupToDriveDialog" -> {
                    val fileName = call.argument<String>("fileName") ?: "simplista_backup.json"
                    val content = call.argument<String>("content") ?: ""
                    pendingSaveContent = content
                    pendingSafResult = result

                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, REQ_CREATE_DOCUMENT)
                }
                "openBackupFromDriveDialog" -> {
                    pendingSafResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, REQ_OPEN_DOCUMENT)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQ_CREATE_DOCUMENT) {
            val res = pendingSafResult
            val content = pendingSaveContent
            pendingSafResult = null
            pendingSaveContent = null

            if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
                val uri = data.data!!
                Thread {
                    try {
                        contentResolver.openOutputStream(uri)?.use { out ->
                            out.write(content.toByteArray(Charsets.UTF_8))
                            out.flush()
                        }
                        runOnUiThread {
                            res?.success(uri.toString())
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            res?.error("WRITE_ERR", e.message, null)
                        }
                    }
                }.start()
            } else {
                res?.success(null)
            }
        } else if (requestCode == REQ_OPEN_DOCUMENT) {
            val res = pendingSafResult
            pendingSafResult = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                Thread {
                    try {
                        val sb = StringBuilder()
                        contentResolver.openInputStream(uri)?.use { input ->
                            BufferedReader(InputStreamReader(input, Charsets.UTF_8)).use { reader ->
                                var line: String?
                                while (reader.readLine().also { line = it } != null) {
                                    sb.append(line)
                                }
                            }
                        }
                        runOnUiThread {
                            res?.success(sb.toString())
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            res?.error("READ_ERR", e.message, null)
                        }
                    }
                }.start()
            } else {
                res?.success(null)
            }
        }
    }
}
