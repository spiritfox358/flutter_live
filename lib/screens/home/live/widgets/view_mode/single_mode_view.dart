import 'dart:async';
import 'package:flutter/material.dart';
// 🟢 换成 media_kit
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_live/screens/home/live/widgets/top_bar/build_top_bar.dart';

import '../top_bar/viewer_list.dart';

class SingleModeView extends StatefulWidget {
  final String title;
  final String name;
  final String roomId;
  final int onlineCount;
  final String avatar;
  final int anchorId;
  final bool isVideoBackground;
  final bool isBgInitialized;
  final VideoController? bgController; // 🟢 media_kit VideoController
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
  State<SingleModeView> createState() => _SingleModeViewState();
}

class _SingleModeViewState extends State<SingleModeView> {
  bool _isVideoReady = false;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _setupVideoListener();
  }

  @override
  void didUpdateWidget(SingleModeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bgController != oldWidget.bgController) {
      _setupVideoListener();
    }

    if (!widget.isVideoBackground && oldWidget.isVideoBackground) {
      setState(() {
        _isVideoReady = false;
      });
    }
  }

  void _setupVideoListener() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (widget.isVideoBackground && widget.bgController != null) {
      final player = widget.bgController!.player;

      // 检查当前是否已经播过 50ms 了
      if (player.state.position.inMilliseconds > 50) {
        if (mounted && !_isVideoReady) {
          setState(() => _isVideoReady = true);
        }
      }

      // 🟢 完美抄袭推荐流的逻辑：死盯进度条！
      _positionSubscription = player.stream.position.listen((position) {
        // 只要进度走过了 50 毫秒，直接掀开封面图，绝不拖泥带水
        if (mounted && !_isVideoReady && position.inMilliseconds > 50) {
          setState(() {
            _isVideoReady = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层：视频播放器
        // 只要传入了 isVideoBackground，底层就垫着视频播放器去缓冲
        if (widget.isVideoBackground && widget.isBgInitialized && widget.bgController != null)
          SizedBox.expand(
            child: Video(
              controller: widget.bgController!,
              fit: BoxFit.cover,
              controls: NoVideoControls, // 隐藏默认控制条
            ),
          )
        else
        // 兜底底色
          Container(color: Colors.black),

        // 2. 遮罩图层：封面图 (AnimatedOpacity 实现丝滑淡出)
        // 核心逻辑：如果是不是视频模式，或者视频模式下视频还未 Ready，就显示封面图
        AnimatedOpacity(
          opacity: (!widget.isVideoBackground || !_isVideoReady) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300), // 淡出动画时长
          curve: Curves.easeOut,
          // ignorePointer：当它变透明时，不拦截底部的点击事件
          child: IgnorePointer(
            ignoring: widget.isVideoBackground && _isVideoReady,
            child: Image.network(
              widget.currentBgImage,
              fit: BoxFit.cover,
              // 如果图片没加载出来，给个安全的黑底
              errorBuilder: (ctx, err, stack) => Container(color: Colors.black),
            ),
          ),
        ),

        // 3. 渐变遮罩层 (让顶部状态栏文字更清晰)
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
              roomId: widget.roomId,
              onlineCount: widget.onlineCount,
              title: widget.title,
              name: widget.name,
              avatar: widget.avatar,
              onClose: widget.onClose,
              anchorId: widget.anchorId,
              viewerListKey: widget.viewerListKey,
            ),
          ),
        ),
      ],
    );
  }
}