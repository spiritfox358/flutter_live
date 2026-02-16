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

  @override
  void dispose() {
    _entryController.dispose();
    _comboController.dispose();
    _stayTimer?.cancel();
    super.dispose();
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
            padding: const EdgeInsets.only(left: 2, right: 8), // 右侧padding稍微加大一点，避免文字贴边
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF0080).withOpacity(0.8), // 左侧：醒目的洋红色
                  const Color(0xFFFF8C00).withOpacity(0.5), // 右侧：过渡到橙色/透明
                ],
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
                  constraints: const BoxConstraints(maxWidth: 80), // 🟢 限制最大宽度，防止名字太长
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
