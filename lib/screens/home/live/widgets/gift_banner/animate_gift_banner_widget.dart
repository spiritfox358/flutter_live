import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/live_models.dart';
import 'animate_gift_item.dart';

class AnimatedGiftBannerWidget extends State<AnimatedGiftItem> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _comboController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _stayTimer;
  Timer? _safeGuardTimer; // 🆕 安全守护定时器

  // 🆕 状态标记
  bool _isDisposed = false;
  bool _isCleaningUp = false;
  bool _hasCalledOnFinished = false;
  Completer<void>? _exitCompleter;

  final Duration _displayDuration = const Duration(seconds: 4);
  final Duration _safeGuardDuration = const Duration(seconds: 8); // 🆕 8秒安全守护

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener((status) {
      // 🆕 监听动画状态
      if (status == AnimationStatus.dismissed && !_hasCalledOnFinished) {
        _safeCallOnFinished();
      }
    });

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_entryController);

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.3, end: 1.0).animate(
        CurvedAnimation(parent: _comboController, curve: Curves.elasticOut)
    );

    _entryController.forward();
    _comboController.forward(from: 0.0);

    // 🆕 启动安全守护定时器
    _safeGuardTimer = Timer(_safeGuardDuration, _forceCleanup);

    _startStayTimer();
  }

  @override
  void didUpdateWidget(AnimatedGiftItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.giftEvent.count > oldWidget.giftEvent.count) {
      _restartTimers();
      _comboController.forward(from: 0.0);
    }
  }

  void _startStayTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer(_displayDuration, _startExitAnimation);
  }

  void _startExitAnimation() {
    if (_isDisposed || _hasCalledOnFinished) return;

    // 🆕 使用Completer确保动画完成
    _exitCompleter = Completer<void>();
    _entryController.reverse().then((_) {
      if (!_exitCompleter!.isCompleted) {
        _exitCompleter!.complete();
      }
      _safeCallOnFinished();
    }).catchError((_) {
      // 动画出错时也调用完成
      _safeCallOnFinished();
    });

    // 🆕 设置一个超时，防止动画卡住
    _exitCompleter!.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {
        _safeCallOnFinished();
        return null;
      },
    );
  }

  void _restartTimers() {
    _stayTimer?.cancel();
    _safeGuardTimer?.cancel();

    _startStayTimer();

    // 🆕 重启安全守护定时器
    _safeGuardTimer = Timer(_safeGuardDuration, _forceCleanup);
  }

  // 🆕 强制清理
  void _forceCleanup() {
    if (_isDisposed || _isCleaningUp) return;

    _isCleaningUp = true;

    // 立即停止所有动画
    if (_entryController.isAnimating) {
      _entryController.stop();
    }
    if (_comboController.isAnimating) {
      _comboController.stop();
    }

    // 取消所有定时器
    _stayTimer?.cancel();
    _safeGuardTimer?.cancel();

    // 如果还没调用onFinished，立即调用
    if (!_hasCalledOnFinished) {
      _hasCalledOnFinished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFinished();
        }
      });
    }

    _isCleaningUp = false;
  }

  void _safeCallOnFinished() {
    if (_isDisposed || _hasCalledOnFinished) return;

    _hasCalledOnFinished = true;

    // 🆕 下一帧再调用，避免在当前动画帧中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        widget.onFinished();
      }
    });
  }

  @override
  void deactivate() {
    _forceCleanup();
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _stayTimer?.cancel();
    _safeGuardTimer?.cancel();

    if (_exitCompleter != null && !_exitCompleter!.isCompleted) {
      _exitCompleter?.complete();  // 完成Completer
    }

    _entryController.dispose();
    _comboController.dispose();

    _stayTimer = null;
    _safeGuardTimer = null;

    super.dispose();
  }

  // 🆕 添加这个方法，让父组件可以手动触发清理
  void exit() {
    _forceCleanup();
  }

  List<Color> _getGradientColors(int count) {
    final baseLeft = const Color(0xFFFF0080).withOpacity(0.8);
    final baseRight = const Color(0xFFFF8C00).withOpacity(0.5);
    final redLeft = const Color(0xFFFF0000).withOpacity(0.95);
    final redRight = const Color(0xFFCC0000).withOpacity(0.85);
    final darkLeft = const Color(0xFF8B0000).withOpacity(0.95);
    final darkRight = const Color(0xFF1A0000).withOpacity(0.90);

    if (count < 30000) {
      return [baseLeft, baseRight];
    } else if (count <= 10) {
      double t = (count - 3) / 7.0;
      return [
        Color.lerp(baseLeft, redLeft, t)!,
        Color.lerp(baseRight, redRight, t)!,
      ];
    } else if (count <= 100) {
      double t = (count - 10) / 90.0;
      return [
        Color.lerp(redLeft, darkLeft, t)!,
        Color.lerp(redRight, darkRight, t)!,
      ];
    } else {
      return [darkLeft, darkRight];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildPremiumGiftBanner(widget.giftEvent),
      ),
    );
  }

  Widget _buildPremiumGiftBanner(GiftEvent gift) {
    final List<Color> dynamicColors = _getGradientColors(gift.count);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 2, right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dynamicColors[0],
                  dynamicColors[1],
                  dynamicColors[1].withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white24,
                  backgroundImage: NetworkImage(gift.senderAvatar),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(maxWidth: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gift.senderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "送出 ${gift.giftName}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Image.network(
                  gift.giftIconUrl,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: const Offset(0, 1),
                    child: const Text(
                      "x",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: const Offset(0, 5),
                    child: Text(
                      "${gift.count}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}