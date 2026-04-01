package com.example.hardcore_mixer

import android.content.Context
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

class HardcoreMixerPlugin: FlutterPlugin, MethodCallHandler {

    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private lateinit var textureRegistry: TextureRegistry

    private var renderer: HardcoreRenderer? = null
    private var decoderPool: VideoDecoderPool? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hardcore_mixer")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initializeMixer" -> {
                // 1. 向 Flutter 申请一块共享显存画板
                val textureEntry = textureRegistry.createSurfaceTexture()
                val textureId = textureEntry.id()

                // 2. 启动 OpenGL 渲染引擎
                renderer = HardcoreRenderer(textureEntry)
                renderer?.start()

                // 3. 启动解码器池，并把渲染器传给它
                decoderPool = VideoDecoderPool(context, renderer!!)
                decoderPool?.initialize()

                // 4. 将这块画板的 ID 传给 Flutter
                result.success(textureId)
            }
            "playStreams" -> {
                // 接收 Flutter 传过来的 视频 URL 数组
                val urls = call.argument<List<String>>("urls") ?: emptyList()
                decoderPool?.playStreams(urls)
                result.success(null)
            }
            "disposeMixer" -> {
                decoderPool?.release()
                renderer?.release()
                decoderPool = null
                renderer = null
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        decoderPool?.release()
        renderer?.release()
    }
}