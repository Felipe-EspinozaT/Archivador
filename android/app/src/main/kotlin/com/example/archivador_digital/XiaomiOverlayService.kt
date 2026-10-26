package com.example.archivador_digital

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
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
import java.io.FileInputStream
import java.io.FileOutputStream

class XiaomiOverlayService : Service() {

    companion object {
        var rutaUltimaCaptura: String? = null
    }

    private var windowManager: WindowManager? = null
    private var edgeHandleView: View? = null
    private var optionPopupView: View? = null
    private var quickContentBarView: View? = null
    private var quickNoteModalView: View? = null
    private var cropOverlayView: GeminiCropOverlayView? = null
    private var ladoDerecha: Boolean = true
    private var posY: Int = 450
    private var screenshotTempPath: String? = null
    private var idFichaDestinoParaContenido: Long? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "ACTION_CAPTURE_GRANTED") {
            iniciarNotificacionMinima(conMediaProjection = true)
            if (edgeHandleView == null) {
                mostrarBotonLateralS()
            }
            edgeHandleView?.visibility = View.INVISIBLE
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                CaptureActivity.capturarPantallaReal(this) { ruta ->
                    edgeHandleView?.visibility = View.VISIBLE
                    if (ruta != null) {
                        screenshotTempPath = ruta
                        rutaUltimaCaptura = ruta
                        iniciarModoSeleccionGemini()
                    } else {
                        Toast.makeText(this, "No se pudo capturar la pantalla. Toca la 'S' nuevamente.", Toast.LENGTH_SHORT).show()
                    }
                }
            }, 150)
            return START_STICKY
        }

        if (intent?.hasExtra("lado") == true) {
            ladoDerecha = intent.getStringExtra("lado") != "izquierda"
        }
        iniciarNotificacionMinima(conMediaProjection = CaptureActivity.mediaProjectionData != null)
        mostrarBotonLateralS()
        return START_STICKY
    }

    private fun iniciarNotificacionMinima(conMediaProjection: Boolean = false) {
        val channelId = "simplista_xiaomi_overlay"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Botón Rápido Simplista",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene activo el botón lateral de captura rápida Simplista"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setContentTitle("Simplista Botón Rápido")
            .setContentText("Toca la 'S' lateral para recortar pantalla y crear ficha")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val tipoFgs = if (conMediaProjection) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            } else if (Build.VERSION.SDK_INT >= 34) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
            if (tipoFgs != 0) {
                startForeground(1042, notification, tipoFgs)
            } else {
                startForeground(1042, notification)
            }
        } else {
            startForeground(1042, notification)
        }
    }

    private fun obtenerTipoVentana(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    /// Pestaña lateral angosta en forma de "S" estilizada
    private fun mostrarBotonLateralS() {
        removerVistas()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val densidad = resources.displayMetrics.density
        val anchoPx = (22 * densidad).toInt()
        val altoPx = (56 * densidad).toInt()

        val contenedor = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#CC825385")) // Tono púrpura Simplista translúcido
                val r = 14 * densidad
                cornerRadii = if (ladoDerecha) {
                    floatArrayOf(r, r, 0f, 0f, 0f, 0f, r, r)
                } else {
                    floatArrayOf(0f, 0f, r, r, r, r, 0f, 0f)
                }
                setStroke((1.2 * densidad).toInt(), Color.parseColor("#88FFFFFF"))
            }
        }

        // Letra "S" angosta y elegante
        val letraS = TextView(this).apply {
            text = "S"
            setTextColor(Color.WHITE)
            textSize = 17f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        contenedor.addView(letraS)

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
        var arrastrado = false

        contenedor.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = params.y
                    initialTouchY = event.rawY
                    arrastrado = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (kotlin.math.abs(dy) > 10) {
                        arrastrado = true
                        params.y = (initialY + dy).coerceIn(120, resources.displayMetrics.heightPixels - 240)
                        posY = params.y
                        windowManager?.updateViewLayout(contenedor, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!arrastrado) {
                        alternarPopupOpcionesS(params.y)
                    }
                    true
                }
                else -> false
            }
        }

        edgeHandleView = contenedor
        windowManager?.addView(contenedor, params)
    }

    /// Al presionar la opción de captura, va directo al recorte reutilizando la sesión de captura activa
    private fun activarCapturaDirecta() {
        if (CaptureActivity.mediaProjectionData == null) {
            val intent = Intent(this, CaptureActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
            }
            startActivity(intent)
        } else {
            edgeHandleView?.visibility = View.INVISIBLE
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                CaptureActivity.capturarPantallaReal(this) { ruta ->
                    edgeHandleView?.visibility = View.VISIBLE
                    if (ruta != null) {
                        screenshotTempPath = ruta
                        rutaUltimaCaptura = ruta
                        iniciarModoSeleccionGemini()
                    } else {
                        val intent = Intent(this, CaptureActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
                        }
                        startActivity(intent)
                    }
                }
            }, 80)
        }
    }

    /// Activa el marco de pantalla completa 1:1 (sin achicar ni restar barras del sistema)
    private fun iniciarModoSeleccionGemini() {
        removerSelectorRecorte()
        cerrarModalNota()
        val rutaPantalla = screenshotTempPath ?: rutaUltimaCaptura

        val cropView = GeminiCropOverlayView(
            this,
            rutaPantalla,
            onCancelar = {
                removerSelectorRecorte()
            },
            onOmitir = {
                removerSelectorRecorte()
                if (idFichaDestinoParaContenido != null) {
                    idFichaDestinoParaContenido = null
                } else {
                    abrirModalApunteLigero(null) // Crea ficha sin portada
                }
            },
            onAreaSelected = { rutaFinalRecorte ->
                removerSelectorRecorte()
                val targetFichaId = idFichaDestinoParaContenido
                idFichaDestinoParaContenido = null

                if (targetFichaId != null) {
                    val rutaGuardada = copiarImagenAPermanente(rutaFinalRecorte ?: rutaPantalla)
                    val intent = Intent(this@XiaomiOverlayService, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("quick_action", "imagen")
                        putExtra("quick_ficha_id", targetFichaId)
                        putExtra("quick_portada", rutaGuardada)
                    }
                    startActivity(intent)
                } else {
                    abrirModalApunteLigero(rutaFinalRecorte ?: rutaPantalla)
                }
            }
        )

        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager?.defaultDisplay?.getRealMetrics(metrics)
        val realW = if (metrics.widthPixels > 0) metrics.widthPixels else WindowManager.LayoutParams.MATCH_PARENT
        val realH = if (metrics.heightPixels > 0) metrics.heightPixels else WindowManager.LayoutParams.MATCH_PARENT

        val params = WindowManager.LayoutParams(
            realW,
            realH,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

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

    /// Hoja inferior (Bottom Sheet estilo Gemini):
    /// Título (OBLIGATORIO) + Texto general (OPCIONAL) + Miniatura + [Guardar] / [+ Contenido]
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
                setColor(Color.parseColor("#F41E293B")) // Estilo Glass Dark
                val r = 24 * densidad
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
                setStroke((1.5 * densidad).toInt(), Color.parseColor("#55FFFFFF"))
            }
        }

        // Manilla superior
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

        // Cabecera con título y botón cerrar
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (10 * densidad).toInt()
            }
            layoutParams = lp
        }

        val tituloHeader = TextView(this).apply {
            text = if (rutaPortada != null) "Nueva Ficha con Portada" else "Nueva Ficha Rápida"
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        header.addView(tituloHeader)

        val btnCerrarModal = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 16f
            setPadding((6 * densidad).toInt(), (2 * densidad).toInt(), (6 * densidad).toInt(), (2 * densidad).toInt())
            setOnClickListener { cerrarModalNota() }
        }
        header.addView(btnCerrarModal)
        cardModal.addView(header)

        // Contenedor de formulario: [Miniatura de Portada] + [Inputs]
        val formRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
        }

        if (rutaPortada != null && File(rutaPortada).exists()) {
            val imgPreview = ImageView(this).apply {
                val bmp = BitmapFactory.decodeFile(rutaPortada)
                setImageBitmap(bmp)
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = GradientDrawable().apply {
                    cornerRadius = 10 * densidad
                    setStroke((1 * densidad).toInt(), Color.parseColor("#4464748B"))
                }
                clipToOutline = true
                val anchoPx = (64 * densidad).toInt()
                val altoPx = (72 * densidad).toInt()
                val lp = LinearLayout.LayoutParams(anchoPx, altoPx).apply {
                    marginEnd = (12 * densidad).toInt()
                }
                layoutParams = lp
            }
            formRow.addView(imgPreview)
        }

        val camposCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        // 1. Campo de TÍTULO (OBLIGATORIO)
        val inputTitulo = EditText(this).apply {
            hint = "Título de la ficha (obligatorio)..."
            setHintTextColor(Color.parseColor("#94A3B8"))
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            maxLines = 1
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#33334155"))
                cornerRadius = 10 * densidad
                setStroke((1 * densidad).toInt(), Color.parseColor("#4464748B"))
            }
            setPadding((12 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
        }
        camposCol.addView(inputTitulo)

        // 2. Campo de TEXTO GENERAL (OPCIONAL)
        val inputTexto = EditText(this).apply {
            hint = "Texto o descripción general (opcional)..."
            setHintTextColor(Color.parseColor("#64748B"))
            setTextColor(Color.WHITE)
            textSize = 13f
            minLines = 2
            maxLines = 4
            gravity = Gravity.TOP or Gravity.START
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#22334155"))
                cornerRadius = 10 * densidad
            }
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = (6 * densidad).toInt()
            }
            layoutParams = lp
            setPadding((12 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
        }
        camposCol.addView(inputTexto)
        formRow.addView(camposCol)
        cardModal.addView(formRow)

        // 3. Fila de selección de CATEGORÍA
        var categoriaIdSeleccionada = 1L
        val catRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = (8 * densidad).toInt()
            }
            layoutParams = lp
        }

        val lblCat = TextView(this).apply {
            text = "Categoría:"
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 12f
            setPadding(0, 0, (8 * densidad).toInt(), 0)
        }
        catRow.addView(lblCat)

        val spinnerCat = android.widget.Spinner(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#22334155"))
                cornerRadius = 8 * densidad
                setStroke((1 * densidad).toInt(), Color.parseColor("#4464748B"))
            }
            layoutParams = LinearLayout.LayoutParams(0, (36 * densidad).toInt(), 1f)
        }

        // Cargar categorías disponibles desde la base de datos
        val listaCategorias = mutableListOf<Pair<Long, String>>()
        try {
            val dbFile = getDatabasePath("archivador_digital.db")
            if (dbFile.exists()) {
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbFile.path,
                    null,
                    android.database.sqlite.SQLiteDatabase.OPEN_READONLY
                )
                val cursor = db.rawQuery("SELECT id, nombre FROM categorias ORDER BY orden ASC, id ASC", null)
                while (cursor.moveToNext()) {
                    listaCategorias.add(Pair(cursor.getLong(0), cursor.getString(1)))
                }
                cursor.close()
                db.close()
            }
        } catch (_: Exception) {}

        if (listaCategorias.isEmpty()) {
            listaCategorias.add(Pair(1L, "General"))
        }

        val adapter = android.widget.ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            listaCategorias.map { it.second }
        )
        spinnerCat.adapter = adapter
        spinnerCat.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                categoriaIdSeleccionada = listaCategorias[position].first
            }
            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        }
        catRow.addView(spinnerCat)
        cardModal.addView(catRow)

        // Botones de acción inferiores
        val accionesRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, (14 * densidad).toInt(), 0, 0)
        }

        // Botón: "+ Contenido" (Abre Simplista conservando portada/recorte y textos)
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
                val titulo = inputTitulo.text.toString().trim()
                val texto = inputTexto.text.toString().trim()
                val rutaGuardada = copiarImagenAPermanente(rutaPortada)
                cerrarModalNota()
                val intent = Intent(this@XiaomiOverlayService, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("quick_action", "nota")
                    putExtra("quick_title", if (titulo.isNotEmpty()) titulo else "Apunte rápido")
                    putExtra("quick_text", texto)
                    putExtra("quick_portada", rutaGuardada)
                    putExtra("quick_categoria_id", categoriaIdSeleccionada)
                }
                startActivity(intent)
            }
        }
        accionesRow.addView(btnAbrirSimplista)

        // Botón: "Guardar" (Obligatorio que haya título)
        val btnGuardarFondo = Button(this).apply {
            text = "Guardar"
            setTextColor(Color.WHITE)
            textSize = 12f
            alpha = 0.5f // Inicia atenuado hasta que se ingrese título
            isEnabled = false
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#16A34A"))
                cornerRadius = 12 * densidad
            }
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.2f)
            setOnClickListener {
                val titulo = inputTitulo.text.toString().trim()
                if (titulo.isEmpty()) {
                    Toast.makeText(this@XiaomiOverlayService, "El título es obligatorio", Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }
                val texto = inputTexto.text.toString().trim()
                val rutaGuardada = copiarImagenAPermanente(rutaPortada)
                guardarFichaRapidaEnBaseDatos(titulo, texto, rutaGuardada, categoriaIdSeleccionada)
                desvanecerYCerrarModal(cardModal)
            }
        }
        accionesRow.addView(btnGuardarFondo)
        cardModal.addView(accionesRow)

        // Validación en tiempo real del título obligatorio
        inputTitulo.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val valido = !s.isNullOrBlank()
                btnGuardarFondo.isEnabled = valido
                btnGuardarFondo.alpha = if (valido) 1f else 0.5f
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM
            y = obtenerAlturaBarraNavegacion()
        }

        quickNoteModalView = cardModal
        windowManager?.addView(cardModal, params)

        inputTitulo.post {
            inputTitulo.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(inputTitulo, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    /// Muestra un menú de 2 opciones circulares al tocar la 'S':
    /// 1. [+] Nueva Ficha Rápida
    /// 2. [⤵] Agregar a la última ficha (Barra horizontal)
    private fun alternarPopupOpcionesS(handleY: Int) {
        if (optionPopupView != null) {
            cerrarPopupOpcionesS()
            return
        }

        val densidad = resources.displayMetrics.density
        val popup = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding((6 * densidad).toInt(), (6 * densidad).toInt(), (6 * densidad).toInt(), (6 * densidad).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#EE1E293B"))
                cornerRadius = 24 * densidad
                setStroke((1.5 * densidad).toInt(), Color.parseColor("#44FFFFFF"))
            }
        }

        // 1. Botón '+': Nueva ficha con captura
        val btnNuevo = TextView(this).apply {
            text = "+"
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            val dPx = (42 * densidad).toInt()
            layoutParams = LinearLayout.LayoutParams(dPx, dPx).apply {
                bottomMargin = (8 * densidad).toInt()
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#825385"))
            }
            setOnClickListener {
                cerrarPopupOpcionesS()
                activarCapturaDirecta()
            }
        }
        popup.addView(btnNuevo)

        // 2. Botón '⤵': Cargar y agregar contenido a la última ficha
        val btnUltimaFicha = TextView(this).apply {
            text = "⤵"
            setTextColor(Color.WHITE)
            textSize = 20f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            val dPx = (42 * densidad).toInt()
            layoutParams = LinearLayout.LayoutParams(dPx, dPx)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0284C7")) // Azul cielo vibrante
            }
            setOnClickListener {
                cerrarPopupOpcionesS()
                mostrarBarraHorizontalUltimaFicha()
            }
        }
        popup.addView(btnUltimaFicha)

        val anchoPx = (54 * densidad).toInt()
        val altoPx = (110 * densidad).toInt()
        val params = WindowManager.LayoutParams(
            anchoPx,
            altoPx,
            obtenerTipoVentana(),
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or if (ladoDerecha) Gravity.END else Gravity.START
            x = (28 * densidad).toInt()
            y = (handleY - 25 * densidad).toInt().coerceAtLeast(100)
        }

        optionPopupView = popup
        windowManager?.addView(popup, params)
    }

    private fun cerrarPopupOpcionesS() {
        optionPopupView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        optionPopupView = null
    }

    /// Muestra una barra horizontal flotante referenciada a la última ficha
    /// con los 4 botones: [Nota] [Imagen/Recorte] [Fórmula] [Fecha]
    private fun mostrarBarraHorizontalUltimaFicha() {
        cerrarBarraHorizontalUltima()
        val densidad = resources.displayMetrics.density

        Thread {
            var ultimaFichaTitulo = "Última Ficha"
            var ultimaFichaId = -1L

            try {
                val dbFile = getDatabasePath("archivador_digital.db")
                if (dbFile.exists()) {
                    val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                        dbFile.path,
                        null,
                        android.database.sqlite.SQLiteDatabase.OPEN_READONLY
                    )
                    val cursor = db.rawQuery("SELECT id, titulo FROM fichas ORDER BY id DESC LIMIT 1", null)
                    if (cursor.moveToFirst()) {
                        ultimaFichaId = cursor.getLong(0)
                        ultimaFichaTitulo = cursor.getString(1)
                    }
                    cursor.close()
                    db.close()
                }
            } catch (_: Exception) {}

            android.os.Handler(android.os.Looper.getMainLooper()).post {
                val barContainer = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding((16 * densidad).toInt(), (12 * densidad).toInt(), (16 * densidad).toInt(), (14 * densidad).toInt())
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#F21E293B"))
                        cornerRadius = 20 * densidad
                        setStroke((1.5 * densidad).toInt(), Color.parseColor("#44FFFFFF"))
                    }
                }

                // Cabecera de la barra: Título de la última ficha referenciada + botón cerrar
                val headerRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                }

                val lblTitulo = TextView(this).apply {
                    text = "Agregar a: $ultimaFichaTitulo"
                    setTextColor(Color.WHITE)
                    textSize = 13f
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    maxLines = 1
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }
                headerRow.addView(lblTitulo)

                val btnCerrarBar = TextView(this).apply {
                    text = "✕"
                    setTextColor(Color.parseColor("#94A3B8"))
                    textSize = 15f
                    setPadding((8 * densidad).toInt(), (2 * densidad).toInt(), (8 * densidad).toInt(), (2 * densidad).toInt())
                    setOnClickListener { cerrarBarraHorizontalUltima() }
                }
                headerRow.addView(btnCerrarBar)
                barContainer.addView(headerRow)

                // Fila horizontal con los 4 componentes: Nota, Imagen/Recorte, Fórmula, Fecha
                val horizontalButtons = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                    val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                        topMargin = (10 * densidad).toInt()
                    }
                    layoutParams = lp
                }

                horizontalButtons.addView(crearBotonComponente("Nota", "#FBBF24") {
                    cerrarBarraHorizontalUltima()
                    abrirEditorParaAgregarComponente(ultimaFichaId, "nota")
                })
                horizontalButtons.addView(crearBotonComponente("Recorte", "#4ADE80") {
                    cerrarBarraHorizontalUltima()
                    idFichaDestinoParaContenido = ultimaFichaId
                    activarCapturaDirecta()
                })
                horizontalButtons.addView(crearBotonComponente("Fórmula", "#38BDF8") {
                    cerrarBarraHorizontalUltima()
                    abrirEditorParaAgregarComponente(ultimaFichaId, "formula")
                })
                horizontalButtons.addView(crearBotonComponente("Fecha", "#2DD4BF") {
                    cerrarBarraHorizontalUltima()
                    abrirEditorParaAgregarComponente(ultimaFichaId, "fecha")
                })

                barContainer.addView(horizontalButtons)

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    obtenerTipoVentana(),
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.BOTTOM
                    y = obtenerAlturaBarraNavegacion() + (12 * densidad).toInt()
                }

                quickContentBarView = barContainer
                windowManager?.addView(barContainer, params)
            }
        }.start()
    }

    private fun crearBotonComponente(etiqueta: String, colorHex: String, onClick: () -> Unit): View {
        val densidad = resources.displayMetrics.density
        return TextView(this).apply {
            text = etiqueta
            setTextColor(Color.WHITE)
            textSize = 12f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding((12 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor(colorHex))
                cornerRadius = 14 * densidad
            }
            val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = (6 * densidad).toInt()
            }
            layoutParams = lp
            setOnClickListener { onClick() }
        }
    }

    private fun cerrarBarraHorizontalUltima() {
        quickContentBarView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        quickContentBarView = null
    }

    private fun abrirEditorParaAgregarComponente(fichaId: Long, tipo: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("quick_action", tipo)
            putExtra("quick_ficha_id", fichaId)
        }
        startActivity(intent)
    }

    private fun obtenerAlturaBarraNavegacion(): Int {
        val res = resources
        val resourceId = res.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resourceId > 0) res.getDimensionPixelSize(resourceId) else (16 * resources.displayMetrics.density).toInt()
    }

    /// Guarda la imagen en el almacenamiento permanente de la aplicación para que no se pierda
    private fun copiarImagenAPermanente(origenPath: String?): String? {
        if (origenPath == null) return null
        val origenFile = File(origenPath)
        if (!origenFile.exists()) return null

        return try {
            val appFlutterDir = File(filesDir.parentFile, "app_flutter")
            if (!appFlutterDir.exists()) appFlutterDir.mkdirs()

            val destinoFile = File(appFlutterDir, "portada_${System.currentTimeMillis()}.png")
            FileInputStream(origenFile).use { input ->
                FileOutputStream(destinoFile).use { output ->
                    input.copyTo(output)
                }
            }
            destinoFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            origenPath
        }
    }

    private fun desvanecerYCerrarModal(view: View) {
        view.animate()
            .alpha(0f)
            .setDuration(240)
            .withEndAction {
                cerrarModalNota()
                Toast.makeText(this, "Ficha guardada en Simplista", Toast.LENGTH_SHORT).show()
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

    private fun guardarFichaRapidaEnBaseDatos(
        titulo: String,
        descripcion: String,
        rutaPortada: String?,
        categoriaId: Long? = null
    ) {
        Thread {
            try {
                val dbFile = getDatabasePath("archivador_digital.db")
                if (!dbFile.exists()) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        Toast.makeText(this, "Abre Simplista una vez para crear la base de datos", Toast.LENGTH_LONG).show()
                    }
                } else {
                    val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                        dbFile.path,
                        null,
                        android.database.sqlite.SQLiteDatabase.OPEN_READWRITE
                    )

                    var catId = categoriaId ?: 1L
                    if (categoriaId == null) {
                        try {
                            val cursor = db.rawQuery("SELECT id FROM categorias ORDER BY orden ASC, id ASC LIMIT 1", null)
                            if (cursor.moveToFirst()) {
                                catId = cursor.getLong(0)
                            }
                            cursor.close()
                        } catch (_: Exception) {}
                    }

                    val now = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                        .format(java.util.Date())

                    val values = android.content.ContentValues().apply {
                        put("titulo", titulo)
                        put("descripcion", descripcion)
                        put("categoria_id", catId)
                        put("ruta_imagen", rutaPortada)
                        put("fecha_creacion", now)
                        put("fecha_modificacion", now)
                    }
                    db.insert("fichas", null, values)
                    db.close()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun removerVistas() {
        removerSelectorRecorte()
        cerrarModalNota()
        cerrarPopupOpcionesS()
        cerrarBarraHorizontalUltima()
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
