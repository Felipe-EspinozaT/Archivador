package com.example.archivador_digital

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream

class CaptureActivity : Activity() {

    companion object {
        private const val REQUEST_CODE_SCREEN_CAPTURE = 9988
        var resultCode: Int = 0
        var mediaProjectionData: Intent? = null
        private var activeMediaProjection: MediaProjection? = null
        private var activeVirtualDisplay: VirtualDisplay? = null
        private var activeImageReader: ImageReader? = null
        private var currentWidth: Int = 0
        private var currentHeight: Int = 0
        private var ultimoBitmapCapturado: Bitmap? = null

        fun detenerProjection() {
            liberarRecursosVirtualDisplay()
            try {
                activeMediaProjection?.stop()
            } catch (_: Exception) {}
            activeMediaProjection = null
            mediaProjectionData = null
        }

        private fun liberarRecursosVirtualDisplay() {
            try {
                activeVirtualDisplay?.release()
            } catch (_: Exception) {}
            try {
                activeImageReader?.close()
            } catch (_: Exception) {}
            activeVirtualDisplay = null
            activeImageReader = null
            currentWidth = 0
            currentHeight = 0
        }

        private fun obtenerOIniciarProjection(context: Context): MediaProjection? {
            activeMediaProjection?.let { return it }
            val data = mediaProjectionData ?: return null
            return try {
                val projectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                val mp = projectionManager?.getMediaProjection(resultCode, data)
                mp?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        liberarRecursosVirtualDisplay()
                        activeMediaProjection = null
                        mediaProjectionData = null
                    }
                }, Handler(Looper.getMainLooper()))
                activeMediaProjection = mp
                mp
            } catch (e: Exception) {
                e.printStackTrace()
                liberarRecursosVirtualDisplay()
                activeMediaProjection = null
                mediaProjectionData = null
                null
            }
        }

        fun capturarPantallaReal(context: Context, onResult: (String?) -> Unit) {
            try {
                val mediaProjection = obtenerOIniciarProjection(context)
                if (mediaProjection == null) {
                    onResult(null)
                    return
                }

                val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getRealMetrics(metrics)

                val width = metrics.widthPixels
                val height = metrics.heightPixels
                val density = metrics.densityDpi

                var esNuevoDisplay = false

                // En Android 14+ (API 34+), el sistema invalida MediaProjection si se destruye y recrea
                // el VirtualDisplay en cada foto. Manteniendo la misma instancia activa en espera,
                // todas las capturas siguientes son instantáneas sin volver a pedir permiso.
                if (activeVirtualDisplay == null || activeImageReader == null) {
                    val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                    val vd = mediaProjection.createVirtualDisplay(
                        "SimplistaCapture",
                        width,
                        height,
                        density,
                        DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                        reader.surface,
                        null,
                        null
                    )
                    activeImageReader = reader
                    activeVirtualDisplay = vd
                    currentWidth = width
                    currentHeight = height
                    esNuevoDisplay = true
                } else if (width != currentWidth || height != currentHeight) {
                    try {
                        activeImageReader?.close()
                    } catch (_: Exception) {}
                    val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                    activeVirtualDisplay?.resize(width, height, density)
                    activeVirtualDisplay?.surface = reader.surface
                    activeImageReader = reader
                    currentWidth = width
                    currentHeight = height
                    esNuevoDisplay = true
                }

                val delayMs = if (esNuevoDisplay) 180L else 60L

                Handler(Looper.getMainLooper()).postDelayed({
                    var savedPath: String? = null
                    try {
                        val reader = activeImageReader
                        val image = reader?.acquireLatestImage()
                        var bitmapParaGuardar: Bitmap? = null

                        if (image != null) {
                            val planes = image.planes
                            val buffer = planes[0].buffer
                            val pixelStride = planes[0].pixelStride
                            val rowStride = planes[0].rowStride
                            val rowPadding = rowStride - pixelStride * width

                            val bitmap = Bitmap.createBitmap(
                                width + rowPadding / pixelStride,
                                height,
                                Bitmap.Config.ARGB_8888
                            )
                            bitmap.copyPixelsFromBuffer(buffer)
                            image.close()

                            val cleanBitmap = if (rowPadding > 0) {
                                val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                                bitmap.recycle()
                                cropped
                            } else {
                                bitmap
                            }
                            ultimoBitmapCapturado = cleanBitmap
                            bitmapParaGuardar = cleanBitmap
                        } else if (ultimoBitmapCapturado != null && !ultimoBitmapCapturado!!.isRecycled) {
                            bitmapParaGuardar = ultimoBitmapCapturado
                        }

                        if (bitmapParaGuardar != null) {
                            val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
                            if (!appFlutterDir.exists()) appFlutterDir.mkdirs()

                            val file = File(appFlutterDir, "screen_portada_${System.currentTimeMillis()}.jpg")
                            FileOutputStream(file).use { out ->
                                bitmapParaGuardar.compress(Bitmap.CompressFormat.JPEG, 90, out)
                            }
                            savedPath = file.absolutePath
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    } finally {
                        onResult(savedPath)
                    }
                }, delayMs)
            } catch (e: Exception) {
                e.printStackTrace()
                detenerProjection()
                onResult(null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val captureIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // En Android 14+ preselecciona "Pantalla completa" automáticamente sin obligar a elegir rango/app
            projectionManager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            projectionManager.createScreenCaptureIntent()
        }
        startActivityForResult(captureIntent, REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resCode, data)
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resCode == RESULT_OK && data != null) {
                detenerProjection()
                resultCode = resCode
                mediaProjectionData = data
                // Avisar a XiaomiOverlayService para que active FGS tipo mediaProjection y tome la captura
                val srvIntent = Intent(this, XiaomiOverlayService::class.java).apply {
                    action = "ACTION_CAPTURE_GRANTED"
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(srvIntent)
                } else {
                    startService(srvIntent)
                }
            }
            finish()
        }
    }
}
