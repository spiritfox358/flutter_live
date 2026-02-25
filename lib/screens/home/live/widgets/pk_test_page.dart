import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ==========================================
// 1. 测试页面 (控制面板，用于模拟数据和调试)
// ==========================================
class PKTestPage extends StatefulWidget {
  const PKTestPage({super.key});

  @override
  State<PKTestPage> createState() => _PKTestPageState();
}

class _PKTestPageState extends State<PKTestPage> {
  int _myScore = 0;
  int _opponentScore = 0;
  int _secondsLeft = 180;
  PKStatus _status = PKStatus.playing;
  Timer? _timer;

  int _critSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0 && _status != PKStatus.idle && _status != PKStatus.matching) {
        setState(() => _secondsLeft--);
      }
      if (_critSecondsLeft > 0) {
        setState(() => _critSecondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _addScore(bool isMine, int amount) {
    int finalAmount = amount;

    if (isMine && _critSecondsLeft > 0) {
      final double multiplier = 1.5 + math.Random().nextDouble() * 3.5;
      finalAmount = (amount * multiplier).toInt();
    }

    setState(() {
      if (isMine) {
        _myScore += finalAmount;
      } else {
        _opponentScore += finalAmount;
      }
    });
  }

  void _useCritCard() {
    setState(() {
      _critSecondsLeft += 30;
    });
  }

  void _reset() {
    setState(() {
      _myScore = 0;
      _opponentScore = 0;
      _secondsLeft = 180;
      _critSecondsLeft = 0;
      _status = PKStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161823),
      appBar: AppBar(title: const Text('PK UI 动效调试台'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                PKScoreBar(
                  myScore: _myScore,
                  opponentScore: _opponentScore,
                  status: _status,
                  secondsLeft: _secondsLeft,
                  critSecondsLeft: _critSecondsLeft,
                ),
                Transform.translate(
                  offset: const Offset(0, -2),
                  child: PKTimer(secondsLeft: _secondsLeft, status: _status, myScore: _myScore, opponentScore: _opponentScore),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('道具控制', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: _useCritCard,
                    icon: const Icon(Icons.flash_on),
                    label: Text('扔暴击卡 (当前剩余: $_critSecondsLeft s)'),
                  ),
                  const Divider(height: 30),
                  const Text('分数模拟 (带暴击效果)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () => _addScore(true, 100),
                        child: const Text('我方 +100'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        onPressed: () => _addScore(false, 100),
                        child: const Text('敌方 +100'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重置为 0 分'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 2. PK 核心业务代码
// ==========================================
enum PKStatus { idle, matching, playing, punishment, coHost }

class PKScoreBar extends StatefulWidget {
  final int myScore;
  final int opponentScore;
  final PKStatus status;
  final int secondsLeft;
  final int critSecondsLeft;

  const PKScoreBar({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.status,
    required this.secondsLeft,
    this.critSecondsLeft = 0,
  });

  @override
  State<PKScoreBar> createState() => _PKScoreBarState();
}

class _PKScoreBarState extends State<PKScoreBar> with TickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _oldMyScore = widget.myScore;
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _popScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _popController, curve: const Interval(0.0, 0.1, curve: Curves.easeOutExpo)));
    _popOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _popController, curve: const Interval(0.8, 1.0)));
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _flashValue = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOutQuad));
    _comboTextScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _comboTextScale = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _comboTextScaleController, curve: Curves.easeInOut))..addStatusListener((status) {
      if (status == AnimationStatus.completed) _comboTextScaleController.reverse();
    });

    // 闪电动画时长，500ms 能看清完整的射出和消散
    _lightningController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void didUpdateWidget(covariant PKScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);
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

      if (widget.critSecondsLeft > 0) {
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
                          right: 0, width: rightWidth + 20.0, top: 0, bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF448AFF), Color(0xFF2962FF)])),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(_formatScore(widget.opponentScore), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),

                        // --- 2. 红条 ---
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.horizontal(right: centerRadius),
                            child: SizedBox(
                              width: leftWidth, height: 18,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)]))),

                                  if (total > 0)
                                    AnimatedBuilder(
                                      animation: _flashController,
                                      builder: (context, child) {
                                        final double t = _flashValue.value;
                                        final double intensity = ((_isCombo ? 1.0 : 0.60) + (0.15 * t)).clamp(0.0, 1.0);

                                        return Positioned(
                                          right: 0, top: 0, bottom: 0, width: 40.0 + (15.0 * t),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight, end: Alignment.centerLeft,
                                                stops: [0.0, 0.4 + (0.2 * t), 1.0],
                                                colors: [
                                                  Colors.white.withOpacity(intensity),
                                                  Colors.white.withOpacity(intensity * 0.4),
                                                  Colors.white.withOpacity(0.0)
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // ✨✨✨ 3. 逼真的高压电流闪击特效 ✨✨✨
                                  if (_lightningController.isAnimating)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _lightningController,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: _LightningPainter(_lightningController.value),
                                          );
                                        },
                                      ),
                                    ),

                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(_formatScore(widget.myScore), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- 4. 气泡与发光特效 ---
                        Positioned(
                          left: leftWidth - 30, top: -15, bottom: -15, width: 60,
                          child: PKDividerEffect(isZeroScore: total == 0),
                        ),

                        // --- 5. 暴击卡图片跟随 ---
                        if (widget.critSecondsLeft > 0)
                          Positioned(
                            left: leftWidth - 14,
                            top: -8,
                            child: Image.network(
                              'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%9A%B4%E5%87%BB%E5%8D%A1_prop.png',
                              width: 28,
                              height: 28,
                            ),
                          ),

                        // --- 6. 飘字动画 ---
                        if (_popController.isAnimating || _popController.isCompleted)
                          Positioned(
                            left: 0, top: 0, bottom: 0, width: leftWidth,
                            child: AnimatedBuilder(
                              animation: _popController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _popOpacity.value,
                                  child: Transform.scale(
                                    scale: _isCombo ? 1.0 : _popScale.value,
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 5),
                                      child: AnimatedBuilder(
                                          animation: _comboTextScaleController,
                                          builder: (context, child) {
                                            return Transform.scale(
                                              scale: _comboTextScale.value,
                                              child: Text("+$_addedScore", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
        ),

        // --- 暴击卡生效提示文字 ---
        if (widget.critSecondsLeft > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "暴击卡生效中  ${widget.critSecondsLeft}s ",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 8,
                  color: Colors.white.withOpacity(0.8),
                )
              ],
            ),
          )
      ],
    );
  }
}

