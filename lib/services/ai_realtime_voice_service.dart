import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // 引入 MethodChannel
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';

import '../tools/HttpUtil.dart';

class AiRealTimeVoiceService {
  static final AiRealTimeVoiceService _instance = AiRealTimeVoiceService._internal();
  factory AiRealTimeVoiceService() => _instance;
  AiRealTimeVoiceService._internal();

  // 🟢 建立与 Android 原生的通信桥梁
  static const MethodChannel _nativePlayer = MethodChannel('com.ai.voice/native_player');

  WebSocketChannel? _channel;
  AudioRecorder _audioRecorder = AudioRecorder();

  StreamSubscription<Uint8List>? _micStreamSub;
  StreamSubscription? _wsStreamSub;
  DateTime _muteMicUntil = DateTime.now(); // 防外放/耳机漏音回声打断
  DateTime _lastFeedTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isConnecting = false;
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();

  bool _isFeeding = false;
  bool _isSpeaking = false;
  bool _isPlayingStreamStarted = false;
  bool get isSpeaking => _isSpeaking;

  // 🚀🚀🚀 1. 新增：物理麦克风静音总闸！
  bool _isUserMuted = false;
  void setMicMute(bool isMuted) {
    _isUserMuted = isMuted;
    debugPrint("🎤 本地麦克风总闸已被切换为：${isMuted ? '静音' : '收音'}");
  }

  /// 🟢 计算这段音频的平均音量（本地噪音门算法）
  bool _isLoudEnough(Uint8List data) {
    int sum = 0;
    // 兼容所有 Dart 版本的安全视图读取
    ByteData byteData = ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);

    for (int i = 0; i < data.length - 1; i += 2) {
      sum += byteData.getInt16(i, Endian.little).abs();
    }
    double average = sum / (data.length / 2);

