import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_live/tools/GiftColorsTool.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:vibration/vibration.dart';

/// 1. 定义震动时间点模型 (适配后端 JSON)
class VibrationPoint {
  final double time; // 触发时间 (秒), 对应数据库 "time"
  final int duration; // 震动时长 (毫秒), 对应数据库 "duration"
  final int level; // 震动强度 (1-255), 对应数据库 "level"

  VibrationPoint({
    required this.time,
    required this.duration,
    this.level = 255, // 默认满强度
  });

  // 🏭 工厂方法：把后端传来的 Map 转成对象
  factory VibrationPoint.fromJson(Map<String, dynamic> json) {
    return VibrationPoint(
      // 使用 as num? 防止直接 crash，并给默认值 0
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 255,
    );
  }
}

/// 2. 礼物任务模型
class GiftTask {
  final String url;
  final String giftId;

  // 新增：携带震动配置列表
  final List<VibrationPoint> vibrations;

  GiftTask(this.url, this.giftId, {this.vibrations = const []});
}

class GiftEffectLayer extends StatefulWidget {
  const GiftEffectLayer({super.key});

  @override
  State<GiftEffectLayer> createState() => GiftEffectLayerState();
}

class GiftEffectLayerState extends State<GiftEffectLayer> {
  MyAlphaPlayerController? _alphaPlayerController;
  final Queue<GiftTask> _effectQueue = Queue();

  bool _isEffectPlaying = false;
  double _videoAspectRatio = 9 / 16;
  Timer? _effectWatchdog;

  // 🔴 核心新增：管理所有的震动定时器，用于随时取消
  final List<Timer> _activeVibrationTimers = [];

  @override
  void dispose() {
    _cancelVibrations(); // 销毁组件时，必须清理所有震动
    _effectWatchdog?.cancel();
    _alphaPlayerController?.dispose();
    super.dispose();
  }

