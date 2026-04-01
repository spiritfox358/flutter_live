import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
// 🟢 替换为 media_kit
import 'package:media_kit_video/media_kit_video.dart';
import '../pk_score_bar_widgets.dart';

class PKRealBattleView extends StatefulWidget {
  // --- 左侧配置 (我方/主播) ---
  final VideoController? leftVideoController; // 🟢 修改类型
  final String? leftBgImage;

  // 🟢 新增：左侧头像和名字 (用于非视频模式)
  final String leftAvatarUrl;
  final String leftName;

  // --- 右侧配置 (对手) ---
  final bool isRightVideoMode;
  final VideoController? rightVideoController; // 🟢 修改类型
  final String rightAvatarUrl;
  final String rightName;
  final bool isRotating;
  final String rightBgImage;

  // PK 数据
  final PKStatus pkStatus;
  final int myScore;
  final int opponentScore;

  // 状态控制
  final bool isOpponentSpeaking;
  final VoidCallback? onTapOpponent;

  const PKRealBattleView({
    super.key,
    // 左侧参数
    required this.leftVideoController,
    required this.leftBgImage,
    required this.leftAvatarUrl,
    required this.leftName,
    // 右侧参数
    this.isRightVideoMode = false,
    this.rightVideoController,
    required this.rightAvatarUrl,
    required this.rightName,
    required this.rightBgImage,
    required this.isRotating,

    // 通用参数
    required this.pkStatus,
    required this.myScore,
    required this.opponentScore,
    this.isOpponentSpeaking = true,
    this.onTapOpponent,
  });

  @override
  State<PKRealBattleView> createState() => _PKRealBattleViewState();
}

class _PKRealBattleViewState extends State<PKRealBattleView> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPunishment = widget.pkStatus == PKStatus.punishment;
    final bool isLeftWin = widget.myScore >= widget.opponentScore;

    return Row(
      children: [
        // --- 左侧：我方 ---
        Expanded(
          flex: 1,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(right: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildLeftContent(isPunishment && !isLeftWin),
                Container(color: Colors.transparent),
              ],
            ),
          ),
        ),

        // 中割线
        Container(width: 2, color: Colors.black),

        // --- 右侧：对手 ---
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: widget.onTapOpponent,
            behavior: HitTestBehavior.opaque,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(left: BorderSide(color: Colors.white12, width: 1)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.isRightVideoMode)
                    _buildRightVideoContent(isPunishment && isLeftWin)
                  else
                    _buildRightImageModeContent(isPunishment && isLeftWin),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建左侧内容 (视频 或 复用AvatarView)
  Widget _buildLeftContent(bool showPunishmentMask) {
    // 1. 优先显示视频 (🟢 直接用 Video，不需要判断 isInitialized)
    if (widget.leftVideoController != null) {
      Widget video = SizedBox.expand(
        child: Video(
          controller: widget.leftVideoController!,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        ),
      );

      return RepaintBoundary(
        child: showPunishmentMask ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: video) : video,
      );
    }

    // 2. 无视频时，使用左侧头像作为背景并高斯模糊
    return _buildGenericImageMode(
      avatarUrl: widget.leftAvatarUrl,
      name: widget.leftName,
      isSpeaking: true,
      showPunishmentMask: showPunishmentMask,
      isRotating: false,
    );
  }

  // 构建右侧视频内容
  Widget _buildRightVideoContent(bool isGrayscale) {
    Widget content;
    // 🟢 直接判断 != null
    if (widget.rightVideoController != null) {
      content = SizedBox.expand(
        child: Video(
          controller: widget.rightVideoController!,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        ),
      );
    } else {
      // 视频未准备好时，使用右侧头像作为背景并高斯模糊
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.rightAvatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ],
      );
    }

    return RepaintBoundary(
      child: isGrayscale ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: content) : content,
    );
  }

  // 构建右侧非视频模式
  Widget _buildRightImageModeContent(bool showPunishmentMask) {
    return _buildGenericImageMode(
      avatarUrl: widget.rightAvatarUrl,
      name: widget.rightName,
      isSpeaking: widget.isOpponentSpeaking,
      isRotating: widget.isRotating,
      showPunishmentMask: showPunishmentMask,
    );
  }

  // 通用的非视频模式构建器
  Widget _buildGenericImageMode({
    required String avatarUrl,
    required String name,
    required bool isSpeaking,
    required bool isRotating,
    required bool showPunishmentMask,
  }) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          Center(
            child: AvatarAnimation(
              avatarUrl: avatarUrl,
              name: name,
              isSpeaking: isSpeaking,
              isRotating: isRotating,
            ),
          ),
          if (showPunishmentMask)
            BackdropFilter(
              filter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }
}