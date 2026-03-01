import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// PK 状态枚举
enum PKStatus { idle, matching, playing, punishment, coHost }

// 🟢 组件 1：PK 进度条 (血条)
// 🟢 组件 1：PK 进度条 (血条)
class PKScoreBar extends StatefulWidget {
  final int myScore;
  final int opponentScore;
  final PKStatus status;
  final int secondsLeft;
  final String myRoomId; // 🟢 新增：告诉组件哪个是我方的房间号
  final Map<String, DateTime> critEndTimes; // 🟢 新增：支持 N 人的动态时间集合

  const PKScoreBar({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.status,
    required this.secondsLeft,
    required this.myRoomId,
    required this.critEndTimes,
  });

  @override
  State<PKScoreBar> createState() => PKScoreBarState();
}

class PKScoreBarState extends State<PKScoreBar> with TickerProviderStateMixin {
  // 🟢 内部维护的动态时间集合
  Map<String, DateTime> _currentCritEndTimes = {};

  // 🟢 双方倒计时：敌方如果有多人，取最高值
  int _myCritSecondsLeft = 0;
  int _oppCritSecondsLeft = 0;
  // =========================================================================
  // 🛠️ 微调参数区
  // =========================================================================
  final double critCardOffsetX = -14.0; // 暴击卡左右偏移
  final double critCardOffsetY = -5.0; // 暴击卡上下偏移
  final double scorePopTopOffset = 0.0; // 飘字上下偏移
  // =========================================================================

  int _oldMyScore = 0;
  int _addedScore = 0;
  Duration _barAnimationDuration = const Duration(milliseconds: 1500);
  DateTime? _lastMyScoreTime;
  bool _isCombo = false;

  late AnimationController _popController;
  late Animation<double> _popScale;
  late Animation<double> _popOpacity;
  late AnimationController _flashController;
  late Animation<double> _flashValue;
  late AnimationController _comboTextScaleController;
  late Animation<double> _comboTextScale;

  late AnimationController _lightningController;

  // 内部独立计时器，隔离父级刷新
  Timer? _localCritTimer;
// 🟢 4. 新增敌方倒计时
  @override
  void initState() {
    super.initState();
    _currentCritEndTimes = Map.from(widget.critEndTimes);
    // 初始化时拿父组件传进来的初始值
    _oldMyScore = widget.myScore;
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _popScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _popController,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOutExpo),
      ),
    );
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _popController, curve: const Interval(0.8, 1.0)));
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _flashValue = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOutQuad));
    _comboTextScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _comboTextScale = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _comboTextScaleController, curve: Curves.easeInOut))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _comboTextScaleController.reverse();
      });

    _lightningController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _checkCritTime();
    _startLocalCritTimer();
  }

  void _startLocalCritTimer() {
    _localCritTimer?.cancel();
    _localCritTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkCritTime();
    });
  }

