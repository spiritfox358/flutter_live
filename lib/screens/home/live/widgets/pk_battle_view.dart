import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

import '../../../../services/ai_music_service.dart';
import '../models/live_models.dart';
import '../widgets/pk_widgets.dart';

class PKBattleView extends StatefulWidget {
  final VideoPlayerController? leftVideoController;
  final String? leftBgImage;

  // 右侧配置
  final bool isRightVideoMode;
  final VideoPlayerController? rightVideoController;
  final String rightBgImage;

  // PK 数据
  final AIBoss? currentBoss;
  final PKStatus pkStatus;
  final int myScore;
  final int opponentScore;
  final bool isAiRaging;

  // 新增：说话状态控制（默认开启）
  final bool isOpponentSpeaking;

  // 点击回调
  final VoidCallback? onTapOpponent;

  const PKBattleView({
    super.key,
    required this.leftVideoController,
    required this.leftBgImage,
    required this.isRightVideoMode,
    this.rightVideoController,
    required this.rightBgImage,

    required this.currentBoss,
    required this.pkStatus,
    required this.myScore,
    required this.opponentScore,
    this.isAiRaging = false,

    this.isOpponentSpeaking = true, // 默认打开说话波纹

    this.onTapOpponent,
  });

  @override
  State<PKBattleView> createState() => _PKBattleViewState();
}

class _PKBattleViewState extends State<PKBattleView> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _waveController; // 波纹控制器

  @override
  void initState() {
    super.initState();
    // 1. 头像旋转
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 2. 波纹扩散动画 (1.5秒循环一次)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    if (widget.pkStatus == PKStatus.playing) {
      _safePlayMusic();
    }
  }

  @override
  void didUpdateWidget(covariant PKBattleView oldWidget) {
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
    _waveController.dispose(); // 记得销毁
    _safeStopMusic();
    super.dispose();
  }

  void _safePlayMusic() {
    try {
      AIMusicService().playRandomBgm();
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
                Container(color: Colors.black.withOpacity(0.1)),
              ],
            ),
          ),
        ),

        // 中割线
        Container(width: 2, color: Colors.black),

        // --- 右侧：敌方 ---
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: widget.onTapOpponent,
            behavior: HitTestBehavior.opaque,
            child: Container(
              // 注意：这里的 Clip.hardEdge 可能会裁剪掉超出容器的内容
              // 但我们在内部使用了 Expanded 和 Center，通常空间是足够的
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(left: BorderSide(color: Colors.white12, width: 1)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图
                  Image.network(
                    widget.rightBgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
                  ),

                  // 内容区
                  if (widget.isRightVideoMode)
                    _buildRightVideoContent()
                  else
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.black.withOpacity(0.6)),
                        _buildRightAvatarContent(), // 重点修改了这里
                      ],
                    ),

                  // 惩罚遮罩
                  if (isPunishment && isLeftWin)
                    BackdropFilter(
                      filter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: Container(color: Colors.transparent),
                    ),

                  // 暴走特效
                  if (widget.isAiRaging)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red.withOpacity(0.6), width: 2),
                            gradient: RadialGradient(
                              colors: [Colors.transparent, Colors.red.withOpacity(0.3)],
                              stops: const [0.7, 1.0],
                              radius: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightVideoContent() {
    if (widget.rightVideoController != null && widget.rightVideoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: widget.rightVideoController!.value.size.width,
            height: widget.rightVideoController!.value.size.height,
            child: VideoPlayer(widget.rightVideoController!),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  // --- 🔥 重新写的头像 + 波纹逻辑 ---
  Widget _buildRightAvatarContent() {
    if (widget.currentBoss == null) return const SizedBox();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 使用 SizedBox 强制撑开一个大空间 (200x200)，保证波纹不被切掉
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 波纹层：放在最底下
                if (widget.isOpponentSpeaking) ...[
                  // 两个波纹，错开时间
                  _buildFixedWave(delay: 0.0),
                  _buildFixedWave(delay: 0.5),
                ],

                // 头像层：放在中间
                RotationTransition(
                  turns: _rotateController,
                  child: Container(
                    width: 100,
                    height: 100,
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
                          image: NetworkImage(widget.currentBoss!.avatarUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 文字部分 (因为上面 SizedBox 高度是 200，为了视觉紧凑，这里可以把间距设为 0 或者更小)
          const SizedBox(height: 0),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(
              widget.currentBoss!.name,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                min(5, widget.currentBoss!.difficulty),
                    (index) => const Icon(Icons.star, color: Colors.amber, size: 10)
            ),
          )
        ],
      ),
    );
  }

  // --- 🔥 绝对稳健的波纹构建器 ---
  // 不使用 Transform.scale，直接改变容器宽高，避免 Transform 导致的视觉错位
  Widget _buildFixedWave({required double delay}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final double t = (_waveController.value + delay) % 1.0;

        // 核心逻辑：
        // 大小从 100 (头像大小) 变大到 180
        final double currentSize = 100 + (80 * t);

        // 透明度从 0.8 变到 0.0
        final double opacity = (1.0 - t).clamp(0.0, 0.8);

        // 边框宽度从 4 变细到 0
        final double borderWidth = 4 * (1.0 - t);

        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFF0080).withOpacity(opacity), // 亮粉色
              width: borderWidth > 0 ? borderWidth : 0,
            ),
          ),
        );
      },
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