// 🌟🌟🌟 重新构建：物理级真实分形闪电 (Fractal Lightning) 🌟🌟🌟
class _LightningPainter extends CustomPainter {
  final double progress;

  _LightningPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    // 💡 视觉秘诀 1：帧锁定 (Seed Random)
    // 真实的闪电不是每一帧都在乱窜的（那样看起来像糊掉的马赛克）。
    // 我们把 0~1 的进度分成 8 个阶段，每个阶段使用同一个随机数种子。
    // 这使得闪电呈现出“定格-变异-定格-变异”的极具力量感的频闪效果！
    int step = (progress * 8).floor();
    math.Random random = math.Random(step);

    // 随机跳帧，增加断电感
    if (random.nextDouble() > 0.75) return;

    // 💡 动画进度控制：前30%的时间闪电射出，后70%的时间闪烁并消散
    double revealProgress = (progress * 3.3).clamp(0.0, 1.0);
    double opacity = 1.0;
    if (progress > 0.3) {
      opacity = 1.0 - ((progress - 0.3) / 0.7);
    }

    // 💡 尺寸与范围控制：从右向左，占据我方血条靠右侧 80% 的距离
    double startX = size.width;
    double endX = size.width * 0.2;

    // 裁剪动画区域，让闪电像光束一样射出
    double currentLeft = startX - (startX - endX) * revealProgress;
    canvas.clipRect(Rect.fromLTRB(currentLeft - 20, -20, startX + 20, size.height + 20));

    // 💡 渐变着色器：最左边耀眼纯白，向右变为紫色，最后完全透明融入背景
    final Rect shaderRect = Rect.fromLTRB(endX, 0, startX, size.height);

