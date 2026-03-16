
// ==========================================
// 🔥 新增：纯原生边缘呼吸发光特效组件
// ==========================================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BreathingGlowEffect extends StatefulWidget {
  const BreathingGlowEffect({super.key});

  @override
  State<BreathingGlowEffect> createState() => _BreathingGlowEffectState();
}

class _BreathingGlowEffectState extends State<BreathingGlowEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 动画时长 1秒，采用往复运动(repeat reverse)模拟呼吸效果
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    // 使用 easeInOut 曲线让呼吸更加自然平滑
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // 计算当前透明度：基础值 0.3 + 动态增量最高 0.6 = 最高 0.9 透明度
        final double opacity = 0.3 + (_animation.value * 0.6);
        final glowColor = const Color(0xFFFF3B30).withOpacity(opacity); // 苹果红，你也可以换成纯红 Colors.red

        return Stack(
          children: [
            // 1. 底部红光 (从下往上渐变)
            Positioned(
              left: 0, right: 0, bottom: 0, height: 60, // 底部发光高度
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),

            // 2. 左侧红光 (从左往右渐变)
            Positioned(
              left: 0, top: 0, bottom: 0, width: 30, // 左侧发光宽度
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    // 侧边光可以比底边稍微弱一点，乘以 0.8
                    colors: [glowColor.withOpacity(opacity * 0.8), Colors.transparent],
                  ),
                ),
              ),
            ),

            // 3. 右侧红光 (从右往左渐变)
            Positioned(
              right: 0, top: 0, bottom: 0, width: 30, // 右侧发光宽度
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight, end: Alignment.centerLeft,
                    colors: [glowColor.withOpacity(opacity * 0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}