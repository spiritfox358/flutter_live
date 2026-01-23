import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/live_models.dart';
import '../widgets/pk_widgets.dart'; // 引入 PKStatus 枚举

class PKBattleView extends StatelessWidget {
  final VideoPlayerController? leftVideoController;
  final String? leftBgImage;
  final VideoPlayerController? rightVideoController;
  final String? rightBgImage;

  // 核心参数
  final PKStatus pkStatus;
  final int myScore;
  final int opponentScore;

  final AIBoss? currentBoss;
  final bool isAiRaging;

  const PKBattleView({
    super.key,
    this.leftVideoController,
    this.leftBgImage,
    this.rightVideoController,
    this.rightBgImage,
    required this.pkStatus,
    required this.myScore,
    required this.opponentScore,
    this.currentBoss,
    this.isAiRaging = false,
  });

  @override
  Widget build(BuildContext context) {
    // 判断是否是惩罚时间
    final bool isPunishment = pkStatus == PKStatus.punishment;
    // 判断我方是否胜利 (平局算赢)
    final bool isLeftWin = myScore >= opponentScore;

    return Row(
      children: [
        // ============================
        // 左侧 (我方)
        // ============================
        _buildHalfView(
          videoController: leftVideoController,
          bgImageUrl: leftBgImage,
          // 惩罚阶段 + 我没赢 = 变黑白
          isGrayscale: isPunishment && !isLeftWin,
          // 🔴 修改：这里不再传 resultOverlay (印章)
        ),

        // 中割线
        Container(width: 2, color: Colors.black),

        // ============================
        // 右侧 (敌方/AI)
        // ============================
        _buildHalfView(
          videoController: rightVideoController,
          bgImageUrl: rightBgImage,
          bossInfo: currentBoss,
          isRaging: isAiRaging,
          // 惩罚阶段 + 我赢了(对面输了) = 变黑白
          isGrayscale: isPunishment && isLeftWin,
          // 🔴 修改：这里不再传 resultOverlay (印章)
        ),
      ],
    );
  }

  Widget _buildHalfView({
    VideoPlayerController? videoController,
    String? bgImageUrl,
    AIBoss? bossInfo,
    bool isRaging = false,
    bool isGrayscale = false,
    // Widget? resultOverlay, // 🔴 参数已移除
  }) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 视频/图片层
            _buildVisualContent(videoController, bgImageUrl, isGrayscale),

            // 2. 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.0, 0.3, 1.0],
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            "LV.${bossInfo.difficulty}",
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isRaging)
                          const Text("🔥 暴走中", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))
                      ],
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

            // 4. 暴走特效框 (呼吸红框)
            if (isRaging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.8), width: 4),
                      // 使用 RadialGradient 替代 BoxShadow inset
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,       // 中心透明
                          Colors.red.withOpacity(0.5) // 边缘半透明红
                        ],
                        stops: const [0.7, 1.0],
                        radius: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

            // 🔴 5. 胜负结果印章已移除
          ],
        ),
      ),
    );
  }

  Widget _buildVisualContent(VideoPlayerController? controller, String? bgUrl, bool isGrayscale) {
    Widget content;

    if (controller != null && controller.value.isInitialized) {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    } else if (bgUrl != null) {
      content = Image.network(
        bgUrl,
        fit: BoxFit.cover,
      );
    } else {
      content = Container(color: Colors.grey[900]);
    }

    if (isGrayscale) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        ),
        child: content,
      );
    }

    return content;
  }
}