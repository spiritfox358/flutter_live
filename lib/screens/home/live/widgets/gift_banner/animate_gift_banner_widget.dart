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

  // 停留时间 4 秒
  final Duration _displayDuration = const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_entryController);

    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.3, end: 1.0).animate(CurvedAnimation(parent: _comboController, curve: Curves.elasticOut));

    _entryController.forward();
    _comboController.forward(from: 0.0);
    _startTimer();
  }

  @override
  void didUpdateWidget(AnimatedGiftItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.giftEvent.count > oldWidget.giftEvent.count) {
      _startTimer();
      _comboController.forward(from: 0.0);
    }
  }

  void _startTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer(_displayDuration, () {
      if (mounted) {
        _entryController.reverse().then((_) {
          // 🚨 终极防线：在 300ms 倒放动画结束后，必须再次检查组件是否存活！
          if (mounted) {
            widget.onFinished();
          }
        });
      }
    });
  }

  // 🟢 新增：当礼物横幅被移出屏幕时，立刻叫停所有动画
  @override
  void deactivate() {
    // 1. 组件准备移出屏幕时，立刻叫停所有动画！
    if (_entryController.isAnimating) _entryController.stop();
    // 如果有连击动画也停掉
    if (_comboController.isAnimating) _comboController.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _comboController.dispose();
    _stayTimer?.cancel();
    super.dispose();
  }

  // 🟢 新增：根据连击数量动态计算平滑过渡的渐变色
  List<Color> _getGradientColors(int count) {
    // 1. 基础色 (1-2连击)：洋红过渡到橙色
    final baseLeft = const Color(0xFFFF0080).withOpacity(0.8);
    final baseRight = const Color(0xFFFF8C00).withOpacity(0.5);

    // 2. 纯红色 (10连击时达到极致)：鲜红过渡到深红
    final redLeft = const Color(0xFFFF0000).withOpacity(0.95);
    final redRight = const Color(0xFFCC0000).withOpacity(0.85);

    // 3. 红黑色 (100连击及以上)：暗红过渡到纯黑
    final darkLeft = const Color(0xFF8B0000).withOpacity(0.95);
    final darkRight = const Color(0xFF1A0000).withOpacity(0.90);

    if (count < 30000) {
      // 3连击以下保持基础色
      return [baseLeft, baseRight];
    } else if (count <= 10) {
      // 3-10连击之间，根据进度比例 (0.0 ~ 1.0) 平滑过渡到红色
      double t = (count - 3) / 7.0;
      return [
        Color.lerp(baseLeft, redLeft, t)!,
        Color.lerp(baseRight, redRight, t)!,
      ];
    } else if (count <= 100) {
      // 10-100连击之间，根据进度比例平滑过渡到红黑色
      double t = (count - 10) / 90.0;
      return [
        Color.lerp(redLeft, darkLeft, t)!,
        Color.lerp(redRight, darkRight, t)!,
      ];
    } else {
      // 超过100，保持红黑终极形态
      return [darkLeft, darkRight];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: _buildPremiumGiftBanner(widget.giftEvent)),
    );
  }

  Widget _buildPremiumGiftBanner(GiftEvent gift) {
    // 🟢 1. 先拿到原本根据连击数算出来的两种颜色
    final List<Color> dynamicColors = _getGradientColors(gift.count);

    return Container(
      // 底部间距
      margin: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==============================
          // 1. 紧凑型胶囊 (带炫彩渐变背景 -> 右侧透明)
          // ==============================
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 2, right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // 🟢 核心修改 1：加入透明颜色，实现拖尾渐变
                colors: [
                  dynamicColors[0], // 左侧原色
                  dynamicColors[1], // 中间原色
                  dynamicColors[1].withOpacity(0.0), // 右侧渐变到完全透明 (0.0)
                ],
                // 🟢 核心修改 2：控制渐变的位置。0.0 ~ 0.5 是实体色，0.5 ~ 1.0 逐渐变透明
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              // 🟢 核心修改 3：必须把这里的边框注释掉！否则右边透明了，白色的边框线还在，会很丑
              // border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. 头像
                CircleAvatar(radius: 15, backgroundColor: Colors.white24, backgroundImage: NetworkImage(gift.senderAvatar)),

                const SizedBox(width: 6),
                // B. 文字信息
                Container(
                  constraints: const BoxConstraints(maxWidth: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 用户名
                      Text(
                        gift.senderName,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 送出礼物名
                      Text(
                        "送出 ${gift.giftName}",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // C. 礼物图标
                Image.network(gift.giftIconUrl, width: 30, height: 30, fit: BoxFit.contain),
              ],
            ),
          ),

          const SizedBox(width: 5),

          // ==============================
          // 2. 连击数字
          // ==============================
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
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
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
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
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
