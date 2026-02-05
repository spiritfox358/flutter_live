import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final bool showConsumption; // ✨ 新增：控制是否显示后面的消费图标

  const LevelBadge({
    super.key,
    required this.level,
    this.showConsumption = false, // 默认为 false，需要显示时传入 true
  });

  // ✨ 核心逻辑：根据等级返回对应的图片 URL
  String _getBadgeUrl(int level) {
    const String baseUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/";

    String iconName;

    // 🎯 映射规则 (从高到低判断)
    if (level >= 70) {
      iconName = "level_70.png";
    } else if (level >= 61) {
      iconName = "level_61.png";
    } else if (level >= 60) {
      iconName = "level_60.png";
    } else if (level >= 50) {
      iconName = "level_50.png";
    } else {
      iconName = "level_40.png";
    }

    return "$baseUrl$iconName";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // 宽度自适应，不要撑满
      crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
      children: [
        // --- 1. 原有的等级徽章 (Stack) ---
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.network(
              _getBadgeUrl(level),
              height: 15,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 15,
                height: 15,
                color: Colors.grey[300],
              ),
            ),
            Positioned(
              right: 2,
              bottom: -0.5,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Text(
                  level.toString(),
                  style: GoogleFonts.roboto( // 🟢 强制使用 Roboto 字体
                    textStyle: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // --- 2. ✨ 追加的消费图标 (可选显示) ---
        if (showConsumption) ...[
          const SizedBox(width: 4), // 两个图标之间的间距
          Image.network(
            "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/consumption_level_1.png",
            height: 15, // 保持与等级图标高度一致
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }
}