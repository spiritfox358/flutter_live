import 'package:flutter/material.dart';
import '../models/live_models.dart';
import 'build_chat_item.dart';
import '../../../../tools/HttpUtil.dart';

class ChatListController {
  void Function(ChatMessage msg)? _onNewMessageAdd;

  void addMessage(ChatMessage msg) {
    _onNewMessageAdd?.call(msg);
  }
}

class BuildChatList extends StatefulWidget {
  final double bottomInset;
  final String roomId;
  final ChatListController? controller;

  const BuildChatList({
    super.key,
    required this.bottomInset,
    required this.roomId,
    this.controller,
  });

  @override
  State<BuildChatList> createState() => _BuildChatListState();
}

class _BuildChatListState extends State<BuildChatList> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    widget.controller?._onNewMessageAdd = (msg) {
      if (mounted) {
        setState(() {
          _messages.insert(0, msg);
        });
      }
    };

    _fetchChatHistory();
  }

  Future<void> _fetchChatHistory() async {
    try {
      final res = await HttpUtil().get(
          "/api/chat/history",
          params: {"roomId": int.parse(widget.roomId)}
      );

      if (res != null && res is List && mounted) {
        setState(() {
          for (var item in res) {
            final String name = item['userName'] ?? "神秘人";
            final String content = item['content'] ?? "";
            final int level = int.tryParse(item['level']?.toString() ?? "0") ?? 0;
            // 🟢 解析主播身份 (假设后端返回字段叫 isAnchor 或 role)
            // 你可能需要根据实际后端字段调整，比如 item['role'] == 'anchor'
            final bool isAnchor = item['isAnchor'] ?? false;

            final int type = item['type'] ?? 1;
            final bool isGift = (type == 2);
            final Color msgColor = isGift ? Colors.yellow : Colors.white;

            _messages.add(ChatMessage(
              name: name,
              content: content,
              level: level,
              levelColor: msgColor,
              isGift: isGift,
              isAnchor: isAnchor, // 🟢 传入 isAnchor
            ));
          }
        });
      }
    } catch (e) {
      debugPrint("❌ 拉取历史消息失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final transparentBlack = Colors.black.withValues(
      red: 0, green: 0, blue: 0, alpha: 0.09,
    );

    return Container(
      color: transparentBlack,
      child: Container(
        color: Colors.transparent,
        height: widget.bottomInset > 0 ? 150 : 250,
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
            controller: _scrollController,
            padding: EdgeInsets.zero,
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) => BuildChatItem(msg: _messages[index]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.controller?._onNewMessageAdd = null;
    super.dispose();
  }
}