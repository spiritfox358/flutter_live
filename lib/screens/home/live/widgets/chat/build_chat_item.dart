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
      // 增加一点垂直间距，防止弹幕太拥挤
      padding: const EdgeInsets.symmetric(vertical: 1.3, horizontal: 0.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          // 限制最大宽度，防止弹幕撑爆屏幕
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                // 1. 等级徽章 (使用 WidgetSpan 嵌入)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle, // 关键：与文字垂直居中对齐
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2.0,top: 1.3), // 右侧间距
                    child: LevelBadge(
                      level: msg.level,
                      showConsumption: true,
                      monthLevel: msg.monthLevel,
                    ),
                  ),
                ),

                // 2. 主播标签 (仅当 isAnchor 为 true 时显示)
                if (msg.isAnchor)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4.0), // 右侧间距
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6699), Color(0xFFFF3366)],
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
                          height: 1.0, // 防止标签内部文字撑高
                        ),
                      ),
                    ),
                  ),

                // 3. 名字
                if (msg.name.isNotEmpty)
                  TextSpan(
                    text: "${msg.name}：",
                    style: TextStyle(
                      color: msg.isAnchor
                          ? const Color(0xFFFF88B0)
                          : Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4, // 调整行高以适应徽章高度
                    ),
                  ),

                // 4. 聊天内容
                TextSpan(
                  text: msg.content,
                  style: TextStyle(
                    color: msg.isGift ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 12,
                    height: 1.4, // 保持与名字一致的行高
                  ),
                ),
              ],
            ),
            // 文本整体设置
            softWrap: true,
            maxLines: 5,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
    );
  }
}