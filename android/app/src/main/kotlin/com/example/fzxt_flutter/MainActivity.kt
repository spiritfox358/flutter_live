package com.example.flutter_live

// 注意：保留你原有的 package xxx.xxx.xxx 声明！

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.view.WindowManager // 🚀 1. 新增：控制屏幕必须导入这个包
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ai.voice/native_player"
    // 🚀 2. 新增：定义屏幕常亮的专属通道名
    private val SCREEN_CHANNEL = "app.channel.screen"

    private var audioTrack: AudioTrack? = null
    // 🟢 核心：一个线程安全的阻塞队列，专门用来接 Flutter 发来的音频块
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var isPlaying = false
    private var playThread: Thread? = null

    // 🟢 新增：记录当前掌控底层音频硬件的房间号
    private var currentRoomId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ==========================================
        // 🎧 原有的语音播放底层通道（原封不动）
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initPlayer" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    initPlayer(sampleRate)
                    result.success(true)
                }
                "feedAudio" -> {
                    val data = call.argument<ByteArray>("data")
                    val reqRoomId = call.argument<String>("roomId") ?: ""

                    // 🟢 拦截前朝余孽：如果传来的语音包是旧房间延迟到达的，直接扔进垃圾桶，防止串音！
                    if (currentRoomId != null && reqRoomId != currentRoomId) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (data != null) {
                        // 🟢 终极防线：收到语音包时，如果发现底层播放线程死了，立刻自动复活！
                        if (!isPlaying || playThread == null || !playThread!!.isAlive) {
                            initPlayer(24000)
                        }

                        // 收到 Flutter 的数据，扔进队列就立刻返回
                        audioQueue.offer(data)
                    }
                    result.success(true)
                }
                "stopPlayer" -> {
                    val reqRoomId = call.argument<String>("roomId") ?: ""

                    // 🟢 防误杀核心：如果旧房间来喊停，发现主人已经换了，直接忽略指令！
                    if (currentRoomId != null && reqRoomId != currentRoomId) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    stopPlayer()
                    currentRoomId = null // 释放主权
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ==========================================
        // 💡 🚀 新增：屏幕常亮控制专属通道
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "keepScreenOn") {
                val on = call.argument<Boolean>("on") ?: false
                if (on) {
                    // 收到了 Flutter 发来的开灯指令 -> 屏幕常亮！
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    // 收到了 Flutter 发来的关灯指令 -> 允许手机正常息屏休眠
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            } else {
                result.notImplemented()
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