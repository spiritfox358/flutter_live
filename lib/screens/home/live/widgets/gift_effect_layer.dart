import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';

/// 🎁 独立的礼物特效播放层
/// 包含：下载、队列管理、播放控制、看门狗保护、UI适配
class GiftEffectLayer extends StatefulWidget {
  const GiftEffectLayer({super.key});

  @override
  State<GiftEffectLayer> createState() => GiftEffectLayerState();
}

class GiftEffectLayerState extends State<GiftEffectLayer> {
  MyAlphaPlayerController? _alphaPlayerController;

  // 特效队列
  final Queue<String> _effectQueue = Queue();

  // 播放状态
  bool _isEffectPlaying = false;

  // 视频比例 (默认为竖屏 9:16，加载后会自动更新)
  double _videoAspectRatio = 9 / 16;

  // 看门狗 (防止播放卡死)
  Timer? _effectWatchdog;

  @override
  void dispose() {
    _effectWatchdog?.cancel();
    _alphaPlayerController?.dispose();
    super.dispose();
  }

  /// 🟢 [外部调用] 添加特效到队列
  void addEffect(String url) {
    _effectQueue.add(url);
    debugPrint("➕ 特效加入队列: $url, 当前队列长度: ${_effectQueue.length}");

    // 如果当前空闲，立即播放
    if (!_isEffectPlaying) {
      _playNextEffect();
    }
  }

  /// 初始化播放器回调
  void _onPlayerCreated(MyAlphaPlayerController controller) {
    debugPrint("✅ 特效播放器就绪");
    _alphaPlayerController = controller;

    // 监听播放结束
    _alphaPlayerController?.onFinish = _onEffectComplete;

    // 监听视频尺寸，自动调整比例
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        setState(() => _videoAspectRatio = width / height);
      }
    };

    // 如果初始化时队列里已经有东西了（比如进房瞬间收礼），立即播放
    if (_effectQueue.isNotEmpty && !_isEffectPlaying) {
      _playNextEffect();
    }
  }

  /// 播放下一个
  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty) return;
    if (_isEffectPlaying && _alphaPlayerController != null) return;

    final url = _effectQueue.removeFirst();
    setState(() => _isEffectPlaying = true);

    // 停止上一个
    try {
      await _alphaPlayerController?.stop();
    } catch (e) {}

    // 启动看门狗 (15秒后强制结束，防止下载卡死或播放回调丢失)
    _startWatchdog(15);

    try {
      // 1. 下载文件
      String? localPath = await _downloadGiftFile(url).timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );

      if (localPath == null || !mounted) {
        debugPrint("❌ 特效文件下载失败，跳过");
        _onEffectComplete();
        return;
      }

      // 2. 开始播放
      if (mounted && _alphaPlayerController != null) {
        debugPrint("▶️ 开始播放特效: $localPath");
        await _alphaPlayerController!.play(localPath);
      } else {
        _onEffectComplete();
      }
    } catch (e) {
      debugPrint("❌ 特效播放异常: $e");
      _onEffectComplete();
    }
  }

  /// 播放完成/结束/异常处理
  void _onEffectComplete() {
    if (!mounted) return;

    _effectWatchdog?.cancel();

    // 稍微延迟重置状态，避免UI闪烁
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _isEffectPlaying = false);
        // 递归播放下一个
        _playNextEffect();
      }
    });
  }

  /// 启动看门狗
  void _startWatchdog(int seconds) {
    _effectWatchdog?.cancel();
    _effectWatchdog = Timer(Duration(seconds: seconds), () {
      debugPrint("🐶 特效看门狗介入：强制切歌");
      _onEffectComplete();
    });
  }

  /// 下载文件
  Future<String?> _downloadGiftFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last; // 简单取文件名，建议加MD5防止重名
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      // 有缓存直接用
      if (await file.exists()) return savePath;

      // 没缓存去下载
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      // 只有在播放时才阻挡点击（如果需要特效穿透点击，这里一直设为 true 即可，或者去掉 IgnorePointer）
      // 通常特效层是完全穿透的，所以这里设为 true 比较好，防止挡住下面的礼物连击按钮
      ignoring: true,
      child: Opacity(
        // 没播放时完全隐藏
        opacity: _isEffectPlaying ? 1.0 : 0.0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: size.width,
            // 根据视频比例动态计算高度，保持不拉伸
            height: size.width / _videoAspectRatio,
            child: MyAlphaPlayerView(
              key: const ValueKey('AlphaPlayer'),
              onCreated: _onPlayerCreated,
            ),
          ),
        ),
      ),
    );
  }
}