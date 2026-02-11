import 'package:flutter/material.dart';
import 'dart:ui'; // 引入 fontFeatures，用于数字等宽显示

// PK 状态枚举，用于控制界面显示逻辑
enum PKStatus {
  idle,       // 空闲状态 (未开始)
  matching,   // 匹配中 (寻找对手)
  playing,    // PK 进行中 (进度条激战)
  punishment, // 惩罚时间 (输赢已定)
  coHost,     // 连线模式 (纯聊天)
}

// 🟢 组件 1：PK 进度条 (血条)
// 这是一个有状态组件，因为需要处理复杂的动画效果
class PKScoreBar extends StatefulWidget {
  final int myScore;       // 我方分数 (左侧红色)
  final int opponentScore; // 对方分数 (右侧蓝色)
  final PKStatus status;   // 当前 PK 状态
  final int secondsLeft;   // 倒计时秒数 (虽然这个参数目前没直接用到，但保留用于扩展)

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
  // 记录上一次更新时的分数，用于计算增加量 (+100)
  int _oldMyScore = 0;
  // 本次增加的分数
  int _addedScore = 0;

  // 进度条滑动的动画时长
  // 默认为 1.5秒 (缓慢滑动)
  // 当触发连击时，会变为 0秒 (瞬间跳变)，制造打击感
  Duration _barAnimationDuration = const Duration(milliseconds: 1500);

  // --- 连击判定相关变量 ---
  DateTime? _lastMyScoreTime; // 上次得分时间
  bool _isCombo = false;      // 当前是否处于连击状态

  // --- 动画控制器 1: 飘字动画 (控制 +score 文字的出现和消失) ---
  late AnimationController _popController;
  late Animation<double> _popScale;   // 文字从小变大
  late Animation<double> _popOpacity; // 文字最后淡出消失

  // --- 动画控制器 2: 白光闪烁 (控制进度条上的高光扫过效果) ---
  late AnimationController _flashController;
  late Animation<double> _flashValue; // 0.0 -> 1.0 的过程

  // --- 动画控制器 3: 文字弹跳 (连击时的"蹦"一下效果) ---
  late AnimationController _comboTextScaleController;
  late Animation<double> _comboTextScale;

