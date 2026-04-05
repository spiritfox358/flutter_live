import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import '../../models/live_models.dart';

class BuildChatItem extends StatelessWidget {
  final ChatMessage msg;
  final Function(ChatMessage)? onNameTap;

  const BuildChatItem({
    super.key,
    required this.msg,
    this.onNameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 1.3, horizontal: 0.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Text.rich(
            TextSpan(
              children: [
                // 1. 等级徽章
                if (msg.level > 0)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2.0, top: 1.3),
                      child: LevelBadge(
                        level: msg.level,
                        showConsumption: true,
                        monthLevel: msg.monthLevel,
                        // 🚀🚀🚀 核心改造：绝对不能写死 1！
                        // 动态读取这条消息发送者的 Buff ID，如果没有这个字段就默认传 0（显示普通等级）
                        levelHonourBuffUrl: msg.levelHonourBuff,
                      ),
                    ),
                  ),

                // 2. 主播标签
                if (msg.isAnchor)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4.0, top: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6699), Color(0xFFFF3366)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "主播",
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1.0),
                      ),
                    ),
                  ),

                // 3. 名字 (在这里添加点击事件)
                if (msg.name.isNotEmpty)
                  TextSpan(
                    text: "${msg.name}：",
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        if (onNameTap != null) {
                          onNameTap!(msg);
                        } else {
                          debugPrint("点击了用户: ${msg.name}");
                        }
                      },
                  ),

                // 4. 聊天内容
                TextSpan(
                  text: msg.content,
                  style: TextStyle(color: msg.isGift ? const Color(0xFFFFD700) : Colors.white, fontSize: 12, height: 1.4),
                ),
              ],
            ),
            softWrap: true,
            maxLines: 5,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
    );
  }
}