import 'package:flutter/material.dart';
import '../index.dart';
import 'build_chat_item.dart';

class BuildChatList extends StatelessWidget {
  // 如果需要从外部传递数据，可以定义构造函数
  final double bottomInset;
  final List<ChatMessage> messages;

  const BuildChatList({
    super.key,
    required this.bottomInset,
    required this.messages,
  });

  // 可选：添加 key 或其他参数
  @override
  Widget build(BuildContext context) {
    final transparentBlack = Colors.black.withValues(
      red: 0,
      green: 0,
      blue: 0,
      alpha: 0.09, // 0.1 * 255 ≈ 25.5 → round to 26
    );
    return Container(
      color: transparentBlack,
      child: Container(
        color: Colors.transparent,
        height: bottomInset > 0 ? 150 : 250,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white],
            stops: const [0.0, 0.1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) =>
                BuildChatItem(msg: messages[index]),
          ),
        ),
      ),
    );
  }
}