  @override
  void initState() {
    super.initState();
    _oldMyScore = widget.myScore;

    // --- 1. 初始化飘字动画 ---
    // 总时长 3秒，但主要动作在前 0.1秒完成，后面是停留展示
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

    // Scale: 0.0s~0.3s 从 0.5倍大 迅速变到 1.0倍
    _popScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.0, 0.1, curve: Curves.easeOutExpo)),
    );

    // Opacity: 2.4s~3.0s 从完全不透明(1.0) 变到 透明(0.0)
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.8, 1.0)),
    );

    // --- 2. 初始化白光闪烁动画 ---
    // 🟢 [可调参数] 白光扫过一次的时间：600毫秒
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flashValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOutQuad),
    );

    // --- 3. 初始化文字弹跳动画 ---
    // 🟢 [可调参数] 文字蹦一下的动画时长：150毫秒 (越小越快，打击感越强)
    _comboTextScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));

    // 🟢 [可调参数] 连击时文字放大的倍数
    // begin: 1.0 (原始大小) -> end: 1.2 (放大到 1.2 倍)
    _comboTextScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _comboTextScaleController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      // 关键逻辑：当放大动画播放完毕后，自动反向播放(缩小)，形成完整的一次“蹦”
      if (status == AnimationStatus.completed) {
        _comboTextScaleController.reverse();
      }
    });
  }

  // 当父组件传入新的参数时触发 (例如分数变了)
  @override
  void didUpdateWidget(covariant PKScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测我方分数是否增加
    if (widget.myScore > _oldMyScore) {
      _addedScore = widget.myScore - _oldMyScore; // 计算本次加分
      final now = DateTime.now();

      // 🟢 [可调参数] 连击判定时间：3秒内再次得分算连击
      // 如果上次得分时间不为空，且距离现在小于3秒，判定为连击
      final bool isComboNow = _lastMyScoreTime != null && now.difference(_lastMyScoreTime!) < const Duration(seconds: 3);
      _lastMyScoreTime = now; // 更新得分时间

      setState(() {
        _isCombo = isComboNow;
        if (isComboNow) {
          // 🚀 连击状态
          // 进度条瞬间跳变，制造激烈的对抗感
          _barAnimationDuration = Duration.zero;

          // 触发文字弹跳动画 (每次连击都蹦一下)
          _comboTextScaleController.forward(from: 0.0);
        } else {
          // 🐢 普通状态
          // 进度条缓慢滑行，优雅过渡
          _barAnimationDuration = const Duration(milliseconds: 1500);
        }
      });

      // 重置并播放飘字动画 (让 +100 重新出现)
      _popController.reset();
      _popController.forward();

      // 触发白光闪烁 (扫光效果)
      _flashController.reset();
      _flashController.forward().then((_) => _flashController.reverse());
    }

    // 更新旧分数，为下一次比较做准备
    _oldMyScore = widget.myScore;
  }

  @override
  void dispose() {
    // 销毁所有动画控制器，防止内存泄漏
    _popController.dispose();
    _flashController.dispose();
    _comboTextScaleController.dispose();
    super.dispose();
  }

  // 辅助方法：格式化分数显示
  // 例如：12500 -> "1.2万"
  String _formatScore(int score) {
    if (score >= 1000000) {
      double w = score / 10000.0;
      return "${w.toStringAsFixed(1)}万";
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    // 如果没开始 PK，不显示血条
    if (widget.status == PKStatus.idle) return const SizedBox();

    final total = widget.myScore + widget.opponentScore;

    // 计算红色进度条的占比 (0.0 ~ 1.0)
    // 如果双方都是 0 分，各占一半 (0.5)
    double targetRatio = total == 0 ? 0.5 : widget.myScore / total;

    // 限制占比范围，防止一方完全消失 (保留 15% 的最小显示区域)
    targetRatio = targetRatio.clamp(0.15, 0.85);

    // 只有在总分为 0 时才不需要圆角，否则中间要有圆角过渡
    final Radius centerRadius = total == 0 ? Radius.zero : const Radius.circular(20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SizedBox(
        height: 18, // 进度条总高度
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth; // 获取当前可用总宽度

            // 使用 TweenAnimationBuilder 实现进度条宽度的平滑过渡动画
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: targetRatio),
              duration: _barAnimationDuration, // 动态时长 (连击时为0)
              curve: Curves.easeOutExpo, // 减速曲线
              builder: (context, ratio, child) {
                // 根据当前动画比例计算左右宽度
                final leftWidth = maxWidth * ratio;
                final rightWidth = maxWidth - leftWidth;

                return Stack(
                  clipBehavior: Clip.none, // 允许子组件超出边界 (用于飘字)
                  alignment: Alignment.centerLeft,
                  children: [
                    // --- 层级 1. 背景/敌方进度条 (蓝色 - 右侧) ---
                    // 先铺一个灰色底色
                    Container(color: Colors.grey[800]),

                    Positioned(
                      right: 0,
                      width: rightWidth + 20.0, // 多加一点宽度防止中间有缝隙
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF448AFF), Color(0xFF2962FF)], // 蓝色渐变
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

                    // --- 层级 2. 我方进度条 (红色 - 左侧) ---
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        // 右侧切圆角，实现中间的斜切视觉效果
                        borderRadius: BorderRadius.horizontal(right: centerRadius),
                        child: SizedBox(
                          width: leftWidth,
                          height: 18,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 红色渐变背景
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                                  ),
                                ),
                              ),

                              // ✨✨✨ 白光扫过动画 ✨✨✨
                              AnimatedBuilder(
                                animation: _flashController,
                                builder: (context, child) {
                                  final double t = _flashValue.value; // 0.0 -> 1.0

                                  // 🟢 [可调参数] 白光亮度动态调整
                                  // _isCombo ? 1.0 (最亮) : 0.60 (平时淡一点)
                                  final double baseIntensity = _isCombo ? 1.0 : 0.60;
                                  // 根据动画进度 t 微调亮度，产生呼吸感
                                  final double intensity = (baseIntensity + (0.15 * t)).clamp(0.0, 1.0);

                                  // 🟢 [可调参数] 白光宽度动态变化
                                  // 基础20像素 + 随动画增加15像素 = 动态变宽
                                  final double currentWidth = 20.0 + (15.0 * t);

                                  // 渐变停止点位置
                                  final double whiteStop = 0.25 + (0.15 * t);

                                  return Positioned(
                                    right: 0, top: 0, bottom: 0, width: currentWidth,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        // 线性渐变实现高光效果
                                        gradient: LinearGradient(
                                          begin: Alignment.centerRight,
                                          end: Alignment.centerLeft,
                                          stops: [0.0, whiteStop, 1.0],
                                          colors: [
                                            Colors.white.withOpacity(intensity), // 核心高亮区
                                            Colors.white.withOpacity(intensity * 0.8), // 过渡区
                                            Colors.white.withOpacity(0.0), // 透明区
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // 我方总分文字 (固定在左侧，不随动画乱动)
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

                    // --- 层级 3. 飘字动画 (+100) ---
                    // 只有在动画播放时才渲染，节省性能
                    if (_popController.isAnimating || _popController.isCompleted)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: leftWidth, // 限制在红色区域内
                        child: AnimatedBuilder(
                          animation: _popController,
                          builder: (context, child) {
                            // 连击时 baseScale 锁定为 1.0，完全由下面的弹跳动画(_comboTextScale)接管
                            // 普通时 baseScale 会从 0.5 变大到 1.0
                            double baseScale = _isCombo ? 1.0 : _popScale.value;

                            return Opacity(
                              opacity: _popOpacity.value, // 控制淡出
                              child: Transform.scale(
                                scale: baseScale,
                                child: Container(
                                  alignment: Alignment.centerRight, // 文字靠右对齐
                                  // 🟢 [可调参数] 文字距离右边框的间距
                                  // right: 5 表示文字距离红色条的右边缘 5像素
                                  padding: const EdgeInsets.only(right: 5),

                                  // 内层嵌套弹跳动画
                                  child: AnimatedBuilder(
                                      animation: _comboTextScaleController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _comboTextScale.value, // 1.0 -> 1.2 -> 1.0
                                          child: Text(
                                            "+$_addedScore",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              // 🟢 [可调参数] 连击加分时的字号
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }
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

// 🟢 组件 2：PK 倒计时与梯形背景 (保持原样，加了部分注释)
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

  // 格式化时间 00:00
  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // 剩余时间小于10秒变红，或者处于惩罚阶段变红
    final bool isRedBg = (secondsLeft <= 10 && status == PKStatus.playing) || status == PKStatus.punishment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 使用 CustomPaint 绘制梯形背景
        CustomPaint(
          painter: _TrapezoidPainter(
            color: isRedBg ? const Color(0xFFFF1744).withOpacity(0.3) : Colors.grey.withOpacity(0.85),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 如果是 PK 进行中，显示 "PK" 图标
                if (status != PKStatus.punishment && status != PKStatus.coHost) ...[
                  const Text("P", style: TextStyle(color: Color(0xFFFF2E56), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 0),
                  const Text("K", style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 6),
                ],
                // 显示时间文本
                Text(
                  status == PKStatus.punishment
                      ? "惩罚时间 ${_formatTime(secondsLeft)}"
                      : status == PKStatus.coHost
                      ? "连线中 ${_formatTime(secondsLeft)}"
                      : _formatTime(secondsLeft),
                  // fontFeatures: [FontFeature.tabularFigures()] 确保数字等宽，不会跳动
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ),
        // 如果是惩罚时间，显示胜负结果
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

// 🟢 自定义画笔：绘制梯形背景
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

    // 内缩距离
    const double inset = 4.0;
    // 底部切角半径
    const double r = 4.0;
    final double effectiveR = r.clamp(0.0, size.height / 2);

    final path = Path();
    path.moveTo(0, 0); // 左上角
    path.lineTo(size.width, 0); // 右上角

    // 右下角贝塞尔曲线切角
    final brStartX = size.width - inset * (1.0 - effectiveR / size.height);
    path.lineTo(brStartX, size.height - effectiveR);
    path.quadraticBezierTo(size.width - inset, size.height, size.width - inset - effectiveR, size.height);

    // 底部水平线
    path.lineTo(inset + effectiveR, size.height);

    // 左下角贝塞尔曲线切角
    final blEndX = inset * (1.0 - effectiveR / size.height);
    path.quadraticBezierTo(inset, size.height, blEndX, size.height - effectiveR);

    path.close(); // 闭合路径
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrapezoidPainter oldDelegate) {
    // 只有颜色变了才重绘
    return color != oldDelegate.color;
  }
}