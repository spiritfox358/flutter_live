import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// 黄金光束特效组件
/// 
/// 用于背景层，提供高性能、可配置的流光溢彩效果。
/// 建议放置在 [Stack] 的底层。
class ShineBeamEffect extends StatefulWidget {
  /// 光束的主色调 (默认：金色)
  final Color color;

  /// 光束的数量 (建议范围：5 ~ 20，默认：10)
  /// 数量越多，光束越密集，但 GPU 负载也会增加。
  final int beamCount;

  /// 动画流动的速度倍率 (默认：1.0)
  /// 1.0 为标准呼吸速度，数值越大越快。
  final double speed;

  /// 光束根部的宽度 (默认：20.0)
  /// 数值越大，光束越粗壮，更有“大口径”的感觉。
  final double beamWidth;

  const ShineBeamEffect({
    super.key,
    this.color = const Color(0xFFFFD700),
    this.beamCount = 10,
    this.speed = 1.0,
    this.beamWidth = 20.0,
  });

  @override
  State<ShineBeamEffect> createState() => _ShineBeamEffectState();
}

class _ShineBeamEffectState extends State<ShineBeamEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 用于累加时间的变量，保证变速时动画平滑过渡
  double _simulationTime = 0.0;
  double _lastTimestamp = 0.0;

  @override
  void initState() {
    super.initState();
    // 这里的 duration 只是为了驱动 ticker，不代表实际动画周期
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 性能核心：RepaintBoundary 隔离重绘区域
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 计算两帧之间的时间差 (Delta Time)
          double now = DateTime.now().millisecondsSinceEpoch / 1000.0;
          if (_lastTimestamp == 0) _lastTimestamp = now;
          double dt = now - _lastTimestamp;
          _lastTimestamp = now;

          // 根据传入的 speed 累加时间
          // 除以 30.0 是为了将标准速度归一化到我们舒适的呼吸节奏
          if (dt > 0.1) dt = 0.016; // 防止页面暂停后切回来的时间跳跃
          _simulationTime += dt * (widget.speed / 30.0);

          return CustomPaint(
            painter: _GoldenBeamPainter(
              progress: _simulationTime,
              beamCount: widget.beamCount,
              baseWidth: widget.beamWidth,
              color: widget.color,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GoldenBeamPainter extends CustomPainter {
  final double progress;
  final int beamCount;
  final double baseWidth;
  final Color color;

  _GoldenBeamPainter({
    required this.progress,
    required this.beamCount,
    required this.baseWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..blendMode = BlendMode.screen;

    // --- 配置区域：如需调整光束方向，修改这里 ---
    // 起点：左侧 23% 高度
    final Offset sourceOrigin = Offset(-50, size.height * 0.23);
    // 终点方向：右侧 60% 高度
    final Offset targetDirection = Offset(size.width, size.height * 0.60);
    // ---------------------------------------

    double mainAngle = math.atan2(
      targetDirection.dy - sourceOrigin.dy,
      targetDirection.dx - sourceOrigin.dx,
    );

    // 高斯模糊：性能消耗的主要来源，3.0 是性价比比较好的值
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (int i = 0; i < beamCount; i++) {
      // 1. 主要波动：控制摆动
      double mainWave = math.sin(progress * math.pi * 2 + (i * 0.4));

      // 2. 呼吸波动：控制张合
      double breathingWave = math.sin(progress * math.pi * 2 + (i * 0.2) + math.pi / 4);

      // --- 动态计算 ---
      // 自动计算分散系数：光束越少散得越开，光束越多收得越紧
      double dynamicSpreadFactor = 0.55 / math.max(beamCount, 5);
      double baseSpread = (i - beamCount / 2) * dynamicSpreadFactor;

      double currentSpread = baseSpread * (1.0 + breathingWave * 0.12);
      double currentAngle = mainAngle + currentSpread + (mainWave * 0.007);

      // 宽度与呼吸
      double calculatedStartWidth = baseWidth + (i % 5) * 2.5 + (i % 2) * 1.5;
      double currentStartWidth = calculatedStartWidth * (1.0 + breathingWave * 0.06);

      // 长度：延伸至屏幕外
      double length = size.width * 2.5;

      // 透明度呼吸
      double alpha = 0.04 + ((mainWave + 1) / 2) * 0.07;

      // 绘制渐变
      paint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withOpacity(alpha),
          color.withOpacity(alpha * 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 1.2, size.height));

      _drawRay(canvas, sourceOrigin, currentAngle, currentStartWidth, length, paint);
    }
  }

  void _drawRay(Canvas canvas, Offset origin, double angle, double startWidth, double length, Paint paint) {
    Path path = Path();

    double dx = math.cos(angle + math.pi / 2);
    double dy = math.sin(angle + math.pi / 2);

    Offset p1 = Offset(origin.dx - dx * startWidth, origin.dy - dy * startWidth);
    Offset p2 = Offset(origin.dx + dx * startWidth, origin.dy + dy * startWidth);

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);

    double endWidth = startWidth * 7.0;

    Offset endCenter = Offset(
        origin.dx + math.cos(angle) * length,
        origin.dy + math.sin(angle) * length
    );

    Offset p3 = Offset(endCenter.dx + dx * endWidth, endCenter.dy + dy * endWidth);
    Offset p4 = Offset(endCenter.dx - dx * endWidth, endCenter.dy - dy * endWidth);

    path.lineTo(p3.dx, p3.dy);
    path.lineTo(p4.dx, p4.dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldenBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.beamCount != beamCount ||
        oldDelegate.baseWidth != baseWidth ||
        oldDelegate.color != color;
  }
}