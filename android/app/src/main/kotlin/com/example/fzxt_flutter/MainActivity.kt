package com.example.flutter_live

// 注意：保留你原有的 package xxx.xxx.xxx 声明！

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ai.voice/native_player"
    private var audioTrack: AudioTrack? = null
    // 🟢 核心：一个线程安全的阻塞队列，专门用来接 Flutter 发来的音频块
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var isPlaying = false
    private var playThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initPlayer" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    initPlayer(sampleRate)
                    result.success(true)
                }
                "feedAudio" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        // 收到 Flutter 的数据，扔进队列就立刻返回，绝对不阻塞 Flutter 线程
                        audioQueue.offer(data)
                    }
                    result.success(true)
                }
                "stopPlayer" -> {
                    stopPlayer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initPlayer(sampleRate: Int) {
        stopPlayer()

        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        // 使用 Android 官方推荐的 AudioTrack Builder 初始化
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(minBufferSize * 4) // 留足缓冲空间
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
        isPlaying = true

        // 🟢 核心：开辟一个专门的后台线程，死循环读取队列并播放
        playThread = Thread {
            while (isPlaying) {
                try {
                    // take() 是阻塞的，如果没有音频数据，线程会在这里安静地休眠，完全不耗费 CPU
                    val data = audioQueue.take()
                    audioTrack?.write(data, 0, data.size)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        playThread?.start()
    }

    private fun stopPlayer() {
        isPlaying = false
        playThread?.interrupt()
        playThread = null
        audioQueue.clear()
        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        audioTrack = null
    }
}