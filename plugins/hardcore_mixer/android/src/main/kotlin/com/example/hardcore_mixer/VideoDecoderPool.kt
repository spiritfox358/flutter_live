package com.example.hardcore_mixer

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.DefaultLoadControl
import com.google.android.exoplayer2.DefaultRenderersFactory
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector
// 🚀 新增导入：用于劫持底层解码器分配
import com.google.android.exoplayer2.mediacodec.MediaCodecInfo
import com.google.android.exoplayer2.mediacodec.MediaCodecSelector
import com.google.android.exoplayer2.mediacodec.MediaCodecUtil

class VideoDecoderPool(private val context: Context, private val renderer: HardcoreRenderer) {

    private val TAG = "VideoDecoderPool"
    private val players = arrayOfNulls<ExoPlayer>(9)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun initialize() {
        mainHandler.post {
            // 🚀 撤销之前的 customCodecSelector，恢复原生的硬解优先！
            // 现代手机硬解 9 个低分辨率视频轻轻松松，绝不会卡顿！
            val renderersFactory = DefaultRenderersFactory(context).setEnableDecoderFallback(true)

            for (i in 0 until 9) {
                val trackSelector = DefaultTrackSelector(context).apply {
                    setParameters(
                        buildUponParameters()
                            .setForceLowestBitrate(true) // 保持限制低分辨率
                            .setMaxVideoSize(640, 360)   // 严控解码大小
                    )
                }

                // 保持严苛的缓冲限制，防止内存溢出
                val loadControl = DefaultLoadControl.Builder()
                    .setBufferDurationsMs(1000, 2000, 500, 500)
                    .build()

                players[i] = ExoPlayer.Builder(context, renderersFactory)
                    .setTrackSelector(trackSelector)
                    .setLoadControl(loadControl)
                    .build().apply {
                        repeatMode = Player.REPEAT_MODE_ALL
                        volume = 1.0f // 声音全开
                        // 🚀🚀🚀 核心魔法：强行禁止安卓底层加黑边，强制缩放并裁剪填满画板！
                        videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
                    }
            }
            Log.d(TAG, "9 个【彻底防卡死硬件版】引擎已就位！")
        }
    }

    fun playStreams(urls: List<String>) {
        mainHandler.post {
            renderer.activeStreamCount = urls.size

            for (i in 0 until 9) {
                val player = players[i] ?: continue
                player.stop()
                player.clearMediaItems()

                if (i < urls.size && urls[i].startsWith("http")) {
                    if (renderer.inputSurfaces[i] != null) {
                        player.setVideoSurface(renderer.inputSurfaces[i])
                    }

                    val mediaItem = MediaItem.fromUri(urls[i])
                    player.setMediaItem(mediaItem)
                    player.prepare()

                    mainHandler.postDelayed({
                        try {
                            player.play()
                            Log.d(TAG, "通道 $i 开始播放")
                        } catch (e: Exception) {
                            Log.e(TAG, "通道 $i 异常", e)
                        }
                    }, (i * 300).toLong())
                }
            }
        }
    }

    fun release() {
        mainHandler.post {
            for (i in 0 until 9) {
                players[i]?.release()
                players[i] = null
            }
            Log.d(TAG, "销毁完毕")
        }
    }
}