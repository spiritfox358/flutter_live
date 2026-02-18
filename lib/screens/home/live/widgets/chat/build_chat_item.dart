import 'package:flutter/gestures.dart'; // 1. 需要引入手势库
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import '../../models/live_models.dart';

class BuildChatItem extends StatelessWidget {
  final ChatMessage msg;
  // 2. 新增点击回调，把被点击的消息或者是用户信息传出去
  final Function(ChatMessage)? onNameTap;

  const BuildChatItem({
    super.key,
    required this.msg,
    this.onNameTap, // 构造函数接收回调
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 1.3, horizontal: 0.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                // 1. 等级徽章
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2.0, top: 1.3),
                    child: LevelBadge(
                      level: msg.level,
                      showConsumption: true,
                      monthLevel: msg.monthLevel,
                    ),
                  ),
                ),

                // 2. 主播标签
                if (msg.isAnchor)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4.0),
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
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                // 3. 名字 (在这里添加点击事件)
                if (msg.name.isNotEmpty)
                  TextSpan(
                    text: "${msg.name}：",
                    style: TextStyle(
                      color: msg.isAnchor
                          ? const Color(0xFFFF88B0)
                          : Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    // 核心修改：添加 recognizer
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // 触发回调
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
                  style: TextStyle(
                    color: msg.isGift ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
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