package com.example.my_alpha_player

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** MyAlphaPlayerPlugin */
class MyAlphaPlayerPlugin : FlutterPlugin {

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // 核心代码在这里！
        // 当插件连接到 Flutter 引擎时，我们注册视图工厂
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "com.example.live/alpha_player", // 必须和 Dart 代码里的 viewType 一模一样
            NativeAlphaPlayerFactory(flutterPluginBinding.binaryMessenger)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // 插件卸载时，通常不需要做特殊清理，除非你需要解绑 channel
    }
}