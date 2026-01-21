import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyAlphaPlayerController {
  MethodChannel? _channel;

  VoidCallback? onFinish;
  Function(double width, double height)? onVideoSize;

  void bind(int viewId) {
    _channel = MethodChannel('com.example.live/alpha_player_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == "onPlayFinished") {
        onFinish?.call();
      }
      // 🟢 修复点：正确解析原生传来的 Map 参数
      else if (call.method == "onVideoSize") {
        final args = call.arguments;
        if (args is Map) {
          final width = args['width'];
          final height = args['height'];
          if (width != null && height != null) {
            // 安全转换为 double
            onVideoSize?.call((width as num).toDouble(), (height as num).toDouble());
          }
        }
      }
    });
  }

  Future<void> play(String url) async {
    await _channel?.invokeMethod('play', {"url": url});
  }

  Future<void> stop() async {
    await _channel?.invokeMethod('stop');
  }
}

class MyAlphaPlayerView extends StatefulWidget {
  final void Function(MyAlphaPlayerController controller)? onCreated;

  const MyAlphaPlayerView({Key? key, this.onCreated}) : super(key: key);

  @override
  State<MyAlphaPlayerView> createState() => _MyAlphaPlayerViewState();
}

class _MyAlphaPlayerViewState extends State<MyAlphaPlayerView> {
  @override
  Widget build(BuildContext context) {
    const String viewType = 'com.example.live/alpha_player';

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const Center(child: Text("IOS 暂未实现"));
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onCreated != null) {
      final controller = MyAlphaPlayerController();
      controller.bind(id);
      widget.onCreated!(controller);
    }
  }
}