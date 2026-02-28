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

  // =========================================================================
  // 🛠️🛠️🛠️ 微调参数区：方便你直接调节飘字和暴击卡的位置 🛠️🛠️🛠️
  // =========================================================================

  // 1. 暴击卡图标位置控制
  // 默认宽 28，基于中心线往左退一半(-14)就是居中。如果想让它偏右一点，把这个值调大(比如 -5)
  final double critCardOffsetX = -14.0;
  // 控制上下浮动。0是和血条平齐，负数是往上漂浮。如果想让它再高一点不挡数字，可以改成 -15.0
  final double critCardOffsetY = -5;

  // 2. 飘字动画 (+分数) 位置控制
  // 控制飘字距离我方红条最右侧(交界处)的距离。
  // 💡 如果你发现被暴击卡挡住了，把这个值调大（比如改成 25.0 或 30.0），飘字就会往左挪，避开暴击卡！
  final double scorePopRightPadding = 13.0;
  // 控制飘字的上下偏移。负数往上，正数往下。0 表示垂直居中。
  final double scorePopTopOffset = 0.0;

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

                                  // ✨✨✨ 3. 终极爆裂光波：瞬间全屏贯穿，右亮左暗，中心突出撕裂 ✨✨✨
                                  if (_lightningController.isAnimating)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _lightningController,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: _ExplosionPainter(_lightningController.value),
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

                        // --- 5. 暴击卡图片跟随 (使用顶部变量控制) ---
                        if (widget.critSecondsLeft > 0)
                          Positioned(
                            left: leftWidth + critCardOffsetX,
                            top: critCardOffsetY,
                            child: Image.network(
                              'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%9A%B4%E5%87%BB%E5%8D%A1_prop.png',
                              width: 28,
                              height: 28,
                            ),
                          ),

                        // --- 6. 飘字动画 (使用顶部变量控制) ---
                        if (_popController.isAnimating || _popController.isCompleted)
                          Positioned(
                            left: 0,
                            top: scorePopTopOffset,    // 应用顶部变量的偏移
                            bottom: -scorePopTopOffset, // 上下挤压保持原高，实现偏移
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
                                      // 应用顶部变量的左移距离
                                      padding: EdgeInsets.only(right: scorePopRightPadding),
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

// 🌟🌟🌟 终极优化：“右侧爆发、左侧衰减” + “中间长边缘短的物理撕裂” 🌟🌟🌟
class _ExplosionPainter extends CustomPainter {
  final double progress;
  final math.Random random = math.Random();

  _ExplosionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    // 高频闪烁制造极强的能量不稳定性
    if (random.nextDouble() > 0.75) return;

    // 💡 调整 1：光速无限快！进度决定的是透明度(衰减)，不再是位移。
    // 第 0.0 帧瞬间达到最亮(opacity=1.0)，随后光波一起同步变暗消散。
    double opacity = 1.0;
    if (progress > 0.05) {
      opacity = 1.0 - ((progress - 0.05) / 0.95);
    }

    // 固定种子保证一次暴击产生固定的撕裂形状，仅随透明度闪烁
    math.Random shapeRandom = math.Random(666);

    // 💡 调整 2：“中间长尖、两边短”的物理撕裂算法
    Path blastPath = Path();
    blastPath.moveTo(size.width, 0);           // 起点：右上角
    blastPath.lineTo(size.width, size.height); // 起点：右下角

    // 从下往上勾勒左侧的撕裂边缘
    int steps = 16;
    for (int i = steps; i >= 0; i--) {
      double y = size.height * (i / steps);

      // 计算当前点距离中心高度的比例 (0.0=最中心, 1.0=最边缘)
      double distFromCenter = (y - size.height / 2).abs() / (size.height / 2);

      // 核心算法：边缘后退距离。边缘(上下)退得最多，中心退得最少
      // 假设最多退后 80 像素
      double pullback = distFromCenter * 80.0;

      // 加入随机锯齿感，同样中心锯齿长，边缘锯齿短
      double jitter = shapeRandom.nextDouble() * 30.0 * (1.0 - distFromCenter * 0.5);

      // 最终的 x 坐标：允许横穿数字甚至直接顶到 0.0 最左端
      double x = pullback + jitter;
      x = math.max(0.0, x); // 防止越过最左侧边界

      blastPath.lineTo(x, y);
    }
    blastPath.close();

    // 💡 调整 3：渐变方向修正为“右侧最亮 -> 左侧衰减”
    final Rect shaderRect = Rect.fromLTRB(0, 0, size.width, size.height);
    final Shader blastShader = LinearGradient(
      // 从右往左渐变
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        Colors.white.withOpacity(opacity),                   // 最右侧 (源头)：爆出耀眼纯白核心
        const Color(0xFFFFF59D).withOpacity(opacity * 0.9),  // 偏右段：极高亮的火花黄
        const Color(0xFFE040FB).withOpacity(opacity * 0.6),  // 偏左段：能量紫晕
        Colors.transparent,                                  // 最左侧 (末端)：完全透明，融入背景
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    ).createShader(shaderRect);

    // 1. 绘制主体能量波
    canvas.drawPath(blastPath, Paint()..shader = blastShader..style = PaintingStyle.fill);

    // 2. 绘制源头极亮曝光区 (强化右侧起点的爆发感)
    final Shader originFlashShader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(0.0)
        ],
        stops: const [0.0, 0.4] // 只占右边一点点
    ).createShader(shaderRect);
    canvas.drawRect(shaderRect, Paint()..shader = originFlashShader);

    // 💡 3. 散落的高能火花线，从右侧核心向左射出
    final Paint sparkPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.9)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    int sparkCount = random.nextInt(6) + 4; // 随机火花条数
    for (int i = 0; i < sparkCount; i++) {
      double sparkY = random.nextDouble() * size.height;
      // 起点大部分集中在右侧 (交界处)
      double sparkX = size.width - random.nextDouble() * (size.width * 0.4);
      // 长度向左延伸
      double length = random.nextDouble() * 60 + 20;

      canvas.drawLine(Offset(sparkX, sparkY), Offset(sparkX - length, sparkY), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter oldDelegate) => true;
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