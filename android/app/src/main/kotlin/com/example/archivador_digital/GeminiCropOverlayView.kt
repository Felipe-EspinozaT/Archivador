package com.example.archivador_digital

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min

class GeminiCropOverlayView(
    context: Context,
    private val fullScreenshotPath: String?,
    private val onCancelar: () -> Unit,
    private val onOmitir: () -> Unit,
    private val onAreaSelected: (String?) -> Unit
) : FrameLayout(context) {

    private var fullBitmap: Bitmap? = null
    private val paintDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#99000000")
    }
    private val paintClear = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
    }
    private val paintBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 3f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }
    private val paintGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#9038BDF8")
        style = Paint.Style.STROKE
        strokeWidth = 6f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }
    private val paintBitmap = Paint(Paint.FILTER_BITMAP_FLAG)

    private var startPoint = PointF()
    private var selectionRect: RectF? = null

    private val drawingView: View

    init {
        if (fullScreenshotPath != null && File(fullScreenshotPath).exists()) {
            try {
                fullBitmap = BitmapFactory.decodeFile(fullScreenshotPath)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        drawingView = object : View(context) {
            init {
                setLayerType(LAYER_TYPE_SOFTWARE, null)
            }

            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                // Inicializar un rectángulo editable en el centro si aún no hay uno
                if (selectionRect == null && w > 0 && h > 0) {
                    val margenX = w * 0.14f
                    val margenY = h * 0.24f
                    selectionRect = RectF(margenX, margenY, w - margenX, h - margenY)
                }
            }

            override fun onDraw(canvas: Canvas) {
                super.onDraw(canvas)
                // 1. Pintar la captura congelada de fondo en escala 1:1 exacta (sin achicar por barras del sistema)
                val bmp = fullBitmap
                if (bmp != null) {
                    val loc = IntArray(2)
                    getLocationOnScreen(loc)
                    val dest = Rect(-loc[0], -loc[1], -loc[0] + bmp.width, -loc[1] + bmp.height)
                    canvas.drawBitmap(bmp, null, dest, paintBitmap)
                }

                // 2. Capa de oscurecimiento en un saveLayer para que PorterDuff.CLEAR solo borre el velo oscuro y no el bitmap de fondo
                val saveCount = canvas.saveLayer(0f, 0f, width.toFloat(), height.toFloat(), null)
                canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paintDim)

                val rect = selectionRect
                val density = resources.displayMetrics.density
                val cornerRadius = 16f * density
                val cornerLen = 26f * density

                if (rect != null && rect.width() > 10 && rect.height() > 10) {
                    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paintClear)
                }
                canvas.restoreToCount(saveCount)

                if (rect != null && rect.width() > 10 && rect.height() > 10) {
                    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paintGlow)
                    dibujarEsquinasVisor(canvas, rect, cornerLen, cornerRadius)
                }
            }
        }
        addView(drawingView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        val densidad = resources.displayMetrics.density
        val topBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * densidad).toInt(), (40 * densidad).toInt(), (16 * densidad).toInt(), (12 * densidad).toInt())
        }

        val btnCancelar = TextView(context).apply {
            text = "✕ Cancelar"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding((12 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC1E293B"))
                cornerRadius = 16 * densidad
                setStroke((1 * densidad).toInt(), Color.parseColor("#66FFFFFF"))
            }
            setOnClickListener { onCancelar() }
        }
        topBar.addView(btnCancelar)

        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }
        topBar.addView(spacer)

        val btnOmitir = TextView(context).apply {
            text = "Omitir imagen"
            setTextColor(Color.parseColor("#E2E8F0"))
            textSize = 13f
            setPadding((12 * densidad).toInt(), (8 * densidad).toInt(), (12 * densidad).toInt(), (8 * densidad).toInt())
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC334155"))
                cornerRadius = 16 * densidad
            }
            setOnClickListener { onOmitir() }
        }
        val lpOmitir = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            marginEnd = (8 * densidad).toInt()
        }
        topBar.addView(btnOmitir, lpOmitir)

        val btnAplicar = TextView(context).apply {
            text = "✓ Recortar"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding((14 * densidad).toInt(), (8 * densidad).toInt(), (14 * densidad).toInt(), (8 * densidad).toInt())
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#825385"))
                cornerRadius = 16 * densidad
            }
            setOnClickListener {
                val rect = selectionRect
                if (rect != null && rect.width() > 20 && rect.height() > 20) {
                    val cropped = recortarBitmap(rect)
                    onAreaSelected(cropped ?: fullScreenshotPath)
                } else {
                    onAreaSelected(fullScreenshotPath)
                }
            }
        }
        topBar.addView(btnAplicar)

        addView(topBar, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    }

    private var modoArrastre = 0
    private var bordesActivos = 0
    private var ultimoX = 0f
    private var ultimoY = 0f
    private val minLado get() = 60f * resources.displayMetrics.density

    private fun detectarBordes(r: RectF, x: Float, y: Float): Int {
        val t = 30f * resources.displayMetrics.density
        var b = 0
        val dentroY = y > r.top - t && y < r.bottom + t
        val dentroX = x > r.left - t && x < r.right + t
        if (dentroY && kotlin.math.abs(x - r.left) < t) b = b or 1
        if (dentroX && kotlin.math.abs(y - r.top) < t) b = b or 2
        if (dentroY && kotlin.math.abs(x - r.right) < t) b = b or 4
        if (dentroX && kotlin.math.abs(y - r.bottom) < t) b = b or 8
        return b
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val rect = selectionRect
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                ultimoX = event.x
                ultimoY = event.y
                if (rect != null) {
                    val bordes = detectarBordes(rect, event.x, event.y)
                    if (bordes != 0) {
                        modoArrastre = 2
                        bordesActivos = bordes
                        return true
                    }
                    if (rect.contains(event.x, event.y)) {
                        modoArrastre = 1
                        return true
                    }
                }
                modoArrastre = 0
                startPoint.set(event.x, event.y)
                selectionRect = null
                drawingView.invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - ultimoX
                val dy = event.y - ultimoY
                when (modoArrastre) {
                    0 -> {
                        selectionRect = RectF(
                            min(startPoint.x, event.x), min(startPoint.y, event.y),
                            max(startPoint.x, event.x), max(startPoint.y, event.y)
                        )
                    }
                    1 -> rect?.let {
                        val nx = (it.left + dx).coerceIn(0f, width - it.width())
                        val ny = (it.top + dy).coerceIn(0f, height - it.height())
                        it.offsetTo(nx, ny)
                    }
                    2 -> rect?.let {
                        if (bordesActivos and 1 != 0) it.left = min(max(0f, it.left + dx), it.right - minLado)
                        if (bordesActivos and 2 != 0) it.top = min(max(0f, it.top + dy), it.bottom - minLado)
                        if (bordesActivos and 4 != 0) it.right = max(min(width.toFloat(), it.right + dx), it.left + minLado)
                        if (bordesActivos and 8 != 0) it.bottom = max(min(height.toFloat(), it.bottom + dy), it.top + minLado)
                    }
                }
                ultimoX = event.x
                ultimoY = event.y
                drawingView.invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                modoArrastre = 0
                drawingView.invalidate()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun recortarBitmap(rect: RectF): String? {
        val srcBitmap = fullBitmap ?: return null
        return try {
            val loc = IntArray(2)
            drawingView.getLocationOnScreen(loc)

            val cropX = (rect.left + loc[0]).toInt().coerceIn(0, max(0, srcBitmap.width - 1))
            val cropY = (rect.top + loc[1]).toInt().coerceIn(0, max(0, srcBitmap.height - 1))
            val cropW = rect.width().toInt().coerceIn(1, srcBitmap.width - cropX)
            val cropH = rect.height().toInt().coerceIn(1, srcBitmap.height - cropY)

            if (cropW <= 0 || cropH <= 0) return null

            val croppedBmp = Bitmap.createBitmap(srcBitmap, cropX, cropY, cropW, cropH)
            val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
            if (!appFlutterDir.exists()) appFlutterDir.mkdirs()

            val file = File(appFlutterDir, "portada_recorte_${System.currentTimeMillis()}.jpg")
            FileOutputStream(file).use { out ->
                croppedBmp.compress(Bitmap.CompressFormat.JPEG, 90, out)
            }
            file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun dibujarEsquinasVisor(canvas: Canvas, r: RectF, len: Float, radius: Float) {
        val path = Path()

        path.moveTo(r.left, r.top + len)
        path.lineTo(r.left, r.top + radius)
        path.quadTo(r.left, r.top, r.left + radius, r.top)
        path.lineTo(r.left + len, r.top)

        path.moveTo(r.right - len, r.top)
        path.lineTo(r.right - radius, r.top)
        path.quadTo(r.right, r.top, r.right, r.top + radius)
        path.lineTo(r.right, r.top + len)

        path.moveTo(r.right, r.bottom - len)
        path.lineTo(r.right, r.bottom - radius)
        path.quadTo(r.right, r.bottom, r.right - radius, r.bottom)
        path.lineTo(r.right - len, r.bottom)

        path.moveTo(r.left + len, r.bottom)
        path.lineTo(r.left + radius, r.bottom)
        path.quadTo(r.left, r.bottom, r.left, r.bottom - radius)
        path.lineTo(r.left, r.bottom - len)

        canvas.drawPath(path, paintBorder)
    }
}
