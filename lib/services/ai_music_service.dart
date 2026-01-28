import 'dart:async';
import 'dart:math'; // 🟢 引入数学库用于随机
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../tools/HttpUtil.dart';

class AIMusicService {
  static final AIMusicService _instance = AIMusicService._internal();
  factory AIMusicService() => _instance;
  AIMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentUrl;

  /// 🟢 随机播放全站音乐 (不再需要 roomId)
  Future<void> playRandomBgm() async {
    // 1. 获取全站 BGM 列表
    List<dynamic> musicList = await _fetchAllBgm();

    if (musicList.isEmpty) {
      debugPrint("🎵 曲库为空，无法播放");
      await stopMusic();
      return;
    }

    // 2. 🟢 随机挑选一首
    final random = Random();
    final randomMusic = musicList[random.nextInt(musicList.length)];
    final String musicUrl = randomMusic['url'];
    final String musicName = randomMusic['name'] ?? "未知歌曲";

    // 3. 如果随机到的刚好是正在放的，就不打断了 (可选逻辑)
    if (_isPlaying && _currentUrl == musicUrl) {
      return;
    }

    // 4. 播放流程
    await stopMusic();

    try {
      debugPrint("🎵 随机命中 BGM: $musicName ($musicUrl)");
      _currentUrl = musicUrl;

      await _player.setUrl(musicUrl);
      await _player.setLoopMode(LoopMode.one); // 单曲循环当前随机到的这首
      // 如果你想放完这首自动随机下一首，需要监听 player.playerStateStream

      _isPlaying = true;
      _player.play();

    } catch (e) {
      debugPrint("❌ BGM 播放失败: $e");
      _isPlaying = false;
      _currentUrl = null;
    }
  }

  /// 🔴 停止播放
  Future<void> stopMusic() async {
    // ... 保持不变 ...
    try {
      await _player.stop();
    } catch (e) {}
    _isPlaying = false;
  }

  /// 🟡 调用接口获取所有音乐
  Future<List<dynamic>> _fetchAllBgm() async {
    try {
      // 🟢 调用后端: /api/bgm/list (不传参数即查所有)
      final res = await HttpUtil().get("/api/bgm/list");

      if (res != null && res is List) {
        // 简单的过滤：必须有 url 才能播
        return res.where((m) => m['url'] != null && m['url'].toString().isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint("❌ 获取全站 BGM 列表失败: $e");
    }
    return [];
  }
}