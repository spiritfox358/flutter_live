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
        _entryController.reverse().then((_) => widget.onFinished());
      }
    });
  }

  // 🟢 新增：当礼物横幅被移出屏幕时，立刻叫停所有动画
  @override
  void deactivate() {
    _entryController.stop();
    _comboController.stop();
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

    if (count < 3) {
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
    return Container(
      // 底部间距
      margin: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==============================
          // 1. 紧凑型胶囊 (带炫彩渐变背景)
          // ==============================
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 2, right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // 🟢 核心修改：直接传入当前的连击数，动态获取颜色
                colors: _getGradientColors(gift.count),
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. 头像
                CircleAvatar(radius: 15, backgroundColor: Colors.white24, backgroundImage: NetworkImage(gift.senderAvatar)),

                const SizedBox(width: 6), // 间距稍微拉大一点点
                // B. 文字信息 (🟢 核心修改：增加宽度限制)
                Container(
                  constraints: const BoxConstraints(maxWidth: 60), // 🟢 限制最大宽度，防止名字太长
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 用户名
                      Text(
                        gift.senderName,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1, // 🟢 单行
                        overflow: TextOverflow.ellipsis, // 🟢 超出显示省略号
                      ),
                      // 送出礼物名
                      Text(
                        "送出 ${gift.giftName}",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 9),
                        maxLines: 1, // 🟢 单行
                        overflow: TextOverflow.ellipsis, // 🟢 超出显示省略号
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
                    offset: const Offset(0, 1), // 向下移动1像素（按需调整）
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
                    offset: const Offset(0, 5), // 向下移动1像素（按需调整）
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
