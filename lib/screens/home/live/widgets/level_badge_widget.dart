import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  final int level;

  const LevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    // 生成动态图片URL (格式: level_{level}.png)
    final imageUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/user_level/level_70.png";

    return Stack(
      alignment: Alignment.bottomRight, // 数字定位在右下角
      children: [
        // 等级图标
        Image.network(
          imageUrl,
          height: 15,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 15,
            height: 15,
            color: Colors.grey[300],
            child: Icon(Icons.error, color: Colors.grey[600], size: 12),
          ),
        ),
        // 覆盖在图标上的等级数字
        Positioned(
          right: 2, // 从右边开始
          bottom: -0.5, // 从底部开始
          child: Padding(
            padding: const EdgeInsets.all(0.0), // 调整内边距避免紧贴边缘
            child: Text(
              level.toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                shadows: [Shadow(offset: Offset(1, 1), color: Colors.black26, blurRadius: 2)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
