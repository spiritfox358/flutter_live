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

  // 新增：说话波纹控制 (默认为 true)
  final bool isOpponentSpeaking;

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
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 波纹动画
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    _waveController.dispose();
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
                  Image.network(
                    widget.rightBgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
                  ),
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black.withOpacity(0.6)),
                      _buildRightAvatarContent(),
                    ],
                  ),
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

  Widget _buildRightAvatarContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⬇️ 修改：尺寸从 200 缩小到 140，刚刚好包裹住波纹即可
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isOpponentSpeaking) ...[
                  _buildFixedWave(delay: 0.0),
                  _buildFixedWave(delay: 0.5),
                ],

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
                          image: NetworkImage(widget.rightAvatarUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 0),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(
              widget.rightName,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ⬇️ 修改：微调波纹参数，使其更精致
  Widget _buildFixedWave({required double delay}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final double t = (_waveController.value + delay) % 1.0;

        // 1. 范围缩小：只向外扩散 35px (100 -> 135)
        final double currentSize = 100 + (35 * t);

        // 2. 透明度降低：最大透明度 0.5，更隐约
        final double opacity = (1.0 - t).clamp(0.0, 0.5);

        // 3. 线条变细：从 2.0 开始变细
        final double borderWidth = 2.0 * (1.0 - t);

        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFF0080).withOpacity(opacity),
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