// 🟢 倒计时检测：支持 N 人遍历
  void _checkCritTime() {
    final now = DateTime.now();
    int myMax = 0;
    int oppMax = 0;

    _currentCritEndTimes.forEach((roomId, endTime) {
      final diff = endTime.difference(now).inSeconds;
      if (diff > 0) {
        if (roomId == widget.myRoomId) {
          myMax = diff; // 我方时间
        } else {
          if (diff > oppMax) oppMax = diff; // 敌方如果有多人，取最长的那个时间显示在右侧
        }
      }
    });

    if (_myCritSecondsLeft != myMax || _oppCritSecondsLeft != oppMax) {
      setState(() {
        _myCritSecondsLeft = myMax;
        _oppCritSecondsLeft = oppMax;
      });
    }
  }

  // 🟢 局部刷新：精准更新某一个房间的时间
  void updateCritTime(String targetRoomId, int secondsLeft) {
    setState(() {
      if (secondsLeft > 0) {
        _currentCritEndTimes[targetRoomId] = DateTime.now().add(Duration(seconds: secondsLeft));
      } else {
        _currentCritEndTimes.remove(targetRoomId);
      }
    });
    _checkCritTime();

    // 如果是我方触发暴击，播放闪电特效
    if (targetRoomId == widget.myRoomId && _myCritSecondsLeft > 0) {
      _lightningController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant PKScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 同步父组件传来的新集合
    _currentCritEndTimes = Map.from(widget.critEndTimes);
    _checkCritTime();

    if (widget.myScore > _oldMyScore) {
      _addedScore = widget.myScore - _oldMyScore;
      final now = DateTime.now();
      final bool isComboNow = _lastMyScoreTime != null && now.difference(_lastMyScoreTime!) < const Duration(seconds: 3);
      _lastMyScoreTime = now;

      setState(() {
        _isCombo = isComboNow;
        if (isComboNow) {
          _barAnimationDuration = Duration.zero;
          _comboTextScaleController.forward(from: 0.0);
        } else {
          _barAnimationDuration = const Duration(milliseconds: 1500);
        }
      });
      _popController.reset();
      _popController.forward();
      _flashController.reset();
      _flashController.forward().then((_) => _flashController.reverse());

      // 有暴击卡生效时触发爆炸
      if (_myCritSecondsLeft > 0) {
        _lightningController.forward(from: 0.0);
      }
    }
    _oldMyScore = widget.myScore;
  }

  @override
  void dispose() {
    _popController.dispose();
    _flashController.dispose();
    _comboTextScaleController.dispose();
    _lightningController.dispose();
    _localCritTimer?.cancel();
    super.dispose();
  }

  String _formatScore(int score) {
    if (score >= 1000000) return "${(score / 10000.0).toStringAsFixed(1)}万";
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == PKStatus.idle) return const SizedBox();

    final total = widget.myScore + widget.opponentScore;
    double targetRatio = total == 0 ? 0.5 : widget.myScore / total;
    targetRatio = targetRatio.clamp(0.15, 0.85);

    final Radius centerRadius = total == 0 ? Radius.zero : const Radius.circular(20);

    // 🟢 核心修正：判断当前是否有暴击卡，动态设置飘字的边距
    final double currentPopRightPadding = _myCritSecondsLeft > 0 ? 13.0 : 5.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: targetRatio),
                  duration: _barAnimationDuration,
                  curve: Curves.easeOutExpo,
                  builder: (context, ratio, child) {
                    final leftWidth = maxWidth * ratio;
                    final rightWidth = maxWidth - leftWidth;

                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // --- 1. 蓝条 ---
                        Container(color: Colors.grey[800]),
                        Positioned(
                          right: 0,
                          width: rightWidth + 20.0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF448AFF), Color(0xFF2962FF)])),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _formatScore(widget.opponentScore),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ),

                        // --- 2. 红条 ---
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
                                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)])),
                                  ),

                                  if (total > 0)
                                    AnimatedBuilder(
                                      animation: _flashController,
                                      builder: (context, child) {
                                        final double t = _flashValue.value;
                                        final double intensity = ((_isCombo ? 1.0 : 0.75) + (0.15 * t)).clamp(0.0, 1.0);
                                        return Positioned(
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: 40.0 + (15.0 * t),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight,
                                                end: Alignment.centerLeft,
                                                stops: [0.0, 0.4 + (0.2 * t), 1.0],
                                                colors: [
                                                  Colors.white.withOpacity(intensity),
                                                  Colors.white.withOpacity(intensity * 0.4),
                                                  Colors.white.withOpacity(0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // --- 3. 爆裂光波特效 ---
                                  if (_lightningController.isAnimating)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _lightningController,
                                        builder: (context, child) {
                                          return CustomPaint(painter: _ExplosionPainter(_lightningController.value));
                                        },
                                      ),
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

                        // --- 4. 交界处气泡特效 ---
                        Positioned(
                          left: leftWidth - 30,
                          top: -15,
                          bottom: -15,
                          width: 60,
                          child: PKDividerEffect(isZeroScore: total == 0),
                        ),

                        // --- 5. 暴击卡图片跟随 ---
                        if (_myCritSecondsLeft > 0)
                          Positioned(
                            left: leftWidth + critCardOffsetX,
                            top: critCardOffsetY,
                            child: Image.network(
                              'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%9A%B4%E5%87%BB%E5%8D%A1_prop.png',
                              width: 28,
                              height: 28,
                            ),
                          ),

                        // --- 6. 飘字动画 (应用动态 Padding) ---
                        if (_popController.isAnimating || _popController.isCompleted)
                          Positioned(
                            left: 0,
                            top: scorePopTopOffset,
                            bottom: -scorePopTopOffset,
                            width: leftWidth,
                            child: AnimatedBuilder(
                              animation: _popController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _popOpacity.value,
                                  child: Transform.scale(
                                    scale: _isCombo ? 1.0 : _popScale.value,
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      // 🟢 动态使用 Padding：没卡 5.0，有卡 25.0 完美避开遮挡！
                                      padding: EdgeInsets.only(right: currentPopRightPadding),
                                      child: AnimatedBuilder(
                                        animation: _comboTextScaleController,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _comboTextScale.value,
                                            child: Text(
                                              "+$_addedScore",
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          );
                                        },
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
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 我方：红色向右渐变
            _myCritSecondsLeft > 0 ? _buildCritLabel(true, _myCritSecondsLeft) : const SizedBox(),

            // 敌方：蓝色向左渐变
            _oppCritSecondsLeft > 0 ? _buildCritLabel(false, _oppCritSecondsLeft) : const SizedBox(),
          ],
        ),

        if (widget.status == PKStatus.punishment)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.myScore >= widget.opponentScore ? "🎉 我方胜利" : "😭 对方胜利",
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
      ],
    );
  }
  // 🟢 新增：提取的红蓝双向渐变标签组件
  Widget _buildCritLabel(bool isMe, int seconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isMe ? Alignment.centerLeft : Alignment.centerRight,
          end: isMe ? Alignment.centerRight : Alignment.centerLeft,
          colors: isMe
              ? [const Color(0xFFFF2E56), Colors.transparent] // 我方：狂暴红
              : [const Color(0xFF2962FF), Colors.transparent], // 敌方：冰霜蓝
          stops: const [0.2, 1.0],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe) const Icon(Icons.arrow_back_ios, size: 8, color: Colors.white),
          if (!isMe) const SizedBox(width: 4),
          Text(
            isMe ? "暴击卡生效中  ${seconds}s " : "暴击中... ",
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (isMe) const Icon(Icons.arrow_forward_ios, size: 8, color: Colors.white),
        ],
      ),
    );
  }
}

