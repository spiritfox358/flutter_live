import 'package:flutter/material.dart';
// 🟢 换成 media_kit
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/build_top_bar.dart';

import '../top_bar/viewer_list.dart';

class SingleModeView extends StatelessWidget {
  final String title;
  final String name;
  final String roomId;
  final int onlineCount;
  final String avatar;
  final int anchorId;
  final bool isVideoBackground;
  final bool isBgInitialized;
  final VideoController? bgController; // 🟢 修改为 VideoController
  final String currentBgImage;
  final VoidCallback? onClose;

  final GlobalKey<ViewerListState>? viewerListKey;

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
    required this.anchorId,
    this.onClose,
    this.viewerListKey,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 背景层
        isVideoBackground
        // 🟢 直接利用 media_kit 的 Video 渲染
            ? (isBgInitialized && bgController != null
            ? SizedBox.expand(
          child: Video(
            controller: bgController!,
            fit: BoxFit.cover,
            controls: NoVideoControls, // 隐藏默认控制条
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
            child: BuildTopBar(
              key: const ValueKey("TopBar"),
              roomId: roomId,
              onlineCount: onlineCount,
              title: title,
              name: name,
              avatar: avatar,
              onClose: onClose,
              anchorId: anchorId,
              viewerListKey: viewerListKey,
            ),
          ),
        ),
      ],
    );
  }
}