import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

import '../../../../services/ai_music_service.dart';
import '../widgets/pk_widgets.dart';

class PKRealBattleView extends StatefulWidget {
  final VideoPlayerController? leftVideoController;
  final String? leftBgImage;

  // 右侧配置 (真人对手)
  final String rightAvatarUrl;
  final String rightName;
  final String rightBgImage;

  // PK 数据
  final PKStatus pkStatus;
  final int myScore;
  final int opponentScore;

  // 点击回调
  final VoidCallback? onTapOpponent;

  const PKRealBattleView({
    super.key,
    required this.leftVideoController,
    required this.leftBgImage,
    required this.rightAvatarUrl,
    required this.rightName,
    required this.rightBgImage,
    required this.pkStatus,
    required this.myScore,
    required this.opponentScore,
    this.onTapOpponent,
  });

  @override
  State<PKRealBattleView> createState() => _PKRealBattleViewState();
}

class _PKRealBattleViewState extends State<PKRealBattleView> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    // 保留您原有的旋转动画逻辑
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    if (widget.pkStatus == PKStatus.playing) {
      _safePlayMusic();
    }
  }

  @override
  void didUpdateWidget(covariant PKRealBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pkStatus != widget.pkStatus) {
      if (widget.pkStatus == PKStatus.playing) {
        _safePlayMusic();
      } else {
        _safeStopMusic();
      }
    }
  }

  @override
  void deactivate() {
    _safeStopMusic();
    super.deactivate();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _safeStopMusic();
    super.dispose();
  }

  void _safePlayMusic() {
    try {
      AIMusicService().playRandomBattleMusic();
    } catch (e) {
      debugPrint("播放音乐失败: $e");
    }
  }

  void _safeStopMusic() {
    try {
      AIMusicService().stopMusic();
    } catch (e) {
      debugPrint("停止音乐失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPunishment = widget.pkStatus == PKStatus.punishment;
    final bool isLeftWin = widget.myScore >= widget.opponentScore;

    return Row(
      children: [
        // --- 左侧：我方 (主视角) ---
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
                Container(color: Colors.black.withOpacity(0.1)),
              ],
            ),
          ),
        ),

        // 中割线
        Container(width: 2, color: Colors.black),

        // --- 右侧：真人对手 ---
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
                  // 对手背景图
                  Image.network(
                    widget.rightBgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
                  ),

                  // 对手层级覆盖
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black.withOpacity(0.6)),
                      _buildRightAvatarContent(), // 构建对手旋转头像
                    ],
                  ),

                  // 惩罚阶段的置灰滤镜逻辑
                  if (isPunishment && isLeftWin)
                    BackdropFilter(
                      filter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: Container(color: Colors.transparent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建右侧：旋转头像模式 (适配真人)
  Widget _buildRightAvatarContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _rotateController,
            child: Container(
              width: 100, height: 100,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF4081).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                    image: NetworkImage(widget.rightAvatarUrl), // 使用真人对手头像
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 对手名字标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(
              widget.rightName, // 使用真人对手名字
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftContent(bool isGrayscale) {
    Widget content;
    if (widget.leftVideoController != null && widget.leftVideoController!.value.isInitialized) {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: widget.leftVideoController!.value.size.width,
            height: widget.leftVideoController!.value.size.height,
            child: VideoPlayer(widget.leftVideoController!),
          ),
        ),
      );
    } else if (widget.leftBgImage != null) {
      content = Image.network(widget.leftBgImage!, fit: BoxFit.cover);
    } else {
      content = Container(color: Colors.black);
    }

    if (isGrayscale) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: content,
      );
    }
    return content;
  }
}