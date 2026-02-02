import 'package:flutter/material.dart';

class AvatarAnimation extends StatefulWidget {
  final String avatarUrl;
  final String name;
  final bool isSpeaking;
  final bool isRotating; // 控制旋转的开关

  const AvatarAnimation({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.isSpeaking,
    this.isRotating = true, // 默认为 true
  });

  @override
  State<AvatarAnimation> createState() => _AvatarAnimationState();
}

class _AvatarAnimationState extends State<AvatarAnimation> with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // 1. 初始化旋转控制器 (10秒一圈)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // 2. 初始化波纹控制器 (2秒一次)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    // 组件销毁时，自动释放控制器，不用父组件操心
    _rotateController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 波纹动画
              if (widget.isSpeaking) ...[
                _buildFixedWave(delay: 0.0),
                _buildFixedWave(delay: 0.5),
              ],

              // 旋转部分
              RotationTransition(
                // 根据开关决定是否使用旋转动画
                turns: widget.isRotating ? _rotateController : const AlwaysStoppedAnimation(0),
                child: _buildAvatarBody(),
              ),
            ],
          ),
        ),
        _buildNameLabel(),
      ],
    );
  }

  Widget _buildAvatarBody() {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4081).withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
            image: NetworkImage(widget.avatarUrl),
            fit: BoxFit.cover,
            onError: (obj, stack) {},
          ),
        ),
      ),
    );
  }

  Widget _buildNameLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        widget.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFixedWave({required double delay}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final double t = (_waveController.value + delay) % 1.0;
        final double currentSize = 100 + (35 * t);
        final double opacity = (1.0 - t).clamp(0.0, 0.5);
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
}