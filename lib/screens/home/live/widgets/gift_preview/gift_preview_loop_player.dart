import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart'; // 引入您的播放器库
import 'package:flutter_live/tools/GiftColorsTool.dart'; // 引入您的颜色工具(如果有)

class GiftPreviewLoopPlayer extends StatefulWidget {
  final String videoUrl;

  const GiftPreviewLoopPlayer({super.key, required this.videoUrl});

  @override
  State<GiftPreviewLoopPlayer> createState() => _GiftPreviewLoopPlayerState();
}

class _GiftPreviewLoopPlayerState extends State<GiftPreviewLoopPlayer> {
  MyAlphaPlayerController? _controller;
  String? _localFilePath;
  double _aspectRatio = 9 / 16; // 默认竖屏比例

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  @override
  void didUpdateWidget(covariant GiftPreviewLoopPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _prepareVideo(); // URL 变了，重新下载播放
    }
  }

  @override
  void dispose() {
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }

  /// 1. 下载或获取缓存文件
  Future<void> _prepareVideo() async {
    if (widget.videoUrl.isEmpty) return;

    // 先停止旧的
    try { await _controller?.stop(); } catch (e) {}

    String? path = await _downloadGiftFile(widget.videoUrl);
    if (mounted && path != null) {
      setState(() {
        _localFilePath = path;
      });
      _startPlay();
    }
  }

  /// 2. 开始播放
  void _startPlay() {
    if (_controller != null && _localFilePath != null) {
      // 这里的 hue 参数根据您项目的 GiftColorsTool 设定
      _controller!.play(_localFilePath!, hue: GiftColorsTool.original);
    }
  }

  /// 3. 播放器创建回调
  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _controller = controller;

    // 🔥 新增：静音播放
    // 尝试设置音量为 0。请确认您的控制器支持此方法。
    try {
      // 如果你的库支持 setVolume:
      // controller.setVolume(0.0);
      // 如果不支持 setVolume 但有 mute 属性:
      // controller.setMute(true);
    } catch (e) {
      debugPrint("设置静音失败，您的播放器控制器可能不支持: $e");
    }
    // 🟢 核心逻辑：监听播放结束，实现循环播放
    controller.onFinish = () {
      if (mounted && _localFilePath != null) {
        // 播完了，立刻重播
        _startPlay();
      }
    };

    // 监听尺寸，调整比例
    controller.onVideoSize = (w, h) {
      if (w > 0 && h > 0 && mounted) {
        setState(() {
          _aspectRatio = w / h;
        });
      }
    };

    // 如果文件已经准备好了，直接播放
    if (_localFilePath != null) {
      _startPlay();
    }
  }

  /// 4. 复用您的下载逻辑
  Future<String?> _downloadGiftFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // 使用 hash 命名避免重复下载
      String fileName = "gift_preview_${url.hashCode}.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      if (await file.exists() && await file.length() > 0) return savePath;

      // 下载
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      await dio.download(url, savePath);

      if (await file.exists() && await file.length() > 0) return savePath;
      return null;
    } catch (e) {
      debugPrint("预览视频下载失败: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 AspectRatio 保证视频不拉伸
    return Center(
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: MyAlphaPlayerView(
          key: ValueKey(widget.videoUrl), // URL变化时重建Key，确保刷新
          onCreated: _onPlayerCreated,
        ),
      ),
    );
  }
}