import 'dart:convert';
import 'dart:math';
import 'dart:typed_data'; // 🟢 新增：用于处理二进制流
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart'; // 🟢 新增：播放器

// 你的 DeepSeek API Key
const String _apiKey = "sk-89228156b56b4c0ab4b6163fd4cfe96f";

class AIDecision {
  final String message;
  final int addScore;
  final String emotion;

  AIDecision({
    required this.message,
    required this.addScore,
    required this.emotion,
  });

  factory AIDecision.fromMap(Map<String, dynamic> map) {
    return AIDecision(
      message: map['message']?.toString() ?? "",
      addScore: int.tryParse(map['add_score']?.toString() ?? "0") ?? 0,
      emotion: map['emotion']?.toString() ?? "neutral",
    );
  }
}

class AIService {
  // 🟢 1. 定义音频播放器 (静态单例，防止声音重叠)
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: "https://api.deepseek.com",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      "Authorization": "Bearer $_apiKey",
      "Content-Type": "application/json",
    },
  ));

  // 🟢 2. 新增：TTS 请求与播放方法
  // 在这里直接调用后端接口并播放
  static Future<void> playTTS(String text) async {
    if (text.isEmpty) return;

    // 创建一个新的 Dio 实例用于 TTS，避免和 DeepSeek 的 BaseUrl 冲突
    // 或者你可以复用全局 HttpUtil，这里为了演示独立写
    final Dio ttsDio = Dio(BaseOptions(
      // ⚠️ 替换成你自己的后端地址
      baseUrl: "http://你的后端IP:端口",
      connectTimeout: const Duration(seconds: 10),
    ));

    try {
      debugPrint("🔊 正在请求 TTS: $text");

      // 调用后端接口
      // 假设你的接口是 /api/tts，参数是 text
      final response = await ttsDio.post("/api/tts", data: {"text": text});

      if (response.statusCode == 200 && response.data != null) {
        // 解析结构: {"data": {"audio": "...", "status": 2}, ...}
        final dataObj = response.data['data'];

        if (dataObj != null && dataObj['audio'] != null) {
          String audioStr = dataObj['audio'].toString();

          // 1. 处理前缀 (如果有 data:audio/mp3;base64, 则去掉)
          if (audioStr.contains(',')) {
            audioStr = audioStr.split(',').last;
          }

          // 2. 解码 (Base64 -> Bytes)
          // 注意：虽然文档写 Hex，但看之前截图通常是 Base64。
          // 如果真的是 Hex 字符串，请告诉我，需要换一种解码方式。
          Uint8List audioBytes = base64Decode(audioStr);

          // 3. 停止上一句，播放当前句
          await _audioPlayer.stop();
          await _audioPlayer.play(BytesSource(audioBytes));
          debugPrint("✅ TTS 播放成功");
        }
      }
    } catch (e) {
      debugPrint("❌ TTS 播放失败: $e");
    }
  }

  // --- 原有的 DeepSeek 逻辑保持不变 ---

  static Future<AIDecision> analyzeSituation({
    required String bossName,
    required String bossPersona,
    required int myScore,
    required int opponentScore,
    required int timeLeft,
    String? userAction,
    String? userChat,
  }) async {
    // 计算局势
    int scoreDiff = opponentScore - myScore; // 正数=AI领先
    bool isLosing = scoreDiff < 0;
    bool isStealTowerTime = timeLeft <= 10;

    // 1. 构建激进的直播间 Prompt
    final systemPrompt = """
你现在正在进行一场激烈的直播PK，你的名字叫"$bossName"。
你的设定是：【性格火爆、极其护短、嘴硬、喜欢嘲讽对手的PK主播】。

当前局势：
- 剩余时间：${timeLeft}秒
- 你的分数：$opponentScore
- 对手分数：$myScore
- 状态：${isLosing ? "落后 ${-scoreDiff}分" : "领先 $scoreDiff 分"}

🔥 行为准则（必须严格遵守）：
1. **绝对禁止使用英语！** 全程使用中国直播间“黑话”和口语。
2. **性格特征**：
   - 领先时：极其嚣张，看不起对面。（例：“就这？对面没人了？”、“你们是来搞笑的吗？”）
   - 落后时：气急败坏，疯狂摇人。（例：“兄弟们给我上！”、“别让对面看笑话！”、“偷塔！把家底都拿出来！”）
   - 被挑衅时：直接怼回去。（例：“小黑子闭嘴”、“房管把那个人封了”）
3. **上票逻辑**：
   - **普通时刻**：随机上 100~800 分。
   - **偷塔时刻 (最后10秒)**：
     - 如果落后或分差小：**必须“偷塔”，狂砸 5000~30000 分！** 并大喊“给我秒了！”
     - 如果大幅领先：可以嘲讽“让你三秒又何妨”。

请根据局势返回 JSON。
""";

    String userContent = "当前画面：";
    if (userAction != null) userContent += "对手那边动静：$userAction。";
    if (userChat != null) userContent += "公屏弹幕：$userChat。";
    if (userAction == null && userChat == null) {
      if (isStealTowerTime) {
        userContent += "⚠️ 最后时刻！全军出击！";
      } else if (isLosing) {
        userContent += "我们落后了！快输了！";
      } else {
        userContent += "暂时领先，继续保持压迫感。";
      }
    }

    try {
      final response = await _dio.post(
        "/chat/completions",
        data: {
          "model": "deepseek-chat",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userContent}
          ],
          "temperature": 1.5,
          "response_format": {"type": "json_object"},
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        return AIDecision.fromMap(jsonMap);
      }
    } catch (e) {
      debugPrint("API 调用失败: $e");
    }

    return _fallbackLogic(isStealTowerTime, isLosing, scoreDiff);
  }

  static AIDecision _fallbackLogic(bool isStealTower, bool isLosing, int diff) {
    if (isStealTower) {
      if (isLosing || diff < 2000) {
        return AIDecision(message: "给我秒了他们！！", addScore: 8888, emotion: "excited");
      }
      return AIDecision(message: "让你们绝望！", addScore: 500, emotion: "proud");
    }
    if (isLosing) {
      return AIDecision(message: "兄弟们别睡了！上票！", addScore: 2000, emotion: "angry");
    }
    return AIDecision(message: "就这点分？", addScore: 100, emotion: "disdain");
  }
}