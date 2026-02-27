import 'package:flutter/material.dart';
import '../../../../../tools/HttpUtil.dart';
import '../../models/live_models.dart';
import '../profile/live_user_profile_popup.dart';
import 'build_chat_item.dart';

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

  const BuildChatList({super.key, required this.bottomInset, required this.roomId, this.controller});

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
      if (!mounted) return;

      setState(() {
        // 🔍 判断条件：
        // 1. 名字为空 (name == "")
        // 2. 内容包含 "加入直播间"
        bool isJoinSystemMsg = (msg.name == "" || msg.name.isEmpty) && msg.content.contains("加入直播间");

        if (isJoinSystemMsg) {
          // 🧹 如果是系统加入消息，先查找并移除列表中已存在的同类消息
          // 我们遍历列表，找到第一个符合条件的并移除
          _messages.removeWhere((existingMsg) {
            return (existingMsg.name == "" || existingMsg.name.isEmpty) && existingMsg.content.contains("加入直播间");
          });

          // 💡 移除后，再将新消息插入到头部 (index 0)
          _messages.insert(0, msg);
        } else {
          // 📝 普通消息或礼物消息，直接追加
          _messages.insert(0, msg);
        }

        // 📉 可选：限制列表总长度，防止内存溢出 (例如只保留最近 50 条)
        if (_messages.length > 50) {
          _messages.removeLast();
        }
      });
    };

    _fetchChatHistory();
  }

  Future<void> _fetchChatHistory() async {
    try {
      final res = await HttpUtil().get("/api/chat/history", params: {"roomId": int.parse(widget.roomId)});

      if (res != null && res is List && mounted) {
        setState(() {
          for (var item in res) {
            final String name = item['userName'] ?? "神秘人";
            final String content = item['content'] ?? "";
            final String userId = item['userId'].toString();
            final int level = int.tryParse(item['level']?.toString() ?? "0") ?? 0;
            final int monthLevel = int.tryParse(item['monthLevel']?.toString() ?? "0") ?? 0;
            // 🟢 解析主播身份 (假设后端返回字段叫 isAnchor 或 role)
            // 你可能需要根据实际后端字段调整，比如 item['role'] == 'anchor'
            final bool isAnchor = (item['isHost'] ?? 0) == 1;

            final int type = item['type'] ?? 1;
            final bool isGift = (type == 2);
            final Color msgColor = isGift ? Colors.yellow : Colors.white;

            _messages.add(
              ChatMessage(
                name: name,
                content: content,
                level: level,
                monthLevel: monthLevel,
                levelColor: msgColor,
                isGift: isGift,
                isAnchor: isAnchor,
                userId: userId,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("❌ 拉取历史消息失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final transparentBlack = Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.00);
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
            physics: const ClampingScrollPhysics(),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) => BuildChatItem(
              msg: _messages[index],
              onNameTap: (msg) {
                Map<String, dynamic> user = {"userId": msg.userId};
                LiveUserProfilePopup.show(context, user);
              },
            ),
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
