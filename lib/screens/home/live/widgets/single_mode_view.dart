import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/build_chat_list.dart';
import 'package:flutter_live/screens/home/live/widgets/build_input_bar.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';
import '../models/live_models.dart';
class SingleModeView extends StatelessWidget {
  final bool isVideoBackground;
  final bool isBgInitialized;
  final VideoPlayerController? bgController;
  final String currentBgImage;
  final List<ChatMessage> messages;
  final TextEditingController textController;
  final VoidCallback onTapGift;
  final VoidCallback onStartPK;
  final Function(String) onSendMessage;

  const SingleModeView({
    super.key,
    required this.isVideoBackground,
    required this.isBgInitialized,
    required this.bgController,
    required this.currentBgImage,
    required this.messages,
    required this.textController,
    required this.onTapGift,
    required this.onStartPK,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景
        isVideoBackground
            ? (isBgInitialized && bgController != null
            ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
                width: bgController!.value.size.width,
                height: bgController!.value.size.height,
                child: VideoPlayer(bgController!)))
            : Container(color: Colors.black))
            : Image.network(currentBgImage, fit: BoxFit.cover),

        // 遮罩
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              stops: const [0.0, 0.2],
            ),
          ),
        ),

        // 顶部栏
        const Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: BuildTopBar(title: "直播间"))),

        // 聊天列表
        Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 300,
              child: BuildChatList(bottomInset: 0, messages: messages),
            ),
            BuildInputBar(
              textController: textController,
              onTapGift: onTapGift,
              onSend: onSendMessage,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),

        // PK 按钮
        Positioned(
          bottom: 120, right: 20,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onStartPK,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eighteen_mp, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text("发起PK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}