import 'package:flutter/material.dart';

class BuildInputBar extends StatelessWidget {
  // 接收外部传入的控制器
  final TextEditingController textController;

  // 定义回调函数，把操作权交给父组件
  final Function(String) onSend; // 当点击发送时
  final VoidCallback onTapGift;  // 当点击礼物时

  const BuildInputBar({
    super.key,
    required this.textController,
    required this.onSend,
    required this.onTapGift,
  });

  // 内部处理发送逻辑：触发回调 -> 清空输入框 -> 收起键盘
  void _handleSend(BuildContext context) {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // 1. 把文字传给父组件去处理 (比如添加到列表)
    onSend(text);

    // 2. UI清理工作
    textController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.pinkAccent,
                textInputAction: TextInputAction.send,
                // 传入 context 以便收起键盘
                onSubmitted: (_) => _handleSend(context),
                decoration: InputDecoration(
                  hintText: "说点什么...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.pinkAccent,
                      size: 20,
                    ),
                    onPressed: () => _handleSend(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30),
          const SizedBox(width: 10),
          // 点击礼物按钮
          GestureDetector(
            onTap: onTapGift, // 触发外部传入的回调
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.pinkAccent,
              size: 30,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.reply, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}