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
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min

class GeminiCropOverlayView(
    context: Context,
    private val fullScreenshotPath: String?,
    private val onAreaSelected: (String?) -> Unit
) : View(context) {

    private var fullBitmap: Bitmap? = null
    private val paintDim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#99000000") // Oscurecido general
    }
    private val paintClear = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
    }

    // Pincel para esquinas / bordes blancos elegantes estilo Gemini / Circle to search
    private val paintBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 3f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }

    // Pincel para el resplandor / brillo
    private val paintGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#8060A5FA") // Azul claro / destello
        style = Paint.Style.STROKE
        strokeWidth = 6f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }

    private var startPoint = PointF()
    private var currentPoint = PointF()
    private var isSelecting = false
    private var selectionRect: RectF? = null

    init {
        // Habilitar aceleración por capas de software si se usa PorterDuff.CLEAR
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        if (fullScreenshotPath != null && File(fullScreenshotPath).exists()) {
            try {
                fullBitmap = BitmapFactory.decodeFile(fullScreenshotPath)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                startPoint.set(event.x, event.y)
                currentPoint.set(event.x, event.y)
                isSelecting = true
                selectionRect = null
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (isSelecting) {
                    currentPoint.set(event.x, event.y)
                    val left = min(startPoint.x, currentPoint.x)
                    val top = min(startPoint.y, currentPoint.y)
                    val right = max(startPoint.x, currentPoint.x)
                    val bottom = max(startPoint.y, currentPoint.y)
                    selectionRect = RectF(left, top, right, bottom)
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isSelecting) {
                    isSelecting = false
                    val rect = selectionRect
                    if (rect != null && rect.width() > 30 && rect.height() > 30) {
                        val croppedPath = recortarBitmap(rect)
                        onAreaSelected(croppedPath ?: fullScreenshotPath)
                    } else {
                        // Si solo fue un tap o área muy pequeña, conserva la captura completa
                        onAreaSelected(fullScreenshotPath)
                    }
                }
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun recortarBitmap(rect: RectF): String? {
        val srcBitmap = fullBitmap ?: return null
        return try {
            val scaleX = srcBitmap.width.toFloat() / width.toFloat()
            val scaleY = srcBitmap.height.toFloat() / height.toFloat()

            val cropX = max(0, (rect.left * scaleX).toInt())
            val cropY = max(0, (rect.top * scaleY).toInt())
            val cropW = min(srcBitmap.width - cropX, (rect.width() * scaleX).toInt())
            val cropH = min(srcBitmap.height - cropY, (rect.height() * scaleY).toInt())

            if (cropW <= 0 || cropH <= 0) return null

            val croppedBmp = Bitmap.createBitmap(srcBitmap, cropX, cropY, cropW, cropH)
            val file = File(context.cacheDir, "gemini_crop_${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { out ->
                croppedBmp.compress(Bitmap.CompressFormat.JPEG, 88, out)
            }
            file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 1. Oscurecer la pantalla
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paintDim)

        val rect = selectionRect
        val cornerRadius = 18f * resources.displayMetrics.density
        val cornerLen = 28f * resources.displayMetrics.density

        if (rect != null && rect.width() > 10 && rect.height() > 10) {
            // 2. Dejar transparente el área seleccionada para que destaque la imagen/contenido
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paintClear)

            // 3. Resplandor exterior alrededor del recorte
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paintGlow)

            // 4. Dibujar las 4 esquinas blancas estilo visor de escaneo
            dibujarEsquinasVisor(canvas, rect, cornerLen, cornerRadius)
        }
    }

    private fun dibujarEsquinasVisor(canvas: Canvas, r: RectF, len: Float, radius: Float) {
        val path = Path()

        // Esquina Superior Izquierda
        path.moveTo(r.left, r.top + len)
        path.lineTo(r.left, r.top + radius)
        path.quadTo(r.left, r.top, r.left + radius, r.top)
        path.lineTo(r.left + len, r.top)

        // Esquina Superior Derecha
        path.moveTo(r.right - len, r.top)
        path.lineTo(r.right - radius, r.top)
        path.quadTo(r.right, r.top, r.right, r.top + radius)
        path.lineTo(r.right, r.top + len)

        // Esquina Inferior Derecha
        path.moveTo(r.right, r.bottom - len)
        path.lineTo(r.right, r.bottom - radius)
        path.quadTo(r.right, r.bottom, r.right - radius, r.bottom)
        path.lineTo(r.right - len, r.bottom)

        // Esquina Inferior Izquierda
        path.moveTo(r.left + len, r.bottom)
        path.lineTo(r.left + radius, r.bottom)
        path.quadTo(r.left, r.bottom, r.left, r.bottom - radius)
        path.lineTo(r.left, r.bottom - len)

        canvas.drawPath(path, paintBorder)
    }
}