// ===========================================================================
// 下方为纯特效画笔组件代码 (直接拷贝)
// ===========================================================================

class _ExplosionPainter extends CustomPainter {
  final double progress;
  final math.Random random = math.Random();

  _ExplosionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    if (random.nextDouble() > 0.75) return;

    double opacity = 1.0;
    if (progress > 0.05) {
      opacity = 1.0 - ((progress - 0.05) / 0.95);
    }

    math.Random shapeRandom = math.Random(666);

    Path blastPath = Path();
    blastPath.moveTo(size.width, 0);
    blastPath.lineTo(size.width, size.height);

    int steps = 16;
    for (int i = steps; i >= 0; i--) {
      double y = size.height * (i / steps);
      double distFromCenter = (y - size.height / 2).abs() / (size.height / 2);
      double pullback = distFromCenter * 80.0;
      double jitter = shapeRandom.nextDouble() * 30.0 * (1.0 - distFromCenter * 0.5);
      double x = pullback + jitter;
      x = math.max(0.0, x);
      blastPath.lineTo(x, y);
    }
    blastPath.close();

    final Rect shaderRect = Rect.fromLTRB(0, 0, size.width, size.height);
    final Shader blastShader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        Colors.white.withOpacity(opacity),
        const Color(0xFFFFF59D).withOpacity(opacity * 0.9),
        const Color(0xFFE040FB).withOpacity(opacity * 0.6),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    ).createShader(shaderRect);

    canvas.drawPath(
      blastPath,
      Paint()
        ..shader = blastShader
        ..style = PaintingStyle.fill,
    );

    final Shader originFlashShader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [Colors.white.withOpacity(opacity), Colors.white.withOpacity(0.0)],
      stops: const [0.0, 0.4],
    ).createShader(shaderRect);
    canvas.drawRect(shaderRect, Paint()..shader = originFlashShader);

    final Paint sparkPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.9)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    int sparkCount = random.nextInt(6) + 4;
    for (int i = 0; i < sparkCount; i++) {
      double sparkY = random.nextDouble() * size.height;
      double sparkX = size.width - random.nextDouble() * (size.width * 0.4);
      double length = random.nextDouble() * 60 + 20;
      canvas.drawLine(Offset(sparkX, sparkY), Offset(sparkX - length, sparkY), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter oldDelegate) => true;
}

class PKDividerEffect extends StatefulWidget {
  final bool isZeroScore;

  const PKDividerEffect({super.key, required this.isZeroScore});

  @override
  State<PKDividerEffect> createState() => _PKDividerEffectState();
}

