import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import '../models/live_models.dart';

class BuildChatItem extends StatelessWidget {
  // 如果需要从外部传递数据，可以定义构造函数
  final ChatMessage msg;

  const BuildChatItem({super.key, required this.msg});

  // 可选：添加 key 或其他参数
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1), child: LevelBadge(level: msg.level)),
                    const SizedBox(width: 4),
                    Text(
                      msg.name.isEmpty ? '' : "${msg.name}：",
                      // 🟢 如果是礼物消息，使用黄色，否则使用原来的颜色
                      style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      msg.content,
                      // 🟢 如果是礼物消息，使用黄色，否则使用白色
                      style: TextStyle(color: msg.isGift ? Colors.yellow : Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
