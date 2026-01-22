import 'package:flutter/material.dart';
import 'dart:ui'; // 引入 fontFeatures

enum PKStatus {
  idle,
  matching,
  playing,
  punishment,
  coHost,
}

class PKScoreBar extends StatefulWidget {
  final int myScore;
  final int opponentScore;
  final int secondsLeft;
  final PKStatus status;

  const PKScoreBar({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.secondsLeft,
    required this.status,
  });

  @override
  State<PKScoreBar> createState() => _PKScoreBarState();
}

class _PKScoreBarState extends State<PKScoreBar> with TickerProviderStateMixin {
  int _oldMyScore = 0;
  int _addedScore = 0;

  // 飘字动画
  late AnimationController _popController;
  late Animation<double> _popScale;
  late Animation<double> _popOpacity;

  // 爆闪动画控制器
  late AnimationController _flashController;
  late Animation<double> _flashValue;

  @override
  void initState() {
    super.initState();
    _oldMyScore = widget.myScore;

    // --- 飘字动画 (3秒) ---
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 极速快出 (0.3秒弹出)
    _popScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _popController,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOutExpo),
      ),
    );

    // 停留久 (最后0.6秒才消失)
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _popController,
        curve: const Interval(0.8, 1.0),
      ),
    );

    // --- 爆闪动画 ---
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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

      // 触发爆闪
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

  // 时间格式化
  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == PKStatus.idle) return const SizedBox();

    final total = widget.myScore + widget.opponentScore;
    double targetRatio = total == 0 ? 0.5 : widget.myScore / total;
    targetRatio = targetRatio.clamp(0.15, 0.85);

    // 逻辑：如果都没分(total=0)，中间是直角；一旦有分，中间变圆角
    final Radius centerRadius = total == 0 ? Radius.zero : const Radius.circular(20);

    // 逻辑：紧急时刻判断 (最后10秒 & 正在PK)
    final bool isUrgent = widget.secondsLeft <= 10 && widget.status == PKStatus.playing;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ==============================
          // 1. 核心血条区域
          // ==============================
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;

              return SizedBox(
                height: 18,
                child: TweenAnimationBuilder<double>(
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
                        // --- 层级1: 背景槽 ---
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            // 背景始终直角
                          ),
                        ),

                        // --- 层级2: 右侧敌方 (蓝色，垫底) ---
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
                              // 蓝色条始终直角
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _formatScore(widget.opponentScore),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // --- 层级3: 左侧我方 (红色) ---
                        Align(
                          alignment: Alignment.centerLeft,
                          // 使用 centerRadius 变量，0分时直角，有分时圆角
                          child: ClipRRect(
                            borderRadius: BorderRadius.horizontal(
                              right: centerRadius,
                            ),
                            child: SizedBox(
                              width: leftWidth,
                              height: 18,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 红色底色
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                                      ),
                                    ),
                                  ),

                                  // 保留爆闪光效
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

                                  // 分数文字
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        _formatScore(widget.myScore),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- 层级4: 飘字动画 ---
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
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          // ==============================
          // 2. 倒计时部分 (已优化：背景更亮、边框更细、PK有间隙)
          // ==============================
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              // 🟢 修改1：紧急时刻颜色改亮一点 (从深红 D50000 -> 亮红Accent FF1744)，并加点透明度
              color: isUrgent ? const Color(0xFFFF1744).withOpacity(0.9) : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              // 🟢 修改2：边框宽度从 1.5 -> 1.0
              border: isUrgent ? Border.all(color: Colors.yellowAccent, width: 1.0) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.status != PKStatus.punishment) ...[
                  // P: 红色
                  const Text(
                    "P",
                    style: TextStyle(
                      color: Color(0xFFFF2E56),
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.0,
                      shadows: [Shadow(color: Colors.black26, offset: Offset(1,1))],
                    ),
                  ),

                  // 🟢 修改3：这里加一个间隙，让 P 和 K 分开一点
                  const SizedBox(width: 0),

                  // K: 蓝色
                  const Text(
                    "K",
                    style: TextStyle(
                      color: Color(0xFF2979FF),
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.0,
                      shadows: [Shadow(color: Colors.black26, offset: Offset(1,1))],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 倒计时数字
                Text(
                  widget.status == PKStatus.punishment
                      ? "惩罚时间 ${widget.secondsLeft}s"
                      : _formatTime(widget.secondsLeft),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          // 结果提示
          if (widget.status == PKStatus.punishment)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.myScore > widget.opponentScore ? "🎉 我方胜利" : "😭 对方胜利",
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}