import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:vibration/vibration.dart';

/// 1. 定义震动时间点模型
class VibrationPoint {
  final double time; // 在第几秒触发
  final int duration; // 震动持续时长 (毫秒)
  VibrationPoint(this.time, this.duration);
}

/// 2. 礼物任务模型
class GiftTask {
  final String url;
  final String giftId; // 礼物ID，用于匹配震动配置

  GiftTask(this.url, this.giftId);
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
  /// 例如：addEffect("http://...", 32);
  void addEffect(String url, String giftId) {
    _effectQueue.add(GiftTask(url, giftId));
    debugPrint("➕ 特效加入: $url (ID: $giftId)");

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
      debugPrint("⏳ 开始下载: ${task.url}");
      String? localPath = await _downloadGiftFile(task.url);

      if (localPath == null || !mounted) {
        _onEffectComplete();
        return;
      }

      if (mounted && _alphaPlayerController != null) {
        debugPrint("▶️ 开始播放: $localPath (ID: ${task.giftId})");

        // =========================================================
        // 📳 前端模拟配置中心 (Hardcode Mock)
        // =========================================================
        List<VibrationPoint> vibrations = [];

        // 👉 针对 ID=32 的礼物，配置特殊的震动剧本
        if (task.giftId == 32.toString()) {
          debugPrint("⚡️ 命中 ID=32 特效配置，准备震动！");
          vibrations = [
            VibrationPoint(1.5, 1000), // 第1.5秒，震1秒
            VibrationPoint(4.3, 1000), // 第5.0秒，震1秒
            VibrationPoint(6.5, 600), // 第8.0秒，震1秒
          ];
        }
        // 你也可以加其他 ID 的配置
        else if (task.giftId == 666) {
          vibrations = [VibrationPoint(0.1, 500)]; // 简单震一下
        }

        // 启动震动调度器
        if (vibrations.isNotEmpty) {
          _scheduleVibrations(vibrations);
        }
        // =========================================================

        _startWatchdog(20);
        await _alphaPlayerController!.play(localPath);
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
            Vibration.vibrate(duration: point.duration, amplitude: 255);
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
    // 同时也停止当前正在震的马达（防止震到一半视频停了，手机还在震）
    Vibration.cancel();
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
    try {
      final dir = await getApplicationDocumentsDirectory();
      String fileName = "gift_${url.hashCode}.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      if (await file.exists() && await file.length() > 0) return savePath;
      if (await file.exists()) await file.delete();

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ));
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