import 'dart:async';
import 'dart:collection'; // 🟢 引入队列支持
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../tools/HttpUtil.dart';
import '../avatar_animation.dart';

class VoiceRoomContentView extends StatefulWidget {
  final String currentBgImage;
  final String roomTitle;
  final String anchorName;
  final String anchorAvatar;
  final String roomId;

  const VoiceRoomContentView({
    super.key,
    required this.currentBgImage,
    required this.roomTitle,
    required this.anchorName,
    this.anchorAvatar = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/def_avatar.png",
    required this.roomId,
  });

  @override
  State<VoiceRoomContentView> createState() => VoiceRoomContentViewState();
}

// 🟢 把 state 改为 public (去掉下划线)，方便父组件引用类型
class VoiceRoomContentViewState extends State<VoiceRoomContentView> {
  final AudioPlayer _player = AudioPlayer();

  // 🟢 播放队列：先进先出
  final Queue<Map<String, String>> _audioQueue = Queue();

  bool _isSpeaking = false; // 控制头像波纹
  bool _isPlayingProcess = false; // 内部锁，防止重复触发播放
  String _currentSubtitle = ""; // (可选) 显示当前主播说的文字字幕
  // 🟢 控制自动闲聊
  Timer? _autoChatTimer;
  bool _isFetchingAutoChat = false; // 防止重复请求

  @override
  void initState() {
    super.initState();
    // 监听播放状态：播放结束 -> 停止动画 -> 尝试播下一首
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _currentSubtitle = "";
          });
        }
        _playNext(); // 🟢 播完一句，自动检查下一句
      }
    });

    // 2. 🟢 启动自动闲聊检查 (进房 3秒后开始)
    Future.delayed(const Duration(seconds: 3), () {
      _checkAutoChat();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // =========================================================
  // 🟢 自动闲聊逻辑 (永动机核心)
  // =========================================================

  void _checkAutoChat() {
    _autoChatTimer?.cancel();

    // 每隔 2 秒检查一次状态
    _autoChatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // 如果 没在播放 && 没在请求中 && 队列是空的
      if (!_isSpeaking && !_isPlayingProcess && _audioQueue.isEmpty && !_isFetchingAutoChat) {
        _fetchAutoChat();
      }
    });
  }

  // 请求后端获取一句闲聊
  Future<void> _fetchAutoChat() async {
    _isFetchingAutoChat = true;
    try {
      // 🟢 调用后端接口获取闲聊 (需要后端加这个接口，或者复用 tts 接口传特定 text)
      // 这里建议后端加一个 /api/robot/auto_chat 接口，随机返回一句语音
      // 或者前端随机生成一句文案传给 TTS

      // 简单方案：前端随机选一句文案，调 TTS
      final topics = ["好无聊啊，大家怎么不说话？", "有人想听歌吗？点关注不迷路哦。", "今天的风儿甚是喧嚣呢。", "榜一大哥在吗？出来聊聊呗。", "有没有小哥哥带我打游戏呀？", "直播间好安静，我是不是被屏蔽了？"];
      final text = topics[DateTime.now().millisecondsSinceEpoch % topics.length];

      // 调用 TTS 接口
      var responseData = await HttpUtil().get('/api/robot/auto_chat', params: {'text': text, "roomId": widget.roomId});

      if (responseData != null && responseData is Map) {
        final text = responseData['text'];
        final audioData = responseData['audioData'];

        if (audioData != null && audioData.isNotEmpty) {
          speakFromSocket({'audioData': audioData, 'text': text});
        }
      }
    } catch (e) {
      debugPrint("自动闲聊获取失败: $e");
    } finally {
      _isFetchingAutoChat = false;
    }
  }

  // =========================================================
  // 🟢 核心方法：供 RealLivePage 通过 Key 调用
  // =========================================================
  void speakFromSocket(Map<String, dynamic> data) {
    // 后端传回的字段：audioData (Base64), text (字幕)
    final String? audioBase64 = data['audioData'];
    final String? text = data['text'];

    if (audioBase64 != null && audioBase64.isNotEmpty) {
      // 加入队列
      _audioQueue.add({'audio': audioBase64, 'text': text ?? ''});

      // 如果当前没有在播放，立即开始
      if (!_isPlayingProcess && !_isSpeaking) {
        _playNext();
      }
    }
  }

  // 内部方法：处理队列播放
  Future<void> _playNext() async {
    if (_audioQueue.isEmpty) {
      _isPlayingProcess = false;
      return;
    }

    _isPlayingProcess = true;
    final item = _audioQueue.removeFirst(); // 取出最早的一条
    final base64String = item['audio']!;
    final text = item['text']!;

    try {
      if (mounted) {
        setState(() {
          _isSpeaking = true; // 头像开始动
          _currentSubtitle = text; // 显示字幕
        });
      }

      // 1. 解码 Base64
      // 注意：有的 Base64 带有 "data:audio/mp3;base64," 前缀，需要去掉
      String cleanBase64 = base64String;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      // 去掉回车换行
      cleanBase64 = cleanBase64.replaceAll('\n', '').replaceAll('\r', '');

      Uint8List audioBytes = base64Decode(cleanBase64);

      // 2. 写入临时文件 (just_audio 播文件最稳定，也不用自己写 StreamSource)
      final tempDir = await getTemporaryDirectory();
      // 加时间戳防止文件名冲突
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/tts_voice_$timestamp.mp3');
      await tempFile.writeAsBytes(audioBytes);

      // 3. 播放
      await _player.setFilePath(tempFile.path);
      _player.play();
    } catch (e) {
      debugPrint("❌ 语音播放失败: $e");
      // 出错了也要把状态重置，并尝试播下一首，否则队列会卡死
      if (mounted) setState(() => _isSpeaking = false);
      _playNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 背景层
        Positioned.fill(
          child: Image.network(
            widget.currentBgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        ),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),

        // 2. 核心内容层
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 改为居中，好看一点
            children: [
              // 头像组件
              AvatarAnimation(
                avatarUrl: widget.anchorAvatar,
                name: widget.anchorName,
                isSpeaking: _isSpeaking, // 🟢 由播放状态控制
                isRotating: true,
              ),

              const SizedBox(height: 30),

              // 🟢 字幕气泡 (当主播说话时显示)
              if (_isSpeaking && _currentSubtitle.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(2), // 像气泡一样的一个角
                    ),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Text(
                    _currentSubtitle,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