  /// 🟢 [外部调用] 添加特效
  /// configJsonList: 从后端接口拿到的 vibration_config 字段 (List<dynamic>)
  /// 🟢 [外部调用] 添加特效
  void addEffect(String url, String giftId, List<dynamic>? configJsonList) {
    // 1. 解析后端数据 (保持原样)
    List<VibrationPoint> parsedVibrations = [];
    if (configJsonList != null && configJsonList.isNotEmpty) {
      try {
        parsedVibrations = configJsonList.map((e) => VibrationPoint.fromJson(e)).toList();
      } catch (e) {
        debugPrint("❌ 震动配置解析失败: $e");
      }
    }

    // 2. 存入队列
    _effectQueue.add(GiftTask(url, giftId, vibrations: parsedVibrations));
    debugPrint("➕ 特效加入队列: $url");

    // 🟢 修复点：使用 addPostFrameCallback 避开 "during build" 错误
    // 只有当控制器存在且当前没在播放时，才尝试播放
    if (!_isEffectPlaying && _alphaPlayerController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 再次检查 mounted，防止异步执行时组件已销毁
        if (mounted) {
          _playNextEffect();
        }
      });
    }
  }

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaPlayerController = controller;
    _alphaPlayerController?.onFinish = _onEffectComplete;
    _alphaPlayerController?.onVideoSize = (width, height) {
      if (width > 0 && height > 0 && mounted) {
        setState(() => _videoAspectRatio = width / height);
      }
    };
    if (_effectQueue.isNotEmpty && !_isEffectPlaying) {
      _playNextEffect();
    }
  }

  Future<void> _playNextEffect() async {
    if (_effectQueue.isEmpty) return;

    // 1. 基础校验
    if (_isEffectPlaying && _alphaPlayerController != null) return;
    if (_alphaPlayerController == null) {
      debugPrint("⚠️ [Effect] 播放器未就绪，暂停处理队列");
      return;
    }

    debugPrint("🎬 [Effect] 准备播放下一条，剩余队列: ${_effectQueue.length}");

    try {
      final task = _effectQueue.removeFirst();

      // 2. 更新状态
      setState(() => _isEffectPlaying = true);
      debugPrint("✅ [Effect] 状态已更新为 Playing");

      // 3. 安全清理旧震动 (防止这里崩溃卡死)
      try {
        _cancelVibrations();
        debugPrint("✅ [Effect] 旧震动已清理");
      } catch (e) {
        debugPrint("❌ [Effect] 清理震动出错(不影响播放): $e");
      }

      // 4. 停止上一个视频
      try {
        await _alphaPlayerController?.stop();
        debugPrint("✅ [Effect] 上个视频已Stop");
      } catch (e) {
        debugPrint("⚠️ [Effect] Stop异常: $e");
      }

      String playPath = task.url;
      debugPrint("⬇️ [Effect] 准备处理资源: $playPath");

      // 5. 下载逻辑 (App端)
      if (!kIsWeb) {
        try {
          // 这里的 _downloadGiftFile 内部必须有 try-catch，否则会崩在这里
          String? localPath = await _downloadGiftFile(task.url);

          if (localPath == null || !mounted) {
            debugPrint("❌ [Effect] 下载失败或页面已销毁，跳过");
            _onEffectComplete();
            return;
          }
          playPath = localPath;
          debugPrint("✅ [Effect] 下载完成: $playPath");
        } catch (e) {
          debugPrint("❌ [Effect] 下载过程严重崩溃: $e");
          _onEffectComplete();
          return;
        }
      }

      // 6. 开始播放
      if (mounted && _alphaPlayerController != null) {
        // 设置震动定时器
        if (task.vibrations.isNotEmpty) {
          _scheduleVibrations(task.vibrations);
        }

        // 启动看门狗（防止视频播完不回调导致卡死）
        _startWatchdog(45);

        debugPrint("▶️ [Effect] 调用底层 play()");
        await _alphaPlayerController!.play(playPath, hue: GiftColorsTool.original);
      } else {
        _onEffectComplete();
      }
    } catch (e, stack) {
      // 捕获所有未知的逻辑错误，防止队列卡死
      debugPrint("❌ [Effect] _playNextEffect 发生致命错误: $e\n$stack");
      // 遇到错误必须重置状态，否则队列永远不会继续
      if (mounted) {
        setState(() => _isEffectPlaying = false);
      }
      // 尝试播下一个，避免死锁
      Future.delayed(const Duration(milliseconds: 500), _playNextEffect);
    }
  }

  /// ⏰ 核心调度逻辑：根据时间点设置定时器
  void _scheduleVibrations(List<VibrationPoint> timeline) {
    if (kIsWeb) return;
    // 双重保险：先清理
    _cancelVibrations();

    for (var point in timeline) {
      // 计算延迟毫秒数 (例如 1.5秒 -> 1500毫秒)
      final int delayMs = (point.time * 1000).toInt();

      Timer timer = Timer(Duration(milliseconds: delayMs), () async {
        // 触发时再次检查：必须还在播放状态，且组件还在树上
        if (_isEffectPlaying && mounted) {
          if (await Vibration.hasVibrator() ?? false) {
            debugPrint("📳 [${point.time}s] 触发震动，持续: ${point.duration}ms");
            // 这里 amplitude: 255 是最大强度 (1-255)
            Vibration.vibrate(duration: point.duration, amplitude: point.level);
          }
        }
      });

      // 加入管理列表，方便随时 kill
      _activeVibrationTimers.add(timer);
    }
  }

  /// 🛑 熔断机制：取消所有未触发的震动
  void _cancelVibrations() {
    if (_activeVibrationTimers.isNotEmpty) {
      // debugPrint("🛑 清理剩余 ${_activeVibrationTimers.length} 个未执行的震动任务");
      for (var timer in _activeVibrationTimers) {
        timer.cancel();
      }
      _activeVibrationTimers.clear();
    }
    if (!kIsWeb) {
      try {
        // 同时也停止当前正在震的马达（防止震到一半视频停了，手机还在震）
        Vibration.cancel();
      } catch (e) {
        // 忽略错误
      }
    }
  }

  void _onEffectComplete() {
    if (!mounted) return;
    _effectWatchdog?.cancel();

    // 播放结束，立即停止所有震动逻辑
    _cancelVibrations();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _isEffectPlaying = false);
        _playNextEffect();
      }
    });
  }

  void _startWatchdog(int seconds) {
    _effectWatchdog?.cancel();
    _effectWatchdog = Timer(Duration(seconds: seconds), () {
      _onEffectComplete();
    });
  }

  Future<String?> _downloadGiftFile(String url) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();

      // 🟢 修复 1：绝对不能用 url.hashCode！改用 base64Url 编码保证路径持久唯一
      String safeName = base64Url.encode(utf8.encode(url));
      // 防文件名过长导致文件系统报错，截取后50位
      if (safeName.length > 50) safeName = safeName.substring(safeName.length - 50);

      String fileName = "gift_$safeName.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      // 如果文件完整存在，且大于 1KB (防止空壳文件)，直接极速返回
      if (await file.exists() && await file.length() > 1000) {
        return savePath;
      }

      // 🟢 修复 2：原子下载法。先下载到 .tmp 临时文件
      final tempPath = "$savePath.tmp";
      final tempFile = File(tempPath);

      // 清理残留的损坏临时文件
      if (await tempFile.exists()) await tempFile.delete();

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds:30),
          receiveTimeout: const Duration(seconds: 180), // 放宽一点接收时间
        ),
      );

      await dio.download(url, tempPath);

      // 🟢 修复 3：下载彻底成功后，再重命名为正式的 .mp4 文件
      // 这样 AVPlayer 只要读到 .mp4，就保证它 100% 是完整健康的，绝不会死锁！
      if (await tempFile.exists() && await tempFile.length() > 1000) {
        await tempFile.rename(savePath);
        return savePath;
      }

      return null;
    } catch (e) {
      debugPrint("❌ [Effect] 礼物下载异常: $e");
      // 清理可能下载失败的半截临时文件
      try {
        final tempFile = File("${(await getApplicationDocumentsDirectory()).path}/gift_${base64Url.encode(utf8.encode(url))}.mp4.tmp");
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      ignoring: true,
      child: Opacity(
        opacity: _isEffectPlaying ? 1.0 : 0.0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: size.width,
            height: size.width / _videoAspectRatio,
            child: MyAlphaPlayerView(key: const ValueKey('GiftAlphaPlayer_Key'), onCreated: _onPlayerCreated),
          ),
        ),
      ),
    );
  }
}
