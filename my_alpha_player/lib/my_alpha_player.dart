import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class MyAlphaPlayerController {
  MethodChannel? _channel;
  bool _isDisposed = false; // 🟢 增加销毁标记

  VoidCallback? onFinish;
  Function(double width, double height)? onVideoSize;
  // 🟢 增加错误回调，方便上层处理异常
  Function(String error)? onError;

  void bind(int viewId) {
    if (_isDisposed) return;
    _channel = MethodChannel('com.example.live/alpha_player_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (_isDisposed) return; // 如果已销毁，不再处理回调

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
          // 🟢 假设原生层会发 onError，这里接一下，防止死锁
          onError?.call(call.arguments?.toString() ?? "Native Error");
          // 出错时也视为结束，解开队列锁
          onFinish?.call();
        }
      } catch (e) {
        print("AlphaPlayer callback error: $e");
      }
    });
  }

// ✨ 修改后的 play 方法：支持传入可选的 hue (0.0 ~ 1.0)
  Future<void> play(String url, {double? hue}) async {
    if (_isDisposed) return;
    try {
      // 1. 构建参数 Map
      final Map<String, dynamic> args = {"url": url};

      // 2. 如果传入了 hue，则添加到参数中
      // Native 端收到 hue 后会开启染色模式，否则保持原画
      if (hue != null) {
        args["hue"] = hue;
      }

      await _channel?.invokeMethod('play', args);
    } catch (e) {
      debugPrint("AlphaPlayer Play Error: $e");
      // 出错时触发结束，防止队列卡死
      onFinish?.call();
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _channel?.invokeMethod('stop');
    } catch (e) {
      print("AlphaPlayer Stop Error: $e");
    }
  }

  // 🟢 新增：销毁方法
  void dispose() {
    _isDisposed = true;
    _channel?.setMethodCallHandler(null); // 断开监听
    _channel = null;
    onFinish = null;
    onVideoSize = null;
    onError = null;
  }
}

class MyAlphaPlayerView extends StatefulWidget {
  final void Function(MyAlphaPlayerController controller)? onCreated;

  // 🟢 强烈建议：在使用此组件时，必须传入一个 GlobalKey 或者 ValueKey
  // 否则父组件 setState 时，View 会被销毁重建，导致上一条特效中断！
  const MyAlphaPlayerView({Key? key, this.onCreated}) : super(key: key);

  @override
  State<MyAlphaPlayerView> createState() => _MyAlphaPlayerViewState();
}

class _MyAlphaPlayerViewState extends State<MyAlphaPlayerView> {
  // 🟢 持有 Controller 的引用，以便在 dispose 时清理
  MyAlphaPlayerController? _controller;

  @override
  Widget build(BuildContext context) {
    const String viewType = 'com.example.live/alpha_player';

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
        // 🟢 优化：避免重复创建，这在列表或频繁刷新页面中很重要
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      );
    } else if (Platform.isIOS) {
      // 👇👇👇 新增 iOS 支持 👇👇👇
      return UiKitView(
        viewType: viewType, // 使用同一个 ID
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
        // 如果需要传递初始参数（例如为了预加载），可以在这里传
        // creationParams: {"url": "xxx"},
      );
    }

    return const Center(child: Text("不支持的平台"));
  }

  void _onPlatformViewCreated(int id) {
    // 创建新的 Controller
    final controller = MyAlphaPlayerController();
    _controller = controller; // 🟢 保存引用
    controller.bind(id);

    if (widget.onCreated != null) {
      widget.onCreated!(controller);
    }
  }

  @override
  void dispose() {
    // 🟢 页面销毁时，强制停止播放并清理 Controller
    // 这能防止后台播放，或者回调空指针
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }
}