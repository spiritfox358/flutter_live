import 'package:flutter/material.dart';
import 'dart:ui'; // 引入 fontFeatures

enum PKStatus {
  idle,
  matching,
  playing,
  punishment,
  coHost,
}

// 🟢 组件 1：纯血条
class PKScoreBar extends StatefulWidget {
  final int myScore;
  final int opponentScore;
  final PKStatus status;
  final int secondsLeft;

  const PKScoreBar({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.status,
    required this.secondsLeft,
  });

  @override
  State<PKScoreBar> createState() => _PKScoreBarState();
}

class _PKScoreBarState extends State<PKScoreBar> with TickerProviderStateMixin {
  int _oldMyScore = 0;
  int _addedScore = 0;

  late AnimationController _popController;
  late Animation<double> _popScale;
  late Animation<double> _popOpacity;

  late AnimationController _flashController;
  late Animation<double> _flashValue;

  @override
  void initState() {
    super.initState();
    _oldMyScore = widget.myScore;

    // 飘字动画
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _popScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.0, 0.1, curve: Curves.easeOutExpo)),
    );
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.8, 1.0)),
    );

    // 爆闪动画
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flashValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void didUpdateWidget(covariant PKScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.myScore > _oldMyScore) {
      _addedScore = widget.myScore - _oldMyScore;
      _popController.reset();
      _popController.forward();
      _flashController.reset();
      _flashController.forward().then((_) => _flashController.reverse());
    }
    _oldMyScore = widget.myScore;
  }

  @override
  void dispose() {
    _popController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  String _formatScore(int score) {
    if (score >= 1000000) {
      double w = score / 10000.0;
      return "${w.toStringAsFixed(1)}万";
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == PKStatus.idle) return const SizedBox();

    final total = widget.myScore + widget.opponentScore;
    double targetRatio = total == 0 ? 0.5 : widget.myScore / total;
    targetRatio = targetRatio.clamp(0.15, 0.85);
    final Radius centerRadius = total == 0 ? Radius.zero : const Radius.circular(20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SizedBox(
        height: 18,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: targetRatio),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutExpo,
              builder: (context, ratio, child) {
                final leftWidth = maxWidth * ratio;
                final rightWidth = maxWidth - leftWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // --- 1. 背景/敌方 (蓝色) ---
                    Container(color: Colors.grey[800]),
                    Positioned(
                      right: 0,
                      width: rightWidth + 20.0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF448AFF), Color(0xFF2962FF)],
                          ),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _formatScore(widget.opponentScore),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ),

                    // --- 2. 我方 (红色) ---
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.horizontal(right: centerRadius),
                        child: SizedBox(
                          width: leftWidth,
                          height: 18,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                                  ),
                                ),
                              ),
                              // 爆闪
                              AnimatedBuilder(
                                animation: _flashController,
                                builder: (context, child) {
                                  final double t = _flashValue.value;
                                  final double intensity = 0.60 + (0.15 * t);
                                  final double currentWidth = 20.0 + (15.0 * t);
                                  final double whiteStop = 0.25 + (0.15 * t);
                                  return Positioned(
                                    right: 0, top: 0, bottom: 0, width: currentWidth,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                          stops: [0.0, whiteStop, 1.0],
                                          colors: [
                                            Colors.white.withOpacity(intensity),
                                            Colors.white.withOpacity(intensity * 0.8),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    _formatScore(widget.myScore),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // --- 3. 飘字动画 ---
                    if (_popController.isAnimating || _popController.isCompleted)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: leftWidth,
                        child: AnimatedBuilder(
                          animation: _popController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _popOpacity.value,
                              child: Transform.scale(
                                scale: _popScale.value,
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 15),
                                  child: Text(
                                    "+$_addedScore",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// 🟢 组件 2：倒计时
class PKTimer extends StatelessWidget {
  final int secondsLeft;
  final PKStatus status;
  final int myScore;
  final int opponentScore;

  const PKTimer({
    super.key,
    required this.secondsLeft,
    required this.status,
    required this.myScore,
    required this.opponentScore,
  });

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // 紧急状态：Playing 且 <10s，或 Punishment
    // 注意：coHost 状态下这里不为 true，所以背景会是灰色
    final bool isRedBg = (secondsLeft <= 10 && status == PKStatus.playing) || status == PKStatus.punishment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: _TrapezoidPainter(
            // 浅灰色背景，紧急时刻淡红
            color: isRedBg ? const Color(0xFFFF1744).withOpacity(0.3) : Colors.grey.withOpacity(0.85),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🟢 隐藏 P K 字样：在惩罚时间(punishment) 和 连线中(coHost) 都不显示 P K
                if (status != PKStatus.punishment && status != PKStatus.coHost) ...[
                  const Text("P", style: TextStyle(color: Color(0xFFFF2E56), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 0),
                  const Text("K", style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 6),
                ],
                Text(
                  // 🟢 文案逻辑：
                  // 1. 惩罚/过渡期 -> "惩罚时间 00:20"
                  // 2. 连线中 -> "连线中 00:00" (累加)
                  // 3. PK中 -> "00:00"
                  status == PKStatus.punishment
                      ? "惩罚时间 ${_formatTime(secondsLeft)}"
                      : status == PKStatus.coHost
                      ? "连线中 ${_formatTime(secondsLeft)}"
                      : _formatTime(secondsLeft),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ),

        // 结果提示 (仅惩罚时间显示，连线中不显示)
        if (status == PKStatus.punishment)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              myScore >= opponentScore ? "🎉 我方胜利" : "😭 对方胜利",
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

// 🟢 梯形画笔 (保持您要求的样式)
class _TrapezoidPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;

  _TrapezoidPainter({
    required this.color,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double inset = 4.0;
    const double r = 4.0;
    final double effectiveR = r.clamp(0.0, size.height / 2);

    final path = Path();
    path.moveTo(0, 0); // 左上
    path.lineTo(size.width, 0); // 右上

    // 右下圆角
    final brStartX = size.width - inset * (1.0 - effectiveR / size.height);
    path.lineTo(brStartX, size.height - effectiveR);
    path.quadraticBezierTo(size.width - inset, size.height, size.width - inset - effectiveR, size.height);

    // 底部平直边
    path.lineTo(inset + effectiveR, size.height);

    // 左下圆角
    final blEndX = inset * (1.0 - effectiveR / size.height);
    path.quadraticBezierTo(inset, size.height, blEndX, size.height - effectiveR);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrapezoidPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}