    final Shader coreShader = LinearGradient(
      begin: Alignment.centerLeft, end: Alignment.centerRight,
      colors: [
        Colors.white.withOpacity(opacity),
        Colors.white.withOpacity(opacity * 0.7),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(shaderRect);

    // 紫色/青色高压电弧晕影
    final Shader glowShader = LinearGradient(
      begin: Alignment.centerLeft, end: Alignment.centerRight,
      colors: [
        const Color(0xFFE040FB).withOpacity(opacity),       // 高亮紫
        const Color(0xFFE040FB).withOpacity(opacity * 0.6), // 过渡
        const Color(0xFFE040FB).withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(shaderRect);

    final Paint glowPaint = Paint()
      ..shader = glowShader
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final Paint corePaint = Paint()
      ..shader = coreShader
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // 🌟 绘制横向主闪电 (粗)
    Path mainPath = _generateLightning(startX, endX, size.height / 2, random, true);
    canvas.drawPath(mainPath, glowPaint..strokeWidth = 5.0); // 宽层光晕
    canvas.drawPath(mainPath, glowPaint..strokeWidth = 2.0); // 核心光晕
    canvas.drawPath(mainPath, corePaint..strokeWidth = 1.5); // 白炽核心

    // 🌟 绘制侧向分支闪电 (细)，大部分集中在爆发的左端
    int branchCount = random.nextInt(3) + 2; // 随机 2~4 条分支
    for (int i = 0; i < branchCount; i++) {
      // 让分支的起点偏向左边 (更靠近 endX)
      double startFactor = random.nextDouble() * random.nextDouble();
      double branchStartX = endX + startFactor * (startX - endX);
      double branchStartY = size.height / 2 + (random.nextDouble() * 8 - 4);

      // 分支大概向左侧延伸一小段
      double branchEndX = branchStartX - random.nextDouble() * 30 - 10;

      Path branchPath = _generateLightning(branchStartX, branchEndX, branchStartY, random, false);
      canvas.drawPath(branchPath, glowPaint..strokeWidth = 2.0);
      canvas.drawPath(branchPath, corePaint..strokeWidth = 0.8);
    }

    // 🌟 射出前端的能量高光球 (模拟击穿空气的火花)
    if (revealProgress < 1.0) {
      canvas.drawCircle(Offset(currentLeft, size.height / 2), 10.0, Paint()..color = const Color(0xFFE040FB).withOpacity(opacity * 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0));
      canvas.drawCircle(Offset(currentLeft, size.height / 2), 4.0, Paint()..color = Colors.white.withOpacity(opacity));
    }
  }

  // 生成真实分形折线的核心算法
  Path _generateLightning(double startX, double endX, double startY, math.Random random, bool isMain) {
    Path path = Path();
    path.moveTo(startX, startY);

    double currX = startX;
    double currY = startY;
    double centerY = startY;

    // 只要还没抵达左侧终点，就不断生成折线段
    while (currX > endX) {
      // 每次稳步向左推进一段距离
      currX -= (random.nextDouble() * 12 + 6);
      if (currX < endX) currX = endX;

      // 💡 视觉秘诀 2：横向约束
      // 纵向(上下)随机跳跃，但如果是主干，跳跃幅度更大；
      double jitter = isMain ? 8.0 : 4.0;
      currY += (random.nextDouble() * jitter * 2 - jitter);

      // 核心！利用引力公式，强行把电流拉回中轴线，保证它永远是横着劈的，不会飞出红条上下边界！
      currY += (centerY - currY) * 0.4; // 每次偏离后，会有 40% 的力量把它扯回中间

      path.lineTo(currX, currY);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _LightningPainter oldDelegate) => true;
}

// ----------------------------------------
// 🌟 特效核心代码 (白色气泡 + 加宽竖杠)
// ----------------------------------------
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

    final Color color = Colors.white;

    return _PKParticle(
      x: startX,
      y: startY,
      vx: vx,
      vy: vy,
      size: _random.nextDouble() * 1.0 + 0.5,
      color: color,
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
      child: CustomPaint(
        painter: _PKDividerPainter(_particles, widget.isZeroScore),
        size: Size.infinite,
      ),
    );
  }
}

class _PKParticle {
  double x, y, vx, vy, size, life, decayRate;
  Color color;
  _PKParticle({required this.x, required this.y, required this.vx, required this.vy, required this.size, required this.life, required this.decayRate, required this.color});
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
      final p1 = Offset(centerX, centerY - barHeightHalf);
      final p2 = Offset(centerX, centerY + barHeightHalf);

      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, corePaint);
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

// ----------------------------------------
// ⏱️ 计时器组件 (保留不变)
// ----------------------------------------
class PKTimer extends StatelessWidget {
  final int secondsLeft;
  final PKStatus status;
  final int myScore;
  final int opponentScore;

  const PKTimer({
    super.key, required this.secondsLeft, required this.status, required this.myScore, required this.opponentScore,
  });

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
          painter: _TrapezoidPainter(
            color: isRedBg ? const Color(0xFFFF1744).withOpacity(0.3) : Colors.grey.withOpacity(0.85),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (status != PKStatus.punishment && status != PKStatus.coHost) ...[
                  const Text("P", style: TextStyle(color: Color(0xFFFF2E56), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 0),
                  const Text("K", style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0)),
                  const SizedBox(width: 6),
                ],
                Text(
                  status == PKStatus.punishment ? "惩罚时间 ${_formatTime(secondsLeft)}" : status == PKStatus.coHost ? "连线中 ${_formatTime(secondsLeft)}" : _formatTime(secondsLeft),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
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
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    const double inset = 4.0;
    const double r = 4.0;
    final double effectiveR = r.clamp(0.0, size.height / 2);
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0);
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