package com.example.my_alpha_player

import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.lifecycle.LifecycleOwner // ✅ 必须是 androidx
import com.ss.ugc.android.alpha_player.IMonitor
import com.ss.ugc.android.alpha_player.IPlayerAction
import com.ss.ugc.android.alpha_player.controller.IPlayerController
import com.ss.ugc.android.alpha_player.controller.PlayerController
import com.ss.ugc.android.alpha_player.model.AlphaVideoViewType
import com.ss.ugc.android.alpha_player.model.Configuration
import com.ss.ugc.android.alpha_player.model.DataSource
import com.ss.ugc.android.alpha_player.model.ScaleType
import com.ss.ugc.android.alpha_player.player.DefaultSystemPlayer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File

class NativeAlphaPlayerView(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
    viewId: Int
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container: FrameLayout = FrameLayout(context)
    private var playerController: IPlayerController? = null
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.example.live/alpha_player_$viewId")

    init {
        methodChannel.setMethodCallHandler(this)
        initPlayer()
    }

    // 🛠️ 辅助方法：递归查找真正的 Activity/LifecycleOwner
    // 防止传入的 Context 是被包装过的 (TintContextWrapper 等)，导致直接强转失败
    private fun getLifecycleOwner(context: Context): LifecycleOwner? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is LifecycleOwner) {
                return ctx
            }
            ctx = ctx.baseContext
        }
        return null
    }

    private fun initPlayer() {
        // 1. 安全地获取 LifecycleOwner
        val owner = getLifecycleOwner(context)

        if (owner == null) {
            Log.e("AlphaPlayer", "❌ 严重错误: 无法从 Context 中获取 LifecycleOwner，播放器无法初始化！")
            // 这里我们不 return，而是尝试传 null 碰碰运气，或者让它报错以便调试
            // 但通常开启 Jetifier 后，Context 本身就是 LifecycleOwner
        } else {
            Log.i("AlphaPlayer", "✅ 成功获取 LifecycleOwner: $owner")
        }

        // 2. 配置播放器
        // 如果 gradle.properties 的 enableJetifier=true 生效，这里就不会报类型错误
        // 如果 owner 为空，这里可能会崩溃，但在 FlutterActivity 环境下通常不会为空
        try {
            val configuration = Configuration(context, owner ?: (context as LifecycleOwner))
            configuration.alphaVideoViewType = AlphaVideoViewType.GL_TEXTURE_VIEW

            val player = DefaultSystemPlayer()
            playerController = PlayerController.get(configuration, player)

            playerController?.let { controller ->
                controller.attachAlphaView(container)

                controller.setPlayerAction(object : IPlayerAction {
                    // 🟢 1. 监听视频尺寸变化，并传回给 Flutter
                    override fun onVideoSizeChanged(videoWidth: Int, videoHeight: Int, scaleType: ScaleType) {
                        Log.i("AlphaPlayer", "视频尺寸: $videoWidth x $videoHeight")
                        // 切换到主线程发送消息（防止崩溃）
                        container.post {
                            methodChannel.invokeMethod("onVideoSize", mapOf("width" to videoWidth, "height" to videoHeight))
                        }
                    }

                    override fun startAction() {
                        Log.i("AlphaPlayer", "开始播放")
                        container.post {
                            container.alpha = 1f
                        }
                    }
                    override fun endAction() {
                        Log.i("AlphaPlayer", "播放结束")
                        methodChannel.invokeMethod("onPlayFinished", null)
                    }
                })

                controller.setMonitor(object : IMonitor {
                    override fun monitor(result: Boolean, playType: String, what: Int, extra: Int, errorInfo: String) {
                        if (!result) {
                            Log.e("AlphaPlayer", "播放报错: $errorInfo")
                            methodChannel.invokeMethod("onError", mapOf("error" to errorInfo))
                        }
                    }
                })
            }
        } catch (e: Exception) {
            Log.e("AlphaPlayer", "初始化崩溃: ${e.message}")
            // 如果在初始化就崩溃，说明 Jetifier 没生效，类型依然不匹配
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    playVideo(url)
                    result.success(null)
                } else {
                    result.error("ARGS_ERROR", "URL is null", null)
                }
            }
            "stop" -> {
                playerController?.stop()
                result.success(null)
            }
            "detach" -> {
                playerController?.detachAlphaView(container)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun playVideo(path: String) {
        val file = File(path)
        if (!file.exists()) {
            Log.e("AlphaPlayer", "文件不存在: $path")
            return
        }

        container.alpha = 0f

        // 使用 canonicalPath 获取标准路径
        val realPath = file.canonicalPath
        Log.i("AlphaPlayer", "播放路径: $realPath")

        // 🟢 核心修改：将缩放模式改为 1 (ScaleAspectFitCenter)
        // 1 = 宽度占满，高度自适应 (保持比例，不裁剪，内容全部显示)
        // 2 = 充满屏幕 (可能会放大裁切，导致感觉"很大")
        val scaleType = 1

        val dataSource = DataSource()
            .setBaseDir(File(realPath).parent)
            .setPortraitPath(file.name, scaleType)  // 改为 1
            .setLandscapePath(file.name, scaleType) // 改为 1
            .setLooping(false)

        if (dataSource.isValid()) {
            playerController?.start(dataSource)
        } else {
            Log.e("AlphaPlayer", "DataSource 无效")
        }
    }

    override fun getView(): View {
        return container
    }

    override fun dispose() {
        playerController?.let {
            it.detachAlphaView(container)
            it.release()
        }
    }
}