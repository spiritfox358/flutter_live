import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

  // 增加容错处理，防止 AI 返回的 JSON 格式不对
  factory AIDecision.fromMap(Map<String, dynamic> map) {
    return AIDecision(
      message: map['message']?.toString() ?? "",
      addScore: int.tryParse(map['add_score']?.toString() ?? "0") ?? 0,
      emotion: map['emotion']?.toString() ?? "neutral",
    );
  }
}

class AIService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: "https://api.deepseek.com", // DeepSeek 官方接口地址
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      "Authorization": "Bearer $_apiKey",
      "Content-Type": "application/json",
    },
  ));

  static Future<AIDecision> analyzeSituation({
    required String bossName,
    required String bossPersona,
    required int myScore,
    required int opponentScore,
    required int timeLeft,
    String? userAction,
    String? userChat,
  }) async {
    // 1. 构建 Prompt (提示词)
    final systemPrompt = """
你现在扮演一个直播PK的主播对手，名字叫"$bossName"。
你的性格设定是：$bossPersona。
当前局势：
- 我方(你)分数：$opponentScore
- 对方(玩家)分数：$myScore
- 剩余时间：${timeLeft}秒

请根据玩家的行为做出反应。
必须严格仅返回一个 JSON 对象，不要包含 Markdown 格式或其他废话。
JSON 格式要求：
{
  "message": "你要说的骚话（如果不想说话留空字符串，不要太啰嗦，简短有力，符合人设）",
  "add_score": 0, // 决定给自己上多少分（0~5000），根据情绪决定。被骂或偷塔时可以上高分。
  "emotion": "neutral" // 情绪状态：neutral, happy, angry, shock, disdain, sad
}
""";

    String userContent = "现在的情况是：";
    if (userAction != null) userContent += "玩家刚刚操作：$userAction。";
    if (userChat != null) userContent += "玩家发送弹幕：$userChat。";
    if (userAction == null && userChat == null) userContent += "场面暂时平静，你可以选择嘲讽或者发呆。";

    try {
      // 2. 发起请求
      final response = await _dio.post(
        "/chat/completions",
        data: {
          "model": "deepseek-chat", // 使用 V3 模型，便宜又快
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userContent}
          ],
          "temperature": 1.3, // 稍微调高一点，让 AI 更疯癫/有创意
          "response_format": {"type": "json_object"}, // 强制返回 JSON
        },
      );

      // 3. 解析结果
      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        debugPrint("AI 原始返回: $content");

        // 解析 JSON 字符串
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        return AIDecision.fromMap(jsonMap);
      }
    } catch (e) {
      debugPrint("API 调用失败: $e");
    }

    // 4. 降级方案（如果没网或 API 欠费，回退到本地随机逻辑，防止报错）
    return _fallbackLogic(bossName, myScore, opponentScore);
  }

  // 兜底逻辑 (Mock)
  static AIDecision _fallbackLogic(String name, int myScore, int aiScore) {
    final random = Random();
    int diff = myScore - aiScore;
    if (diff > 1000) {
      return AIDecision(message: "系统繁忙，但我还是要赢！", addScore: 500, emotion: "angry");
    }
    return AIDecision(message: "", addScore: random.nextInt(50), emotion: "neutral");
  }
}