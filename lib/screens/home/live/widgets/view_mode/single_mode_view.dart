import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/build_top_bar.dart';

class SingleModeView extends StatelessWidget {
  final String title;
  final String name;
  final String roomId;
  final int onlineCount;
  final String avatar;
  final int anchorId;
  final bool isVideoBackground;
  final bool isBgInitialized;
  final VideoPlayerController? bgController;
  final String currentBgImage;
  final VoidCallback? onClose;

  const SingleModeView({
    super.key,
    required this.isVideoBackground,
    required this.title,
    required this.name,
    required this.roomId,
    required this.onlineCount,
    required this.avatar,
    required this.isBgInitialized,
    required this.bgController,
    required this.currentBgImage,
    this.onClose, required this.anchorId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 背景层
        isVideoBackground
            ? (isBgInitialized && bgController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: bgController!.value.size.width,
                        height: bgController!.value.size.height,
                        child: VideoPlayer(bgController!),
                      ),
                    )
                  : Container(color: Colors.black))
            : Image.network(currentBgImage, fit: BoxFit.cover),

        // 2. 遮罩层
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              stops: const [0.0, 0.2],
            ),
          ),
        ),

        // 3. 顶部栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: BuildTopBar(roomId: roomId, onlineCount: onlineCount, title: title, name: name, avatar: avatar, onClose: onClose, anchorId: anchorId,),
          ),
        ),
      ],
    );
  }
}
