package com.example.archivador_digital

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.text.InputType
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.io.File

class XiaomiOverlayService : Service() {

    companion object {
        var rutaUltimaCaptura: String? = null
    }

    private var windowManager: WindowManager? = null
    private var edgeHandleView: View? = null
    private var quickPanelView: View? = null
    private var quickNoteModalView: View? = null
    private var ladoDerecha: Boolean = true
    private var posY: Int = 450
    private var screenshotTempPath: String? = null
    private var cropOverlayView: GeminiCropOverlayView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ladoDerecha = intent?.getStringExtra("lado") != "izquierda"
        iniciarNotificacionMinima()
        mostrarPestanaBorde()
        return START_STICKY
    }

    private fun iniciarNotificacionMinima() {
        val channelId = "simplista_xiaomi_overlay"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Barra Rápida Simplista",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene activa la barra rápida lateral con consumo mínimo"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setContentTitle("Simplista Barra Rápida")
            .setContentText("Toca la pestaña lateral para notas y capturas rápidas")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        startForeground(1042, notification)
    }

    private fun obtenerTipoVentana(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun mostrarPestanaBorde() {
        removerVistas()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val densidad = resources.displayMetrics.density
        val anchoPx = (18 * densidad).toInt()
        val altoPx = (78 * densidad).toInt()

        val contenedor = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#B01E293B"))
                val r = 12 * densidad
                cornerRadii = if (ladoDerecha) {
                    floatArrayOf(r, r, 0f, 0f, 0f, 0f, r, r)
                } else {
                    floatArrayOf(0f, 0f, r, r, r, r, 0f, 0f)
                }
                setStroke((1 * densidad).toInt(), Color.parseColor("#66FFFFFF"))
            }
        }

        val barritaInterna = View(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#DDFFFFFF"))
                cornerRadius = 4 * densidad
            }
            layoutParams = LinearLayout.LayoutParams(
                (4 * densidad).toInt(),
                (34 * densidad).toInt()
            )
        }
        contenedor.addView(barritaInterna)

        val params = WindowManager.LayoutParams(
            anchoPx,
            altoPx,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or if (ladoDerecha) Gravity.END else Gravity.START
            x = 0
            y = posY
        }

        var initialY = 0
        var initialTouchY = 0f
        var initialTouchX = 0f
        var arrastrado = false

        contenedor.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = params.y
                    initialTouchY = event.rawY
                    initialTouchX = event.rawX
                    arrastrado = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (event.rawY - initialTouchY).toInt()
                    val dx = event.rawX - initialTouchX
                    if (kotlin.math.abs(dy) > 12) {
                        arrastrado = true
                        params.y = (initialY + dy).coerceIn(120, resources.displayMetrics.heightPixels - 300)
                        posY = params.y
                        windowManager?.updateViewLayout(contenedor, params)
                    } else if ((ladoDerecha && dx < -25) || (!ladoDerecha && dx > 25)) {
                        arrastrado = true
                        activarDespliegueConCaptura()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!arrastrado) {
                        activarDespliegueConCaptura()
                    }
                    true
                }
                else -> false
            }
        }

        edgeHandleView = contenedor
        windowManager?.addView(contenedor, params)
    }

    /// Al tocar o jalar la barra: si aún no hay permiso de captura real, pide permiso con MediaProjection
    private fun activarDespliegueConCaptura() {
        if (CaptureActivity.mediaProjectionData == null) {
            val intent = Intent(this, CaptureActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
            }
            startActivity(intent)
        } else {
            // Ocultar pestaña un instante para tomar screenshot limpio de la pantalla
            edgeHandleView?.visibility = View.INVISIBLE
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                CaptureActivity.capturarPantallaReal(this) { ruta ->
                    edgeHandleView?.visibility = View.VISIBLE
                    screenshotTempPath = ruta
                    mostrarMenuDesplegado()
                }
            }, 60)
            return
        }
        mostrarMenuDesplegado()
    }

    /// Menú flotante con iconos redondos limpios sin texto
    private fun mostrarMenuDesplegado() {
        if (quickPanelView != null) return
        cerrarModalNota()
        val densidad = resources.displayMetrics.density

        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(
                (10 * densidad).toInt(),
                (10 * densidad).toInt(),
                (10 * densidad).toInt(),
                (10 * densidad).toInt()
            )
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#EE1E293B"))
                cornerRadius = 24 * densidad
                setStroke((1.5 * densidad).toInt(), Color.parseColor("#55FFFFFF"))
            }
        }

        fun agregarBotonRedondo(simbolo: String, colorHex: String, onClick: () -> Unit) {
            val btn = TextView(this).apply {
                text = simbolo
                setTextColor(Color.WHITE)
                textSize = 18f
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    setColor(Color.parseColor(colorHex))
                    shape = GradientDrawable.OVAL
                }
                val tam = (42 * densidad).toInt()
                val lp = LinearLayout.LayoutParams(tam, tam).apply {
                    bottomMargin = (8 * densidad).toInt()
                }
                layoutParams = lp
                setOnClickListener {
                    cerrarMenuDesplegado()
                    onClick()
                }
            }
            panel.addView(btn)
        }

        // 1. Apunte Rápido con Selección Rectangular tipo Gemini
        agregarBotonRedondo("📝", "#D97706") {
            iniciarModoSeleccionGemini()
        }

        // 2. Fórmula
        agregarBotonRedondo("∑", "#2563EB") {
            lanzarAccionEnApp("formula")
        }

        // 3. Imagen
        agregarBotonRedondo("📷", "#16A34A") {
            lanzarAccionEnApp("imagen")
        }

        // 4. Fecha / Hito
        agregarBotonRedondo("📅", "#0D9488") {
            lanzarAccionEnApp("fecha")
        }

        val btnCerrar = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, (4 * densidad).toInt(), 0, (2 * densidad).toInt())
            setOnClickListener { cerrarMenuDesplegado() }
        }
        panel.addView(btnCerrar)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or if (ladoDerecha) Gravity.END else Gravity.START
            x = (22 * densidad).toInt()
            y = posY
        }

        quickPanelView = panel
        windowManager?.addView(panel, params)
    }

    private fun cerrarMenuDesplegado() {
        quickPanelView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        quickPanelView = null
    }

    /// Activa el marco de pantalla con oscurecimiento y selección de área rectangular (estilo Gemini)
    private fun iniciarModoSeleccionGemini() {
        removerSelectorRecorte()
        cerrarModalNota()
        val rutaPantalla = screenshotTempPath ?: rutaUltimaCaptura

        val cropView = GeminiCropOverlayView(this, rutaPantalla) { rutaFinalRecorte ->
            removerSelectorRecorte()
            abrirModalApunteLigero(rutaFinalRecorte ?: rutaPantalla)
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        cropOverlayView = cropView
        windowManager?.addView(cropView, params)
    }

    private fun removerSelectorRecorte() {
        cropOverlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        cropOverlayView = null
    }

    /// Hoja inferior (Bottom Sheet estilo Gemini) con la miniatura recortada y texto rápido
    private fun abrirModalApunteLigero(rutaPortada: String?) {
        cerrarModalNota()
        val densidad = resources.displayMetrics.density

        val cardModal = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                (20 * densidad).toInt(),
                (14 * densidad).toInt(),
                (20 * densidad).toInt(),
                (18 * densidad).toInt()
            )
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F41E293B")) // Fondo elegante Glass Dark
                val r = 24 * densidad
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f) // Esquinas superiores redondeadas
                setStroke((1.5 * densidad).toInt(), Color.parseColor("#55FFFFFF"))
            }
        }

        // Manilla superior (Handle indicador de hoja inferior)
        val handleBar = View(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#64748B"))
                cornerRadius = 3 * densidad
            }
            val lp = LinearLayout.LayoutParams((38 * densidad).toInt(), (4 * densidad).toInt()).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = (12 * densidad).toInt()
            }
            layoutParams = lp
        }
        cardModal.addView(handleBar)

        // Fila de Entrada: [Miniatura Recortada] + [EditText] + [✕]
        val inputRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#33334155"))
                cornerRadius = 16 * densidad
                setStroke((1 * densidad).toInt(), Color.parseColor("#4464748B"))
            }
            setPadding((10 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
        }

        // Miniatura del recorte
        if (rutaPortada != null && File(rutaPortada).exists()) {
            val imgPreview = ImageView(this).apply {
                val bmp = BitmapFactory.decodeFile(rutaPortada)
                setImageBitmap(bmp)
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = GradientDrawable().apply {
                    cornerRadius = 10 * densidad
                }
                clipToOutline = true
                val anchoPx = (54 * densidad).toInt()
                val altoPx = (46 * densidad).toInt()
                val lp = LinearLayout.LayoutParams(anchoPx, altoPx).apply {
                    marginEnd = (10 * densidad).toInt()
                }
                layoutParams = lp
            }
            inputRow.addView(imgPreview)
        }

        // Campo de texto principal
        val inputTexto = EditText(this).apply {
            hint = "Escribe acerca de esta selección..."
            setHintTextColor(Color.parseColor("#94A3B8"))
            setTextColor(Color.WHITE)
            textSize = 14f
            maxLines = 4
            background = null
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        inputRow.addView(inputTexto)

        val btnCerrarModal = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 16f
            setPadding((6 * densidad).toInt(), (4 * densidad).toInt(), (4 * densidad).toInt(), (4 * densidad).toInt())
            setOnClickListener { cerrarModalNota() }
        }
        inputRow.addView(btnCerrarModal)
        cardModal.addView(inputRow)

        // Botones de acción inferiores
        val accionesRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, (14 * densidad).toInt(), 0, 0)
        }

        // Botón: "+ Contenido" (Abre Simplista conservando portada/recorte y texto)
        val btnAbrirSimplista = Button(this).apply {
            text = "+ Contenido"
            setTextColor(Color.WHITE)
            textSize = 12f
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#825385"))
                cornerRadius = 12 * densidad
            }
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = (10 * densidad).toInt()
            }
            setOnClickListener {
                val texto = inputTexto.text.toString().trim()
                cerrarModalNota()
                val intent = Intent(this@XiaomiOverlayService, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("quick_action", "nota")
                    putExtra("quick_text", texto)
                    putExtra("quick_portada", rutaPortada)
                }
                startActivity(intent)
            }
        }
        accionesRow.addView(btnAbrirSimplista)

        // Botón: "Listo (Guardar)" (Guarda en SQLite de fondo sin salir de la app de origen)
        val btnGuardarFondo = Button(this).apply {
            text = "Listo (Guardar)"
            setTextColor(Color.WHITE)
            textSize = 12f
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#16A34A"))
                cornerRadius = 12 * densidad
            }
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.2f)
            setOnClickListener {
                val texto = inputTexto.text.toString().trim()
                guardarFichaRapidaEnBaseDatos(texto, rutaPortada)
                desvanecerYCerrarModal(cardModal)
            }
        }
        accionesRow.addView(btnGuardarFondo)
        cardModal.addView(accionesRow)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM
        }

        quickNoteModalView = cardModal
        windowManager?.addView(cardModal, params)

        inputTexto.post {
            inputTexto.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(inputTexto, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun desvanecerYCerrarModal(view: View) {
        view.animate()
            .alpha(0f)
            .setDuration(240)
            .withEndAction {
                cerrarModalNota()
                Toast.makeText(this, "Apunte guardado en Simplista", Toast.LENGTH_SHORT).show()
            }
            .start()
    }

    private fun cerrarModalNota() {
        quickNoteModalView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        quickNoteModalView = null
    }

    private fun guardarFichaRapidaEnBaseDatos(texto: String, rutaPortada: String?) {
        Thread {
            try {
                val dbFile = getDatabasePath("simplista.db")
                if (dbFile.exists()) {
                    val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                        dbFile.path,
                        null,
                        android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                    )
                    val values = android.content.ContentValues().apply {
                        val titulo = if (texto.isNotEmpty()) {
                            if (texto.length > 30) texto.substring(0, 30) + "..." else texto
                        } else {
                            "Apunte rápido"
                        }
                        put("titulo", titulo)
                        put("descripcion", texto)
                        put("categoria_id", 1) // Categoría General
                        put("ruta_imagen", rutaPortada)
                        val now = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                            .format(java.util.Date())
                        put("fecha_creacion", now)
                        put("fecha_modificacion", now)
                    }
                    db.insert("fichas", null, values)
                    db.close()
                }
            } catch (_: Exception) {}
        }.start()
    }

    private fun lanzarAccionEnApp(accion: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("quick_action", accion)
        }
        startActivity(intent)
    }

    private fun removerVistas() {
        cerrarMenuDesplegado()
        cerrarModalNota()
        edgeHandleView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        edgeHandleView = null
    }

    override fun onDestroy() {
        removerVistas()
        super.onDestroy()
    }
}
