package com.example.hardcore_mixer

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.DefaultLoadControl
import com.google.android.exoplayer2.DefaultRenderersFactory
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector
import com.google.android.exoplayer2.video.VideoSize

class VideoDecoderPool(private val context: Context, private val renderer: HardcoreRenderer) {

    private val players = arrayOfNulls<ExoPlayer>(9)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentUrls: List<String> = emptyList()
    private var isReleased = false

    fun initialize() {
        isReleased = false
        mainHandler.post {
            val renderersFactory = DefaultRenderersFactory(context).setEnableDecoderFallback(true)

            for (i in 0 until 9) {
                val trackSelector = DefaultTrackSelector(context)
                val loadControl = DefaultLoadControl.Builder().setBufferDurationsMs(1000, 2000, 500, 500).build()

                players[i] = ExoPlayer.Builder(context, renderersFactory)
                    .setTrackSelector(trackSelector)
                    .setLoadControl(loadControl)
                    .build().apply {
                        repeatMode = Player.REPEAT_MODE_ALL
                        volume = 1.0f

                        addListener(object : Player.Listener {
                            override fun onVideoSizeChanged(videoSize: VideoSize) {
                                if (videoSize.width > 0 && videoSize.height > 0) {
                                    // 还原推流端真实的非正方形像素比例，彻底解决拉伸
                                    var realW = videoSize.width.toFloat() * videoSize.pixelWidthHeightRatio
                                    var realH = videoSize.height.toFloat()

                                    if (videoSize.unappliedRotationDegrees == 90 || videoSize.unappliedRotationDegrees == 270) {
                                        val temp = realW
                                        realW = realH
                                        realH = temp
                                    }
                                    renderer.updateVideoRatio(i, realW / realH)
                                }
                            }
                        })
                    }
            }
        }
    }

    fun playStreams(urls: List<String>) {
        mainHandler.post {
            if (isReleased) return@post
            renderer.activeStreamCount = urls.size
            if (currentUrls == urls) return@post
            currentUrls = urls

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
                        if (isReleased) return@postDelayed
                        try { player.play() } catch (e: Exception) {}
                    }, (i * 300).toLong())
                }
            }
        }
    }

    fun getReadyUrls(): List<String> {
        val readyUrls = mutableListOf<String>()
        for (i in currentUrls.indices) {
            if (i < 9 && players[i]?.playbackState == Player.STATE_READY) {
                readyUrls.add(currentUrls[i])
            }
        }
        return readyUrls
    }

    fun setMuted(url: String, isMuted: Boolean) {
        mainHandler.post {
            val index = currentUrls.indexOf(url)
            if (index != -1 && index < 9) {
                players[index]?.volume = if (isMuted) 0.0f else 1.0f
            }
        }
    }

    fun release() {
        isReleased = true
        mainHandler.removeCallbacksAndMessages(null)
        for (i in 0 until 9) {
            try {
                players[i]?.volume = 0f
                players[i]?.stop()
            } catch (e: Exception) {}
        }
        for (i in 0 until 9) {
            mainHandler.postDelayed({
                try {
                    players[i]?.release()
                    players[i] = null
                } catch (e: Exception) {}
            }, (i * 30 + 50).toLong())
        }
    }
}