class _PKDividerEffectState extends State<PKDividerEffect> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_PKParticle> _particles = [];
  final math.Random _random = math.Random();
  Duration _lastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastTime == Duration.zero) {
        _lastTime = elapsed;
        return;
      }
      final double dt = (elapsed - _lastTime).inMilliseconds / 1000.0;
      _lastTime = elapsed;
      _updateParticles(dt);
    });
    _ticker.start();
  }

  void _updateParticles(double dt) {
    if (_random.nextDouble() < 0.15) {
      if (widget.isZeroScore) {
        _particles.add(_createParticle(isLeft: true));
        _particles.add(_createParticle(isLeft: false));
      } else {
        _particles.add(_createParticle(isLeft: true));
      }
    }
    for (var p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt * p.decayRate;
    }
    _particles.removeWhere((p) => p.life <= 0);
    if (mounted) setState(() {});
  }

  _PKParticle _createParticle({required bool isLeft}) {
    final double startX = widget.isZeroScore ? 0.0 : -8.0;
    final double yRange = widget.isZeroScore ? 8.0 : 4.5;
    final double startY = _random.nextDouble() * (yRange * 2) - yRange;
    final double baseVx = _random.nextDouble() * 15 + 10;
    final double vx = (isLeft ? -1 : 1) * baseVx;
    final double vy = _random.nextDouble() * 4 - 2;

    return _PKParticle(
      x: startX,
      y: startY,
      vx: vx,
      vy: vy,
      size: _random.nextDouble() * 1.0 + 0.5,
      color: Colors.white,
      life: 1.0,
      decayRate: _random.nextDouble() * 1.2 + 0.6,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _PKDividerPainter(_particles, widget.isZeroScore), size: Size.infinite),
    );
  }
}

class _PKParticle {
  double x, y, vx, vy, size, life, decayRate;
  Color color;

  _PKParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.decayRate,
    required this.color,
  });
}

class _PKDividerPainter extends CustomPainter {
  final List<_PKParticle> particles;
  final bool isZeroScore;

  _PKDividerPainter(this.particles, this.isZeroScore);

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    if (isZeroScore) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      final corePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      const double barHeightHalf = 8.5;
      canvas.drawLine(Offset(centerX, centerY - barHeightHalf), Offset(centerX, centerY + barHeightHalf), glowPaint);
      canvas.drawLine(Offset(centerX, centerY - barHeightHalf), Offset(centerX, centerY + barHeightHalf), corePaint);
    }

    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5);
      canvas.drawCircle(Offset(centerX + p.x, centerY + p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PKDividerPainter oldDelegate) => true;
}

class PKTimer extends StatelessWidget {
  final int secondsLeft;
  final PKStatus status;
  final int myScore;
  final int opponentScore;

  const PKTimer({super.key, required this.secondsLeft, required this.status, required this.myScore, required this.opponentScore});

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isRedBg = (secondsLeft <= 10 && status == PKStatus.playing) || status == PKStatus.punishment;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: _TrapezoidPainter(color: isRedBg ? const Color(0xFFFF1744).withOpacity(0.3) : Colors.grey.withOpacity(0.85)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                if (status != PKStatus.punishment && status != PKStatus.coHost) ...[
                  const Text(
                    "P",
                    style: TextStyle(color: Color(0xFFFF2E56), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0),
                  ),
                  const SizedBox(width: 0),
                  const Text(
                    "K",
                    style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  status == PKStatus.punishment
                      ? "惩罚时间 ${_formatTime(secondsLeft)}"
                      : status == PKStatus.coHost
                      ? "连线中 ${_formatTime(secondsLeft)}"
                      : _formatTime(secondsLeft),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _TrapezoidPainter extends CustomPainter {
  final Color color;

  _TrapezoidPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const double inset = 4.0;
    const double r = 4.0;
    final double effectiveR = r.clamp(0.0, size.height / 2);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    final brStartX = size.width - inset * (1.0 - effectiveR / size.height);
    path.lineTo(brStartX, size.height - effectiveR);
    path.quadraticBezierTo(size.width - inset, size.height, size.width - inset - effectiveR, size.height);
    path.lineTo(inset + effectiveR, size.height);
    final blEndX = inset * (1.0 - effectiveR / size.height);
    path.quadraticBezierTo(inset, size.height, blEndX, size.height - effectiveR);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrapezoidPainter oldDelegate) => color != oldDelegate.color;
}
