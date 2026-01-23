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
    baseUrl: "https://api.deepseek.com",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      "Authorization": "Bearer $_apiKey",
      "Content-Type": "application/json",
    },
  ));

  static Future<AIDecision> analyzeSituation({
    required String bossName,
    required String bossPersona, // 这个参数其实在下面被覆盖了，为了接口兼容保留
    required int myScore,
    required int opponentScore,
    required int timeLeft,
    String? userAction,
    String? userChat,
  }) async {
    // 计算分差
    int scoreDiff = opponentScore - myScore; // 正数表示我方(AI)领先，负数表示落后
    bool isLosing = scoreDiff < 0;
    bool isStealTowerTime = timeLeft <= 10;

    // 1. 构建极具攻击性的 Prompt (提示词)
    final systemPrompt = """
你现在正在进行一场直播PK，你是一个【顶级神豪/海外留学生】，性格【极度好胜、狂妄、喜欢用英语口语、人狠话不多】。
你的名字叫"$bossName"。

当前局势：
- 剩余时间：${timeLeft}秒
- 你的分数：$opponentScore
- 对手(玩家)分数：$myScore
- 状态：${isLosing ? "落后 ${-scoreDiff}分" : "领先 $scoreDiff 分"}

🔥 你的行为准则（必须严格遵守）：
1. **不要做话痨！** 只有 30% 的概率需要说话，剩下 70% 的概率把 "message" 留空字符串，直接砸钱。
2. **语言风格**：必须中英文夹杂 (Chinglish)，使用简短的 Slang。例如："What?", "No way", "Naive", "GG", "Easy game", "Come on", "Sit down", "偷塔?", "就这?".
3. **上票逻辑 (关键)**：
   - **普通时刻**：随机上 100~500 分，保持活跃。
   - **被反超/被挑衅**：必须重拳出击，直接上 2000~5000 分，并回复愤怒的话（带英语脏字/感叹词）。
   - **偷塔时刻 (剩余时间 < 10秒)**：
     - 如果落后或分差很小：**必须执行“偷塔”操作，直接加 5000~20000 分！** 试图绝杀对手。
     - 此时说话内容要短："Steal!", "绝杀!", "Bye~", "Too young".
   - **领先很多时**：可以发呆（不加分），或者嘲讽 "Give up via?".

请根据玩家行为和当前时间，返回一个 JSON 对象。
""";

    String userContent = "现在的情况是：";
    if (userAction != null) userContent += "玩家突然操作：$userAction。";
    if (userChat != null) userContent += "玩家发弹幕：$userChat。";
    if (userAction == null && userChat == null) {
      if (isStealTowerTime) {
        userContent += "⚠️ 警告：比赛即将结束！现在是偷塔的关键时刻！";
      } else {
        userContent += "场面平静。";
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
          "temperature": 1.4, // 温度调高，让它更疯
          "response_format": {"type": "json_object"},
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        debugPrint("AI 决策 ($bossName): $content"); // 方便你在控制台看 AI 怎么想的
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        return AIDecision.fromMap(jsonMap);
      }
    } catch (e) {
      debugPrint("API 调用失败: $e");
    }

    // 4. 降级方案 (本地逻辑，防止断网变傻)
    return _fallbackLogic(isStealTowerTime, isLosing, scoreDiff);
  }

  // 本地兜底逻辑（当 AI 挂了时，也要保证有偷塔行为）
  static AIDecision _fallbackLogic(bool isStealTower, bool isLosing, int diff) {
    final random = Random();

    // 偷塔时刻兜底
    if (isStealTower) {
      if (isLosing || diff < 1000) {
        return AIDecision(message: "Steal!!", addScore: 5000 + random.nextInt(5000), emotion: "excited");
      }
    }

    // 普通时刻
    if (isLosing && diff < -2000) {
      return AIDecision(message: "WTF?", addScore: 2000, emotion: "angry");
    }

    return AIDecision(message: "", addScore: random.nextInt(100), emotion: "neutral");
  }
}