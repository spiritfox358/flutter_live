// lib/my_alpha_player.dart

import 'package:flutter/foundation.dart'; // 🟢 1. 用 foundation 代替 dart:io
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// 🟢 2. 条件导入：如果是 Web 环境导入真身，否则导入替身(Stub)
import 'web/my_alpha_player_web_stub.dart'
if (dart.library.js_interop) 'web/my_alpha_player_web.dart';

class MyAlphaPlayerController {
  // 原有逻辑保持不变
  MethodChannel? _channel;
  bool _isDisposed = false;

  // 🟢 新增：Web 控制器引用
  MyAlphaPlayerWebController? _webController;

  VoidCallback? onFinish;
  Function(double width, double height)? onVideoSize;
  Function(String error)? onError;

  // 绑定 Web 控制器 (供 Web 端调用)
  void bindWeb(MyAlphaPlayerWebController webCtrl) {
    _webController = webCtrl;
  }

  void bind(int viewId) {
    // 🟢 如果是 Web，直接跳过 MethodChannel 绑定
    if (kIsWeb || _isDisposed) return;

    _channel = MethodChannel('com.example.live/alpha_player_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (_isDisposed) return;

      try {
        if (call.method == "onPlayFinished") {
          onFinish?.call();
        } else if (call.method == "onVideoSize") {
          final args = call.arguments;
          if (args is Map) {
            final width = args['width'];
            final height = args['height'];
            if (width != null && height != null) {
              onVideoSize?.call((width as num).toDouble(), (height as num).toDouble());
            }
          }
        } else if (call.method == "onError") {
          onError?.call(call.arguments?.toString() ?? "Native Error");
          onFinish?.call();
        }
      } catch (e) {
        print("AlphaPlayer callback error: $e");
      }
    });
  }

  Future<void> play(String url, {double? hue}) async {
    if (_isDisposed) return;

    // 🟢 分发逻辑：Web 走 Web，原生走 Channel
    if (kIsWeb) {
      _webController?.play(url, hue: hue);
      return;
    }

    // --- 以下是原有的原生逻辑 ---
    try {
      final Map<String, dynamic> args = {"url": url};
      if (hue != null) {
        args["hue"] = hue;
      }
      await _channel?.invokeMethod('play', args);
    } catch (e) {
      debugPrint("AlphaPlayer Play Error: $e");
      onFinish?.call();
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;

    if (kIsWeb) {
      _webController?.stop();
      return;
    }

    try {
      await _channel?.invokeMethod('stop');
    } catch (e) {
      print("AlphaPlayer Stop Error: $e");
    }
  }

  void dispose() {
    _isDisposed = true;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _webController = null; // 清理 Web 引用
    onFinish = null;
    onVideoSize = null;
    onError = null;
  }
}

class MyAlphaPlayerView extends StatefulWidget {
  final void Function(MyAlphaPlayerController controller)? onCreated;

  const MyAlphaPlayerView({Key? key, this.onCreated}) : super(key: key);

  @override
  State<MyAlphaPlayerView> createState() => _MyAlphaPlayerViewState();
}

class _MyAlphaPlayerViewState extends State<MyAlphaPlayerView> {
  MyAlphaPlayerController? _controller;

  @override
  Widget build(BuildContext context) {
    const String viewType = 'com.example.live/alpha_player';

    // 🟢 1. 优先判断 Web (必须放在 Platform 判断之前)
    if (kIsWeb) {
      // 生成一个唯一 ID 给 Web 用
      final int webViewId = DateTime.now().microsecondsSinceEpoch;

      // 这里的 MyAlphaPlayerWeb 会根据环境自动切换文件
      // 在 Android 上它就是 Stub (空壳)，在 Web 上它是真身
      return MyAlphaPlayerWeb(
        viewId: webViewId,
        onFinish: () {
          // 告诉上层逻辑（礼物队列）播放结束了，可以播下一个了
          _controller?.onFinish?.call();
        },
        onCreated: (webCtrl) {
          final controller = MyAlphaPlayerController();
          controller.bindWeb(webCtrl);
          _controller = controller;
          widget.onCreated?.call(controller);
        },
      );
    }

    // 🟢 2. Android 判断 (不能用 Platform.isAndroid，要用 defaultTargetPlatform)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      );
    }

    // 🟢 3. iOS 判断
    else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const Center(child: Text("不支持的平台"));
  }

  void _onPlatformViewCreated(int id) {
    final controller = MyAlphaPlayerController();
    _controller = controller;
    controller.bind(id);

    if (widget.onCreated != null) {
      widget.onCreated!(controller);
    }
  }

  @override
  void dispose() {
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }
}