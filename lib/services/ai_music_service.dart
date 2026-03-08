import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AIMusicService {
  static final AIMusicService _instance = AIMusicService._internal();
  factory AIMusicService() => _instance;
  AIMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentUrl;

  // 🟢 新增：记录当前拥有播放器主权的房间号
  String? _currentRoomId;

  DateTime _aiSpeakingEndTime = DateTime.now();
  Timer? _bgmDuckTimer;

  static const double _normalVolume = 0.27;
  static const double _duckVolume = 0.05;

  /// 🎵 1. 同步并播放 BGM (加入 roomId 主权宣告)
  Future<void> syncAndPlayBgm(String roomId, String bgmUrl, int serverStartTimeMs) async {
    _currentRoomId = roomId; // 🟢 宣誓主权！
    try {
      int nowMs = DateTime.now().millisecondsSinceEpoch;
      int elapsedMs = nowMs - serverStartTimeMs;
      if (elapsedMs < 0) elapsedMs = 0;

      await _player.setLoopMode(LoopMode.one);

      bool isAiSpeaking = _aiSpeakingEndTime.isAfter(DateTime.now());
      await _player.setVolume(isAiSpeaking ? _duckVolume : _normalVolume);

      await _player.setUrl(bgmUrl);
      await _player.seek(Duration(milliseconds: elapsedMs));
      _player.play();

      _isPlaying = true;
      _currentUrl = bgmUrl;

      debugPrint("🎵 BGM 同步播放成功，当前归属房间: $_currentRoomId");
    } catch (e) {
      debugPrint("❌ BGM 播放失败: $e");
      _isPlaying = false;
      _currentUrl = null;
    }
  }

  /// 🔈 2. 核心闪避算法
  void duckFor(String roomId, int durationMs) {
    if (!_isPlaying || _currentRoomId != roomId) return; // 🟢 防误操作

    DateTime now = DateTime.now();
    if (_aiSpeakingEndTime.isBefore(now)) {
      _aiSpeakingEndTime = now.add(Duration(milliseconds: durationMs));
    } else {
      _aiSpeakingEndTime = _aiSpeakingEndTime.add(Duration(milliseconds: durationMs));
    }

    _player.setVolume(_duckVolume);

    _bgmDuckTimer?.cancel();
    int waitMs = _aiSpeakingEndTime.difference(now).inMilliseconds + 500;

    _bgmDuckTimer = Timer(Duration(milliseconds: waitMs), () {
      _player.setVolume(_normalVolume);
    });
  }

  /// 🔊 3. 瞬间恢复 100% 音量
  void restoreVolumeNow(String roomId) {
    if (_currentRoomId != roomId) return; // 🟢 防误操作
    _aiSpeakingEndTime = DateTime.now();
    _bgmDuckTimer?.cancel();
    _player.setVolume(_normalVolume);
  }

  /// 🛑 4. 停止播放 (核心拦截逻辑)
  Future<void> stopMusic(String roomId) async {
    // 🟢 所有权校验：如果你不是当前房间，说明你已经被别人顶掉了，旧房间无权停止新房间的音乐！
    if (_currentRoomId != null && _currentRoomId != roomId) {
      debugPrint("⚠️ 拦截误杀: 房间 $roomId 试图关闭 BGM，但当前主权属于 $_currentRoomId");
      return;
    }

    try {
      await _player.stop();
    } catch (e) {}
    _isPlaying = false;
    _currentUrl = null;
    _currentRoomId = null; // 释放主权
    _bgmDuckTimer?.cancel();
  }
}