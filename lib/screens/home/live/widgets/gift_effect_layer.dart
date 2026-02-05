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

    // 如果初始化时队列里已经有东西了，立即播放
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

    // 停止上一个（如果有）
    try {
      await _alphaPlayerController?.stop();
    } catch (e) {}

    // ⚠️ 注意：此处不启动看门狗，因为下载时间不确定
    // 下载的超时控制全权交给 _downloadGiftFile 中的 Dio

    try {
      // 1. 下载文件
      debugPrint("⏳ 开始下载特效资源: $url");
      String? localPath = await _downloadGiftFile(url);

      // 下载失败处理
      if (localPath == null || !mounted) {
        debugPrint("❌ 下载失败或页面已销毁，跳过");
        _onEffectComplete();
        return;
      }

      // 文件有效性双重检查
      final file = File(localPath);
      if (!await file.exists() || await file.length() == 0) {
        debugPrint("❌ 文件无效或大小为0，跳过");
        _onEffectComplete();
        return;
      }

      // 2. 开始播放
      if (mounted && _alphaPlayerController != null) {
        debugPrint("▶️ 下载完成，开始播放: $localPath");

        // ✨ 关键优化：只有真正开始播放时，才启动看门狗
        // 10秒后如果还没播完（或者卡死），强制结束
        _startWatchdog(18);

        await _alphaPlayerController!.play(localPath);
      } else {
        _onEffectComplete();
      }
    } catch (e) {
      debugPrint("❌ 特效播放流程异常: $e");
      _onEffectComplete();
    }
  }

  /// 播放完成/结束/异常处理
  void _onEffectComplete() {
    if (!mounted) return;

    _effectWatchdog?.cancel(); // 关狗

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
      debugPrint("🐶 特效看门狗介入：播放超时或卡死，强制切歌");
      _onEffectComplete();
    });
  }

  /// 下载文件 (智能超时版)
  Future<String?> _downloadGiftFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      // 🟢 优化 1: 使用 Hash 生成文件名
      // 避免 URL 过长或包含特殊字符导致文件名非法
      String fileName = "gift_${url.hashCode}.mp4";

      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      // 命中有效缓存（存在且不为空）
      if (await file.exists() && await file.length() > 0) {
        debugPrint("✅ 命中缓存: $savePath");
        return savePath;
      }

      // 删除旧的无效文件
      if (await file.exists()) await file.delete();

      // 🟢 优化 2: 配置 Dio 智能超时
      final dio = Dio(BaseOptions(
        // 连接超时：连不上服务器（5秒报错）
        connectTimeout: const Duration(seconds: 5),
        // 接收超时：连上了但对方不发数据了（10秒没动静报错）
        // 只要数据还在传输（哪怕只有 1kb/s），就不会触发这个超时，适合大文件！
        receiveTimeout: const Duration(seconds: 10),
      ));

      await dio.download(url, savePath);

      // 🟢 优化 3: 下载后校验
      if (await file.exists() && await file.length() > 0) {
        debugPrint("✅ 下载成功 (大小: ${await file.length()} bytes)");
        return savePath;
      } else {
        debugPrint("❌ 下载显示成功但文件为空");
        return null;
      }

    } catch (e) {
      debugPrint("❌ 下载报错: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      // 播放时是否阻挡点击？
      // true: 点击穿透（不挡下面的礼物按钮）
      // false: 拦截点击
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