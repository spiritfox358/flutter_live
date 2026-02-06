package com.example.my_alpha_player

import android.content.Context
import android.media.MediaPlayer
import android.util.Log
import android.view.Surface
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
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

    init {
        methodChannel.setMethodCallHandler(this)
        initCustomPlayer()
    }

    override fun getView(): View = container

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
        customAlphaView = AlphaTextureView(context)
        container.addView(customAlphaView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        customAlphaView?.onSurfaceReady = { st ->
            customAlphaView?.setClear(true)
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
                if (mediaPlayer!!.isPlaying) mediaPlayer!!.stop()
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

        // 设置滤镜
        val params = if (hue != null) FilterParams(isOn = true, hue = hue) else FilterParams(isOn = false)
        customAlphaView?.setFilterParams(params)

        // 1. 播放前先开启 Clear，清空屏幕
        customAlphaView?.setClear(true)

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

                // 🟢 关键修复：准备好后必须 start()，否则不播放！
                setOnPreparedListener { mp ->
                    Log.i("AlphaPlayer", "✅ 视频准备完毕，开始播放")
                    mp.start()
                    // 只要开始播放，就允许渲染器工作。
                    // 渲染器内部有 "前5帧丢弃" 逻辑，所以这里直接设为 false 也没问题。
                    customAlphaView?.setClear(false)
                }

                setOnCompletionListener {
                    methodChannel.invokeMethod("onPlayFinished", null)
                    customAlphaView?.setClear(true)
                }

                setOnErrorListener { _, what, extra ->
                    methodChannel.invokeMethod("onError", mapOf("error" to "MediaPlayer Error: $what"))
                    releaseMediaPlayer()
                    customAlphaView?.setClear(true)
                    return@setOnErrorListener true
                }

                prepareAsync()
            }
        } catch (e: Exception) {
            releaseMediaPlayer()
            customAlphaView?.setClear(true)
        }
    }

    private fun stop_Custom() {
        releaseMediaPlayer()
        customAlphaView?.setClear(true)
        pendingUrl = null
    }
}