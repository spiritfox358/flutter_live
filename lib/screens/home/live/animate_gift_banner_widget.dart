import 'dart:async';

import 'package:flutter/material.dart';
import 'animate_gift_item.dart';
import 'models/live_models.dart';

class AnimatedGiftBannerWidget extends State<AnimatedGiftItem>
    with TickerProviderStateMixin {
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
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_entryController);

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.3, end: 1.0).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut),
    );

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
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildPremiumGiftBanner(widget.giftEvent),
      ),
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
            padding: const EdgeInsets.only(left: 2, right: 4),
            decoration: BoxDecoration(
              // 🟢 核心修改：使用粉橙色渐变，比黑色更醒目，减少视觉干扰
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF0080).withOpacity(0.8), // 左侧：醒目的洋红色
                  const Color(0xFFFF8C00).withOpacity(0.5), // 右侧：过渡到橙色/透明
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              // 边框稍微亮一点，增加质感
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. 头像
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white24, // 头像加载前的底色
                  backgroundImage: NetworkImage(
                    'https://picsum.photos/seed/myAvatar/200',
                  ),
                ),

                const SizedBox(width: 4),

                // B. 文字信息
                Column(
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
                    ),
                    Text(
                      "送出 ${gift.giftName}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95), // 提高亮度
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),

                // C. 礼物图标
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

          // ==============================
          // 2. 连击数字 (纯白、基线对齐)
          // ==============================
          ScaleTransition(
            scale: _scaleAnimation,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  "x",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  "${gift.count}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
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
