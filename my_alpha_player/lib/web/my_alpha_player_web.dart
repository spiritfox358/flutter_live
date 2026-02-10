// lib/web/my_alpha_player_web.dart

import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

// 1. 定义 JS 接口
@JS('AlphaPlayerWeb.create')
external JSAlphaPlayer createAlphaPlayer(int viewId);

@JS()
extension type JSAlphaPlayer._(JSObject _) implements JSObject {
  external web.HTMLCanvasElement getDomElement();
  external void play(String url, double? hue);
  external void stop();

  // 🟢 关键：定义 JS 的 setOnEnded 方法
  // JSFunction 是 dart:js_interop 里的类型
  external void setOnEnded(JSFunction callback);
}

// 2. Web 组件
class MyAlphaPlayerWeb extends StatefulWidget {
  final int viewId;
  // 🟢 增加 onFinish 回调
  final VoidCallback? onFinish;
  final Function(MyAlphaPlayerWebController controller) onCreated;

  const MyAlphaPlayerWeb({
    super.key,
    required this.viewId,
    required this.onCreated,
    this.onFinish,
  });

  @override
  State<MyAlphaPlayerWeb> createState() => _MyAlphaPlayerWebState();
}

class _MyAlphaPlayerWebState extends State<MyAlphaPlayerWeb> {
  late JSAlphaPlayer _jsPlayer;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'alpha_player_web_${widget.viewId}';

    // 创建 JS 实例
    _jsPlayer = createAlphaPlayer(widget.viewId);

    // 🟢 关键：将 Dart 回调转换成 JS 函数并传给 JS
    // 当 JS 视频播放结束时，会调用这个闭包，进而触发 widget.onFinish
    _jsPlayer.setOnEnded(
          () {
        print("🎯 Dart received: Video Ended");
        if (widget.onFinish != null) {
          widget.onFinish!();
        }
      }.toJS, // 👈 .toJS 魔法：把 Dart 函数变成 JS 函数
    );

    // 注册 Web 视图
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _jsPlayer.getDomElement();
    });

    // 回调控制器给父组件
    Future.delayed(Duration.zero, () {
      widget.onCreated(MyAlphaPlayerWebController(_jsPlayer));
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

// Web 控制器
class MyAlphaPlayerWebController {
  final JSAlphaPlayer _jsPlayer;
  MyAlphaPlayerWebController(this._jsPlayer);

  void play(String url, {double? hue}) {
    _jsPlayer.play(url, hue);
  }

  void stop() {
    _jsPlayer.stop();
  }
}