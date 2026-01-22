import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/live_models.dart';

class PKBattleView extends StatelessWidget {
  final VideoPlayerController? leftVideoController;
  final String? leftBgImage;
  final VideoPlayerController? rightVideoController;
  final String? rightBgImage;
  final AIBoss? currentBoss;
  final bool isAiRaging;

  const PKBattleView({
    super.key,
    this.leftVideoController,
    this.leftBgImage,
    this.rightVideoController,
    this.rightBgImage,
    this.currentBoss,
    this.isAiRaging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧 (我方)
        _buildHalfView(
          videoController: leftVideoController,
          bgImageUrl: leftBgImage,
        ),
        // 中割线
        Container(width: 1.5, color: Colors.black),
        // 右侧 (敌方/AI)
        _buildHalfView(
          videoController: rightVideoController,
          bgImageUrl: rightBgImage,
          bossInfo: currentBoss,
          isRaging: isAiRaging,
        ),
      ],
    );
  }

  Widget _buildHalfView({
    VideoPlayerController? videoController,
    String? bgImageUrl,
    AIBoss? bossInfo,
    bool isRaging = false,
  }) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 背景层 (视频 > 图片 > 纯色)
            if (videoController != null && videoController.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoController.value.size.width,
                    height: videoController.value.size.height,
                    child: VideoPlayer(videoController),
                  ),
                ),
              )
            else if (bgImageUrl != null)
              Image.network(
                bgImageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
              )
            else
              Container(color: Colors.grey[900]),

            // 2. 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.2, 1.0],
                ),
              ),
            ),

            // 3. Boss 信息
            if (bossInfo != null)
              Positioned(
                bottom: 10, left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "LV.${bossInfo.difficulty}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bossInfo.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                  ],
                ),
              ),

            // 4. 暴走特效框
            if (isRaging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.6), width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}