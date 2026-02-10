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
      time: (json['time'] as num).toDouble(),
      duration: (json['duration'] as num).toInt(),
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
  void addEffect(String url, String giftId, List<dynamic>? configJsonList) {
    // 1. 解析后端数据
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

    debugPrint("➕ 特效加入: $url (含 ${parsedVibrations.length} 个震动点)");

    if (!_isEffectPlaying) {
      _playNextEffect();
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
    if (_isEffectPlaying && _alphaPlayerController != null) return;

    final task = _effectQueue.removeFirst();
    setState(() => _isEffectPlaying = true);

    // 播放新视频前，清理上一场的残留震动
    _cancelVibrations();

    try {
      await _alphaPlayerController?.stop();
    } catch (e) {}

    try {
      String playPath = task.url;

      // 🟢 核心修改：如果是 Web，直接播放网络地址；如果是 App，才去下载
      if (!kIsWeb) {
        debugPrint("⏳ (App) 开始下载: ${task.url}");
        String? localPath = await _downloadGiftFile(task.url);
        if (localPath == null || !mounted) {
          _onEffectComplete();
          return;
        }
        playPath = localPath;
      } else {
        debugPrint("🌐 (Web) 直接播放网络地址: ${task.url}");
      }

      if (mounted && _alphaPlayerController != null) {
        debugPrint("▶️ 开始播放: $playPath (ID: ${task.giftId})");

        if (task.vibrations.isNotEmpty) {
          _scheduleVibrations(task.vibrations);
        }

        _startWatchdog(20);
        await _alphaPlayerController!.play(playPath, hue: GiftColorsTool.original);
      } else {
        _onEffectComplete();
      }
    } catch (e) {
      debugPrint("❌ 播放异常: $e");
      _onEffectComplete();
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
      String fileName = "gift_${url.hashCode}.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      if (await file.exists() && await file.length() > 0) return savePath;
      if (await file.exists()) await file.delete();

      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 10)));
      await dio.download(url, savePath);

      if (await file.exists() && await file.length() > 0) return savePath;
      return null;
    } catch (e) {
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
            child: MyAlphaPlayerView(key: const ValueKey('AlphaPlayer'), onCreated: _onPlayerCreated),
          ),
        ),
      ),
    );
  }
}
