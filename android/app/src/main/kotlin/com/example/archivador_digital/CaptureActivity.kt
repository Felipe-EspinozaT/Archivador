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

        fun capturarPantallaReal(context: Context, onResult: (String?) -> Unit) {
            val data = mediaProjectionData
            if (data == null) {
                onResult(null)
                return
            }

            try {
                val projectionManager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                val mediaProjection = projectionManager?.getMediaProjection(resultCode, data.clone() as Intent)
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

                // Dar tiempo mínimo para renderizar el frame en el ImageReader
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

                            // Cortar si hubo padding en los renglones
                            val cleanBitmap = if (rowPadding > 0) {
                                Bitmap.createBitmap(bitmap, 0, 0, width, height)
                            } else {
                                bitmap
                            }

                            val dir = context.cacheDir
                            val file = File(dir, "screen_portada_${System.currentTimeMillis()}.png")
                            FileOutputStream(file).use { out ->
                                cleanBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                            }
                            savedPath = file.absolutePath
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    } finally {
                        virtualDisplay?.release()
                        imageReader.close()
                        mediaProjection.stop()
                        onResult(savedPath)
                    }
                }, 220)
            } catch (e: Exception) {
                e.printStackTrace()
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
                // Inmediatamente tomar la captura solicitada y notificar al servicio
                capturarPantallaReal(applicationContext) { ruta ->
                    XiaomiOverlayService.rutaUltimaCaptura = ruta
                }
            }
            finish()
        }
    }
}
