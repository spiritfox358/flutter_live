import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart'; // 🟢 使用 just_audio

class AIMusicService {
  static final AIMusicService _instance = AIMusicService._internal();
  factory AIMusicService() => _instance;
  AIMusicService._internal();

  final AudioPlayer _player = AudioPlayer(); // 🟢 just_audio 实例
  bool _isPlaying = false;

  // 模拟歌单
  final List<String> _musicLibrary = [
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/music/%E3%80%90rap%E3%80%91%E6%88%91%E7%9A%84%E5%86%9C%E8%8D%AF%E5%B1%85%E7%84%B6%E8%BF%99%E4%B9%88%E5%B8%A6%E6%84%9F%EF%BC%9F%E7%99%BD%E8%A1%A3%E8%A2%82%E9%A3%9E%E6%89%AC.aac",
    "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/music/%E6%AC%A0%E4%BD%A0%E4%B8%80%E4%B8%AA%E5%A4%A9%E4%B8%8B-%E6%9D%8E%E5%93%88%E5%93%88.aac",
  ];

  /// 🟢 播放战歌
  Future<void> playRandomBattleMusic() async {
    // 如果已经在播放，先停止旧的再放新的，或者直接返回
    // 这里选择先强制停止，确保状态重置
    await stopMusic();

    try {
      final String url = await _fetchRandomMusicUrl();
      debugPrint("🎵 AI 正在播放战歌 (just_audio): $url");

      // 1. 先加载资源
      await _player.setUrl(url);
      await _player.setLoopMode(LoopMode.one); // 单曲循环

      // 2. 🟢 关键修改：在 play 之前就标记为 true！
      // 因为 _player.play() 在循环模式下会阻塞，导致后面的代码执行不到
      _isPlaying = true;

      // 3. 开始播放 (不使用 await，或者捕获它，防止阻塞)
      _player.play();

    } catch (e) {
      debugPrint("❌ 音乐播放失败: $e");
      _isPlaying = false;
    }
  }

  /// 🔴 停止播放
  Future<void> stopMusic() async {
    // 🟢 关键修改：删除 (!isPlaying) 的判断！
    // 因为状态可能会乱，我们要“宁可错杀，不可放过”，强制调用 stop
    debugPrint("🛑 强制停止战歌");

    try {
      await _player.stop();
    } catch (e) {
      debugPrint("停止异常(忽略): $e");
    }

    _isPlaying = false;
  }

  // 预留接口：获取随机音乐 URL
  Future<String> _fetchRandomMusicUrl() async {
    // 模拟网络延迟
    // await Future.delayed(const Duration(milliseconds: 100));
    final random = Random();
    return _musicLibrary[random.nextInt(_musicLibrary.length)];
  }
}