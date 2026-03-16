// ==========================================
// 🔥 新增：纯原生跳动火苗粒子特效组件 (猛火连贯版)
// ==========================================
import 'dart:math';
import 'package:flutter/material.dart';

class JumpingFlameEffect extends StatefulWidget {
  const JumpingFlameEffect({super.key});

  @override
  State<JumpingFlameEffect> createState() => _JumpingFlameEffectState();
}

class _JumpingFlameEffectState extends State<JumpingFlameEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FlameParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // 动画控制器，用作引擎驱动粒子不断更新
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

    // 💡 引擎预热：瞬间模拟前 80 帧的物理轨迹，确保一上来看见的就是满状态的火，消除开局的空白
    for (int i = 0; i < 80; i++) {
      _updateParticles();
    }

    _controller.addListener(() {
      setState(() {
        _updateParticles();
      });
    });
  }

  void _updateParticles() {
    _particles.removeWhere((p) => p.life <= 0);

    for (int i = 0; i < 3; i++) {
      _particles.add(_createParticle());
    }

    for (var p in _particles) {
      p.y -= p.speed;
      p.x += sin(p.life * 25) * 0.004;

      // 💡 调整这里控制火焰的整体高度！
      // 数字越大，火苗死得越快，火就越矮。原本是 0.012，改为 0.018 可以让火矮大约 1/3
      p.life -= 0.018;

      p.size *= 0.98;
    }
  }

  // 生成一个全新的火苗粒子
  _FlameParticle _createParticle() {
    return _FlameParticle(
      x: _random.nextDouble(), // 随机横向位置
      // 💡 出生点死死锚定在底部 (1.0 代表最底部，1.1 代表超出格子底边的下方，确保无缝隙)
      y: 1.0 + _random.nextDouble() * 0.15,
      // 💡 火苗体积大幅增加：基础半径 20，最大可达 45
      size: _random.nextDouble() * 25 + 20,
      life: 1.0 + _random.nextDouble() * 0.2, // 初始生命值
      speed: _random.nextDouble() * 0.015 + 0.008, // 随机升空速度
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // 👇 这里加上 _FlamePainter
      painter: _FlamePainter(particles: _particles),
      child: Container(),
    );
  }
}

class _FlameParticle {
  double x; double y; double size; double life; double speed;
  _FlameParticle({required this.x, required this.y, required this.size, required this.life, required this.speed});
}

class _FlamePainter extends CustomPainter {
  final List<_FlameParticle> particles;

  _FlamePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    // 🔪 核心修复：增加这一行裁剪代码！强制把超出格子边界的火苗“切”掉，绝不越界！
    canvas.clipRect(Offset.zero & size);

    // 1. 强力底座铺垫
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF5000).withOpacity(0.95),
          const Color(0xFFD83020).withOpacity(0.6),
          Colors.transparent
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5), basePaint);

    // 2. 绘制所有跳动的火苗粒子
    for (var p in particles) {
      final paint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            _getFlameColor(p.life).withOpacity((p.life * 1.5).clamp(0.0, 1.0)),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: Offset(p.x * size.width, p.y * size.height), radius: p.size));

      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  Color _getFlameColor(double life) {
    if (life > 0.8) return const Color(0xFFFFE000);
    if (life > 0.5) return const Color(0xFFFF7000);
    return const Color(0xFFFF0000);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}