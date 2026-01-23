import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/build_top_bar.dart';

class SingleModeView extends StatelessWidget {
  final bool isVideoBackground;
  final bool isBgInitialized;
  final VideoPlayerController? bgController;
  final String currentBgImage;
  final VoidCallback? onClose;

  const SingleModeView({
    super.key,
    required this.isVideoBackground,
    required this.isBgInitialized,
    required this.bgController,
    required this.currentBgImage,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 背景层 (视频或图片)
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

        // 2. 黑色渐变遮罩 (让顶部文字更清晰)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              stops: const [0.0, 0.2],
            ),
          ),
        ),

        // 3. 顶部栏 (只保留这个，其他 UI 全部移交 index.dart)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: BuildTopBar(
              title: "直播间",
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}