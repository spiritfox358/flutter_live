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

    companion object {
        init { System.loadLibrary("hardcore_mixer") }
    }

    private external fun nativeInitEngine()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hardcore_mixer")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initEngine", "initializeMixer" -> {
                decoderPool?.release()
                renderer?.release()

                try { nativeInitEngine() } catch (e: Exception) {}

                val textureEntry = textureRegistry.createSurfaceTexture()
                val textureId = textureEntry.id()

                renderer = HardcoreRenderer(textureEntry)
                renderer?.start()

                decoderPool = VideoDecoderPool(context, renderer!!)
                decoderPool?.initialize()

                result.success(textureId)
            }
            "playStreams" -> {
                val urls = call.argument<List<String>>("urls") ?: emptyList()

                // 🚀🚀🚀 核心修复 1：使用 Number 泛型防崩溃！完美接收 Flutter 传来的任何数值！
                val containerW = (call.argument<Any>("containerWidth") as? Number)?.toFloat() ?: 1080f
                val containerH = (call.argument<Any>("containerHeight") as? Number)?.toFloat() ?: 1080f

                decoderPool?.playStreams(urls)

                // 🚀🚀🚀 核心修复 2：手动安全遍历强转，防止 Flutter 的 [0.0, 1.0] 整数塌陷导致整盘崩溃！
                val rawLayouts = call.argument<List<*>>("layouts")
                if (rawLayouts != null && rawLayouts.isNotEmpty()) {
                    val flatLayouts = FloatArray(rawLayouts.size * 4)
                    for (i in rawLayouts.indices) {
                        val row = rawLayouts[i] as? List<*>
                        if (row != null && row.size >= 4) {
                            flatLayouts[i * 4 + 0] = (row[0] as? Number)?.toFloat() ?: 0f
                            flatLayouts[i * 4 + 1] = (row[1] as? Number)?.toFloat() ?: 0f
                            flatLayouts[i * 4 + 2] = (row[2] as? Number)?.toFloat() ?: 0f
                            flatLayouts[i * 4 + 3] = (row[3] as? Number)?.toFloat() ?: 0f
                        }
                    }
                    // 只有这里执行成功了，底层才会真正根据屏幕缩放！
                    renderer?.updateLayouts(flatLayouts, containerW, containerH)
                }
                result.success(null)
            }
            "getReadyUrls" -> {
                val readyUrls = decoderPool?.getReadyUrls() ?: emptyList<String>()
                result.success(readyUrls)
            }
            "setMuted" -> {
                val url = call.argument<String>("url") ?: ""
                val isMuted = call.argument<Boolean>("isMuted") ?: false
                decoderPool?.setMuted(url, isMuted)
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