    // 阈值设为 400（最大值是32768），可过滤掉绝大部分呼吸声、环境轻微底噪
    return average > 400;
  }

  Future<bool> startVoiceCall({required String roomId, required String userId}) async {
    if (_isConnecting || _isSpeaking) return false;
    _isConnecting = true;

    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("🎤 麦克风权限被拒绝");
        return false;
      }

      // 🟢 核心大招：提前预热！
      // 在刚进入房间时，立刻唤醒 Android 底层播放器，霸占音频硬件！
      // 不要等 AI 发声了才去开喇叭，那时候硬件冷启动会吞掉前 0.5 秒的声音。
      try {
        await _nativePlayer.invokeMethod('initPlayer', {'sampleRate': 24000});
        _isPlayingStreamStarted = true;
        debugPrint("🔊 原生 PCM 播放引擎已提前点火待命！");
      } catch (e) {
        debugPrint("⚠️ 原生播放器预热异常: $e");
      }

      final wsUrl = "ws://${HttpUtil.getBaseIpPort}/ws/audio";
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsStreamSub = _channel!.stream.listen(
            (message) => _handleWsMessage(message),
        onError: (error) => stopVoiceCall(),
        onDone: () => stopVoiceCall(),
      );

      final startCmd = jsonEncode({"type": "START_AUDIO", "roomId": int.parse(roomId), "userId": int.parse(userId)});
      _channel!.sink.add(startCmd);

      return true;
    } catch (e) {
      debugPrint("❌ 开启语音对讲失败: $e");
      stopVoiceCall();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void _handleWsMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'AUDIO_READY') {
          debugPrint("✅ 后端通道已就绪，开始采集麦克风...");
          _startAudioIO();
        }
      } catch (e) {
        debugPrint("解析控制指令失败: $e");
      }
    } else if (message is Uint8List) {
      _audioQueue.add(message);
      _processAudioQueue();
    }
  }

  /// 🟢 喂食器：呼叫 Android 原生播放，并加入“冷启动唤醒”防吞字机制
  /// 🟢 纯粹的极速喂食器：拿到声音，0延迟直接推给已预热好的原生播放器
  /// 🟢 纯粹的极速喂食器：加入“智能唤醒防吞字”机制
  Future<void> _processAudioQueue() async {
    if (_isFeeding || _audioQueue.isEmpty) return;
    _isFeeding = true;

    try {
      BytesBuilder builder = BytesBuilder();

      // 🟢 终极防吞字核心逻辑：
      // 如果距离上次给原生层喂数据已经超过 500 毫秒，说明 Android 底层的音频硬件极可能为了省电而休眠了。
      // 此时，我们在真实声音的最前面，硬塞 300 毫秒的静音数据（14400 字节的 0）。
      // 让硬件在唤醒时的 300ms 里“吞”掉这些静音，保全后面的真实语音！
      if (DateTime.now().difference(_lastFeedTime).inMilliseconds > 500) {
        builder.add(Uint8List(14400)); // 塞入 300ms 的纯静音祭品包
        debugPrint("📢 硬件可能已休眠，插入 300ms 静音包唤醒音频功放...");
      }

      // 把队列里真实的音频数据拼接起来
      while (_audioQueue.isNotEmpty) {
        builder.add(_audioQueue.removeFirst());
      }
      Uint8List combinedData = builder.toBytes();

      if (combinedData.isNotEmpty) {
        // 直接无脑发给已经点火待命的原生端
        await _nativePlayer.invokeMethod('feedAudio', {'data': combinedData});

        // 🟢 记录本次喂数据的时间
        _lastFeedTime = DateTime.now();

        // 计算禁言时间（这里包含那 300ms 静音的时长，所以计算是完全精准的）
        int durationMs = (combinedData.length / 48.0).ceil();
        DateTime now = DateTime.now();
        if (_muteMicUntil.isBefore(now)) {
          _muteMicUntil = now.add(Duration(milliseconds: durationMs));
        } else {
          _muteMicUntil = _muteMicUntil.add(Duration(milliseconds: durationMs));
        }
      }
    } catch (e) {
      debugPrint("❌ 发送音频到原生层失败: $e");
    } finally {
      _isFeeding = false;

      // 如果期间又收到了新包，继续处理
      if (_audioQueue.isNotEmpty) {
        _processAudioQueue();
      }
    }
  }

  Future<void> _startAudioIO() async {
    try {
      _audioRecorder = AudioRecorder();
      final recordStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          // 🔴 核心修复：戴耳机时，彻底关掉系统的硬件回声消除，防止它吞掉开头几个字！
          echoCancel: false,
          noiseSuppress: false,
          autoGain: false,
        ),
      );

      _isSpeaking = true;
      _micStreamSub = recordStream.listen((data) {
        if (_channel == null || !_isSpeaking) return;

        // 🚀🚀🚀 2. 核心拦截：如果你被禁言了，或者主动闭麦了，强行发送“静音包”！
        // 这样服务器收到的是没有声音的空数据，别人就绝对听不到你说话了！
        if (_isUserMuted) {
          _channel!.sink.add(Uint8List(data.length));
          return;
        }

        // 🟢 核心修复 2：绝不能用 return 暴力拔网线！
        if (DateTime.now().isBefore(_muteMicUntil)) {
          // Dart 的 Uint8List 默认会用 0 填充。
          // 我们发送一段与真实录音等长、但全是 0 的“绝对静音包”给服务器。
          _channel!.sink.add(Uint8List(data.length));
          return;
        }

        // 不在禁言期时，原汁原味地发送你的真实声音
        _channel!.sink.add(data);
      });
    } catch (e) {
      debugPrint("❌ 启动麦克风失败: $e");
    }
  }

  Future<void> stopVoiceCall() async {
    _isSpeaking = false;
    _isPlayingStreamStarted = false;
    _audioQueue.clear();
    _isFeeding = false;

    await _micStreamSub?.cancel();

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint("⚠️ 麦克风已释放，跳过关闭");
    }

    // 🟢 挂断时通知 Android 原生销毁播放器
    try {
      await _nativePlayer.invokeMethod('stopPlayer');
    } catch (e) {}

    await _wsStreamSub?.cancel();
    _channel?.sink.close();
    _channel = null;

    debugPrint("🛑 AI 语音连麦已结束并清理资源");
  }

  void dispose() {
    // 🚀 核心修复：排队执行！
    // 必须等 stopVoiceCall (释放录音) 彻底走完之后，再去调用 dispose (销毁硬件)！
    // 并且用 .catchError 把所有底层的异步报错死死捂在肚子里！
    stopVoiceCall().then((_) {
      try {
        _audioRecorder.dispose().catchError((e) {
          debugPrint("⚠️ 拦截到麦克风销毁异常，安全忽略: $e");
        });
      } catch (e) {}
    }).catchError((e) {
      debugPrint("⚠️ 拦截到挂断异常，安全忽略: $e");
    });
  }
}