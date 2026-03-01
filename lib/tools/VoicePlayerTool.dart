import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 全局 TTS 语音播放服务 (单例模式 + 队列管理)
class VoicePlayerTool {
  // 1. 单例模式实现
  static final VoicePlayerTool _instance = VoicePlayerTool._internal();
  factory VoicePlayerTool() => _instance;
  VoicePlayerTool._internal() {
    _initPlayer();
  }

  final AudioPlayer _player = AudioPlayer();
  final Queue<Map<String, String>> _audioQueue = Queue();

  bool _isPlayingProcess = false;

  // 2. 状态监听回调（可选，供外部监听当前是否正在说话、以及说的内容）
  // 外部可以使用 ValueNotifier 来动态更新 UI (比如头像跳动、字幕显示)
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentSubtitle = ValueNotifier<String>("");

  void _initPlayer() {
    // 监听播放器状态：播放结束 -> 停止动画 -> 尝试播下一首
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onPlayFinished();
      }
    });
  }

  void _onPlayFinished() {
    isSpeaking.value = false;
    currentSubtitle.value = "";
    _isPlayingProcess = false; // 释放锁
    _playNext(); // 自动检查并播放下一句
  }

  /// 🟢 核心入口：将 Base64 语音加入队列并尝试播放
  /// [audioBase64] 后端传来的音频 Base64 字符串
  /// [text] 对应的字幕文本 (可选)
  void playBase64Audio(String? audioBase64, {String? text}) {
    if (audioBase64 == null || audioBase64.isEmpty) return;

    // 1. 加入队列
    _audioQueue.add({
      'audio': audioBase64,
      'text': text ?? '',
    });

    // 2. 如果当前空闲，立即启动播放引擎
    if (!_isPlayingProcess && !isSpeaking.value) {
      _playNext();
    }
  }

  /// 内部方法：处理队列播放
  Future<void> _playNext() async {
    if (_audioQueue.isEmpty) {
      _isPlayingProcess = false;
      return;
    }

    _isPlayingProcess = true; // 上锁
    final item = _audioQueue.removeFirst(); // 取出最早的一条
    final base64String = item['audio']!;
    final text = item['text']!;

    try {
      // 触发 UI 更新
      isSpeaking.value = true;
      currentSubtitle.value = text;

      // 1. 解码 Base64
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      // 去除可能导致解码失败的空白符和换行
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

      Uint8List audioBytes = base64Decode(cleanBase64);

      // 2. 写入临时文件 (just_audio 播文件最稳定)
      final tempDir = await getTemporaryDirectory();
      // 使用 hashCode 和时间戳确保文件名唯一
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/tts_voice_$timestamp.mp3');
      await tempFile.writeAsBytes(audioBytes);

      // 3. 开始播放
      await _player.setFilePath(tempFile.path);
      await _player.play();

    } catch (e) {
      debugPrint("❌ TTS 语音播放失败: $e");
      // 出错也要重置状态并尝试下一首，防止队列永久卡死
      _onPlayFinished();
    }
  }

  /// 停止当前播放并清空队列 (用于切房间或退出时)
  Future<void> stopAndClear() async {
    _audioQueue.clear();
    await _player.stop();
    isSpeaking.value = false;
    currentSubtitle.value = "";
    _isPlayingProcess = false;
  }

  /// 释放资源
  void dispose() {
    _player.dispose();
    isSpeaking.dispose();
    currentSubtitle.dispose();
  }
}