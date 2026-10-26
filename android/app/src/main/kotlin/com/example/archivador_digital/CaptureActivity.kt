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
import android.media.projection.MediaProjectionManager
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

        fun detenerProjection() {
            try {
                activeMediaProjection?.stop()
            } catch (_: Exception) {}
            activeMediaProjection = null
            mediaProjectionData = null
        }

        private fun obtenerOIniciarProjection(context: Context): MediaProjection? {
            activeMediaProjection?.let { return it }
            val data = mediaProjectionData ?: return null
            return try {
                val projectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                val mp = projectionManager?.getMediaProjection(resultCode, data)
                mp?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        activeMediaProjection = null
                        mediaProjectionData = null
                    }
                }, Handler(Looper.getMainLooper()))
                activeMediaProjection = mp
                mp
            } catch (e: Exception) {
                e.printStackTrace()
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

                val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                var virtualDisplay: VirtualDisplay? = null

                virtualDisplay = mediaProjection.createVirtualDisplay(
                    "SimplistaCapture",
                    width,
                    height,
                    density,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    imageReader.surface,
                    null,
                    null
                )

                Handler(Looper.getMainLooper()).postDelayed({
                    var savedPath: String? = null
                    try {
                        val image = imageReader.acquireLatestImage()
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
                                Bitmap.createBitmap(bitmap, 0, 0, width, height)
                            } else {
                                bitmap
                            }

                            val appFlutterDir = File(context.filesDir.parentFile, "app_flutter")
                            if (!appFlutterDir.exists()) appFlutterDir.mkdirs()

                            val file = File(appFlutterDir, "screen_portada_${System.currentTimeMillis()}.jpg")
                            FileOutputStream(file).use { out ->
                                cleanBitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
                            }
                            savedPath = file.absolutePath
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    } finally {
                        try {
                            virtualDisplay?.release()
                        } catch (_: Exception) {}
                        try {
                            imageReader.close()
                        } catch (_: Exception) {}
                        onResult(savedPath)
                    }
                }, 200)
            } catch (e: Exception) {
                e.printStackTrace()
                activeMediaProjection = null
                mediaProjectionData = null
                onResult(null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resCode, data)
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resCode == RESULT_OK && data != null) {
                resultCode = resCode
                mediaProjectionData = data
                // Avisar a XiaomiOverlayService para que active FGS tipo mediaProjection y tome la captura
                val srvIntent = Intent(this, XiaomiOverlayService::class.java).apply {
                    action = "ACTION_CAPTURE_GRANTED"
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(srvIntent)
                } else {
                    startService(srvIntent)
                }
            }
            finish()
        }
    }
}
