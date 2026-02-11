import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import '../../models/live_models.dart';

class BuildChatItem extends StatelessWidget {
  final ChatMessage msg;

  const BuildChatItem({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.3), // 稍微增加间距
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25), //稍微调淡一点背景
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                // 🟢 核心：RichText
                child: Text.rich(
                  TextSpan(
                    children: [
                      // 1. 等级徽章
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: LevelBadge(level: msg.level,showConsumption: true, monthLevel: msg.monthLevel),
                        ),
                      ),

                      // 🟢 2. 新增：主播标签 (如果是主播才显示)
                      if (msg.isAnchor)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6.0), // 标签和名字的间距
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical:1),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6699), Color(0xFFFF3366)], // 骚粉色渐变
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "主播",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.2, // 微调内部对齐
                              ),
                            ),
                          ),
                        ),

                      // 3. 名字 (主播的名字颜色也可以特殊处理，比如粉色)
                      TextSpan(
                        text: msg.name.isEmpty ? '' : "${msg.name}：",
                        style: TextStyle(
                          color: msg.isAnchor ? const Color(0xFFFF88B0) : Colors.lightBlueAccent, // 主播名字也粉一点
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),

                      // 4. 聊天内容
                      TextSpan(
                        text: msg.content,
                        style: TextStyle(
                          color: msg.isGift ? const Color(0xFFFFD700) : Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}