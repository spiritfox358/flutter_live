import 'package:flutter/material.dart';

enum PKStatus {
  idle,
  matching,
  playing,
  punishment,
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

class _PKScoreBarState extends State<PKScoreBar> with SingleTickerProviderStateMixin {
  int _oldMyScore = 0;
  int _addedScore = 0;
  late AnimationController _popController;
  late Animation<double> _popScale;
  late Animation<double> _popOpacity;

  @override
  void initState() {
    super.initState();
    _oldMyScore = widget.myScore;
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _popScale = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _popController, curve: Curves.elasticOut),
    );
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.5, 1.0)),
    );
  }

  @override
  void didUpdateWidget(covariant PKScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.myScore > _oldMyScore) {
      _addedScore = widget.myScore - _oldMyScore;
      _popController.reset();
      _popController.forward();
    }
    _oldMyScore = widget.myScore;
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == PKStatus.idle) return const SizedBox();

    final total = widget.myScore + widget.opponentScore;
    double targetRatio = total == 0 ? 0.5 : widget.myScore / total;

    // 🟢 修复：限制比例范围，保证双方至少保留 15% 的宽度，防止一方消失
    targetRatio = targetRatio.clamp(0.15, 0.85);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // 倒计时
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.status == PKStatus.punishment
                  ? "惩罚时间 ${widget.secondsLeft}s"
                  : "PK ${widget.secondsLeft}s",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // 血条主体
          SizedBox(
            height: 18,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: targetRatio),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, ratio, child) {
                // 计算 flex，避免为 0
                int leftFlex = (ratio * 100).toInt();
                int rightFlex = 100 - leftFlex;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 背景
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    // 🟢 修复：红蓝条布局
                    Row(
                      children: [
                        // 左侧：我方 (红色)
                        Expanded(
                          flex: leftFlex,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD50000), Color(0xFFFF5252)], // 🔴 纯红
                              ),
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              "${widget.myScore}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // 右侧：敌方 (蓝色)
                        Expanded(
                          flex: rightFlex,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2962FF), Color(0xFF448AFF)], // 🔵 纯蓝
                              ),
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              "${widget.opponentScore}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 中间 VS 徽章
                    Container(
                      width: 42,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "VS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),

                    // 飘字动画
                    if (_popController.isAnimating || _popController.isCompleted)
                      Align(
                        alignment: Alignment((ratio * 2) - 1, -3.0),
                        child: AnimatedBuilder(
                          animation: _popController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _popOpacity.value,
                              child: Transform.scale(
                                scale: _popScale.value,
                                child: Text(
                                  "+$_addedScore",
                                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 4)]),
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
          ),

          // 结果提示
          if (widget.status == PKStatus.punishment)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                widget.myScore > widget.opponentScore ? "🎉 我方胜利" : "😭 对方胜利",
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}