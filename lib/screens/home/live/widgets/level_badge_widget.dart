import 'dart:math'; // 🟢 1. 引入 math 库用于生成随机数
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🟢 2. 改为 StatefulWidget，为了保持随机图片在当前页面生命周期内不变
class LevelBadge extends StatefulWidget {
  final int level;
  final int monthLevel;
  final bool showConsumption;

  const LevelBadge({super.key, required this.level, required this.monthLevel, this.showConsumption = false});

  @override
  State<LevelBadge> createState() => _LevelBadgeState();
}

class _LevelBadgeState extends State<LevelBadge> {
  // 用于存储随机出来的后缀 (1, 2, 3, 4)
  late int _randomConsumptionIndex;

  @override
  void initState() {
    super.initState();
    // 🎯 3. 在初始化时生成一次随机数 (范围 1-4)
    // Random().nextInt(4) 生成 0,1,2,3，加 1 后变成 1,2,3,4
    _randomConsumptionIndex = Random().nextInt(4) + 1;
  }

  // 核心逻辑：根据等级返回对应的图片 URL (保持不变)
  String _getBadgeUrl(int level) {
    const String baseUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/";
    String iconName;

    if (level >= 70) {
      iconName = "level_70.png";
    } else if (level >= 61) {
      iconName = "level_61.png";
    } else if (level >= 60) {
      iconName = "level_60.png";
    } else if (level >= 50) {
      iconName = "level_50.png";
    } else if (level >= 41) {
      iconName = "level_40.png";
    } else if (level >= 30) {
      iconName = "level_30.png";
    } else if (level >= 20) {
      iconName = "level_20.png";
    } else if (level >= 10) {
      iconName = "level_10.png";
    } else {
      iconName = "level_0.png";
    }

    return "$baseUrl$iconName";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- 1. 原有的等级徽章 (Stack) ---
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.network(
              _getBadgeUrl(widget.level), // 注意：StatefulWidget 中访问参数要加 widget.
              height: 15,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(width: 15, height: 15, color: Colors.grey[300]),
            ),
            Positioned(
              top: -0.5,
              right: widget.level < 10 ? 7 : 2.5,
              bottom: -0.5,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Text(
                  widget.level.toString(),
                  style: GoogleFonts.roboto(
                    textStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),

        // --- 2. ✨ 追加的消费图标 (随机显示 1-4) ---
        if (widget.showConsumption && widget.monthLevel > 0) ...[
          const SizedBox(width: 4),
          Image.network(
            // 🎯 4. 使用初始化时生成的随机后缀
            "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/consumption_level_${widget.monthLevel}.png",
            height: 15,
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }
}
