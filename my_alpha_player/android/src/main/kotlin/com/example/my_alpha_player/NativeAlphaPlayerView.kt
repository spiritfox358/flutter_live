package com.example.my_alpha_player

import android.content.Context
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.util.Log
import android.view.Surface
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
// 🌟 必须导入这些
import com.example.my_alpha_player.player.FilterParams
import com.example.my_alpha_player.player.AlphaTextureView

class NativeAlphaPlayerView(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
    viewId: Int
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container: FrameLayout = FrameLayout(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.example.live/alpha_player_$viewId")

    private var customAlphaView: AlphaTextureView? = null
    private var mediaPlayer: MediaPlayer? = null
    private var currentSurface: Surface? = null
    private var pendingUrl: String? = null

    // 默认神仙参数
    private val defaultBestParams = FilterParams(
        hue = 0.0f,
        sat = 1.0f,
        value = 1.1f,
        shadow = 0.15f,
        gamma = 0.8f,
        inLow = 0.0f,
        mixOrigin = 0.0f,
        isOn = true
    )

    init {
        methodChannel.setMethodCallHandler(this)
        initCustomPlayer()
    }

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        releaseMediaPlayer()
        currentSurface?.release()
        currentSurface = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                val hue = call.argument<Double>("hue")?.toFloat()

                if (url != null) {
                    playVideo_Custom(url, hue)
                    result.success(null)
                } else {
                    result.error("ARGS_ERROR", "URL is null", null)
                }
            }
            "stop" -> {
                stop_Custom()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initCustomPlayer() {
        Log.i("AlphaPlayer", "✨ 初始化引擎...")
        customAlphaView = AlphaTextureView(context)

        container.addView(customAlphaView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        container.alpha = 0f

        // 🌟 修正：使用 onSurfaceReady 回调，而不是 setOnSurfaceTextureListener
        customAlphaView?.onSurfaceReady = { st ->
            st.setOnFrameAvailableListener {
                customAlphaView?.requestRender()
            }

            currentSurface?.release()
            currentSurface = Surface(st)

            pendingUrl?.let { url ->
                playVideo_Custom(url, null)
                pendingUrl = null
            }
        }
    }

    private fun releaseMediaPlayer() {
        try {
            if (mediaPlayer != null) {
                if (mediaPlayer!!.isPlaying) {
                    mediaPlayer!!.stop()
                }
                mediaPlayer!!.reset()
                mediaPlayer!!.release()
                mediaPlayer = null
            }
        } catch (e: Exception) {}
    }

    private fun playVideo_Custom(path: String, hue: Float?) {
        val file = File(path)
        if (!file.exists()) return

        if (currentSurface == null || !currentSurface!!.isValid) {
            pendingUrl = path
            return
        }

        // 设置参数
        if (hue != null) {
            val newParams = defaultBestParams.copy(isOn = true, hue = hue)
            customAlphaView?.setFilterParams(newParams)
            Log.i("AlphaPlayer", "🎨 开启染色: Hue=$hue")
        } else {
            customAlphaView?.setFilterParams(FilterParams(isOn = false))
            Log.i("AlphaPlayer", "🎞️ 原画模式")
        }

        // 防鬼影
        customAlphaView?.setClear(true)
        container.animate().cancel()
        container.alpha = 0f

        releaseMediaPlayer()

        try {
            mediaPlayer = MediaPlayer()
            mediaPlayer?.apply {
                setSurface(currentSurface)
                setDataSource(file.canonicalPath)
                isLooping = false

                setOnVideoSizeChangedListener { _, width, height ->
                    val realWidth = width / 2
                    container.post {
                        methodChannel.invokeMethod("onVideoSize", mapOf("width" to realWidth, "height" to height))
                    }
                }

                setOnPreparedListener { mp ->
                    mp.start()
                }

                setOnInfoListener { _, what, _ ->
                    if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) {
                        Log.i("AlphaPlayer", "✨ 首帧显示")
                        customAlphaView?.setClear(false)
                        container.post {
                            container.animate().alpha(1f).setDuration(200).start()
                        }
                        return@setOnInfoListener true
                    }
                    false
                }

                setOnCompletionListener {
                    methodChannel.invokeMethod("onPlayFinished", null)
                }

                setOnErrorListener { _, what, extra ->
                    methodChannel.invokeMethod("onError", mapOf("error" to "MediaPlayer Error: $what"))
                    releaseMediaPlayer()
                    return@setOnErrorListener true
                }

                prepareAsync()
            }
        } catch (e: Exception) {
            releaseMediaPlayer()
        }
    }

    private fun stop_Custom() {
        releaseMediaPlayer()
        customAlphaView?.setClear(true)
        container.post { container.alpha = 0f }
        pendingUrl = null
    }
}