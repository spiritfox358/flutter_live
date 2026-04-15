import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/build_top_bar.dart';

import '../top_bar/viewer_list.dart';

// 🟢 彻底移除 media_kit 后，组件变得极其轻量，可以直接使用 StatelessWidget！
class SingleModeView extends StatelessWidget {
  final String title;
  final String name;
  final String roomId;
  final int onlineCount;
  final String avatar;
  final int anchorId;
  final String currentBgImage;
  final VoidCallback? onClose;

  final GlobalKey<ViewerListState>? viewerListKey;

  // 🚀 核心：只接收 TRTC 的视频组件
  final Widget? trtcVideoView;

  const SingleModeView({
    super.key,
    required this.title,
    required this.name,
    required this.roomId,
    required this.onlineCount,
    required this.avatar,
    required this.currentBgImage,
    required this.anchorId,
    this.onClose,
    this.viewerListKey,
    this.trtcVideoView, // 🚀 只需要它
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 最底层：视频播放器 (彻底只用 TRTC)
        if (trtcVideoView != null)
          SizedBox.expand(child: trtcVideoView!)
        else
          Container(color: Colors.black), // 没有画面时兜底黑屏
        // 2. 遮罩图层：绝美封面图 (AnimatedOpacity 实现丝滑淡出)
        // 核心逻辑：只要 TRTC 的画面传过来了，封面图就自动透明消失！
        AnimatedOpacity(
          opacity: trtcVideoView != null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: IgnorePointer(
            // 如果画面来了，就让点击事件穿透下去
            ignoring: trtcVideoView != null,
            child: Image.network(
              currentBgImage,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: Colors.black),
            ),
          ),
        ),

        // 3. 渐变遮罩层 (让顶部状态栏文字更清晰，不被高光画面影响)
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

        // 4. 顶部栏
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