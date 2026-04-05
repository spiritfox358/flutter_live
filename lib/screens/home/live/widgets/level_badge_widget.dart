import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelBadge extends StatefulWidget {
  final int level;
  final int monthLevel;
  final bool showConsumption;
  final String? levelHonourBuffUrl; // 🚀 1. 改为接收 String 类型的 URL

  const LevelBadge({super.key, required this.level, required this.monthLevel, this.showConsumption = false, this.levelHonourBuffUrl});

  @override
  State<LevelBadge> createState() => _LevelBadgeState();
}

class _LevelBadgeState extends State<LevelBadge> {
  late int _randomConsumptionIndex;

  @override
  void initState() {
    super.initState();
    _randomConsumptionIndex = Random().nextInt(4) + 1;
  }

  // 📝 辅助判断：当前是否开启了荣耀 Buff
  bool get _isBuffActive => widget.levelHonourBuffUrl != null && widget.levelHonourBuffUrl!.isNotEmpty;

  String _getBadgeUrl(int level) {
    // 🚀 4. 核心：如果处于 Buff 状态，直接原封不动返回这个 URL！
    if (_isBuffActive) {
      return widget.levelHonourBuffUrl!;
    }

    const String baseUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/";
    String iconName;
    if (level >= 70)
      iconName = "level_70.png";
    else if (level >= 61)
      iconName = "level_61.png";
    else if (level >= 60)
      iconName = "level_60.png";
    else if (level >= 50)
      iconName = "level_50.png";
    else if (level >= 41)
      iconName = "level_40.png";
    else if (level >= 30)
      iconName = "level_30.png";
    else if (level >= 20)
      iconName = "level_20.png";
    else if (level >= 10)
      iconName = "level_10.png";
    else
      iconName = "level_0.png";

    return "$baseUrl$iconName";
  }

  String _getConsumptionLevelUrl(int level) {
    const String baseUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/";
    if (level == 4) return "${baseUrl}consumption_level_4.gif";
    return "${baseUrl}consumption_level_$level.png";
  }

  @override
  Widget build(BuildContext context) {
    // -----------------------------------------------------------------------
    // 🛠️ 调整区域：在这里添加你的判断逻辑
    // -----------------------------------------------------------------------

    // 1. 设置图片的宽度
    double? currentHeight =13;

    // 2. 设置图片的缩放模式
    BoxFit currentFit = BoxFit.contain;

    // 3. 设置文字的右侧偏移量 (Right) - 控制左右
    double textRight = widget.level < 10 ? 7.0 : 2.0;
    if (_isBuffActive) {
      textRight = widget.level >= 10 ? 5.0 : 8.0;
      currentHeight = 15;
    }

    // 4. 设置字体大小
    double currentFontSize = _isBuffActive ? 10.0 : 10.0;

    // 5. ✨ 新增：设置文字的垂直偏移量 (Top) - 控制上下
    // 💡 逻辑：如果文字偏上，增加 top 的值让它往下移（原值为 -1.0）。
    double textTop = -1.1;
    if (_isBuffActive) {
      textTop = -0; // 👈 你可以修改这里！数值越大，文字越往下；数值越小（越负），文字越往上。
    }

    // -----------------------------------------------------------------------

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.network(
              _getBadgeUrl(widget.level),
              height: currentHeight,
              // width: currentHeight,
              fit: currentFit,
              errorBuilder: (context, error, stackTrace) => Container(width: 15, height: 15, color: Colors.grey[300]),
            ),
            Positioned(
              top: textTop, // ✨ 👈 应用你设置的垂直偏移量
              right: textRight,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Text(
                  widget.level.toString(),
                  style: GoogleFonts.roboto(
                    textStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w900, fontSize: currentFontSize),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.showConsumption && widget.monthLevel > 0) ...[
          const SizedBox(width: 4),
          Image.network(_getConsumptionLevelUrl(widget.monthLevel), height: 12.5, fit: BoxFit.contain),
        ],
      ],
    );
  }
}
