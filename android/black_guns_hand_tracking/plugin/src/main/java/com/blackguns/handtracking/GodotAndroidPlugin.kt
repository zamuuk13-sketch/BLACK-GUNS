package com.blackguns.handtracking
import android.graphics.Bitmap
import android.os.SystemClock
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.Godot

class GodotAndroidPlugin(godot: Godot?) : GodotPlugin(godot) {
    private var landmarker: HandLandmarker? = null
    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME
    @UsedByGodot
    fun initialize(): Boolean {
        if (landmarker != null) return true
        return try {
            val base = BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build()
            val options = HandLandmarker.HandLandmarkerOptions.builder().setBaseOptions(base).setNumHands(2)
                .setMinHandDetectionConfidence(0.5f).setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f).setRunningMode(RunningMode.VIDEO).build()
            landmarker = HandLandmarker.createFromOptions(getActivity(), options)
            true
        } catch (e: Exception) {
            android.util.Log.e("BlackGunsHands", "MediaPipe init failed", e); false
        }
    }
    @UsedByGodot
    fun processFrame(rgb: ByteArray, width: Int, height: Int, timestampUs: Long): String {
        val detector = landmarker ?: return emptyResult(timestampUs)
        if (width <= 0 || height <= 0 || rgb.size < width * height * 3) return emptyResult(timestampUs)
        return try {
            val pixels = IntArray(width * height)
            var p = 0
            for (i in pixels.indices) {
                val r = rgb[p++].toInt() and 255
                val g = rgb[p++].toInt() and 255
                val b = rgb[p++].toInt() and 255
                pixels[i] = -0x1000000 or (r shl 16) or (g shl 8) or b
            }
            val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
            val image = BitmapImageBuilder(bitmap).build()
            val ts = if (timestampUs > 0) timestampUs / 1000L else SystemClock.uptimeMillis()
            val result = detector.detectForVideo(image, ts)
            var left = ""
            var right = ""
            var confidence = 0.0
            result.landmarks().forEachIndexed { index, hand ->
                val handed = result.handednesses().getOrNull(index)?.firstOrNull()
                val label = handed?.categoryName()?.lowercase() ?: ""
                val score = handed?.score()?.toDouble() ?: 0.0
                val encoded = hand.joinToString(";") { lm ->
                    "%.6f,%.6f,%.6f".format(java.util.Locale.US, lm.x(), lm.y(), lm.z())
                }
                if (label == "left") left = encoded else if (label == "right") right = encoded
                else if (left.isEmpty()) left = encoded else right = encoded
                confidence = maxOf(confidence, score)
            }
            val count = result.landmarks().size
            """{"left":"$left","right":"$right","hands":""" + count + ""","timestamp_us":""" + timestampUs + ""","confidence":""" + confidence + "}"""
        } catch (e: Exception) {
            android.util.Log.e("BlackGunsHands", "Frame failed", e); emptyResult(timestampUs)
        }
    }
    @UsedByGodot
    fun close() { landmarker?.close(); landmarker = null }
    private fun emptyResult(timestampUs: Long): String =
        """{"left":"","right":"","hands":0,"timestamp_us":""" + timestampUs + ""","confidence":0.0}"""
}
